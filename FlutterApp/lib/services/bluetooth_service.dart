import 'dart:io';
import 'package:flutter/services.dart';

class BluetoothDeviceInfo {
  final String name;
  final String address;
  final int? rssi; // dBm (negative), may be null for bonded devices
  BluetoothDeviceInfo({required this.name, required this.address, this.rssi});

  @override
  String toString() => name.isNotEmpty ? '$name ($address)' : address;
}

class BluetoothService {
  static const MethodChannel _channel = MethodChannel('com.homesense/bluetooth');

  static Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('ensurePermissions');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BluetoothDeviceInfo>> scanDevices() async {
    if (!Platform.isAndroid) return [];
    try {
      final list = await _channel.invokeMethod('scanDevices');
      if (list is List) {
        return list.whereType<Map>().map((m) {
          final name = (m['name'] as String?)?.trim() ?? '';
          final address = (m['address'] as String?)?.trim() ?? '';
          final rssi = (m['rssi'] is int) ? m['rssi'] as int : null;
          return BluetoothDeviceInfo(name: name, address: address, rssi: rssi);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // Convenience: transform scan results into readings for inference
  // beacon_id: use MAC address; rssi: use latest RSSI from scan
  static Future<List<Map<String, dynamic>>> scanReadings() async {
    final devices = await scanDevices();
    final readings = <Map<String, dynamic>>[];
    for (final d in devices) {
      if (d.rssi != null) {
        readings.add({
          'beacon_id': d.address, // use MAC as stable id
          'rssi': d.rssi,
        });
      }
    }
    return readings;
  }

  static Future<bool> isLocationEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('checkLocationEnabled');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openLocationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('openLocationSettings');
      return res == true;
    } catch (_) {
      return false;
    }
  }
}
