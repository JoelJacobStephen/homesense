import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SystemService {
  static const MethodChannel _channel = MethodChannel('com.homesense/system');

  static Future<bool> openTimer() async {
    if (kIsWeb || !Platform.isAndroid) return false; // Only implemented for Android now
    try {
      final res = await _channel.invokeMethod('openTimer');
      return res == true;
    } catch (_) {
      return false;
    }
  }
}
