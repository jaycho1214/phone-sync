import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/server/handlers/sync_status_handler.dart';

/// State for desktop activity reported to Android
class DesktopActivityState {
  final bool isExporting;
  final String? exportPhase; // 'contacts', 'sms', 'calls'
  final int currentCount;
  final int totalCount;
  final int? contactsExported;
  final int? smsExported;
  final int? callsExported;
  final DateTime? lastExportTime;

  const DesktopActivityState({
    this.isExporting = false,
    this.exportPhase,
    this.currentCount = 0,
    this.totalCount = 0,
    this.contactsExported,
    this.smsExported,
    this.callsExported,
    this.lastExportTime,
  });

  DesktopActivityState copyWith({
    bool? isExporting,
    String? exportPhase,
    int? currentCount,
    int? totalCount,
    int? contactsExported,
    int? smsExported,
    int? callsExported,
    DateTime? lastExportTime,
  }) {
    return DesktopActivityState(
      isExporting: isExporting ?? this.isExporting,
      exportPhase: exportPhase ?? this.exportPhase,
      currentCount: currentCount ?? this.currentCount,
      totalCount: totalCount ?? this.totalCount,
      contactsExported: contactsExported ?? this.contactsExported,
      smsExported: smsExported ?? this.smsExported,
      callsExported: callsExported ?? this.callsExported,
      lastExportTime: lastExportTime ?? this.lastExportTime,
    );
  }

  String get exportStatusMessage {
    if (!isExporting) return '';
    if (exportPhase == 'contacts') return 'Exporting contacts...';
    if (exportPhase == 'sms') return 'Exporting SMS...';
    if (exportPhase == 'calls') return 'Exporting calls...';
    return 'Exporting...';
  }
}

class DesktopActivityNotifier extends Notifier<DesktopActivityState> {
  bool _isDisposed = false;

  @override
  DesktopActivityState build() {
    _isDisposed = false;

    // Register callback with the handler
    SyncStatusHandler.setCallback(_onStatusChanged);

    // Register cleanup on dispose
    ref.onDispose(() {
      _isDisposed = true;
      SyncStatusHandler.setCallback(null);
    });

    return const DesktopActivityState();
  }

  void _onStatusChanged(SyncStatus status) {
    if (_isDisposed) return;
    if (status.isSyncing) {
      state = state.copyWith(
        isExporting: true,
        exportPhase: status.phase,
        currentCount: status.currentCount,
        totalCount: status.totalCount,
      );
    } else {
      // Export completed
      state = DesktopActivityState(
        isExporting: false,
        exportPhase: null,
        contactsExported: status.contactsSynced,
        smsExported: status.smsSynced,
        callsExported: status.callsSynced,
        lastExportTime: DateTime.now(),
      );
    }
  }

  void reset() {
    state = const DesktopActivityState();
  }
}

final desktopActivityProvider =
    NotifierProvider<DesktopActivityNotifier, DesktopActivityState>(
      DesktopActivityNotifier.new,
    );
