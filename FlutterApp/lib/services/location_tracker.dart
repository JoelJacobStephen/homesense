import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Represents a pending room detection that needs confirmation
class _PendingRoom {
  final String room;
  final DateTime firstSeen;
  final List<double> confidences;
  int consecutiveHits;

  _PendingRoom({
    required this.room,
    required this.firstSeen,
  })  : confidences = [],
        consecutiveHits = 1;

  void addConfidence(double confidence) {
    confidences.add(confidence);
    consecutiveHits++;
  }

  double get averageConfidence =>
      confidences.isEmpty ? 0 : confidences.reduce((a, b) => a + b) / confidences.length;

  Duration get dwellDuration => DateTime.now().difference(firstSeen);
}

/// Tracks user's room location with dwell confirmation.
/// 
/// Key features:
/// 1. Quick room confirmation when motion stops
/// 2. Filters brief pass-through detections
/// 3. Logs dwell events when user stays in a room for significant duration
class LocationTracker {
  final ApiService api;

  // --- Configuration ---
  
  /// Minimum consecutive readings in same room to consider it valid (reduced for responsiveness)
  static const int minConsecutiveReadings = 1;
  
  /// Minimum time in a room to confirm location (filters pass-through)
  /// Reduced to 2 seconds for faster confirmation
  static const Duration confirmationThreshold = Duration(seconds: 2);
  
  /// Minimum time in a room before logging a dwell event
  static const Duration dwellThreshold = Duration(seconds: 15);

  /// Maximum number of recent rooms to track
  static const int maxRecentRooms = 5;

  // --- State ---
  
  /// The confirmed current room (null if not yet confirmed)
  String? _confirmedRoom;
  
  /// When the user entered the confirmed room
  DateTime? _confirmedSince;
  
  /// Confidences collected in the confirmed room
  final List<double> _confirmedConfidences = [];
  
  /// Pending room detection (not yet confirmed)
  _PendingRoom? _pendingRoom;
  
  /// Recently visited rooms (most recent first)
  final List<String> _recentRooms = [];
  
  /// Track if we're waiting for motion to stop
  bool _awaitingMotionStop = false;

  LocationTracker({required this.api});

  /// Get the confirmed current room (may be null if not yet confirmed)
  String? get currentRoom => _confirmedRoom;
  
  /// Get the pending room (room being considered but not confirmed)
  String? get pendingRoom => _pendingRoom?.room;
  
  /// Check if we have a confirmed room
  bool get hasConfirmedRoom => _confirmedRoom != null;

  /// Get list of recently visited rooms (most recent first)
  List<String> get recentRooms => List.unmodifiable(_recentRooms);
  
  /// Get how long user has been in current room
  Duration get currentRoomDuration {
    if (_confirmedSince == null) return Duration.zero;
    return DateTime.now().difference(_confirmedSince!);
  }

  /// Called when a new inference result is received.
  /// Returns true if a dwell event was logged.
  Future<bool> onInferenceResult(String room, double confidence) async {
    final now = DateTime.now();
    bool eventLogged = false;
    
    // Skip unknown rooms
    if (room == 'unknown') {
      return false;
    }

    debugPrint('[LocationTracker] Inference: $room (conf: ${confidence.toStringAsFixed(2)}), confirmed: $_confirmedRoom, pending: ${_pendingRoom?.room}');

    // Case 1: Same room as confirmed - continue tracking
    if (room == _confirmedRoom) {
      _confirmedConfidences.add(confidence);
      _pendingRoom = null; // Clear any pending room
      return false;
    }

    // Case 2: Same room as pending - continue confirmation process
    if (room == _pendingRoom?.room) {
      _pendingRoom!.addConfidence(confidence);
      
      // Check if we should confirm this room
      // More lenient: just need 1 reading and 2 seconds, OR 2 readings
      final shouldConfirm = 
          (_pendingRoom!.consecutiveHits >= minConsecutiveReadings &&
           _pendingRoom!.dwellDuration >= confirmationThreshold) ||
          _pendingRoom!.consecutiveHits >= 2;
      
      if (shouldConfirm) {
        eventLogged = await _confirmRoom(_pendingRoom!.room, now);
      }
      return eventLogged;
    }

    // Case 3: Different room - start new pending detection
    debugPrint('[LocationTracker] New pending room: $room');
    _pendingRoom = _PendingRoom(room: room, firstSeen: now);
    _pendingRoom!.addConfidence(confidence);
    
    // If this is our first room detection ever, confirm immediately
    if (_confirmedRoom == null) {
      eventLogged = await _confirmRoom(room, now);
    }
    
    return eventLogged;
  }

  /// Confirm transition to a new room
  Future<bool> _confirmRoom(String newRoom, DateTime now) async {
    bool eventLogged = false;
    
    debugPrint('[LocationTracker] Confirming room: $newRoom');
    
    // Log dwell event for previous room if applicable
    if (_confirmedRoom != null && _confirmedSince != null) {
      final duration = now.difference(_confirmedSince!);
      if (duration >= dwellThreshold && _confirmedConfidences.isNotEmpty) {
        final avgConfidence =
            _confirmedConfidences.reduce((a, b) => a + b) / _confirmedConfidences.length;

        try {
          await api.logLocationEvent(
            room: _confirmedRoom!,
            startTs: _confirmedSince!.millisecondsSinceEpoch ~/ 1000,
            endTs: now.millisecondsSinceEpoch ~/ 1000,
            confidence: avgConfidence,
          );
          eventLogged = true;
          debugPrint('[LocationTracker] Logged dwell: $_confirmedRoom for ${duration.inSeconds}s');
        } catch (e) {
          debugPrint('[LocationTracker] Failed to log dwell event: $e');
        }
      }
      
      // Add to recent rooms
      if (_confirmedRoom != 'unknown') {
        _recentRooms.remove(_confirmedRoom);
        _recentRooms.insert(0, _confirmedRoom!);
        if (_recentRooms.length > maxRecentRooms) {
          _recentRooms.removeLast();
        }
      }
    }

    // Update to new confirmed room
    _confirmedRoom = newRoom;
    _confirmedSince = _pendingRoom?.firstSeen ?? now;
    _confirmedConfidences.clear();
    if (_pendingRoom != null) {
      _confirmedConfidences.addAll(_pendingRoom!.confidences);
    }
    _pendingRoom = null;
    
    debugPrint('[LocationTracker] ✓ Confirmed room: $newRoom');
    return eventLogged;
  }

  /// Force confirm current pending room (used when motion stops)
  Future<bool> forceConfirmPending() async {
    if (_pendingRoom == null) {
      debugPrint('[LocationTracker] No pending room to force confirm');
      return false;
    }
    
    debugPrint('[LocationTracker] Force confirming pending room: ${_pendingRoom!.room}');
    return await _confirmRoom(_pendingRoom!.room, DateTime.now());
  }

  /// Force log current dwell event (e.g., when app is closing)
  Future<void> flush() async {
    final now = DateTime.now();

    if (_confirmedRoom != null && 
        _confirmedSince != null && 
        _confirmedRoom != 'unknown') {
      final duration = now.difference(_confirmedSince!);
      if (duration >= dwellThreshold && _confirmedConfidences.isNotEmpty) {
        final avgConfidence =
            _confirmedConfidences.reduce((a, b) => a + b) / _confirmedConfidences.length;

        try {
          await api.logLocationEvent(
            room: _confirmedRoom!,
            startTs: _confirmedSince!.millisecondsSinceEpoch ~/ 1000,
            endTs: now.millisecondsSinceEpoch ~/ 1000,
            confidence: avgConfidence,
          );
          debugPrint('[LocationTracker] Flushed dwell: $_confirmedRoom for ${duration.inSeconds}s');
        } catch (e) {
          debugPrint('[LocationTracker] Failed to flush dwell event: $e');
        }
      }
    }

    // Reset timestamps but keep room
    _confirmedConfidences.clear();
    _confirmedSince = now;
    _pendingRoom = null;
  }

  /// Reset the tracker state (e.g., on recalibration)
  void reset() {
    _confirmedRoom = null;
    _confirmedSince = null;
    _confirmedConfidences.clear();
    _pendingRoom = null;
    _recentRooms.clear();
  }
  
  /// Get debug info about current state
  Map<String, dynamic> get debugInfo => {
    'confirmedRoom': _confirmedRoom,
    'confirmedDuration': currentRoomDuration.inSeconds,
    'pendingRoom': _pendingRoom?.room,
    'pendingHits': _pendingRoom?.consecutiveHits ?? 0,
    'pendingDuration': _pendingRoom?.dwellDuration.inSeconds ?? 0,
  };
}
