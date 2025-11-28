import 'package:flutter/material.dart';
import 'dart:io';
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
    if (Platform.isAndroid) {
      BluetoothService.ensurePermissions();
      // After permissions, check if location services are enabled (needed for scans on many devices).
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
      appBar: AppBar(title: const Text('Start Setup')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _scanning ? null : _onChooseDevices,
                  child: Text(_devices.isEmpty
                      ? 'Choose Devices'
                      : 'Choose Devices (${_selectedAddresses.length} selected)'),
                ),
                const SizedBox(height: 24),
                if (_selectedAddresses.isNotEmpty) ...[
                  Text(
                    'Selected devices',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _devices
                        .where((d) => _selectedAddresses.contains(d.address))
                        .map((d) {
                      final label = d.name.isNotEmpty ? d.name : d.address;
                      return Chip(label: Text(label));
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_selectedAddresses.isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      final chosen = _devices
                          .where((d) => _selectedAddresses.contains(d.address))
                          .map((d) => BeaconInfo(address: d.address, name: d.name))
                          .toList(growable: false);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssignRoomsPage(selectedBeacons: chosen),
                        ),
                      );
                    },
                    child: const Text('Next'),
                  ),
              ],
            ),
          ),
        ),
      ),
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
      } catch (_) {} finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      if (devices.isEmpty) {
        await _showInfo(
            'No devices found',
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
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Select Bluetooth Devices'),
            content: SizedBox(
              width: 400,
              height: 360,
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (_, i) {
                    final d = _devices[i];
                    final checked = tempSelected.contains(d.address);
                    return CheckboxListTile(
                      title: Text(d.name.isNotEmpty ? d.name : 'Unknown'),
                      subtitle: Text(d.address),
                      value: checked,
                      onChanged: (v) {
                        if (v == true) {
                          tempSelected.add(d.address);
                        } else {
                          tempSelected.remove(d.address);
                        }
                        setStateDialog(() {});
                      },
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedAddresses
                      ..clear()
                      ..addAll(tempSelected);
                  });
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('OK'),
              ),
            ],
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
              child: const Text('OK'))
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Scanning for Bluetooth devices...\n(This may take up to 10 seconds)',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
