import 'dart:convert';

import 'package:nsd/nsd.dart';

/// Service for mDNS registration and unregistration
/// Advertises the PhoneSync HTTP server on the local network
class DiscoveryService {
  Registration? _registration;

  /// Advertise the PhoneSync service via mDNS
  ///
  /// Parameters:
  /// - deviceName: Human-readable name for the device
  /// - port: The port the HTTP server is listening on
  Future<void> advertise({
    required String deviceName,
    required int port,
  }) async {
    if (_registration != null) {
      throw StateError('Service is already advertised');
    }

    // Create service with TXT records
    // nsd expects Map<String, Uint8List> for txt
    final txtRecords = {
      'version': utf8.encode('1.0'),
      'device': utf8.encode(deviceName),
    };

    final service = Service(
      name: deviceName,
      type: '_phonesync._tcp',
      port: port,
      txt: txtRecords,
    );

    _registration = await register(service);
  }

  /// Stop advertising the service
  Future<void> stopAdvertising() async {
    if (_registration == null) return;

    await unregister(_registration!);
    _registration = null;
  }

  /// Get the device name for advertising
  /// Returns a default name (device-specific ID can be added later)
  String getDeviceName() {
    return 'PhoneSync-Android';
  }

  /// Check if the service is currently being advertised
  bool get isAdvertising => _registration != null;
}
