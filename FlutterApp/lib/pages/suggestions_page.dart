import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../services/api_service.dart';
import '../services/location_tracker.dart';
import '../services/action_service.dart';
import '../services/motion_service.dart';

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

  // Motion detection
  final MotionService _motionService = MotionService.instance;
  MotionState _motionState = MotionState.stationary;
  
  // Periodic scan timer while walking
  Timer? _walkingScanTimer;
  static const _walkingScanInterval = Duration(seconds: 5);
  
  // Fallback timer (in case motion detection doesn't trigger)
  Timer? _fallbackTimer;
  static const _fallbackInterval = Duration(seconds: 30);
  
  // Scan debounce (prevent too frequent scans)
  DateTime? _lastScanTime;
  static const _minScanInterval = Duration(seconds: 2);

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
    
    // Start motion detection
    _motionService.addListener(_onMotionStateChange);
    _motionService.start();
    
    _loadUserPrefs();
    _runInferenceAndSuggest();
    _startFallbackTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fallbackTimer?.cancel();
    _walkingScanTimer?.cancel();
    _motionService.removeListener(_onMotionStateChange);
    // Flush any pending dwell events
    _locationTracker.flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _fallbackTimer?.cancel();
      _walkingScanTimer?.cancel();
      _motionService.stop();
      _locationTracker.flush();
    } else if (state == AppLifecycleState.resumed) {
      _motionService.start();
      _startFallbackTimer();
      // Do a quick scan on resume
      _runInferenceAndSuggest(showLoading: false);
    }
  }

  void _onMotionStateChange(MotionState state) {
    if (!mounted) return;
    
    final previousState = _motionState;
    setState(() {
      _motionState = state;
    });
    
    debugPrint('[SuggestionsPage] Motion state: $state');
    
    if (state == MotionState.walking && previousState != MotionState.walking) {
      // Started walking - begin periodic scans
      debugPrint('[SuggestionsPage] Started walking - enabling periodic scans');
      _startWalkingScans();
    } else if (state == MotionState.justStopped) {
      // User stopped walking - do final scan and confirm room
      debugPrint('[SuggestionsPage] User stopped - final location check');
      _stopWalkingScans();
      _runInferenceAndSuggest(showLoading: false, isMotionTriggered: true);
    } else if (state == MotionState.stationary && previousState == MotionState.walking) {
      // Transitioned to stationary without justStopped (brief movement)
      _stopWalkingScans();
    }
  }
  
  void _startWalkingScans() {
    _walkingScanTimer?.cancel();
    // Immediate scan when walking starts
    _runInferenceAndSuggest(showLoading: false);
    // Then periodic scans while walking
    _walkingScanTimer = Timer.periodic(_walkingScanInterval, (_) {
      if (mounted && !_loading && _motionState == MotionState.walking) {
        debugPrint('[SuggestionsPage] Walking scan');
        _runInferenceAndSuggest(showLoading: false);
      }
    });
  }
  
  void _stopWalkingScans() {
    _walkingScanTimer?.cancel();
    _walkingScanTimer = null;
  }

  Future<void> _loadUserPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getStringList('user_prefs');
      _userPrefs = (prefsJson != null && prefsJson.isNotEmpty) ? prefsJson : null;
    } catch (_) {
      // Ignore errors
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(_fallbackInterval, (_) {
      if (mounted && !_loading) {
        debugPrint('[SuggestionsPage] Fallback timer triggered');
        _runInferenceAndSuggest(showLoading: false);
      }
    });
  }

  Future<void> _runInferenceAndSuggest({
    bool showLoading = true,
    bool isMotionTriggered = false,
  }) async {
    // Debounce rapid scans
    final now = DateTime.now();
    if (_lastScanTime != null && 
        now.difference(_lastScanTime!) < _minScanInterval) {
      debugPrint('[SuggestionsPage] Scan debounced');
      return;
    }
    _lastScanTime = now;
    
    // Always reload user preferences to pick up any changes
    await _loadUserPrefs();
    
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

      // Update location tracker
      await _locationTracker.onInferenceResult(room, conf);
      
      // If motion triggered (user stopped), force confirm any pending room
      if (isMotionTriggered && _locationTracker.pendingRoom != null) {
        await _locationTracker.forceConfirmPending();
      }

      // Use confirmed room for display, with inference as fallback
      final displayRoom = _locationTracker.currentRoom ?? room;
      
      _currentRoom = displayRoom;
      _confidence = conf;

      // Only fetch new suggestion if room changed or we don't have one
      final shouldFetchSuggestion = _suggestion == null || 
          _suggestion!['_room'] != displayRoom;

      if (shouldFetchSuggestion) {
        // Build local time string like "Sat 08:30"
        final day = DateFormat('EEE').format(now);
        final hm = DateFormat('HH:mm').format(now);
        final localTime = '$day $hm';

        final suggestion = await _api.suggest(
          room: displayRoom,
          localTime: localTime,
          recentRooms: _locationTracker.recentRooms.isNotEmpty
              ? _locationTracker.recentRooms
              : null,
          userPrefs: _userPrefs,
        );
        
        // Tag suggestion with room for comparison
        suggestion['_room'] = displayRoom;

        if (!mounted) return;
        setState(() {
          _suggestion = suggestion;
          _loading = false;
          _error = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
      }
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

  /// Build permanent actions based on current room (always shown regardless of preferences)
  List<Widget> _buildPermanentActions() {
    final actions = <Widget>[];
    final room = _currentRoom?.toLowerCase() ?? '';
    
    // Living Room: Always show "Trending movies"
    if (room.contains('living')) {
      actions.add(_ActionTile(label: 'Trending movies', onExecute: _executeAction));
    }
    
    return actions;
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

            // Debug panel (shows detected beacons and motion)
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
                    // Quick actions from backend
                    ...((_suggestion!['quick_actions'] as List?) ?? const [])
                        .cast<String>()
                        .map((qa) => _ActionTile(label: qa, onExecute: _executeAction)),
                    // Permanent room-specific actions
                    ..._buildPermanentActions(),
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
    
    final trackerInfo = _locationTracker.debugInfo;

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
          // Motion state indicator with metrics
          Row(
            children: [
              Icon(
                _motionState == MotionState.walking
                    ? Icons.directions_walk
                    : _motionState == MotionState.justStopped
                        ? Icons.location_on
                        : Icons.accessibility_new,
                color: _motionState == MotionState.walking
                    ? Colors.green
                    : _motionState == MotionState.justStopped
                        ? Colors.blue
                        : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _motionState.name.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _motionState == MotionState.walking
                      ? Colors.green.shade700
                      : _motionState == MotionState.justStopped
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Motion metrics
          Row(
            children: [
              _buildMetricChip('Variance', _motionService.currentVariance.toStringAsFixed(3), 
                  _motionService.currentVariance > 0.08 ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              _buildMetricChip('Accel', _motionService.currentMagnitude.toStringAsFixed(2),
                  _motionService.currentMagnitude > 0.25 ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              _buildMetricChip('Steps', _motionService.stepCount.toString(), Colors.blue),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          // Location tracker state
          Row(
            children: [
              Icon(Icons.gps_fixed, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Location',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confirmed', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                      Text(
                        trackerInfo['confirmedRoom'] ?? 'none',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                      ),
                      Text('${trackerInfo['confirmedDuration']}s', style: TextStyle(fontSize: 10, color: Colors.green.shade600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: trackerInfo['pendingRoom'] != null ? Colors.orange.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: trackerInfo['pendingRoom'] != null ? Colors.orange.shade200 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
                      Text(
                        trackerInfo['pendingRoom'] ?? 'none',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 12, 
                          color: trackerInfo['pendingRoom'] != null ? Colors.orange.shade900 : Colors.grey,
                        ),
                      ),
                      if (trackerInfo['pendingRoom'] != null)
                        Text('${trackerInfo['pendingHits']} hits, ${trackerInfo['pendingDuration']}s', 
                            style: TextStyle(fontSize: 10, color: Colors.orange.shade600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          // Beacon readings
          Row(
            children: [
              Icon(Icons.bluetooth, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Beacons',
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
                      child: Text(
                        roomName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: detected ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                    if (detected)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$currentRssi',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: distance != null && distance < 15
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Δ${distance?.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: distance != null && distance < 15
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'OFF',
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
        ],
      ),
    );
  }
  
  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final isMoving = _motionState == MotionState.walking;
    final pendingRoom = _locationTracker.pendingRoom;
    
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
              // Motion indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMoving ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMoving ? Icons.directions_walk : Icons.accessibility_new,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMoving ? 'MOVING' : 'STILL',
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
          // Show pending room if different
          if (pendingRoom != null && pendingRoom != _currentRoom)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.trending_flat, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Detecting: $pendingRoom',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          if (_confidence != null) ...[
            const SizedBox(height: 8),
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
