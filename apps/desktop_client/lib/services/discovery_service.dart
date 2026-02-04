import 'package:nsd/nsd.dart' as nsd;

import '../models/device.dart';

/// Service for discovering PhoneSync Android devices on the local network.
class DiscoveryService {
  static const String serviceType = '_phonesync._tcp';

  nsd.Discovery? _discovery;
  final List<Device> _devices = [];
  void Function(List<Device>)? _onDevicesChanged;

  /// Get currently discovered devices.
  List<Device> get devices => List.unmodifiable(_devices);

  /// Start mDNS discovery for PhoneSync devices.
  Future<void> startDiscovery({required void Function(List<Device>) onDevicesChanged}) async {
    _onDevicesChanged = onDevicesChanged;
    _devices.clear();

    try {
      _discovery = await nsd.startDiscovery(serviceType, ipLookupType: nsd.IpLookupType.any);

      _discovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
          final device = Device.fromService(service);
          // Only add if not already present
          if (!_devices.any((d) => d.host == device.host && d.port == device.port)) {
            _devices.add(device);
            _onDevicesChanged?.call(_devices);
          }
        } else if (status == nsd.ServiceStatus.lost) {
          _devices.removeWhere((d) {
            final serviceHost = service.addresses?.firstOrNull?.address ?? service.host;
            return d.host == serviceHost && d.port == service.port;
          });
          _onDevicesChanged?.call(_devices);
        }
      });
    } catch (e) {
      // If discovery fails (e.g., no mDNS support), continue with empty list
      // User can still use manual IP entry
      _onDevicesChanged?.call(_devices);
    }
  }

  /// Stop mDNS discovery.
  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      try {
        await nsd.stopDiscovery(_discovery!);
      } catch (_) {
        // Ignore errors when stopping
      }
      _discovery = null;
    }
    _onDevicesChanged = null;
  }

  /// Add a device manually (for IP:port fallback).
  void addManualDevice(Device device) {
    if (!_devices.any((d) => d.host == device.host && d.port == device.port)) {
      _devices.add(device);
      _onDevicesChanged?.call(_devices);
    }
  }

  /// Parse IP:port string and create a manual device.
  Device? parseManualEntry(String input) {
    try {
      final parts = input.trim().split(':');
      if (parts.length != 2) return null;

      final host = parts[0].trim();
      final port = int.tryParse(parts[1].trim());

      if (host.isEmpty || port == null || port <= 0 || port > 65535) {
        return null;
      }

      return Device.manual(host: host, port: port);
    } catch (_) {
      return null;
    }
  }

  /// Dispose resources.
  void dispose() {
    stopDiscovery();
  }
}
