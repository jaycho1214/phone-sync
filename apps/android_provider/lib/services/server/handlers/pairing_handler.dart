import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../pairing_service.dart';

/// Handle POST /pair endpoint
/// Accepts JSON: {"pin": "123456"}
/// Returns: {"status": "paired", "sessionToken": "..."} or 401 error
Future<Response> handlePair(Request request, PairingService service) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final pin = json['pin'] as String?;

    if (pin == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'Missing pin in request body'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (!service.isValidPin(pin)) {
      return Response(
        401,
        body: jsonEncode({'error': 'Invalid or expired PIN'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Complete pairing and get session token
    service.completePairing();
    final token = service.state?.sessionToken;

    return Response.ok(
      jsonEncode({
        'status': 'paired',
        'sessionToken': token,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid request body'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
