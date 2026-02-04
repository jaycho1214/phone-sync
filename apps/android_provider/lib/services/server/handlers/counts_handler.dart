import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../call_log_service.dart';
import '../../contacts_service.dart';
import '../../counts_cache_service.dart';
import '../../sms_service.dart';

/// Handle GET /counts endpoint - returns counts for all data types
/// phoneNumbers uses cached value from extraction_provider (null if still computing)
Future<Response> handleCounts(
  Request request,
  ContactsService contactsService,
  SmsService smsService,
  CallLogService callLogService,
) async {
  try {
    final cache = CountsCacheService();

    // Fetch counts in parallel (these are fast queries)
    final results = await Future.wait([
      contactsService.getContactsWithPhonesCount(),
      smsService.getSmsCount(),
      callLogService.getCallLogCount(),
    ]);

    final responseBody = jsonEncode({
      'contacts': results[0],
      'sms': results[1],
      'calls': results[2],
      'phoneNumbers': cache.phoneNumbersCount, // null if not yet computed
      'phoneNumbersComputing': cache.isComputing,
    });

    return Response.ok(responseBody, headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
