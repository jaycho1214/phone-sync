import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../pairing_service.dart';

/// Create middleware that validates session token in Authorization header
/// Exempts /pair and /health endpoints from authentication
Middleware createAuthMiddleware(PairingService service) {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;

      // Exempt /pair and /health from authentication
      if (path == 'pair' || path == 'health') {
        return innerHandler(request);
      }

      // Check Authorization header
      final authHeader = request.headers['authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.substring(7); // Remove 'Bearer ' prefix

      if (!service.isValidSession(token)) {
        return Response(
          401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Token is valid, proceed to handler
      return innerHandler(request);
    };
  };
}
