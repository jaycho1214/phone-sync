import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/export_service.dart';
import '../services/sync_service.dart';

/// Data types that can be exported
enum DataType { contacts, sms, calls }

/// State for export operations.
class ExportState {
  final bool isExporting;
  final bool isLoadingCounts;
  final String currentPhase; // 'idle', 'fetching', 'exporting'
  final String? currentDataType; // 'contacts', 'sms', 'calls'
  final int fetchedCount;
  final bool koreanMobileOnly;
  final DateTime? sinceDate;
  final String? lastExportPath;
  final String? error;

  // Data counts from device (null if still loading)
  final int? contactsCount;
  final int? smsCount;
  final int? callsCount;
  final int? phoneNumbersCount; // null if still computing on device

  // Selected data types for export
  final Set<DataType> selectedTypes;

  const ExportState({
    this.isExporting = false,
    this.isLoadingCounts = false,
    this.currentPhase = 'idle',
    this.currentDataType,
    this.fetchedCount = 0,
    this.koreanMobileOnly = true,
    this.sinceDate,
    this.lastExportPath,
    this.error,
    this.contactsCount,
    this.smsCount,
    this.callsCount,
    this.phoneNumbersCount,
    this.selectedTypes = const {DataType.contacts, DataType.sms, DataType.calls},
  });

  ExportState copyWith({
    bool? isExporting,
    bool? isLoadingCounts,
    String? currentPhase,
    String? currentDataType,
    int? fetchedCount,
    bool? koreanMobileOnly,
    DateTime? sinceDate,
    String? lastExportPath,
    String? error,
    bool clearSinceDate = false,
    int? contactsCount,
    int? smsCount,
    int? callsCount,
    int? phoneNumbersCount,
    bool clearPhoneNumbersCount = false,
    bool clearContactsCount = false,
    bool clearSmsCount = false,
    bool clearCallsCount = false,
    Set<DataType>? selectedTypes,
  }) {
    return ExportState(
      isExporting: isExporting ?? this.isExporting,
      isLoadingCounts: isLoadingCounts ?? this.isLoadingCounts,
      currentPhase: currentPhase ?? this.currentPhase,
      currentDataType: currentDataType ?? this.currentDataType,
      fetchedCount: fetchedCount ?? this.fetchedCount,
      koreanMobileOnly: koreanMobileOnly ?? this.koreanMobileOnly,
      sinceDate: clearSinceDate ? null : (sinceDate ?? this.sinceDate),
      lastExportPath: lastExportPath ?? this.lastExportPath,
      error: error,
      contactsCount: clearContactsCount ? null : (contactsCount ?? this.contactsCount),
      smsCount: clearSmsCount ? null : (smsCount ?? this.smsCount),
      callsCount: clearCallsCount ? null : (callsCount ?? this.callsCount),
      phoneNumbersCount: clearPhoneNumbersCount
          ? null
          : (phoneNumbersCount ?? this.phoneNumbersCount),
      selectedTypes: selectedTypes ?? this.selectedTypes,
    );
  }

  String get statusMessage {
    if (!isExporting) return '';
    if (currentPhase == 'fetching') {
      return 'Fetching $currentDataType... ($fetchedCount)';
    }
    if (currentPhase == 'exporting') {
      return 'Writing Excel file...';
    }
    return '';
  }

  bool get hasAnyCounts => (contactsCount ?? 0) > 0 || (smsCount ?? 0) > 0 || (callsCount ?? 0) > 0;

  bool get hasAnySelected => selectedTypes.isNotEmpty;
}

/// Notifier for export state.
class ExportNotifier extends Notifier<ExportState> {
  late final ExportService _exportService;
  SyncService? _syncService;

  @override
  ExportState build() {
    _exportService = ExportService();
    return const ExportState();
  }

  /// Set the sync service (called when paired)
  void setSyncService(SyncService? service) {
    _syncService = service;
    if (service != null) {
      // Auto-fetch counts when service is set
      fetchCounts();
    }
  }

  /// Fetch counts from the device
  Future<void> fetchCounts() async {
    final syncService = _syncService;
    if (syncService == null) return;

    state = state.copyWith(isLoadingCounts: true, error: null);

    try {
      final counts = await syncService.fetchCounts();
      final phoneNumbers = counts['phoneNumbers'];
      final isComputing = counts['phoneNumbersComputing'] == 1;

      state = state.copyWith(
        isLoadingCounts: isComputing, // Keep loading if phone numbers still computing
        contactsCount: counts['contacts'] ?? 0,
        smsCount: counts['sms'] ?? 0,
        callsCount: counts['calls'] ?? 0,
        phoneNumbersCount: phoneNumbers,
        clearPhoneNumbersCount: phoneNumbers == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCounts: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Toggle a data type selection
  void toggleDataType(DataType type) {
    final newSelected = Set<DataType>.from(state.selectedTypes);
    if (newSelected.contains(type)) {
      newSelected.remove(type);
    } else {
      newSelected.add(type);
    }
    state = state.copyWith(selectedTypes: newSelected);
  }

  /// Set the Korean mobile filter.
  void setKoreanMobileFilter(bool value) {
    state = state.copyWith(koreanMobileOnly: value);
  }

  /// Set the since date filter for SMS/calls.
  void setSinceDate(DateTime? date) {
    if (date == null) {
      state = state.copyWith(clearSinceDate: true);
    } else {
      state = state.copyWith(sinceDate: date);
    }
  }

  /// Export selected data types to Excel
  Future<void> exportSelected(String deviceName) async {
    final syncService = _syncService;
    if (syncService == null) {
      state = state.copyWith(error: 'Not connected to device');
      return;
    }

    if (state.selectedTypes.isEmpty) {
      state = state.copyWith(error: 'No data types selected');
      return;
    }

    state = state.copyWith(
      isExporting: true,
      currentPhase: 'fetching',
      error: null,
      lastExportPath: null,
    );

    // Report export start to Android
    await syncService.reportSyncStatus(action: 'start');

    try {
      // Prepare data containers
      List<Map<String, dynamic>>? contacts;
      List<Map<String, dynamic>>? smsMessages;
      List<Map<String, dynamic>>? callLogs;

      final sinceTimestamp = state.sinceDate?.millisecondsSinceEpoch;

      // Fetch data based on selected types
      if (state.selectedTypes.contains(DataType.contacts)) {
        contacts = await _fetchDataType(
          syncService: syncService,
          dataType: 'contacts',
          fetcher: () => syncService.fetchContacts(
            onProgress: (received, _) => state = state.copyWith(fetchedCount: received),
          ),
        );
      }

      if (state.selectedTypes.contains(DataType.sms)) {
        smsMessages = await _fetchDataType(
          syncService: syncService,
          dataType: 'sms',
          fetcher: () => syncService.fetchSms(
            since: sinceTimestamp,
            onProgress: (received, _) => state = state.copyWith(fetchedCount: received),
          ),
        );
      }

      if (state.selectedTypes.contains(DataType.calls)) {
        callLogs = await _fetchDataType(
          syncService: syncService,
          dataType: 'calls',
          fetcher: () => syncService.fetchCalls(
            since: sinceTimestamp,
            onProgress: (received, _) => state = state.copyWith(fetchedCount: received),
          ),
        );
      }

      // Check if we have any data
      final totalItems =
          (contacts?.length ?? 0) + (smsMessages?.length ?? 0) + (callLogs?.length ?? 0);

      if (totalItems == 0) {
        await syncService.reportSyncStatus(action: 'complete');
        state = state.copyWith(
          isExporting: false,
          currentPhase: 'idle',
          error: 'No data to export',
        );
        return;
      }

      // Generate filename based on selected types
      final suffix = _generateSuffix();
      final filename = _exportService.generateFilename(deviceName, suffix);

      // Show file save dialog
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel file',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) {
        // User cancelled
        await syncService.reportSyncStatus(action: 'complete');
        state = state.copyWith(isExporting: false, currentPhase: 'idle');
        return;
      }

      // Ensure .xlsx extension
      final filePath = result.endsWith('.xlsx') ? result : '$result.xlsx';

      state = state.copyWith(currentPhase: 'exporting');

      // Export to file
      await _exportService.exportDataToExcel(
        contacts: contacts,
        smsMessages: smsMessages,
        callLogs: callLogs,
        filePath: filePath,
        koreanMobileOnly: state.koreanMobileOnly,
        sinceDate: state.sinceDate,
        deviceName: deviceName,
      );

      // Report completion to Android
      await syncService.reportSyncStatus(
        action: 'complete',
        contactsSynced: contacts?.length,
        smsSynced: smsMessages?.length,
        callsSynced: callLogs?.length,
      );

      state = state.copyWith(isExporting: false, currentPhase: 'idle', lastExportPath: filePath);
    } catch (e) {
      // Report error/completion to Android
      await syncService.reportSyncStatus(action: 'complete');
      state = state.copyWith(
        isExporting: false,
        currentPhase: 'idle',
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Helper to fetch a data type with progress reporting.
  Future<List<Map<String, dynamic>>> _fetchDataType({
    required SyncService syncService,
    required String dataType,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
  }) async {
    state = state.copyWith(currentDataType: dataType, fetchedCount: 0);
    await syncService.reportSyncStatus(action: 'progress', phase: dataType, currentCount: 0);

    final data = await fetcher();

    state = state.copyWith(fetchedCount: data.length);
    await syncService.reportSyncStatus(
      action: 'progress',
      phase: dataType,
      currentCount: data.length,
      totalCount: data.length,
    );

    return data;
  }

  String _generateSuffix() {
    if (state.selectedTypes.length == 3) return 'All';
    final parts = <String>[];
    if (state.selectedTypes.contains(DataType.contacts)) parts.add('Contacts');
    if (state.selectedTypes.contains(DataType.sms)) parts.add('SMS');
    if (state.selectedTypes.contains(DataType.calls)) parts.add('Calls');
    return parts.join('-');
  }
}

/// Provider for export state.
final exportProvider = NotifierProvider<ExportNotifier, ExportState>(ExportNotifier.new);
