import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'suggestions_page.dart';

class GoToRoomPage extends StatefulWidget {
  final Map<String, String> assignments;
  const GoToRoomPage({super.key, required this.assignments});

  @override
  State<GoToRoomPage> createState() => _GoToRoomPageState();
}

class _GoToRoomPageState extends State<GoToRoomPage> {
  late final List<String> _rooms;
  int _index = 0;
  bool _reading = false;
  bool _completedForRoom = false;
  int _secondsLeft = 60; // 1 minute gap
  Timer? _timer;

  String get _currentRoom => _rooms.isNotEmpty ? _rooms[_index] : 'Room';
  bool get _isLast => _index >= _rooms.length - 1;

  @override
  void initState() {
    super.initState();
    _rooms = widget.assignments.values.toList(growable: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startReading() {
    if (_reading || _completedForRoom) return;
    setState(() {
      _reading = true;
      _secondsLeft = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _reading = false;
          _completedForRoom = true;
          _secondsLeft = 0;
        });
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  Future<void> _next() async {
    if (!_completedForRoom) return;
    if (_isLast) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Calibration Complete'),
          content: const Text('All rooms have been calibrated.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      if (!mounted) return;
      // Persist calibration flag (best-effort, ignore if plugin not ready)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('calibrated', true);
      } catch (_) {
        // Ignore MissingPluginException during hot restart or early startup
      }
      if (!mounted) return;
      // Defer navigation until after the dialog frame settles
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const _CalibrationLoadingPage()),
        );
      });
      return;
    }
    setState(() {
      _index += 1;
      _reading = false;
      _completedForRoom = false;
      _secondsLeft = 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
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
            const SizedBox(height: 12),
            Text(
              'Please click on the start reading data button once you are in the $_currentRoom. This is important as it is meant for proper calibration of your beacons.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!_reading && !_completedForRoom)
              ElevatedButton(
                onPressed: _startReading,
                child: const Text('Start Reading Data'),
              ),
            if (_reading) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  Text('Reading (${_secondsLeft}s left)'),
                ],
              ),
            ],
            if (_completedForRoom) ...[
              const SizedBox(height: 12),
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(height: 6),
              const Text('Reading complete'),
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
            child: Text(_isLast ? 'Finish' : 'Next'),
          ),
        ),
      ),
    );
  }
}

class _CalibrationLoadingPage extends StatefulWidget {
  const _CalibrationLoadingPage();

  @override
  State<_CalibrationLoadingPage> createState() => _CalibrationLoadingPageState();
}

class _CalibrationLoadingPageState extends State<_CalibrationLoadingPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SuggestionsPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizing')),
      body: const Center(
        child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
      ),
    );
  }
}
