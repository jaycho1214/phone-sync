import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/call_log_service.dart';
import '../services/certificate_service.dart';
import '../services/contacts_service.dart';
import '../services/discovery_service.dart';
import '../services/pairing_service.dart';
import '../services/server/http_server.dart';
import '../services/sms_service.dart';
import '../services/sync_storage_service.dart';

/// Server state
class ServerState {
  final bool isRunning;
  final int port;
  final String? localIp;
  final String? error;

  const ServerState({
    this.isRunning = false,
    this.port = 0,
    this.localIp,
    this.error,
  });

  ServerState copyWith({
    bool? isRunning,
    int? port,
    String? localIp,
    String? error,
  }) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      localIp: localIp ?? this.localIp,
      error: error,
    );
  }
}

class ServerNotifier extends Notifier<ServerState> {
  late final DiscoveryService _discoveryService;
  late final ContactsService _contactsService;
  late final SmsService _smsService;
  late final CallLogService _callLogService;
  late final CertificateService _certificateService;
  late final PairingService _pairingService;
  late final SyncStorageService _syncStorageService;

  // Use singleton server instance to survive hot reloads
  final PhoneSyncServer _server = PhoneSyncServer();

  @override
  ServerState build() {
    _discoveryService = ref.read(discoveryServiceProvider);
    _contactsService = ref.read(contactsServiceProvider);
    _smsService = ref.read(smsServiceProvider);
    _callLogService = ref.read(callLogServiceProvider);
    _certificateService = ref.read(certificateServiceProvider);
    _pairingService = ref.read(pairingServiceProvider);
    _syncStorageService = ref.read(syncStorageServiceProvider);

    // Sync state with actual server state on creation (handles hot reload)
    // Use Future.microtask to defer state update after build completes
    Future.microtask(_syncStateWithServer);

    // Note: We don't stop the server on dispose because other providers
    // might still be using it. The server will be stopped when the app
    // goes to background via the lifecycle observer.

    return const ServerState();
  }

  /// Sync provider state with actual singleton server state.
  /// Called on creation to handle hot reload scenarios.
  void _syncStateWithServer() {
    if (_server.isRunning) {
      state = ServerState(isRunning: true, port: _server.port);
    }
  }

  /// Get the pairing service for external access
  PairingService get pairingService => _pairingService;

  /// Start the HTTP server and advertise via mDNS.
  /// Safe to call multiple times - will sync state if already running.
  Future<void> startServer() async {
    // If server singleton is already running, just sync state
    if (_server.isRunning) {
      state = ServerState(isRunning: true, port: _server.port);
      return;
    }

    try {
      // Generate or load TLS certificate
      final certs = await _certificateService.generateOrLoadCertificate();
      final securityContext = _certificateService.createSecurityContext(
        certs.certPem,
        certs.keyPem,
      );

      // Start HTTPS server on dynamic port
      // The singleton will stop any existing server before starting
      await _server.start(
        port: 0,
        contactsService: _contactsService,
        smsService: _smsService,
        callLogService: _callLogService,
        pairingService: _pairingService,
        syncStorageService: _syncStorageService,
        securityContext: securityContext,
      );

      final actualPort = _server.port;
      final localIp = await _getLocalIpAddress();

      // Advertise via mDNS
      final deviceName = await _discoveryService.getDeviceName();
      await _discoveryService.advertise(
        deviceName: deviceName,
        port: actualPort,
      );

      state = ServerState(isRunning: true, port: actualPort, localIp: localIp);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Get the local WiFi IP address
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        // Prefer wlan/wifi interfaces
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('en')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      // Fall back to first non-loopback address
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }
    return null;
  }

  /// Stop the HTTP server and mDNS advertisement
  Future<void> stopServer() async {
    // Always attempt to stop even if state says not running (state might be desynced)
    try {
      // Stop mDNS advertisement first
      await _discoveryService.stopAdvertising();

      // Stop HTTP server
      await _server.stop();

      state = const ServerState(isRunning: false, port: 0);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Service providers (simple instances for now)
final contactsServiceProvider = Provider((ref) => ContactsService());
final smsServiceProvider = Provider((ref) => SmsService());
final callLogServiceProvider = Provider((ref) => CallLogService());
final discoveryServiceProvider = Provider((ref) => DiscoveryService());
final certificateServiceProvider = Provider((ref) => CertificateService());
final pairingServiceProvider = Provider((ref) => PairingService());
final syncStorageServiceProvider = Provider((ref) => SyncStorageService());

final serverProvider = NotifierProvider<ServerNotifier, ServerState>(
  ServerNotifier.new,
);
