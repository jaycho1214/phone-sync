import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../repositories/phone_repository.dart';
import '../services/phone_normalizer.dart';
import '../services/sync_service.dart';

/// State for sync operations.
class SyncState {
  final bool isSyncing;
  final String currentPhase; // 'contacts', 'sms', 'calls', 'idle'
  final int currentCount;
  final int totalCount;
  final String? error;
  final DateTime? lastSyncTime;
  final int totalEntries; // Total unique phone numbers in database

  const SyncState({
    this.isSyncing = false,
    this.currentPhase = 'idle',
    this.currentCount = 0,
    this.totalCount = 0,
    this.error,
    this.lastSyncTime,
    this.totalEntries = 0,
  });

  SyncState copyWith({
    bool? isSyncing,
    String? currentPhase,
    int? currentCount,
    int? totalCount,
    String? error,
    DateTime? lastSyncTime,
    int? totalEntries,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      currentPhase: currentPhase ?? this.currentPhase,
      currentCount: currentCount ?? this.currentCount,
      totalCount: totalCount ?? this.totalCount,
      error: error,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      totalEntries: totalEntries ?? this.totalEntries,
    );
  }

  /// Get progress message for display.
  String get progressMessage {
    if (!isSyncing) return '';
    final phase = currentPhase[0].toUpperCase() + currentPhase.substring(1);
    return 'Syncing $phase... $currentCount / $totalCount';
  }

  /// Get progress as a fraction (0.0 - 1.0).
  double get progress {
    if (totalCount == 0) return 0.0;
    return currentCount / totalCount;
  }
}

/// Notifier for sync state.
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncService? _syncService;
  final PhoneRepository _repository;
  final PhoneNormalizer _normalizer;

  SyncNotifier({
    required SyncService? syncService,
    required PhoneRepository repository,
  })  : _syncService = syncService,
        _repository = repository,
        _normalizer = PhoneNormalizer(),
        super(const SyncState()) {
    _loadInitialState();
  }

  /// Load entry count and last sync time on initialization.
  Future<void> _loadInitialState() async {
    try {
      final count = await _repository.getEntryCount(koreanMobileOnly: false);
      final lastSyncStr =
          await _repository.getSyncTimestamp('last_full_sync');
      final lastSync =
          lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

      state = state.copyWith(
        totalEntries: count,
        lastSyncTime: lastSync,
      );
    } catch (_) {
      // Ignore errors on initial load
    }
  }

  /// Sync all data from the Android device.
  Future<void> syncAll() async {
    if (_syncService == null) {
      state = state.copyWith(error: 'Not connected to device');
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      currentPhase: 'contacts',
      currentCount: 0,
      totalCount: 0,
      error: null,
    );

    try {
      // 1. Fetch and process contacts
      final contacts = await _syncService.fetchContacts(
        onProgress: (received, total) {
          state = state.copyWith(
            currentCount: received,
            totalCount: total > 0 ? total : received,
          );
        },
      );

      state = state.copyWith(totalCount: contacts.length, currentCount: 0);

      for (var i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        final displayName = contact['displayName'] as String?;
        final phones = contact['phones'] as List<dynamic>?;

        if (phones != null) {
          for (final phone in phones) {
            final rawNumber = phone['number'] as String?;
            if (rawNumber != null) {
              final normalized = _normalizer.normalize(rawNumber);
              if (normalized != null) {
                await _repository.upsertPhoneEntry(
                  normalizedNumber: normalized,
                  displayName: displayName,
                  source: 'contact',
                  rawNumber: rawNumber,
                );
              }
            }
          }
        }

        state = state.copyWith(currentCount: i + 1);
      }

      // 2. Fetch and process SMS
      state = state.copyWith(
        currentPhase: 'sms',
        currentCount: 0,
        totalCount: 0,
      );

      // Get last SMS sync timestamp
      final lastSmsStr = await _repository.getSyncTimestamp('sms_since');
      final lastSms = lastSmsStr != null ? int.tryParse(lastSmsStr) : null;

      final messages = await _syncService.fetchSms(
        since: lastSms,
        onProgress: (received, total) {
          state = state.copyWith(
            currentCount: received,
            totalCount: total > 0 ? total : received,
          );
        },
      );

      state = state.copyWith(totalCount: messages.length, currentCount: 0);

      int? maxSmsTimestamp = lastSms;

      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        final rawNumber = message['address'] as String?;
        final date = message['date'] as int?;

        if (rawNumber != null) {
          final normalized = _normalizer.normalize(rawNumber);
          if (normalized != null) {
            await _repository.upsertPhoneEntry(
              normalizedNumber: normalized,
              source: 'sms',
              timestamp: date,
              rawNumber: rawNumber,
            );
          }
        }

        if (date != null && (maxSmsTimestamp == null || date > maxSmsTimestamp)) {
          maxSmsTimestamp = date;
        }

        state = state.copyWith(currentCount: i + 1);
      }

      // Save SMS sync timestamp
      if (maxSmsTimestamp != null) {
        await _repository.setSyncTimestamp(
          'sms_since',
          maxSmsTimestamp.toString(),
        );
      }

      // 3. Fetch and process calls
      state = state.copyWith(
        currentPhase: 'calls',
        currentCount: 0,
        totalCount: 0,
      );

      // Get last calls sync timestamp
      final lastCallsStr = await _repository.getSyncTimestamp('calls_since');
      final lastCalls = lastCallsStr != null ? int.tryParse(lastCallsStr) : null;

      final calls = await _syncService.fetchCalls(
        since: lastCalls,
        onProgress: (received, total) {
          state = state.copyWith(
            currentCount: received,
            totalCount: total > 0 ? total : received,
          );
        },
      );

      state = state.copyWith(totalCount: calls.length, currentCount: 0);

      int? maxCallTimestamp = lastCalls;

      for (var i = 0; i < calls.length; i++) {
        final call = calls[i];
        final rawNumber = call['number'] as String?;
        final name = call['name'] as String?;
        final timestamp = call['timestamp'] as int?;

        if (rawNumber != null) {
          final normalized = _normalizer.normalize(rawNumber);
          if (normalized != null) {
            await _repository.upsertPhoneEntry(
              normalizedNumber: normalized,
              displayName: name,
              source: 'call',
              timestamp: timestamp,
              rawNumber: rawNumber,
            );
          }
        }

        if (timestamp != null &&
            (maxCallTimestamp == null || timestamp > maxCallTimestamp)) {
          maxCallTimestamp = timestamp;
        }

        state = state.copyWith(currentCount: i + 1);
      }

      // Save calls sync timestamp
      if (maxCallTimestamp != null) {
        await _repository.setSyncTimestamp(
          'calls_since',
          maxCallTimestamp.toString(),
        );
      }

      // Save full sync timestamp
      final now = DateTime.now();
      await _repository.setSyncTimestamp('last_full_sync', now.toIso8601String());

      // Get updated entry count
      final totalCount = await _repository.getEntryCount(koreanMobileOnly: false);

      state = SyncState(
        isSyncing: false,
        currentPhase: 'idle',
        lastSyncTime: now,
        totalEntries: totalCount,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        currentPhase: 'idle',
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Clear all synced data and reset.
  Future<void> clearData() async {
    await _repository.clearAllEntries();
    state = const SyncState();
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for the app database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the phone repository.
final phoneRepositoryProvider = Provider<PhoneRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PhoneRepository(db);
});

/// Provider for sync state.
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  // Import sessionProvider here would create circular dependency
  // So we get syncService from the provider argument instead
  throw UnimplementedError('Use syncProviderFamily instead');
});

/// Provider for sync state with sync service parameter.
final syncProviderFamily =
    StateNotifierProvider.family<SyncNotifier, SyncState, SyncService?>(
  (ref, syncService) {
    final repository = ref.watch(phoneRepositoryProvider);
    return SyncNotifier(
      syncService: syncService,
      repository: repository,
    );
  },
);
