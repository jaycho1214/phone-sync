import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../call_log_service.dart';
import '../contacts_service.dart';
import '../pairing_service.dart';
import '../sms_service.dart';
import '../sync_storage_service.dart';
import 'routes.dart';

/// HTTP server for serving phone data endpoints.
/// Uses singleton pattern + fixed port to prevent multiple server instances.
/// Survives hot reload via singleton, handles hot restart via fixed port.
class PhoneSyncServer {
  // Singleton instance
  static final PhoneSyncServer _instance = PhoneSyncServer._internal();
  factory PhoneSyncServer() => _instance;
  PhoneSyncServer._internal();

  // Fixed port for the server - ensures only one instance even after hot restart
  static const int _fixedPort = 42829;
  static const String _portKey = 'phonesync_server_port';

  HttpServer? _server;
  int _port = 0;

  /// Get the actual port the server is listening on
  int get port => _port;

  /// Check if the server is running
  bool get isRunning => _server != null;

  /// Start the server on a fixed port.
  /// Pass securityContext for HTTPS, or null for HTTP (testing only).
  ///
  /// If server is already running, returns immediately.
  /// Uses fixed port to prevent orphaned servers after hot restart.
  Future<void> start({
    int port = 0, // Ignored, uses fixed port
    required ContactsService contactsService,
    required SmsService smsService,
    required CallLogService callLogService,
    required PairingService pairingService,
    required SyncStorageService syncStorageService,
    SecurityContext? securityContext,
  }) async {
    // If this singleton already has a server running, just return
    if (_server != null) {
      return;
    }

    final router = createRouter(
      contactsService: contactsService,
      smsService: smsService,
      callLogService: callLogService,
      pairingService: pairingService,
      syncStorageService: syncStorageService,
    );

    // Try to bind to the fixed port
    // If it fails (port in use from previous hot restart), wait and retry
    HttpServer? server;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        // Use anyIPv6 for dual-stack support (accepts both IPv4 and IPv6)
        // This fixes connection issues when mDNS returns IPv6 addresses
        server = await shelf_io.serve(
          router.call,
          InternetAddress.anyIPv6,
          _fixedPort,
          securityContext: securityContext,
          shared: true, // Allow address reuse for dual-stack
        );
        break;
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 48 || // macOS: Address already in use
            e.osError?.errorCode == 98 || // Linux: Address already in use
            e.message.contains('Address already in use')) {
          // Port is in use - likely orphaned server from hot restart
          // Wait a bit for OS to release it, then retry
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            continue;
          }
        }
        rethrow;
      }
    }

    if (server == null) {
      throw Exception('Failed to start server after multiple attempts');
    }

    _server = server;
    _port = server.port;

    // Store port for reference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_portKey, _port);
  }

  /// Stop the server
  Future<void> stop() async {
    final server = _server;
    if (server != null) {
      _server = null; // Clear reference immediately to prevent race conditions
      _port = 0;
      await server.close(force: true);

      // Clear stored port
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_portKey);
    }
  }
}
