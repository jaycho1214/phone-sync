import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shelf/shelf.dart';

import '../../contacts_service.dart';

/// Handle GET /contacts endpoint
Future<Response> handleContacts(Request request, ContactsService service) async {
  try {
    // Contacts don't have timestamp filtering - always full extraction
    final contacts = <Contact>[];

    await for (final batch in service.extractContacts()) {
      contacts.addAll(batch);
    }

    // Convert to JSON-serializable format
    final data = contacts.map((c) => _contactToJson(c)).toList();

    final responseBody = jsonEncode({
      'data': data,
      'count': data.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Response.ok(responseBody, headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Map<String, dynamic> _contactToJson(Contact contact) {
  return {
    'id': contact.id,
    'displayName': contact.displayName,
    'phones': contact.phones.map((p) => {'number': p.number, 'label': p.label.name}).toList(),
    'emails': contact.emails.map((e) => {'address': e.address, 'label': e.label.name}).toList(),
  };
}
