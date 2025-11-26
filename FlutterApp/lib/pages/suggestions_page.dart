import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../services/system_service.dart';
import '../services/bluetooth_service.dart';
import '../services/api_service.dart';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  bool _loading = true;
  String? _currentRoom;
  double? _confidence;
  Map<String, dynamic>? _suggestion; // {likely_activity, suggestion, quick_actions}
  String? _error;

  // Suggestions now fetched from backend

  @override
  void initState() {
    super.initState();
    _runInferenceAndSuggest();
  }

  Future<void> _runInferenceAndSuggest() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Ensure permissions and scan
      final ok = await BluetoothService.ensurePermissions();
      if (!ok) {
        throw Exception('Bluetooth permissions not granted');
      }
      // Recommend user to enable location if needed (not enforced here)
      final readings = await BluetoothService.scanReadings();
      if (readings.isEmpty) {
        throw Exception('No beacon readings found');
      }
      final api = ApiService();
      final inferRes = await api.infer(readings);
      final room = (inferRes['room'] as String?) ?? 'unknown';
      final conf = (inferRes['confidence'] as num?)?.toDouble();
      _currentRoom = room;
      _confidence = conf;

      // Build local time string like "Sat 08:30"
      final now = DateTime.now();
      final day = DateFormat('EEE').format(now);
      final hm = DateFormat('HH:mm').format(now);
      final localTime = '$day $hm';

      final suggestion = await api.suggest(
        room: room,
        localTime: localTime,
        recentRooms: null,
        userPrefs: null,
      );
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _onOpenTimer() async {
    final ok = await SystemService.openTimer();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open timer on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended for you',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _runInferenceAndSuggest,
                  tooltip: 'Refresh',
                )
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            else ...[
              if (_currentRoom != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'You are in: ${_currentRoom!}' +
                        (_confidence != null ? '  (confidence: ${_confidence!.toStringAsFixed(2)})' : ''),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (_suggestion != null)
                Expanded(
                  child: ListView(
                    children: [
                      _SuggestionTile(
                        icon: Icons.lightbulb_outline,
                        title: _suggestion!['suggestion'] as String? ?? 'Suggestion',
                      ),
                      ...((_suggestion!['quick_actions'] as List?) ?? const [])
                          .cast<String>()
                          .map((qa) => _ActionTile(label: qa, onOpenTimer: _onOpenTimer))
                          .toList(),
                    ],
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SuggestionTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final Future<void> Function() onOpenTimer;
  const _ActionTile({required this.label, required this.onOpenTimer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.blueGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (label.toLowerCase().contains('timer'))
              ElevatedButton(
                onPressed: onOpenTimer,
                child: const Text('Open'),
              ),
          ],
        ),
      ),
    );
  }
}
