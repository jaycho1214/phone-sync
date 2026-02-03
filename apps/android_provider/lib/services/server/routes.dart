import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../call_log_service.dart';
import '../contacts_service.dart';
import '../pairing_service.dart';
import '../sms_service.dart';
import 'handlers/calls_handler.dart';
import 'handlers/contacts_handler.dart';
import 'handlers/pairing_handler.dart';
import 'handlers/sms_handler.dart';
import 'middleware/auth_middleware.dart';

/// Create router with data extraction endpoints
/// Returns a Pipeline handler with authentication middleware applied
Handler createRouter({
  required ContactsService contactsService,
  required SmsService smsService,
  required CallLogService callLogService,
  required PairingService pairingService,
}) {
  final router = Router();

  // POST /pair - Exchange PIN for session token (no auth required)
  router.post('/pair', (Request request) async {
    return handlePair(request, pairingService);
  });

  // GET /contacts - Extract all contacts with phone numbers
  router.get('/contacts', (Request request) async {
    return handleContacts(request, contactsService);
  });

  // GET /sms - Extract SMS messages, supports ?since= for incremental sync
  router.get('/sms', (Request request) async {
    return handleSms(request, smsService);
  });

  // GET /calls - Extract call log entries, supports ?since= for incremental sync
  router.get('/calls', (Request request) async {
    return handleCalls(request, callLogService);
  });

  // Health check endpoint (no auth required)
  router.get('/health', (Request request) {
    return Response.ok('{"status": "ok"}', headers: {'Content-Type': 'application/json'});
  });

  // Wrap router with authentication middleware
  // /pair and /health are exempt from auth check inside the middleware
  return const Pipeline()
      .addMiddleware(createAuthMiddleware(pairingService))
      .addHandler(router.call);
}
