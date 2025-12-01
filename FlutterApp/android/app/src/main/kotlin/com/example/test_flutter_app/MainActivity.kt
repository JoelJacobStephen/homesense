package com.example.test_flutter_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.provider.AlarmClock
import android.bluetooth.BluetoothManager
import android.media.AudioManager
import android.bluetooth.BluetoothClass

class MainActivity : FlutterActivity() {
	private val channelName = "com.homesense/bluetooth"
	private val systemChannelName = "com.homesense/system"
	private val TIMER_TAG = "HomeSenseTimer"
	private lateinit var channel: MethodChannel
	private lateinit var systemChannel: MethodChannel

	private var permissionResult: MethodChannel.Result? = null
	private var scanResult: MethodChannel.Result? = null
	private var receiverRegistered = false
	private var discoveryReceiver: BroadcastReceiver? = null
	private var bleScanner: BluetoothLeScanner? = null
	private var bleScanCallback: ScanCallback? = null

	private val foundDevices = linkedMapOf<String, BluetoothDevice>() // address -> device
    private val rssiByAddress = mutableMapOf<String, Int>() // latest RSSI per device
    private val connectedAddresses = mutableSetOf<String>() // addresses of actively connected devices
    
    // Default RSSI for connected devices that aren't found during scan
    // Connected devices are typically very close, so we assume a strong signal
    companion object {
        const val CONNECTED_DEVICE_DEFAULT_RSSI = -45
    }
    
    /**
     * Check if a BluetoothDevice is currently connected.
     * Uses multiple strategies for maximum compatibility across Android versions.
     */
    private fun isDeviceConnected(device: BluetoothDevice): Boolean {
        // Strategy 1: Try reflection to call isConnected()
        try {
            val method = device.javaClass.getMethod("isConnected")
            val result = method.invoke(device) as? Boolean
            if (result == true) return true
        } catch (_: Throwable) {}
        
        // Strategy 2: Check if this is an audio device and Bluetooth audio is active
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val isBluetoothAudioOn = audioManager.isBluetoothA2dpOn || audioManager.isBluetoothScoOn
            
            if (isBluetoothAudioOn) {
                // Check if this device is an audio device (headphones, speaker, etc.)
                val deviceClass = device.bluetoothClass
                if (deviceClass != null) {
                    val majorClass = deviceClass.majorDeviceClass
                    val deviceClassInt = deviceClass.deviceClass
                    
                    // Audio device classes
                    val isAudioDevice = majorClass == BluetoothClass.Device.Major.AUDIO_VIDEO ||
                        deviceClassInt == BluetoothClass.Device.AUDIO_VIDEO_HEADPHONES ||
                        deviceClassInt == BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET ||
                        deviceClassInt == BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE ||
                        deviceClassInt == BluetoothClass.Device.AUDIO_VIDEO_LOUDSPEAKER ||
                        deviceClassInt == BluetoothClass.Device.AUDIO_VIDEO_PORTABLE_AUDIO
                    
                    if (isAudioDevice) {
                        // This audio device is likely the one connected since Bluetooth audio is active
                        return true
                    }
                }
            }
        } catch (_: Throwable) {}
        
        // Strategy 3: Check profile connection state (fallback)
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            val a2dpState = adapter.getProfileConnectionState(BluetoothProfile.A2DP)
            val headsetState = adapter.getProfileConnectionState(BluetoothProfile.HEADSET)
            
            // If A2DP or Headset is connected, and this is an audio device, assume it's this one
            if (a2dpState == BluetoothProfile.STATE_CONNECTED || 
                headsetState == BluetoothProfile.STATE_CONNECTED) {
                val deviceClass = device.bluetoothClass
                if (deviceClass != null) {
                    val majorClass = deviceClass.majorDeviceClass
                    if (majorClass == BluetoothClass.Device.Major.AUDIO_VIDEO) {
                        return true
                    }
                }
            }
        } catch (_: Throwable) {}
        
        return false
    }

	private val permissions31 = arrayOf(
		Manifest.permission.BLUETOOTH_SCAN,
		Manifest.permission.BLUETOOTH_CONNECT,
		Manifest.permission.ACCESS_FINE_LOCATION
	)
	private val permissionsPre31 = arrayOf(
		Manifest.permission.ACCESS_FINE_LOCATION,
		Manifest.permission.ACCESS_COARSE_LOCATION
	)

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
		channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
			when (call.method) {
				"ensurePermissions" -> handleEnsurePermissions(result)
				"scanDevices" -> handleScanDevices(result)
				"checkLocationEnabled" -> {
					try {
						val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
						val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
							lm.isLocationEnabled
						} else {
							lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
						}
						result.success(enabled)
					} catch (e: Throwable) {
						result.error("loc_error", e.message, null)
					}
				}
				"openLocationSettings" -> {
					try {
						val intent = Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
						intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
						startActivity(intent)
						result.success(true)
					} catch (e: Throwable) {
						result.error("loc_settings_error", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
		systemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemChannelName)
		systemChannel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
			when (call.method) {
				"openTimer" -> {
					// Enhanced multi-attempt strategy for broader OEM coverage (Samsung, Pixel, etc.)
					val candidateLengths = listOf(60, 300) // 1 min & 5 min
					val timerIntents = candidateLengths.map { len ->
						Intent(AlarmClock.ACTION_SET_TIMER).apply {
							putExtra(AlarmClock.EXTRA_LENGTH, len)
							putExtra(AlarmClock.EXTRA_SKIP_UI, false)
							putExtra(AlarmClock.EXTRA_MESSAGE, "HomeSense Timer")
						}
					}
					val showIntents = listOf(
						Intent(AlarmClock.ACTION_SHOW_TIMERS),
						Intent(AlarmClock.ACTION_SHOW_ALARMS)
					)
					val clockPackages = listOf(
						"com.google.android.deskclock", // Pixel / Google Clock
						"com.android.deskclock",       // AOSP
						"com.sec.android.app.clockpackage" // Samsung Clock
					)
					fun tryLaunchIntent(intent: Intent): Boolean {
						return try {
							val resolved = intent.resolveActivity(packageManager)
							if (resolved != null) {
								intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
								startActivity(intent)
								true
							} else false
						} catch (_: Throwable) {
							false
						}
					}
					var launched = false
					for (ti in timerIntents) {
						if (tryLaunchIntent(ti)) { launched = true; break }
					}
					if (!launched) {
						for (si in showIntents) {
							if (tryLaunchIntent(si)) { launched = true; break }
						}
					}
					if (!launched) {
						for (pkg in clockPackages) {
							try {
								val launch = packageManager.getLaunchIntentForPackage(pkg)
								if (launch != null) {
									launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
									startActivity(launch)
									launched = true
									break
								}
							} catch (_: Throwable) {}
						}
					}
					if (launched) {
						result.success(true)
					} else {
						result.error("timer_error", "Unable to open any clock/timer activity", null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun hasAllPermissions(): Boolean {
		return if (Build.VERSION.SDK_INT >= 31) {
			permissions31.all { ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }
		} else {
			permissionsPre31.all { ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }
		}
	}

	private fun handleEnsurePermissions(result: MethodChannel.Result) {
		if (hasAllPermissions()) {
			result.success(true)
			return
		}
		val perms = if (Build.VERSION.SDK_INT >= 31) permissions31 else permissionsPre31
		permissionResult = result
		ActivityCompat.requestPermissions(this, perms, 1001)
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == 1001) {
			val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
			permissionResult?.success(granted)
			permissionResult = null
		}
	}

	private fun handleScanDevices(result: MethodChannel.Result) {
		val adapter = BluetoothAdapter.getDefaultAdapter()
		if (adapter == null) {
			result.error("unavailable", "Bluetooth not supported", null)
			return
		}
		if (!hasAllPermissions()) {
			result.error("no_permission", "Bluetooth permissions not granted", null)
			return
		}
		if (!adapter.isEnabled) {
			// Ask user to enable Bluetooth. We don't await result here.
			val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
			try { startActivity(enableBtIntent) } catch (_: Throwable) {}
			result.error("bt_off", "Bluetooth is turned off", null)
			return
		}

		scanResult = result
		foundDevices.clear()
		connectedAddresses.clear()

		// Pre-populate with already bonded/paired devices so user always sees connectable devices.
		// Also check if each bonded device is currently connected (for headphones, etc.)
		try {
			adapter?.bondedDevices?.forEach { d ->
				val addr = d.address ?: return@forEach
				if (!foundDevices.containsKey(addr)) {
					foundDevices[addr] = d
				}
				
				// Check if this bonded device is currently connected
				// Connected devices (like headphones streaming audio) may not appear in scans
				if (isDeviceConnected(d)) {
					connectedAddresses.add(addr)
					// Assign default RSSI for connected devices since they're assumed to be nearby
					if (!rssiByAddress.containsKey(addr)) {
						rssiByAddress[addr] = CONNECTED_DEVICE_DEFAULT_RSSI
					}
				}
			}
		} catch (_: Throwable) {}

		val receiver = object : BroadcastReceiver() {
			override fun onReceive(context: Context?, intent: Intent?) {
				if (intent == null) return
				if (intent.action == BluetoothDevice.ACTION_FOUND) {
					val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
					device?.let {
						val addr = it.address ?: return
						foundDevices[addr] = it
						// Classic discovery RSSI
						try {
							val rssiShort = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
							if (rssiShort != Short.MIN_VALUE) {
								rssiByAddress[addr] = rssiShort.toInt()
							}
						} catch (_: Throwable) {}
					}
				}
			}
		}

		// Register receiver (only ACTION_FOUND; we keep scanning full duration)
		if (!receiverRegistered) {
			val filter = IntentFilter().apply {
				addAction(BluetoothDevice.ACTION_FOUND)
			}
			registerReceiver(receiver, filter)
			receiverRegistered = true
			discoveryReceiver = receiver
		}

		// Start / maintain classic discovery for full scan window.
		if (adapter.isDiscovering) adapter.cancelDiscovery()
		adapter.startDiscovery()

		// Start BLE scan (Android 5.0+). Some beacons only appear via BLE.
		try {
			bleScanner = adapter.bluetoothLeScanner
			if (bleScanner != null) {
				bleScanCallback = object : ScanCallback() {
					override fun onScanResult(callbackType: Int, result: ScanResult?) {
						val device = result?.device ?: return
						val addr = device.address ?: return
						foundDevices[addr] = device
                        // BLE RSSI
                        try {
                            rssiByAddress[addr] = result.rssi
                        } catch (_: Throwable) {}
					}
					override fun onBatchScanResults(results: MutableList<ScanResult>?) {
						results.orEmpty().forEach { r ->
							val device = r.device ?: return@forEach
							val addr = device.address ?: return@forEach
							foundDevices[addr] = device
                            try { rssiByAddress[addr] = r.rssi } catch (_: Throwable) {}
						}
					}
					override fun onScanFailed(errorCode: Int) {
						// Ignore; classic discovery may still yield results.
					}
				}
				bleScanner?.startScan(bleScanCallback)
			}
		} catch (_: Throwable) { /* ignore BLE issues */ }

		// Keep restarting classic discovery if it stops before timeout (some stacks auto-stop early)
		val handler = Handler(Looper.getMainLooper())
		val endTime = System.currentTimeMillis() + 10_000
		fun loopCheck() {
			if (System.currentTimeMillis() >= endTime) {
				finishScan(); return
			}
			try {
				val a = BluetoothAdapter.getDefaultAdapter()
				if (a != null && !a.isDiscovering) {
					@Suppress("MissingPermission")
					a.startDiscovery()
				}
			} catch (_: Throwable) {}
			handler.postDelayed({ loopCheck() }, 1500) // poll every 1.5s
		}
		loopCheck()
	}

	private fun finishScan() {
		val adapter = BluetoothAdapter.getDefaultAdapter()
		try {
			if (adapter != null && adapter.isDiscovering) adapter.cancelDiscovery()
		} catch (_: Throwable) {}

		// Stop BLE scan
		try { bleScanner?.stopScan(bleScanCallback) } catch (_: Throwable) {}
		bleScanCallback = null
		bleScanner = null

		// For connected devices that weren't found in scan, use default RSSI
		// This ensures we can still detect headphones/devices that are connected but not advertising
		connectedAddresses.forEach { addr ->
			if (!rssiByAddress.containsKey(addr) || rssiByAddress[addr] == null) {
				rssiByAddress[addr] = CONNECTED_DEVICE_DEFAULT_RSSI
			}
		}

		val list = foundDevices.values.map {
            val addr = it.address
            var rssiVal = try { rssiByAddress[addr] } catch (_: Throwable) { null }
            
            // If device is connected but has no RSSI, use default
            if (rssiVal == null && connectedAddresses.contains(addr)) {
                rssiVal = CONNECTED_DEVICE_DEFAULT_RSSI
            }
            
            mapOf(
                "name" to (it.name ?: "Unknown"),
                "address" to addr,
                "rssi" to rssiVal,
                "connected" to connectedAddresses.contains(addr)  // Include connection status for debugging
            )
        }
		scanResult?.success(list)
		scanResult = null
	}

	override fun onDestroy() {
		super.onDestroy()
		if (receiverRegistered) {
			try { discoveryReceiver?.let { unregisterReceiver(it) } } catch (_: Throwable) {}
			receiverRegistered = false
			discoveryReceiver = null
		}
	}
}
