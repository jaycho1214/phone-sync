import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../pairing_service.dart';

/// Handle POST /unpair endpoint
/// Called by desktop client when user clicks unpair
Future<Response> handleUnpair(Request request, PairingService service) async {
  try {
    // Reset pairing state - this will trigger callback to update UI
    service.reset();

    return Response.ok(
      jsonEncode({'status': 'unpaired'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
