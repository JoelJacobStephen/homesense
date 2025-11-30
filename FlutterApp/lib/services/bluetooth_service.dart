import 'dart:io' show Platform;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class BluetoothDeviceInfo {
  final String name;
  final String address;
  final int? rssi; // dBm (negative), may be null for bonded devices
  BluetoothDeviceInfo({required this.name, required this.address, this.rssi});

  @override
  String toString() => name.isNotEmpty ? '$name ($address)' : address;
}

class BluetoothService {
  static const MethodChannel _channel = MethodChannel('com.homesense/bluetooth');

  // Mock devices for web testing
  static final List<BluetoothDeviceInfo> _mockDevices = [
    BluetoothDeviceInfo(name: 'Living Room Beacon', address: 'AA:BB:CC:DD:EE:01', rssi: -45),
    BluetoothDeviceInfo(name: 'Kitchen Beacon', address: 'AA:BB:CC:DD:EE:02', rssi: -52),
    BluetoothDeviceInfo(name: 'Bedroom Beacon', address: 'AA:BB:CC:DD:EE:03', rssi: -60),
    BluetoothDeviceInfo(name: 'Bathroom Beacon', address: 'AA:BB:CC:DD:EE:04', rssi: -68),
    BluetoothDeviceInfo(name: 'Office Beacon', address: 'AA:BB:CC:DD:EE:05', rssi: -55),
    BluetoothDeviceInfo(name: 'Garage Beacon', address: 'AA:BB:CC:DD:EE:06', rssi: -72),
  ];

  static Future<bool> ensurePermissions() async {
    // On web, return true to allow testing flow
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('ensurePermissions');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BluetoothDeviceInfo>> scanDevices() async {
    // On web, return mock devices for testing
    if (kIsWeb) {
      // Simulate a brief scanning delay
      await Future.delayed(const Duration(seconds: 2));
      return _mockDevices;
    }
    if (!Platform.isAndroid) return [];
    try {
      final list = await _channel.invokeMethod('scanDevices');
      if (list is List) {
        return list.whereType<Map>().map((m) {
          final name = (m['name'] as String?)?.trim() ?? '';
          final address = (m['address'] as String?)?.trim() ?? '';
          final rssi = (m['rssi'] is int) ? m['rssi'] as int : null;
          return BluetoothDeviceInfo(name: name, address: address, rssi: rssi);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // Convenience: transform scan results into readings for inference
  // beacon_id: use MAC address; rssi: use latest RSSI from scan
  static Future<List<Map<String, dynamic>>> scanReadings() async {
    // On web, return simulated readings with some variance
    if (kIsWeb) {
      final random = Random();
      return _mockDevices.map((d) => {
        'beacon_id': d.address,
        'rssi': d.rssi! + random.nextInt(10) - 5, // Add some variance
      }).toList();
    }
    
    final devices = await scanDevices();
    final readings = <Map<String, dynamic>>[];
    for (final d in devices) {
      if (d.rssi != null) {
        readings.add({
          'beacon_id': d.address, // use MAC as stable id
          'rssi': d.rssi,
        });
      }
    }
    return readings;
  }

  static Future<bool> isLocationEnabled() async {
    // On web, return true for testing
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('checkLocationEnabled');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openLocationSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('openLocationSettings');
      return res == true;
    } catch (_) {
      return false;
    }
  }
}
