import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/beacon_info.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';
import 'home_page.dart';

class GoToRoomPage extends StatefulWidget {
  final List<BeaconRoomAssignment> assignments;
  const GoToRoomPage({super.key, required this.assignments});

  @override
  State<GoToRoomPage> createState() => _GoToRoomPageState();
}

class _GoToRoomPageState extends State<GoToRoomPage> {
  int _index = 0;
  bool _reading = false;
  bool _uploading = false;
  bool _completedForRoom = false;
  int _secondsLeft = 60;
  Timer? _countdownTimer;
  Timer? _scanTimer;

  // Collected RSSI samples for the current beacon
  final List<double> _collectedSamples = [];
  int _windowStart = 0;

  // API service for backend calls
  final ApiService _api = ApiService();

  BeaconRoomAssignment get _currentAssignment => widget.assignments[_index];
  String get _currentRoom => _currentAssignment.room;
  String get _currentBeaconAddress => _currentAssignment.beacon.address;
  bool get _isLast => _index >= widget.assignments.length - 1;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _startReading() async {
    if (_reading || _completedForRoom) return;

    // Ensure Bluetooth permissions
    final ok = await BluetoothService.ensurePermissions();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth permissions required')),
      );
      return;
    }

    setState(() {
      _reading = true;
      _secondsLeft = 60;
      _collectedSamples.clear();
      _windowStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    });

    // Start periodic scanning every 2 seconds
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_reading) return;
      await _collectSample();
    });

    // Start countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        _scanTimer?.cancel();
        _onReadingComplete();
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  Future<void> _collectSample() async {
    try {
      final readings = await BluetoothService.scanReadings();
      // Find the RSSI for our target beacon
      for (final reading in readings) {
        if (reading['beacon_id'] == _currentBeaconAddress) {
          final rssi = reading['rssi'];
          if (rssi != null && rssi is num) {
            _collectedSamples.add(rssi.toDouble());
          }
          break;
        }
      }
    } catch (e) {
      // Silently ignore scan errors during calibration
      debugPrint('Scan error during calibration: $e');
    }
  }

  Future<void> _onReadingComplete() async {
    setState(() {
      _reading = false;
      _uploading = true;
    });

    final windowEnd = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Upload calibration data to backend
    try {
      if (_collectedSamples.isEmpty) {
        throw Exception('No RSSI samples collected. Make sure the beacon is nearby.');
      }

      await _api.uploadCalibration(
        beaconId: _currentBeaconAddress,
        room: _currentRoom,
        rssiSamples: _collectedSamples,
        windowStart: _windowStart,
        windowEnd: windowEnd,
      );

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _completedForRoom = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _startReading,
          ),
        ),
      );
    }
  }

  Future<void> _next() async {
    if (!_completedForRoom) return;

    if (_isLast) {
      // All rooms calibrated - now fit the model
      await _finishCalibration();
    } else {
      // Move to next room
      setState(() {
        _index += 1;
        _reading = false;
        _completedForRoom = false;
        _secondsLeft = 60;
        _collectedSamples.clear();
      });
    }
  }

  Future<void> _finishCalibration() async {
    if (!mounted) return;

    // Show loading dialog while fitting
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Computing centroids...'),
          ],
        ),
      ),
    );

    try {
      // Call fit endpoint to compute centroids
      await _api.fitCalibration();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success dialog
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Calibration Complete'),
          content: Text(
            'All ${widget.assignments.length} room(s) have been calibrated successfully!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );

      // Persist calibration flag
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('calibrated', true);
      } catch (_) {
        // Ignore SharedPreferences errors
      }

      if (!mounted) return;

      // Navigate to home page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to compute centroids: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calibrate Room ${_index + 1}/${widget.assignments.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              'Go to $_currentRoom',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Beacon: ${_currentAssignment.beacon.displayName}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Stand in the center of the room and press the button below. '
              'Stay still for 60 seconds while we collect signal readings.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // State-based UI
            if (!_reading && !_uploading && !_completedForRoom)
              ElevatedButton.icon(
                onPressed: _startReading,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Start Reading Data'),
              ),

            if (_reading) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (60 - _secondsLeft) / 60,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                    ),
                    Center(
                      child: Text(
                        '${_secondsLeft}s',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Samples collected: ${_collectedSamples.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please stay still...',
                style: TextStyle(color: Colors.orange),
              ),
            ],

            if (_uploading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Uploading calibration data...'),
            ],

            if (_completedForRoom) ...[
              const SizedBox(height: 12),
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(
                'Room calibrated!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_collectedSamples.length} samples collected',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _completedForRoom ? _next : null,
            child: Text(_isLast ? 'Finish Calibration' : 'Next Room'),
          ),
        ),
      ),
    );
  }
}
