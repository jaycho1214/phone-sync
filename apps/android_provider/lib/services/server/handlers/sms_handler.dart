import 'dart:convert';

import 'package:another_telephony/telephony.dart';
import 'package:shelf/shelf.dart';

import '../../sms_service.dart';

/// Handle GET /sms endpoint
Future<Response> handleSms(Request request, SmsService service) async {
  try {
    // Parse ?since= query parameter (milliseconds since epoch)
    final sinceParam = request.url.queryParameters['since'];
    final sinceTimestamp = sinceParam != null ? int.tryParse(sinceParam) : null;

    final messages = <SmsMessage>[];

    await for (final batch in service.extractSms(sinceTimestamp: sinceTimestamp)) {
      messages.addAll(batch);
    }

    // Convert to JSON-serializable format
    final data = messages.map((m) => _smsToJson(m)).toList();

    final responseBody = jsonEncode({
      'data': data,
      'count': data.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Response.ok(
      responseBody,
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Map<String, dynamic> _smsToJson(SmsMessage message) {
  return {
    'address': message.address,
    'date': message.date,
    'type': message.type?.name,
  };
}
