import 'dart:convert';
import 'dart:io' show Platform, HttpException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl();

  String _baseUrl;
  String get baseUrl => _baseUrl;
  set baseUrl(String v) => _baseUrl = v;

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) {
      // For real devices, use Mac's local IP
      // For emulator, use 10.0.2.2
      return 'http://192.168.1.179:8000';  // <-- Replace with your actual IP, e.g., 'http://192.168.1.100:8000'
    }
    return 'http://localhost:8000';
  }

  Future<void> resolveReachableBaseUrl({Duration timeout = const Duration(seconds: 2)}) async {
    final candidates = <String>[
      _baseUrl,
      'http://192.168.1.179:8000',  // <-- Replace with your actual IP, e.g., 'http://192.168.1.100:8000'
      'http://10.0.2.2:8000',
      'http://localhost:8000',
    ];
    for (final c in candidates) {
      if (await _isHealthOk(c, timeout: timeout)) {
        _baseUrl = c;
        return;
      }
    }
    // If none reachable, keep existing; calls will throw.
  }

  Future<bool> _isHealthOk(String base, {Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final uri = Uri.parse('$base/health');
      final resp = await http.get(uri).timeout(timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> infer(List<Map<String, dynamic>> readings) async {
    final uri = Uri.parse('$_baseUrl/infer');
    await resolveReachableBaseUrl();
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'readings': readings}),
    ).timeout(const Duration(seconds: 5));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('Infer failed ${resp.statusCode}: ${resp.body}');
  }

  Future<Map<String, dynamic>> suggest({
    required String room,
    required String localTime,
    List<String>? recentRooms,
    List<String>? userPrefs,
  }) async {
    final uri = Uri.parse('$_baseUrl/suggest');
    final payload = {
      'room': room,
      'local_time': localTime,
      if (recentRooms != null) 'recent_rooms': recentRooms,
      if (userPrefs != null) 'user_prefs': userPrefs,
    };
    await resolveReachableBaseUrl();
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 5));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('Suggest failed ${resp.statusCode}: ${resp.body}');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Calibration Endpoints
  // ─────────────────────────────────────────────────────────────────────────────

  /// Upload RSSI samples collected during calibration for a single beacon/room.
  Future<Map<String, dynamic>> uploadCalibration({
    required String beaconId,
    required String room,
    required List<double> rssiSamples,
    required int windowStart,
    required int windowEnd,
  }) async {
    final uri = Uri.parse('$_baseUrl/calibration/upload');
    final payload = {
      'beacon_id': beaconId,
      'room': room,
      'rssi_samples': rssiSamples,
      'window_start': windowStart,
      'window_end': windowEnd,
    };
    await resolveReachableBaseUrl();
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('Upload calibration failed ${resp.statusCode}: ${resp.body}');
  }

  /// Compute centroids (mean RSSI) for all calibrated beacons.
  /// Must be called after uploading calibration data.
  Future<Map<String, double>> fitCalibration() async {
    final uri = Uri.parse('$_baseUrl/calibration/fit');
    await resolveReachableBaseUrl();
    final resp = await http.post(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    throw HttpException('Fit calibration failed ${resp.statusCode}: ${resp.body}');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Centroids Endpoint
  // ─────────────────────────────────────────────────────────────────────────────

  /// Retrieve all computed centroids with room info.
  Future<List<Map<String, dynamic>>> getCentroids() async {
    final uri = Uri.parse('$_baseUrl/centroids');
    await resolveReachableBaseUrl();
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    throw HttpException('Get centroids failed ${resp.statusCode}: ${resp.body}');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Events Endpoint
  // ─────────────────────────────────────────────────────────────────────────────

  /// Log a dwell event when user has been in a room for a significant duration.
  Future<int> logLocationEvent({
    required String room,
    required int startTs,
    required int endTs,
    required double confidence,
  }) async {
    final uri = Uri.parse('$_baseUrl/events/location');
    final payload = {
      'room': room,
      'start_ts': startTs,
      'end_ts': endTs,
      'confidence': confidence,
    };
    await resolveReachableBaseUrl();
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 5));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      return decoded['id'] as int;
    }
    throw HttpException('Log location event failed ${resp.statusCode}: ${resp.body}');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Insights Endpoint
  // ─────────────────────────────────────────────────────────────────────────────

  /// Get daily insights including room durations and transitions.
  /// [date] should be in YYYY-MM-DD format.
  Future<Map<String, dynamic>> getDailyInsights(String date) async {
    final uri = Uri.parse('$_baseUrl/insights/daily?date=$date');
    await resolveReachableBaseUrl();
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw HttpException('Get daily insights failed ${resp.statusCode}: ${resp.body}');
  }
}
