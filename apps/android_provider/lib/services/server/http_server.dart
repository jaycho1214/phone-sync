import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../call_log_service.dart';
import '../contacts_service.dart';
import '../sms_service.dart';
import 'routes.dart';

/// HTTP server for serving phone data endpoints
class PhoneSyncServer {
  HttpServer? _server;
  int _port = 0;

  /// Get the actual port the server is listening on
  int get port => _port;

  /// Check if the server is running
  bool get isRunning => _server != null;

  /// Start the server on the specified port
  /// Use port 0 for dynamic port assignment
  Future<void> start({
    int port = 0,
    required ContactsService contactsService,
    required SmsService smsService,
    required CallLogService callLogService,
  }) async {
    if (_server != null) {
      throw StateError('Server is already running');
    }

    final router = createRouter(
      contactsService: contactsService,
      smsService: smsService,
      callLogService: callLogService,
    );

    _server = await shelf_io.serve(
      router.call,
      InternetAddress.anyIPv4,
      port,
    );

    _port = _server!.port;
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }
}
