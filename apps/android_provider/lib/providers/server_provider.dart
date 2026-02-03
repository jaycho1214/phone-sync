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
        super(const ServerState());

  /// Get the pairing service for external access
  PairingService get pairingService => _pairingService;

  /// Start the HTTP server and advertise via mDNS
  Future<void> startServer() async {
    if (state.isRunning) return;

    try {
      // Generate or load TLS certificate
      final certs = await _certificateService.generateOrLoadCertificate();
      final securityContext = _certificateService.createSecurityContext(
        certs.certPem,
        certs.keyPem,
      );

      // Start HTTPS server on dynamic port
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
    if (!state.isRunning) return;

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
    stopServer();
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
