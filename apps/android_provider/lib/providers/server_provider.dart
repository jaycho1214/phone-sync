import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/call_log_service.dart';
import '../services/certificate_service.dart';
import '../services/contacts_service.dart';
import '../services/discovery_service.dart';
import '../services/pairing_service.dart';
import '../services/server/http_server.dart';
import '../services/sms_service.dart';

/// Server state
class ServerState {
  final bool isRunning;
  final int port;
  final String? error;

  const ServerState({
    this.isRunning = false,
    this.port = 0,
    this.error,
  });

  ServerState copyWith({
    bool? isRunning,
    int? port,
    String? error,
  }) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      error: error,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  final DiscoveryService _discoveryService;
  final ContactsService _contactsService;
  final SmsService _smsService;
  final CallLogService _callLogService;
  final CertificateService _certificateService;
  final PairingService _pairingService;

  // Use singleton server instance to survive hot reloads
  final PhoneSyncServer _server = PhoneSyncServer();

  ServerNotifier({
    required DiscoveryService discoveryService,
    required ContactsService contactsService,
    required SmsService smsService,
    required CallLogService callLogService,
    required CertificateService certificateService,
    required PairingService pairingService,
  })  : _discoveryService = discoveryService,
        _contactsService = contactsService,
        _smsService = smsService,
        _callLogService = callLogService,
        _certificateService = certificateService,
        _pairingService = pairingService,
        super(const ServerState()) {
    // Sync state with actual server state on creation (handles hot reload)
    _syncStateWithServer();
  }

  /// Sync provider state with actual singleton server state.
  /// Called on creation to handle hot reload scenarios.
  void _syncStateWithServer() {
    if (_server.isRunning) {
      state = ServerState(
        isRunning: true,
        port: _server.port,
      );
    }
  }

  /// Get the pairing service for external access
  PairingService get pairingService => _pairingService;

  /// Start the HTTP server and advertise via mDNS.
  /// Safe to call multiple times - will sync state if already running.
  Future<void> startServer() async {
    // If server singleton is already running, just sync state
    if (_server.isRunning) {
      state = ServerState(
        isRunning: true,
        port: _server.port,
      );
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
        securityContext: securityContext,
      );

      final actualPort = _server.port;

      // Advertise via mDNS
      final deviceName = _discoveryService.getDeviceName();
      await _discoveryService.advertise(
        deviceName: deviceName,
        port: actualPort,
      );

      state = ServerState(
        isRunning: true,
        port: actualPort,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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

  @override
  void dispose() {
    // Note: We don't stop the server on dispose because other providers
    // might still be using it. The server will be stopped when the app
    // goes to background via the lifecycle observer.
    super.dispose();
  }
}

// Service providers (simple instances for now)
final contactsServiceProvider = Provider((ref) => ContactsService());
final smsServiceProvider = Provider((ref) => SmsService());
final callLogServiceProvider = Provider((ref) => CallLogService());
final discoveryServiceProvider = Provider((ref) => DiscoveryService());
final certificateServiceProvider = Provider((ref) => CertificateService());
final pairingServiceProvider = Provider((ref) => PairingService());

final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>(
  (ref) => ServerNotifier(
    discoveryService: ref.read(discoveryServiceProvider),
    contactsService: ref.read(contactsServiceProvider),
    smsService: ref.read(smsServiceProvider),
    callLogService: ref.read(callLogServiceProvider),
    certificateService: ref.read(certificateServiceProvider),
    pairingService: ref.read(pairingServiceProvider),
  ),
);
