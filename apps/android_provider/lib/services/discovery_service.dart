import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:nsd/nsd.dart';

/// Service for mDNS registration and unregistration
/// Advertises the PhoneSync HTTP server on the local network
class DiscoveryService {
  Registration? _registration;
  String? _cachedDeviceName;

  /// Advertise the PhoneSync service via mDNS
  ///
  /// Parameters:
  /// - deviceName: Human-readable name for the device
  /// - port: The port the HTTP server is listening on
  Future<void> advertise({required String deviceName, required int port}) async {
    if (_registration != null) {
      throw StateError('Service is already advertised');
    }

    // Create service with TXT records
    // nsd expects Map<String, Uint8List> for txt
    final txtRecords = {'version': utf8.encode('1.0'), 'device': utf8.encode(deviceName)};

    final service = Service(name: deviceName, type: '_phonesync._tcp', port: port, txt: txtRecords);

    _registration = await register(service);
  }

  /// Stop advertising the service
  Future<void> stopAdvertising() async {
    if (_registration == null) return;

    await unregister(_registration!);
    _registration = null;
  }

  /// Get the device name for advertising
  /// Returns the real device model name (e.g., "Galaxy S24", "Pixel 8")
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // Use model name (e.g., "SM-S928N" -> marketing name if available, else model)
      // Combine brand and model for clearer identification
      final brand = androidInfo.brand;
      final model = androidInfo.model;

      // Capitalize brand and format nicely
      final brandCapitalized = brand.isNotEmpty
          ? brand[0].toUpperCase() + brand.substring(1)
          : 'Android';

      _cachedDeviceName = '$brandCapitalized $model';
      return _cachedDeviceName!;
    } catch (_) {
      _cachedDeviceName = 'Android Device';
      return _cachedDeviceName!;
    }
  }

  /// Check if the service is currently being advertised
  bool get isAdvertising => _registration != null;
}
