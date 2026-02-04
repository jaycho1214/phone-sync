import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../pairing_service.dart';

/// Paths that don't require authentication.
const _publicPaths = {'pair', 'health'};

/// Create middleware that validates session token in Authorization header.
/// Exempts /pair and /health endpoints from authentication.
Middleware createAuthMiddleware(PairingService service) {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;

      // Exempt public paths from authentication
      if (_publicPaths.contains(path)) {
        return innerHandler(request);
      }

      // Check Authorization header
      final authHeader = request.headers['authorization'];
      final token = _extractBearerToken(authHeader);

      if (token == null) {
        return Response(
          401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (!service.isValidSession(token)) {
        return Response(
          401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Token is valid - update activity time for heartbeat tracking
      service.updateLastActivity();

      // Proceed to handler
      return innerHandler(request);
    };
  };
}

/// Extract Bearer token from Authorization header.
/// Returns null if header is missing, malformed, or too short.
String? _extractBearerToken(String? authHeader) {
  const prefix = 'Bearer ';
  if (authHeader == null || !authHeader.startsWith(prefix)) {
    return null;
  }
  final token = authHeader.substring(prefix.length);
  return token.isNotEmpty ? token : null;
}
