import 'package:another_telephony/telephony.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;
  static const int _pageSize = 500;

  /// Get count of SMS messages (since timestamp if provided)
  Future<int> getSmsCount({int? sinceTimestamp}) async {
    final messages = await _getMessages(sinceTimestamp: sinceTimestamp);
    return messages.length;
  }

  /// Get count and phone numbers in a single query (optimization for UI)
  Future<({int count, List<String> phoneNumbers})> getCountAndPhoneNumbers({
    int? sinceTimestamp,
  }) async {
    final messages = await _getMessages(sinceTimestamp: sinceTimestamp);
    final phoneNumbers = messages
        .map((m) => m.address)
        .where((addr) => addr != null)
        .cast<String>()
        .toList();
    return (count: messages.length, phoneNumbers: phoneNumbers);
  }

  /// Extract SMS messages with timestamp filtering
  Stream<List<SmsMessage>> extractSms({
    int? sinceTimestamp,
    void Function(int current, int total)? onProgress,
  }) async* {
    final messages = await _getMessages(sinceTimestamp: sinceTimestamp);
    final total = messages.length;

    for (var i = 0; i < total; i += _pageSize) {
      final end = (i + _pageSize > total) ? total : i + _pageSize;
      final batch = messages.sublist(i, end);
      onProgress?.call(end, total);
      yield batch;
    }
  }

  /// Get phone numbers from SMS messages
  Future<List<String>> extractPhoneNumbers({int? sinceTimestamp}) async {
    final messages = await _getMessages(sinceTimestamp: sinceTimestamp);
    return messages
        .map((m) => m.address)
        .where((addr) => addr != null)
        .cast<String>()
        .toList();
  }

  Future<List<SmsMessage>> _getMessages({int? sinceTimestamp}) async {
    SmsFilter? filter;
    if (sinceTimestamp != null) {
      filter = SmsFilter.where(
        SmsColumn.DATE,
      ).greaterThan(sinceTimestamp.toString());
    }

    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.DATE, SmsColumn.TYPE],
      filter: filter,
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final sent = await _telephony.getSentSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.DATE, SmsColumn.TYPE],
      filter: filter,
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    return [...inbox, ...sent];
  }
}
