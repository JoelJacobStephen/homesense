import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl();

  String _baseUrl;
  String get baseUrl => _baseUrl;
  set baseUrl(String v) => _baseUrl = v;

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) {
        // Prefer emulator host; if unreachable, we'll fall back during runtime.
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return 'http://localhost:8000';
  }

  Future<void> resolveReachableBaseUrl({Duration timeout = const Duration(seconds: 2)}) async {
    final candidates = <String>[
      _baseUrl,
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
}
