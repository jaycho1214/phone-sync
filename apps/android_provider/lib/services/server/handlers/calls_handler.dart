import 'dart:convert';

import 'package:call_log/call_log.dart';
import 'package:shelf/shelf.dart';

import '../../call_log_service.dart';

/// Handle GET /calls endpoint
Future<Response> handleCalls(Request request, CallLogService service) async {
  try {
    // Parse ?since= query parameter (milliseconds since epoch)
    final sinceParam = request.url.queryParameters['since'];
    final sinceTimestamp = sinceParam != null ? int.tryParse(sinceParam) : null;

    final entries = <CallLogEntry>[];

    await for (final batch in service.extractCallLogs(
      sinceTimestamp: sinceTimestamp,
    )) {
      entries.addAll(batch);
    }

    // Convert to JSON-serializable format
    final data = entries.map((e) => _callToJson(e)).toList();

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

Map<String, dynamic> _callToJson(CallLogEntry entry) {
  return {
    'number': entry.number,
    'name': entry.name,
    'callType': entry.callType?.name,
    'duration': entry.duration,
    'timestamp': entry.timestamp,
  };
}
