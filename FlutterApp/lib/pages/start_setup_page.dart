import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'assign_rooms_page.dart';
import '../models/beacon_info.dart';
import '../services/bluetooth_service.dart';

class StartSetupPage extends StatefulWidget {
  const StartSetupPage({super.key});

  @override
  State<StartSetupPage> createState() => _StartSetupPageState();
}

class _StartSetupPageState extends State<StartSetupPage> {
  List<BluetoothDeviceInfo> _devices = [];
  final Set<String> _selectedAddresses = {};
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      BluetoothService.ensurePermissions();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final enabled = await BluetoothService.isLocationEnabled();
        if (!enabled && mounted) {
          await _promptEnableLocation();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Step 1 of 3',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select your\nbeacons',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A202C),
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan for nearby Bluetooth devices and choose the beacons you want to use for indoor positioning.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Main content
            Expanded(
              child: _selectedAddresses.isEmpty
                  ? _buildEmptyState()
                  : _buildSelectedDevices(),
            ),

            // Bottom action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[100]!,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedAddresses.isEmpty)
                      ElevatedButton(
                        onPressed: _scanning ? null : _onChooseDevices,
                        child: _scanning
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Scan for Devices'),
                      )
                    else ...[
                      OutlinedButton(
                        onPressed: _scanning ? null : _onChooseDevices,
                        child: const Text('Scan Again'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          final chosen = _devices
                              .where(
                                  (d) => _selectedAddresses.contains(d.address))
                              .map((d) =>
                                  BeaconInfo(address: d.address, name: d.name))
                              .toList(growable: false);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssignRoomsPage(selectedBeacons: chosen),
                            ),
                          );
                        },
                        child: const Text('Continue'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.bluetooth_searching_rounded,
                size: 36,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No devices selected',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to scan\nfor nearby Bluetooth beacons',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDevices() {
    final selectedDevices =
        _devices.where((d) => _selectedAddresses.contains(d.address)).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: selectedDevices.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  '${selectedDevices.length} device${selectedDevices.length != 1 ? 's' : ''} selected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final device = selectedDevices[index - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  color: Color(0xFF38B2AC),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isNotEmpty ? device.name : 'Unknown Device',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedAddresses.remove(device.address);
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onChooseDevices() async {
    setState(() => _scanning = true);
    try {
      final granted = await BluetoothService.ensurePermissions();
      if (!granted) {
        if (!mounted) return;
        await _showInfo('Bluetooth permission required',
            'Please grant Bluetooth permissions to scan nearby devices.');
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _ScanningDialog(),
        );
      }

      List<BluetoothDeviceInfo> devices = [];
      try {
        devices = await BluetoothService.scanDevices();
      } catch (_) {
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      if (devices.isEmpty) {
        await _showInfo('No devices found',
            'No nearby Bluetooth devices were found. Make sure Bluetooth is ON and devices are discoverable, then try again.');
      }

      if (!mounted) return;
      setState(() {
        _devices = devices;
      });

      if (_devices.isNotEmpty && mounted) {
        await _showDevicePicker();
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showDevicePicker() async {
    final tempSelected = Set<String>.from(_selectedAddresses);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Available Devices',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_devices.length} found',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Device list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _devices.length,
                    itemBuilder: (_, i) {
                      final d = _devices[i];
                      final checked = tempSelected.contains(d.address);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: checked
                                ? const Color(0xFF38B2AC).withOpacity(0.1)
                                : const Color(0xFFF7FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.bluetooth,
                            color: checked
                                ? const Color(0xFF38B2AC)
                                : Colors.grey[400],
                            size: 22,
                          ),
                        ),
                        title: Text(
                          d.name.isNotEmpty ? d.name : 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: checked
                                ? const Color(0xFF2D3748)
                                : Colors.grey[700],
                          ),
                        ),
                        subtitle: Text(
                          d.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontFamily: 'monospace',
                          ),
                        ),
                        trailing: Checkbox(
                          value: checked,
                          onChanged: (v) {
                            if (v == true) {
                              tempSelected.add(d.address);
                            } else {
                              tempSelected.remove(d.address);
                            }
                            setStateDialog(() {});
                          },
                          activeColor: const Color(0xFF38B2AC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onTap: () {
                          if (tempSelected.contains(d.address)) {
                            tempSelected.remove(d.address);
                          } else {
                            tempSelected.add(d.address);
                          }
                          setStateDialog(() {});
                        },
                      );
                    },
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[100]!),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: tempSelected.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _selectedAddresses
                                        ..clear()
                                        ..addAll(tempSelected);
                                    });
                                    Navigator.of(dialogCtx).pop();
                                  },
                            child: Text(
                              'Select ${tempSelected.isEmpty ? '' : '(${tempSelected.length})'}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInfo(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<void> _promptEnableLocation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Recommended'),
        content: const Text(
          'Turning on Location improves Bluetooth discovery on many devices.\n\n'
          'If scans return no results, enable Location from the system tray or Settings > Location, then try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _ScanningDialog extends StatelessWidget {
  const _ScanningDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF38B2AC)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scanning...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Looking for nearby devices.\nThis may take a few seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
