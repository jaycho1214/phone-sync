import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_storage_service.dart';
import 'extraction_provider.dart';

class SyncState {
  final int? contactsLastSync;
  final int? smsLastSync;
  final int? callLogLastSync;

  const SyncState({
    this.contactsLastSync,
    this.smsLastSync,
    this.callLogLastSync,
  });

  bool get hasEverSynced =>
      contactsLastSync != null ||
      smsLastSync != null ||
      callLogLastSync != null;

  String formatLastSync(int? timestamp) {
    if (timestamp == null) return 'Never';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class SyncStateNotifier extends StateNotifier<SyncState> {
  final SyncStorageService _storage;

  SyncStateNotifier(this._storage) : super(const SyncState());

  Future<void> loadSyncState() async {
    final contacts = await _storage.getLastSyncTimestamp(DataSource.contacts);
    final sms = await _storage.getLastSyncTimestamp(DataSource.sms);
    final callLog = await _storage.getLastSyncTimestamp(DataSource.callLog);

    state = SyncState(
      contactsLastSync: contacts,
      smsLastSync: sms,
      callLogLastSync: callLog,
    );
  }

  Future<void> updateSyncTimestamp(DataSource source, int timestamp) async {
    await _storage.setLastSyncTimestamp(source, timestamp);
    await loadSyncState();
  }

  Future<void> clearAllSyncState() async {
    await _storage.clearAllSyncState();
    state = const SyncState();
  }
}

final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
  return SyncStateNotifier(ref.watch(syncStorageServiceProvider));
});
