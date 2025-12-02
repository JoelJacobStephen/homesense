import 'dart:async';
import 'dart:math' as math;
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

class _GoToRoomPageState extends State<GoToRoomPage>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _reading = false;
  bool _uploading = false;
  bool _completedForRoom = false;
  int _secondsLeft = 60;
  Timer? _countdownTimer;
  Timer? _scanTimer;

  late AnimationController _pulseController;

  final List<double> _collectedSamples = [];
  int _windowStart = 0;

  final ApiService _api = ApiService();

  BeaconRoomAssignment get _currentAssignment => widget.assignments[_index];
  String get _currentRoom => _currentAssignment.room;
  String get _currentBeaconAddress => _currentAssignment.beacon.address;
  bool get _isLast => _index >= widget.assignments.length - 1;

  // Room icons mapping
  IconData _getRoomIcon(String room) {
    switch (room.toLowerCase()) {
      case 'bedroom':
      case 'bedroom 2':
      case 'guest room':
        return Icons.bed_rounded;
      case 'bathroom':
        return Icons.bathtub_rounded;
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'dining room':
        return Icons.dining_rounded;
      case 'living room':
        return Icons.weekend_rounded;
      case 'home theatre':
        return Icons.tv_rounded;
      case 'game room':
        return Icons.sports_esports_rounded;
      case 'fireplace':
        return Icons.fireplace_rounded;
      default:
        return Icons.room_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scanTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startReading() async {
    if (_reading || _completedForRoom) return;

    final ok = await BluetoothService.ensurePermissions();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bluetooth permissions required'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _reading = true;
      _secondsLeft = 60;
      _collectedSamples.clear();
      _windowStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    });

    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_reading) return;
      await _collectSample();
    });

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
      debugPrint('Scan error during calibration: $e');
    }
  }

  Future<void> _onReadingComplete() async {
    setState(() {
      _reading = false;
      _uploading = true;
    });

    final windowEnd = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      if (_collectedSamples.isEmpty) {
        throw Exception(
            'No RSSI samples collected. Make sure the beacon is nearby.');
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _next() async {
    if (!_completedForRoom) return;

    if (_isLast) {
      await _finishCalibration();
    } else {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
                'Finalizing...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Computing room signatures.\nThis will just take a moment.',
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
      ),
    );

    try {
      await _api.fitCalibration();

      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38B2AC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF38B2AC),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'All set!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your ${widget.assignments.length} room${widget.assignments.length != 1 ? 's have' : ' has'} been calibrated successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();

                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('calibrated', true);
                      } catch (_) {}

                      if (!mounted) return;

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                    },
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to compute centroids: $e'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and step indicator row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF4A5568),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          'Step 3 of 3',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.assignments.length,
                  (i) => Container(
                    width: i == _index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i < _index
                          ? const Color(0xFF38B2AC)
                          : i == _index
                              ? const Color(0xFF2D3748)
                              : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Room icon with pulse animation
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_reading) ...[
                              // Outer pulse
                              Transform.scale(
                                scale:
                                    1.0 + (0.3 * math.sin(_pulseController.value * 2 * math.pi)),
                                child: Opacity(
                                  opacity: 1.0 -
                                      math.sin(_pulseController.value * 2 * math.pi)
                                          .abs() *
                                          0.7,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38B2AC)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Main icon container
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: _completedForRoom
                                    ? const Color(0xFF38B2AC).withOpacity(0.1)
                                    : const Color(0xFFF7FAFC),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: _completedForRoom
                                      ? const Color(0xFF38B2AC)
                                      : _reading
                                          ? const Color(0xFF38B2AC)
                                              .withOpacity(0.3)
                                          : const Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _completedForRoom
                                    ? Icons.check_rounded
                                    : _getRoomIcon(_currentRoom),
                                size: 44,
                                color: _completedForRoom
                                    ? const Color(0xFF38B2AC)
                                    : const Color(0xFF4A5568),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Room name
                    Text(
                      _currentRoom,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A202C),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Room ${_index + 1} of ${widget.assignments.length}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[500],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Status card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _reading
                            ? const Color(0xFFF0FFF4)
                            : _completedForRoom
                                ? const Color(0xFFF0FFF4)
                                : const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _reading || _completedForRoom
                              ? const Color(0xFF38B2AC).withOpacity(0.3)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (!_reading &&
                              !_uploading &&
                              !_completedForRoom) ...[
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.grey[400],
                              size: 28,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Stand in the center of the room',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We\'ll collect signal data for 60 seconds.\nPlease stay still during calibration.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (_reading) ...[
                            // Countdown timer
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: (60 - _secondsLeft) / 60,
                                    strokeWidth: 6,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF38B2AC),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      '$_secondsLeft',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Collecting data...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_collectedSamples.length} samples',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                          if (_uploading) ...[
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF38B2AC),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Uploading data...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (_completedForRoom) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF38B2AC),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Room calibrated!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF38B2AC),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_collectedSamples.length} samples collected',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                    if (!_reading && !_uploading && !_completedForRoom)
                      ElevatedButton(
                        onPressed: _startReading,
                        child: const Text('Start Calibration'),
                      ),
                    if (_reading)
                      ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38B2AC),
                        ),
                        child: const Text('Calibrating...'),
                      ),
                    if (_completedForRoom)
                      ElevatedButton(
                        onPressed: _next,
                        child: Text(
                            _isLast ? 'Finish Setup' : 'Continue to Next Room'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
