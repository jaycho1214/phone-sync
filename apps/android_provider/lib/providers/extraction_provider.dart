import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/contacts_service.dart';
import '../services/sms_service.dart';
import '../services/call_log_service.dart';
import '../services/sync_storage_service.dart';

class ExtractionState {
  final int contactCount;
  final int smsCount;
  final int callLogCount;
  final bool isLoading;
  final String? error;
  final double progress;
  final String? currentOperation;

  const ExtractionState({
    this.contactCount = 0,
    this.smsCount = 0,
    this.callLogCount = 0,
    this.isLoading = false,
    this.error,
    this.progress = 0.0,
    this.currentOperation,
  });

  int get totalCount => contactCount + smsCount + callLogCount;

  ExtractionState copyWith({
    int? contactCount,
    int? smsCount,
    int? callLogCount,
    bool? isLoading,
    String? error,
    double? progress,
    String? currentOperation,
  }) {
    return ExtractionState(
      contactCount: contactCount ?? this.contactCount,
      smsCount: smsCount ?? this.smsCount,
      callLogCount: callLogCount ?? this.callLogCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      progress: progress ?? this.progress,
      currentOperation: currentOperation,
    );
  }
}

class ExtractionNotifier extends StateNotifier<ExtractionState> {
  final ContactsService _contactsService;
  final SmsService _smsService;
  final CallLogService _callLogService;
  final SyncStorageService _syncStorage;

  ExtractionNotifier({
    ContactsService? contactsService,
    SmsService? smsService,
    CallLogService? callLogService,
    SyncStorageService? syncStorage,
  })  : _contactsService = contactsService ?? ContactsService(),
        _smsService = smsService ?? SmsService(),
        _callLogService = callLogService ?? CallLogService(),
        _syncStorage = syncStorage ?? SyncStorageService(),
        super(const ExtractionState());

  /// Refresh counts for all granted permissions
  Future<void> refreshCounts({
    required bool hasContacts,
    required bool hasSms,
    required bool hasCallLog,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      int contacts = 0;
      int sms = 0;
      int calls = 0;

      if (hasContacts) {
        contacts = await _contactsService.getContactsWithPhonesCount();
      }

      if (hasSms) {
        final lastSync = await _syncStorage.getLastSyncTimestamp(DataSource.sms);
        sms = await _smsService.getSmsCount(sinceTimestamp: lastSync);
      }

      if (hasCallLog) {
        final lastSync = await _syncStorage.getLastSyncTimestamp(DataSource.callLog);
        calls = await _callLogService.getCallLogCount(sinceTimestamp: lastSync);
      }

      state = ExtractionState(
        contactCount: contacts,
        smsCount: sms,
        callLogCount: calls,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setProgress(double progress, String operation) {
    state = state.copyWith(progress: progress, currentOperation: operation);
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }
}

// Service providers
final contactsServiceProvider = Provider((ref) => ContactsService());
final smsServiceProvider = Provider((ref) => SmsService());
final callLogServiceProvider = Provider((ref) => CallLogService());
final syncStorageServiceProvider = Provider((ref) => SyncStorageService());

final extractionProvider =
    StateNotifierProvider<ExtractionNotifier, ExtractionState>(
  (ref) => ExtractionNotifier(
    contactsService: ref.watch(contactsServiceProvider),
    smsService: ref.watch(smsServiceProvider),
    callLogService: ref.watch(callLogServiceProvider),
    syncStorage: ref.watch(syncStorageServiceProvider),
  ),
);
