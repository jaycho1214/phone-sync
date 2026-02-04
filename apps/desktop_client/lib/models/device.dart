import 'package:nsd/nsd.dart';

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
  factory Device.fromService(Service service) {
    // Get first available IP address
    final addresses = service.addresses;
    final host = addresses != null && addresses.isNotEmpty
        ? addresses.first.address
        : service.host ?? 'unknown';

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
  String get baseUrl => 'https://$host:$port';

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
