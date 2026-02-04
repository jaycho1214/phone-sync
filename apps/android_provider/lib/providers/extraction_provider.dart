import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/contacts_service.dart';
import '../services/sms_service.dart';
import '../services/call_log_service.dart';
import '../services/counts_cache_service.dart';
import 'server_provider.dart';

class ExtractionState {
  final int contactCount;
  final int smsCount;
  final int callLogCount;
  final int phoneNumberCount; // Unique phone numbers
  final bool isLoading;
  final String? error;
  final double progress;
  final String? currentOperation;

  const ExtractionState({
    this.contactCount = 0,
    this.smsCount = 0,
    this.callLogCount = 0,
    this.phoneNumberCount = 0,
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
    int? phoneNumberCount,
    bool? isLoading,
    String? error,
    double? progress,
    String? currentOperation,
  }) {
    return ExtractionState(
      contactCount: contactCount ?? this.contactCount,
      smsCount: smsCount ?? this.smsCount,
      callLogCount: callLogCount ?? this.callLogCount,
      phoneNumberCount: phoneNumberCount ?? this.phoneNumberCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      progress: progress ?? this.progress,
      currentOperation: currentOperation,
    );
  }
}

class ExtractionNotifier extends Notifier<ExtractionState> {
  late final ContactsService _contactsService;
  late final SmsService _smsService;
  late final CallLogService _callLogService;

  @override
  ExtractionState build() {
    _contactsService = ref.watch(contactsServiceProvider);
    _smsService = ref.watch(smsServiceProvider);
    _callLogService = ref.watch(callLogServiceProvider);
    return const ExtractionState();
  }

  /// Refresh counts for all granted permissions
  /// Shows TOTAL counts (not incremental), matching what will be exported
  Future<void> refreshCounts({
    required bool hasContacts,
    required bool hasSms,
    required bool hasCallLog,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final cache = CountsCacheService();
    cache.setComputing(true);

    try {
      int contacts = 0;
      int sms = 0;
      int calls = 0;
      final phoneNumbers = <String>{};

      if (hasContacts) {
        contacts = await _contactsService.getContactsWithPhonesCount();
        // Collect phone numbers from contacts
        final contactNumbers = await _contactsService.extractPhoneNumbers();
        phoneNumbers.addAll(contactNumbers);
      }

      if (hasSms) {
        // Show total count (no timestamp filter for display)
        sms = await _smsService.getSmsCount();
        // Collect phone numbers from SMS
        final smsNumbers = await _smsService.extractPhoneNumbers();
        phoneNumbers.addAll(smsNumbers);
      }

      if (hasCallLog) {
        // Show total count (no timestamp filter for display)
        calls = await _callLogService.getCallLogCount();
        // Collect phone numbers from calls
        final callNumbers = await _callLogService.extractPhoneNumbers();
        phoneNumbers.addAll(callNumbers);
      }

      // Update cache for server endpoint
      cache.setPhoneNumbersCount(phoneNumbers.length);

      state = ExtractionState(
        contactCount: contacts,
        smsCount: sms,
        callLogCount: calls,
        phoneNumberCount: phoneNumbers.length,
        isLoading: false,
      );
    } catch (e) {
      cache.setComputing(false);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Use shared service providers from server_provider.dart to avoid duplicate instances
final extractionProvider = NotifierProvider<ExtractionNotifier, ExtractionState>(
  ExtractionNotifier.new,
);
