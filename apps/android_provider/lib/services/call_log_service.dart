import 'package:call_log/call_log.dart';

class CallLogService {
  static const int _pageSize = 500;

  /// Get count of call log entries (since timestamp if provided)
  Future<int> getCallLogCount({int? sinceTimestamp}) async {
    final entries = await _getEntries(sinceTimestamp: sinceTimestamp);
    return entries.length;
  }

  /// Get count and phone numbers in a single query (optimization for UI)
  Future<({int count, List<String> phoneNumbers})> getCountAndPhoneNumbers({int? sinceTimestamp}) async {
    final entries = await _getEntries(sinceTimestamp: sinceTimestamp);
    final phoneNumbers = entries
        .map((e) => e.number)
        .where((n) => n != null)
        .cast<String>()
        .toList();
    return (count: entries.length, phoneNumbers: phoneNumbers);
  }

  /// Extract call log entries with date filtering
  Stream<List<CallLogEntry>> extractCallLogs({
    int? sinceTimestamp,
    void Function(int current, int total)? onProgress,
  }) async* {
    final entries = await _getEntries(sinceTimestamp: sinceTimestamp);
    final total = entries.length;

    for (var i = 0; i < total; i += _pageSize) {
      final end = (i + _pageSize > total) ? total : i + _pageSize;
      final batch = entries.sublist(i, end);
      onProgress?.call(end, total);
      yield batch;
    }
  }

  /// Get phone numbers from call log
  Future<List<String>> extractPhoneNumbers({int? sinceTimestamp}) async {
    final entries = await _getEntries(sinceTimestamp: sinceTimestamp);
    return entries.map((e) => e.number).where((n) => n != null).cast<String>().toList();
  }

  Future<List<CallLogEntry>> _getEntries({int? sinceTimestamp}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final entries = await CallLog.query(dateFrom: sinceTimestamp ?? 0, dateTo: now);

    return entries.toList();
  }
}
