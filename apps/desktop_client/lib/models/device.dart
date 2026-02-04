import 'dart:io';

import 'package:nsd/nsd.dart' as nsd;

/// Represents a discovered Android device running PhoneSync server.
class Device {
  final String name;
  final String host;
  final int port;
  final List<String> allAddresses; // All discovered addresses for fallback

  const Device({
    required this.name,
    required this.host,
    required this.port,
    this.allAddresses = const [],
  });

  /// Create Device from nsd Service.
  factory Device.fromService(nsd.Service service) {
    final addresses = service.addresses;
    String host = service.host ?? 'unknown';
    final allAddrs = <String>[];

    if (addresses != null && addresses.isNotEmpty) {
      // Collect all addresses (IPv4 first, then IPv6)
      final ipv4Addrs = addresses
          .where((a) => a.type == InternetAddressType.IPv4)
          .map((a) => a.address)
          .toList();
      final ipv6Addrs = addresses
          .where((a) => a.type == InternetAddressType.IPv6)
          .map((a) => a.address)
          .toList();

      allAddrs.addAll(ipv4Addrs);
      allAddrs.addAll(ipv6Addrs);

      // Primary host is first IPv4, or first IPv6 if no IPv4
      if (ipv4Addrs.isNotEmpty) {
        host = ipv4Addrs.first;
      } else if (ipv6Addrs.isNotEmpty) {
        host = ipv6Addrs.first;
      }
    }

    return Device(
      name: service.name ?? 'Unknown Device',
      host: host,
      port: service.port ?? 0,
      allAddresses: allAddrs,
    );
  }

  /// Create Device from manual IP:port entry.
  factory Device.manual({
    required String host,
    required int port,
    String name = 'Manual Device',
  }) {
    return Device(name: name, host: host, port: port, allAddresses: [host]);
  }

  /// Get the base URL for a specific host.
  /// Handles IPv6 addresses by wrapping in brackets and stripping zone IDs.
  String getBaseUrlForHost(String hostAddr) {
    String formattedHost = hostAddr;

    // Check if IPv6 address (contains colons but not just a port separator)
    if (hostAddr.contains(':')) {
      // Strip zone identifier if present (e.g., %en0)
      if (hostAddr.contains('%')) {
        formattedHost = hostAddr.split('%').first;
      }
      // Wrap IPv6 in brackets for URL
      formattedHost = '[$formattedHost]';
    }

    return 'https://$formattedHost:$port';
  }

  /// Get the base URL for HTTP requests (primary address).
  String get baseUrl => getBaseUrlForHost(host);

  /// Get all possible base URLs for fallback attempts.
  List<String> get allBaseUrls {
    if (allAddresses.isEmpty) {
      return [baseUrl];
    }
    return allAddresses.map((addr) => getBaseUrlForHost(addr)).toList();
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
