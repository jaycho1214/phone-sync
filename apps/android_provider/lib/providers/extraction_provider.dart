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
  /// Optimized: runs queries in parallel and extracts count + phone numbers in single query per source
  Future<void> refreshCounts({
    required bool hasContacts,
    required bool hasSms,
    required bool hasCallLog,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final cache = CountsCacheService();
    cache.setComputing(true);

    try {
      // Run all queries in parallel for better performance
      final futures = <Future<({int count, List<String> phoneNumbers})>>[];

      if (hasContacts) {
        futures.add(_contactsService.getCountAndPhoneNumbers());
      }
      if (hasSms) {
        futures.add(_smsService.getCountAndPhoneNumbers());
      }
      if (hasCallLog) {
        futures.add(_callLogService.getCountAndPhoneNumbers());
      }

      final results = await Future.wait(futures);

      // Extract results based on which permissions were granted
      int contacts = 0;
      int sms = 0;
      int calls = 0;
      final phoneNumbers = <String>{};

      int resultIndex = 0;
      if (hasContacts) {
        final result = results[resultIndex++];
        contacts = result.count;
        phoneNumbers.addAll(result.phoneNumbers);
      }
      if (hasSms) {
        final result = results[resultIndex++];
        sms = result.count;
        phoneNumbers.addAll(result.phoneNumbers);
      }
      if (hasCallLog) {
        final result = results[resultIndex++];
        calls = result.count;
        phoneNumbers.addAll(result.phoneNumbers);
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
final extractionProvider =
    NotifierProvider<ExtractionNotifier, ExtractionState>(
      ExtractionNotifier.new,
    );
