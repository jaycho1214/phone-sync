import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../call_log_service.dart';
import '../contacts_service.dart';
import '../pairing_service.dart';
import '../sms_service.dart';
import '../sync_storage_service.dart';
import 'handlers/calls_handler.dart';
import 'handlers/contacts_handler.dart';
import 'handlers/counts_handler.dart';
import 'handlers/pairing_handler.dart';
import 'handlers/sms_handler.dart';
import 'handlers/sync_status_handler.dart';
import 'handlers/unpair_handler.dart';
import 'middleware/auth_middleware.dart';

/// Create router with data extraction endpoints
/// Returns a Pipeline handler with authentication middleware applied
Handler createRouter({
  required ContactsService contactsService,
  required SmsService smsService,
  required CallLogService callLogService,
  required PairingService pairingService,
  required SyncStorageService syncStorageService,
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

  // GET /counts - Get counts for all data types (lightweight)
  router.get('/counts', (Request request) async {
    return handleCounts(request, contactsService, smsService, callLogService);
  });

  // POST /sync/status - Desktop reports sync progress/completion
  router.post('/sync/status', (Request request) async {
    return handleSyncStatus(request, syncStorageService);
  });

  // POST /unpair - Desktop notifies it's unpairing
  router.post('/unpair', (Request request) async {
    return handleUnpair(request, pairingService);
  });

  // Health check endpoint (no auth required)
  // Also updates last activity time for session timeout
  router.get('/health', (Request request) {
    pairingService.updateLastActivity();
    return Response.ok('{"status": "ok"}', headers: {'Content-Type': 'application/json'});
  });

  // Wrap router with authentication middleware
  // /pair and /health are exempt from auth check inside the middleware
  return const Pipeline()
      .addMiddleware(createAuthMiddleware(pairingService))
      .addHandler(router.call);
}
