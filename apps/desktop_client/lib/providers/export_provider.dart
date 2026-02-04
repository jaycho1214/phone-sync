import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/phone_repository.dart';
import '../services/export_service.dart';
import 'sync_provider.dart';

/// State for export operations.
class ExportState {
  final bool isExporting;
  final bool koreanMobileOnly;
  final String? lastExportPath;
  final String? error;

  const ExportState({
    this.isExporting = false,
    this.koreanMobileOnly = true,
    this.lastExportPath,
    this.error,
  });

  ExportState copyWith({
    bool? isExporting,
    bool? koreanMobileOnly,
    String? lastExportPath,
    String? error,
  }) {
    return ExportState(
      isExporting: isExporting ?? this.isExporting,
      koreanMobileOnly: koreanMobileOnly ?? this.koreanMobileOnly,
      lastExportPath: lastExportPath ?? this.lastExportPath,
      error: error,
    );
  }
}

/// Notifier for export state.
class ExportNotifier extends StateNotifier<ExportState> {
  final PhoneRepository _repository;
  final ExportService _exportService;

  ExportNotifier({
    required PhoneRepository repository,
  })  : _repository = repository,
        _exportService = ExportService(),
        super(const ExportState());

  /// Set the Korean mobile filter.
  void setKoreanMobileFilter(bool value) {
    state = state.copyWith(koreanMobileOnly: value);
  }

  /// Export phone entries to Excel.
  Future<void> export(String deviceName) async {
    state = state.copyWith(isExporting: true, error: null);

    try {
      // Get entries from repository with filter
      final entries = await _repository.getAllEntries(
        koreanMobileOnly: state.koreanMobileOnly,
      );

      if (entries.isEmpty) {
        state = state.copyWith(
          isExporting: false,
          error: 'No phone numbers to export',
        );
        return;
      }

      // Generate filename
      final filename = _exportService.generateFilename(deviceName);

      // Show file save dialog
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel file',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) {
        // User cancelled
        state = state.copyWith(isExporting: false);
        return;
      }

      // Ensure .xlsx extension
      final filePath = result.endsWith('.xlsx') ? result : '$result.xlsx';

      // Convert entries to maps for isolate
      final entryMaps = entries
          .map((e) => {
                'phoneNumber': e.phoneNumber,
                'displayName': e.displayName,
                'sourceTypes': e.sourceTypes,
                'firstSeen': e.firstSeen,
                'lastSeen': e.lastSeen,
              })
          .toList();

      // Export to file
      await _exportService.exportToExcel(
        entries: entryMaps,
        filePath: filePath,
      );

      state = state.copyWith(
        isExporting: false,
        lastExportPath: filePath,
      );
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for export state.
final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>(
  (ref) {
    final repository = ref.watch(phoneRepositoryProvider);
    return ExportNotifier(repository: repository);
  },
);
