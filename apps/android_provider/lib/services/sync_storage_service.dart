import 'package:shared_preferences/shared_preferences.dart';

enum DataSource { contacts, sms, callLog }

class SyncStorageService {
  static const _keyPrefix = 'last_sync_';

  Future<int?> getLastSyncTimestamp(DataSource source) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyPrefix${source.name}');
  }

  Future<void> setLastSyncTimestamp(DataSource source, int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyPrefix${source.name}', timestamp);
  }

  Future<void> clearAllSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final source in DataSource.values) {
      await prefs.remove('$_keyPrefix${source.name}');
    }
  }
}
