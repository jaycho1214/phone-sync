import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../call_log_service.dart';
import '../contacts_service.dart';
import '../pairing_service.dart';
import '../sms_service.dart';
import 'routes.dart';

/// HTTP server for serving phone data endpoints.
/// Uses singleton pattern to prevent multiple server instances (especially on hot reload).
class PhoneSyncServer {
  // Singleton instance
  static final PhoneSyncServer _instance = PhoneSyncServer._internal();
  factory PhoneSyncServer() => _instance;
  PhoneSyncServer._internal();

  HttpServer? _server;
  int _port = 0;

  /// Get the actual port the server is listening on
  int get port => _port;

  /// Check if the server is running
  bool get isRunning => _server != null;

  /// Start the server on the specified port.
  /// Use port 0 for dynamic port assignment.
  /// Pass securityContext for HTTPS, or null for HTTP (testing only).
  ///
  /// If server is already running, stops it first to prevent duplicates.
  Future<void> start({
    int port = 0,
    required ContactsService contactsService,
    required SmsService smsService,
    required CallLogService callLogService,
    required PairingService pairingService,
    SecurityContext? securityContext,
  }) async {
    // Always stop existing server first to prevent duplicates
    if (_server != null) {
      await stop();
    }

    final router = createRouter(
      contactsService: contactsService,
      smsService: smsService,
      callLogService: callLogService,
      pairingService: pairingService,
    );

    _server = await shelf_io.serve(
      router.call,
      InternetAddress.anyIPv4,
      port,
      securityContext: securityContext,
    );

    _port = _server!.port;
  }

  /// Stop the server
  Future<void> stop() async {
    final server = _server;
    if (server != null) {
      _server = null; // Clear reference immediately to prevent race conditions
      _port = 0;
      await server.close(force: true);
    }
  }
}
