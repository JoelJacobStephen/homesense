import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Motion state representing the user's movement pattern
enum MotionState {
  /// User is stationary (not moving significantly)
  stationary,

  /// User is currently walking/moving
  walking,

  /// User just stopped after significant movement (potential room change)
  justStopped,
}

/// Callback type for motion state changes
typedef MotionStateCallback = void Function(MotionState state);

/// Service to detect significant user movement using accelerometer.
/// 
/// Uses variance-based detection which works even when phone is held steady
/// at stomach level during walking. Walking produces rhythmic micro-oscillations
/// that increase the variance of acceleration readings.
class MotionService {
  static MotionService? _instance;
  
  MotionService._();
  
  static MotionService get instance {
    _instance ??= MotionService._();
    return _instance!;
  }

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  MotionState _currentState = MotionState.stationary;
  MotionState get currentState => _currentState;
  
  final List<MotionStateCallback> _listeners = [];
  
  // --- Configuration ---
  
  /// Variance threshold for detecting walking motion
  /// Walking produces rhythmic oscillations that increase variance
  /// Even with phone held at stomach, variance is typically 0.15-0.5 during walking
  static const double _varianceThreshold = 0.08;
  
  /// Lower threshold for more sensitive step detection
  static const double _stepThreshold = 0.25;
  
  /// Window size for variance calculation (samples)
  static const int _varianceWindowSize = 30; // ~1.5 seconds at 20Hz
  
  /// Number of high-variance windows to confirm walking
  static const int _walkingWindowsRequired = 2;
  
  /// Number of low-variance windows to confirm stopped
  static const int _stoppedWindowsRequired = 3;
  
  /// Time after stopping to consider it a "just stopped" event
  static const Duration _justStoppedWindow = Duration(seconds: 2);
  
  /// Minimum walking duration to trigger "just stopped" (filters brief movements)
  static const Duration _minWalkingDuration = Duration(milliseconds: 1500);
  
  /// Cooldown between "just stopped" events
  static const Duration _eventCooldown = Duration(seconds: 4);
  
  // --- State tracking ---
  
  /// Rolling window of acceleration magnitudes for variance calculation
  final List<double> _magnitudeWindow = [];
  
  /// Count of consecutive high/low variance windows
  int _walkingWindowCount = 0;
  int _stoppedWindowCount = 0;
  
  /// Step detection using peak counting
  final List<double> _recentMagnitudes = [];
  int _stepCount = 0;
  DateTime? _lastStepTime;
  
  /// When the user started walking
  DateTime? _walkingStartTime;
  
  /// When the last "just stopped" event was fired
  DateTime? _lastEventTime;
  
  /// Baseline gravity magnitude (calibrated from initial readings)
  double _gravityBaseline = 9.8;
  final List<double> _calibrationSamples = [];
  static const int _calibrationSamplesNeeded = 30;
  bool _isCalibrated = false;
  
  /// Current motion metrics (for debug display)
  double _currentVariance = 0;
  double _currentMagnitude = 0;
  
  double get currentVariance => _currentVariance;
  double get currentMagnitude => _currentMagnitude;
  int get stepCount => _stepCount;
  
  /// Start listening to accelerometer events
  void start() {
    if (_accelerometerSubscription != null) return;
    
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // 20 Hz
    ).listen(_onAccelerometerEvent);
    
    debugPrint('[MotionService] Started listening to accelerometer');
  }
  
  /// Stop listening to accelerometer events
  void stop() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _reset();
    debugPrint('[MotionService] Stopped');
  }
  
  /// Add a listener for motion state changes
  void addListener(MotionStateCallback callback) {
    _listeners.add(callback);
  }
  
  /// Remove a listener
  void removeListener(MotionStateCallback callback) {
    _listeners.remove(callback);
  }
  
  void _reset() {
    _magnitudeWindow.clear();
    _recentMagnitudes.clear();
    _walkingWindowCount = 0;
    _stoppedWindowCount = 0;
    _walkingStartTime = null;
    _currentState = MotionState.stationary;
    _calibrationSamples.clear();
    _isCalibrated = false;
    _stepCount = 0;
  }
  
  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Calculate acceleration magnitude
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    
    // Calibrate gravity baseline from initial stationary readings
    if (!_isCalibrated) {
      _calibrationSamples.add(magnitude);
      if (_calibrationSamples.length >= _calibrationSamplesNeeded) {
        _gravityBaseline = _calibrationSamples.reduce((a, b) => a + b) / 
            _calibrationSamples.length;
        _isCalibrated = true;
        debugPrint('[MotionService] Calibrated gravity baseline: $_gravityBaseline');
      }
      return;
    }
    
    // Calculate deviation from gravity (motion component)
    final motionMagnitude = magnitude - _gravityBaseline;
    _currentMagnitude = motionMagnitude.abs();
    
    // Add to variance window
    _magnitudeWindow.add(motionMagnitude);
    if (_magnitudeWindow.length > _varianceWindowSize) {
      _magnitudeWindow.removeAt(0);
    }
    
    // Step detection using peaks
    _detectSteps(motionMagnitude);
    
    // Only analyze when we have enough samples
    if (_magnitudeWindow.length >= _varianceWindowSize) {
      _analyzeMotion();
    }
  }
  
  void _detectSteps(double motionMagnitude) {
    _recentMagnitudes.add(motionMagnitude);
    if (_recentMagnitudes.length > 10) {
      _recentMagnitudes.removeAt(0);
    }
    
    if (_recentMagnitudes.length < 5) return;
    
    // Simple peak detection - look for local maxima above threshold
    final mid = _recentMagnitudes.length ~/ 2;
    final current = _recentMagnitudes[mid];
    
    bool isPeak = current > _stepThreshold;
    for (int i = 0; i < _recentMagnitudes.length; i++) {
      if (i != mid && _recentMagnitudes[i] >= current) {
        isPeak = false;
        break;
      }
    }
    
    if (isPeak) {
      final now = DateTime.now();
      // Debounce steps (min 250ms between steps = max 4 steps/second)
      if (_lastStepTime == null || 
          now.difference(_lastStepTime!) > const Duration(milliseconds: 250)) {
        _stepCount++;
        _lastStepTime = now;
      }
    }
  }
  
  void _analyzeMotion() {
    // Calculate variance of the window
    final mean = _magnitudeWindow.reduce((a, b) => a + b) / _magnitudeWindow.length;
    double sumSquaredDiff = 0;
    for (final val in _magnitudeWindow) {
      sumSquaredDiff += (val - mean) * (val - mean);
    }
    final variance = sumSquaredDiff / _magnitudeWindow.length;
    _currentVariance = variance;
    
    final isWalkingVariance = variance > _varianceThreshold;
    
    if (isWalkingVariance) {
      _walkingWindowCount++;
      _stoppedWindowCount = 0;
    } else {
      _stoppedWindowCount++;
      _walkingWindowCount = 0;
    }
    
    final previousState = _currentState;
    
    // State machine logic
    switch (_currentState) {
      case MotionState.stationary:
        if (_walkingWindowCount >= _walkingWindowsRequired) {
          _currentState = MotionState.walking;
          _walkingStartTime = DateTime.now();
          _stepCount = 0; // Reset step count for new walking session
          debugPrint('[MotionService] Started walking (variance: ${variance.toStringAsFixed(3)})');
        }
        break;
        
      case MotionState.walking:
        if (_stoppedWindowCount >= _stoppedWindowsRequired) {
          final walkingDuration = _walkingStartTime != null
              ? DateTime.now().difference(_walkingStartTime!)
              : Duration.zero;
          
          // Only trigger "just stopped" if walked for minimum duration
          if (walkingDuration >= _minWalkingDuration) {
            // Check cooldown
            final now = DateTime.now();
            if (_lastEventTime == null || 
                now.difference(_lastEventTime!) >= _eventCooldown) {
              _currentState = MotionState.justStopped;
              _lastEventTime = now;
              debugPrint('[MotionService] Just stopped after ${walkingDuration.inMilliseconds}ms, $_stepCount steps');
              
              // Schedule transition back to stationary
              Future.delayed(_justStoppedWindow, () {
                if (_currentState == MotionState.justStopped) {
                  _currentState = MotionState.stationary;
                  _notifyListeners(MotionState.stationary);
                }
              });
            } else {
              _currentState = MotionState.stationary;
            }
          } else {
            _currentState = MotionState.stationary;
            debugPrint('[MotionService] Brief movement ignored (${walkingDuration.inMilliseconds}ms)');
          }
          _walkingStartTime = null;
        }
        break;
        
      case MotionState.justStopped:
        // Will auto-transition to stationary after _justStoppedWindow
        // But can transition back to walking if movement resumes
        if (_walkingWindowCount >= _walkingWindowsRequired) {
          _currentState = MotionState.walking;
          _walkingStartTime = DateTime.now();
          _stepCount = 0;
        }
        break;
    }
    
    if (_currentState != previousState) {
      _notifyListeners(_currentState);
    }
  }
  
  void _notifyListeners(MotionState state) {
    for (final listener in _listeners) {
      listener(state);
    }
  }
  
  /// Get the average motion level (variance-based)
  double get averageMotionLevel => _currentVariance;
  
  /// Check if the user is currently walking
  bool get isWalking => _currentState == MotionState.walking;
  
  /// Check if the user just stopped (potential room change)
  bool get justStopped => _currentState == MotionState.justStopped;
}
