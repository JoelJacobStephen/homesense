import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../services/api_service.dart';
import '../services/location_tracker.dart';
import '../services/action_service.dart';

class SuggestionsPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  
  const SuggestionsPage({super.key, this.onOpenDrawer});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> with WidgetsBindingObserver {
  bool _loading = true;
  String? _currentRoom;
  double? _confidence;
  Map<String, dynamic>? _suggestion;
  String? _error;

  // Auto-refresh timer
  Timer? _refreshTimer;
  bool _autoRefreshEnabled = true;
  static const _refreshInterval = Duration(seconds: 15);

  // Debug mode
  bool _debugMode = false;
  List<Map<String, dynamic>>? _lastReadings;

  // Services
  final ApiService _api = ApiService();
  late final LocationTracker _locationTracker;

  // User preferences (loaded from SharedPreferences)
  List<String>? _userPrefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationTracker = LocationTracker(api: _api);
    _loadUserPrefs();
    _runInferenceAndSuggest();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    // Flush any pending dwell events
    _locationTracker.flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
      _locationTracker.flush();
    } else if (state == AppLifecycleState.resumed) {
      if (_autoRefreshEnabled) {
        _startAutoRefresh();
      }
    }
  }

  Future<void> _loadUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getStringList('user_prefs');
      if (prefsJson != null && prefsJson.isNotEmpty) {
        setState(() {
          _userPrefs = prefsJson;
        });
      }
    } catch (_) {
      // Ignore errors
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (_autoRefreshEnabled) {
      _refreshTimer = Timer.periodic(_refreshInterval, (_) {
        if (mounted && !_loading) {
          _runInferenceAndSuggest(showLoading: false);
        }
      });
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;
    });
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  Future<void> _runInferenceAndSuggest({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Ensure permissions and scan
      final ok = await BluetoothService.ensurePermissions();
      if (!ok) {
        throw Exception('Bluetooth permissions not granted');
      }

      final readings = await BluetoothService.scanReadings();
      _lastReadings = readings; // Store for debug display
      if (readings.isEmpty) {
        throw Exception('No beacon readings found');
      }

      final inferRes = await _api.infer(readings);
      final room = (inferRes['room'] as String?) ?? 'unknown';
      final conf = (inferRes['confidence'] as num?)?.toDouble() ?? 0.0;

      // Update location tracker (this may log dwell events)
      await _locationTracker.onInferenceResult(room, conf);

      _currentRoom = room;
      _confidence = conf;

      // Build local time string like "Sat 08:30"
      final now = DateTime.now();
      final day = DateFormat('EEE').format(now);
      final hm = DateFormat('HH:mm').format(now);
      final localTime = '$day $hm';

      final suggestion = await _api.suggest(
        room: room,
        localTime: localTime,
        recentRooms: _locationTracker.recentRooms.isNotEmpty
            ? _locationTracker.recentRooms
            : null,
        userPrefs: _userPrefs,
      );

      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _executeAction(String action) async {
    final ok = await ActionService.executeAction(action);
    if (!mounted) return;
    if (!ok) {
      final actionType = ActionService.getActionType(action);
      String message;
      if (actionType == ActionType.smartHome) {
        message = 'Smart home action: "$action" requires device integration.';
      } else {
        message = 'Unable to open "$action" on this device.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Open menu',
              )
            : null,
        title: const Text('HomeSense'),
        actions: [
          // Debug toggle
          IconButton(
            icon: Icon(
              Icons.bug_report,
              color: _debugMode ? Colors.orange : null,
            ),
            onPressed: () => setState(() => _debugMode = !_debugMode),
            tooltip: _debugMode ? 'Debug ON' : 'Debug OFF',
          ),
          // Auto-refresh toggle
          IconButton(
            icon: Icon(
              _autoRefreshEnabled ? Icons.sync : Icons.sync_disabled,
              color: _autoRefreshEnabled ? null : Colors.grey,
            ),
            onPressed: _toggleAutoRefresh,
            tooltip: _autoRefreshEnabled ? 'Auto-refresh ON' : 'Auto-refresh OFF',
          ),
          // Manual refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _runInferenceAndSuggest(),
            tooltip: 'Refresh now',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location card
            _buildLocationCard(),
            const SizedBox(height: 20),

            // Debug panel (shows detected beacons)
            if (_debugMode) ...[
              _buildDebugPanel(),
              const SizedBox(height: 20),
            ],

            // Suggestions header
            Text(
              'Recommended for you',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // Content
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _runInferenceAndSuggest,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_suggestion != null)
              Expanded(
                child: ListView(
                  children: [
                    // Activity inference
                    if (_suggestion!['likely_activity'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Likely activity: ${_suggestion!['likely_activity']}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    // Main suggestion
                    _SuggestionTile(
                      icon: Icons.lightbulb_outline,
                      title: _suggestion!['suggestion'] as String? ?? 'No suggestion',
                    ),
                    // Quick actions
                    ...((_suggestion!['quick_actions'] as List?) ?? const [])
                        .cast<String>()
                        .map((qa) => _ActionTile(label: qa, onExecute: _executeAction)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    // Expected beacons from calibration
    const calibratedBeacons = {
      '1C:53:F9:3D:6A:90': ('Living Room', -60.88),
      '08:D2:3E:24:3A:B4': ('Bedroom', -50.4),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Debug: Detected Beacons',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_lastReadings == null || _lastReadings!.isEmpty)
            const Text('No readings yet', style: TextStyle(fontSize: 12))
          else
            ...calibratedBeacons.entries.map((entry) {
              final mac = entry.key;
              final (roomName, calibratedRssi) = entry.value;
              final reading = _lastReadings!.cast<Map<String, dynamic>?>().firstWhere(
                (r) => r?['beacon_id'] == mac,
                orElse: () => null,
              );
              final detected = reading != null;
              final currentRssi = reading?['rssi'] as int?;
              final distance = currentRssi != null
                  ? (currentRssi - calibratedRssi).abs()
                  : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      detected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      size: 16,
                      color: detected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: detected ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          Text(
                            mac,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (detected)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Now: $currentRssi dBm',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Cal: ${calibratedRssi.toStringAsFixed(1)} dBm',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                          Text(
                            'Dist: ${distance?.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: distance != null && distance < 15
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'NOT DETECTED',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            'Lower "Dist" = more likely room. Beacon must be detected to be considered.',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Location',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const Spacer(),
              if (_autoRefreshEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentRoom ?? 'Detecting...',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_confidence != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _confidence!,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _confidence! > 0.7
                            ? Colors.greenAccent
                            : _confidence! > 0.4
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(_confidence! * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.amber[700], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
  final Future<void> Function(String) onExecute;
  const _ActionTile({required this.label, required this.onExecute});

  @override
  Widget build(BuildContext context) {
    final actionType = ActionService.getActionType(label);
    final (icon, color, bgColor) = _getIconAndColors(actionType);
    final isSmartHome = actionType == ActionType.smartHome;

    return GestureDetector(
      onTap: () => onExecute(label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onExecute(label),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (isSmartHome)
                          Text(
                            'Smart home integration needed',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isSmartHome ? Icons.smart_toy_outlined : Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _getIconAndColors(ActionType type) {
    switch (type) {
      case ActionType.browser:
        return (Icons.open_in_browser, Colors.blue[700]!, Colors.blue.withOpacity(0.1));
      case ActionType.calendar:
        return (Icons.calendar_today, Colors.purple[700]!, Colors.purple.withOpacity(0.1));
      case ActionType.clock:
        return (Icons.timer, Colors.orange[700]!, Colors.orange.withOpacity(0.1));
      case ActionType.music:
        return (Icons.music_note, Colors.green[700]!, Colors.green.withOpacity(0.1));
      case ActionType.video:
        return (Icons.play_circle_fill, Colors.red[700]!, Colors.red.withOpacity(0.1));
      case ActionType.tasks:
        return (Icons.checklist, Colors.teal[700]!, Colors.teal.withOpacity(0.1));
      case ActionType.smartHome:
        return (Icons.home_outlined, Colors.grey[600]!, Colors.grey.withOpacity(0.1));
    }
  }
}
