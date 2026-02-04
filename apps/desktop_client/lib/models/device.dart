import 'dart:io';

import 'package:nsd/nsd.dart' as nsd;

/// Represents a discovered Android device running PhoneSync server.
class Device {
  final String name;
  final String host;
  final int port;

  const Device({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Create Device from nsd Service.
  factory Device.fromService(nsd.Service service) {
    // Prefer IPv4 address over IPv6 (avoids zone ID issues)
    final addresses = service.addresses;
    String host = service.host ?? 'unknown';

    if (addresses != null && addresses.isNotEmpty) {
      // Try to find IPv4 first
      final ipv4 = addresses.where((a) => a.type == InternetAddressType.IPv4).firstOrNull;
      if (ipv4 != null) {
        host = ipv4.address;
      } else {
        // Fall back to first address (IPv6)
        host = addresses.first.address;
      }
    }

    return Device(
      name: service.name ?? 'Unknown Device',
      host: host,
      port: service.port ?? 0,
    );
  }

  /// Create Device from manual IP:port entry.
  factory Device.manual({
    required String host,
    required int port,
    String name = 'Manual Device',
  }) {
    return Device(name: name, host: host, port: port);
  }

  /// Get the base URL for HTTP requests.
  /// Handles IPv6 addresses by wrapping in brackets and stripping zone IDs.
  String get baseUrl {
    String formattedHost = host;

    // Check if IPv6 address (contains colons but not just a port separator)
    if (host.contains(':')) {
      // Strip zone identifier if present (e.g., %en0)
      if (host.contains('%')) {
        formattedHost = host.split('%').first;
      }
      // Wrap IPv6 in brackets for URL
      formattedHost = '[$formattedHost]';
    }

    return 'https://$formattedHost:$port';
  }

  @override
  String toString() => 'Device($name, $host:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}
