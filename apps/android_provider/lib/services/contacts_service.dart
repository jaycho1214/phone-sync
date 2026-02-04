import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsService {
  static const int _pageSize = 500;

  /// Get count of contacts with phone numbers
  Future<int> getContactsWithPhonesCount() async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );
    return contacts.where((c) => c.phones.isNotEmpty).length;
  }

  /// Get count and phone numbers in a single query (optimization for UI)
  Future<({int count, List<String> phoneNumbers})>
  getCountAndPhoneNumbers() async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );
    final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();

    final phoneNumbers = <String>[];
    for (final contact in withPhones) {
      for (final phone in contact.phones) {
        phoneNumbers.add(phone.number);
      }
    }
    return (count: withPhones.length, phoneNumbers: phoneNumbers);
  }

  /// Extract contacts with phone numbers, yielding in batches
  /// Note: flutter_contacts doesn't support timestamp filtering natively
  /// For contacts, we do full extraction (contacts change less frequently)
  Stream<List<Contact>> extractContacts({
    void Function(int current, int total)? onProgress,
  }) async* {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    // Filter to contacts with phones
    final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();
    final total = withPhones.length;

    // Yield in batches to avoid memory pressure
    for (var i = 0; i < total; i += _pageSize) {
      final end = (i + _pageSize > total) ? total : i + _pageSize;
      final batch = withPhones.sublist(i, end);
      onProgress?.call(end, total);
      yield batch;
    }
  }

  /// Extract phone numbers from contacts
  Future<List<String>> extractPhoneNumbers() async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final numbers = <String>[];
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        numbers.add(phone.number);
      }
    }
    return numbers;
  }
}
