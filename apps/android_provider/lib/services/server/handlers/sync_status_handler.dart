import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../sync_storage_service.dart';

/// Callback for sync state changes
typedef SyncStateCallback = void Function(SyncStatus status);

/// Represents sync status reported by desktop client
class SyncStatus {
  final bool isSyncing;
  final String? phase; // 'contacts', 'sms', 'calls', 'completed'
  final int currentCount;
  final int totalCount;
  final int? contactsSynced;
  final int? smsSynced;
  final int? callsSynced;

  const SyncStatus({
    required this.isSyncing,
    this.phase,
    this.currentCount = 0,
    this.totalCount = 0,
    this.contactsSynced,
    this.smsSynced,
    this.callsSynced,
  });
}

/// Handler state for sync status
class SyncStatusHandler {
  static SyncStateCallback? _onSyncStateChanged;
  static SyncStatus _currentStatus = const SyncStatus(isSyncing: false);

  /// Set callback for sync state changes
  static void setCallback(SyncStateCallback? callback) {
    _onSyncStateChanged = callback;
  }

  /// Get current sync status
  static SyncStatus get currentStatus => _currentStatus;

  /// Update sync status
  static void updateStatus(SyncStatus status) {
    _currentStatus = status;
    _onSyncStateChanged?.call(status);
  }
}

/// Handle POST /sync/status endpoint
/// Accepts JSON: {
///   "action": "start" | "progress" | "complete",
///   "phase": "contacts" | "sms" | "calls",
///   "currentCount": 123,
///   "totalCount": 456,
///   "contactsSynced": 100,
///   "smsSynced": 200,
///   "callsSynced": 150
/// }
Future<Response> handleSyncStatus(Request request, SyncStorageService storageService) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final action = json['action'] as String?;

    if (action == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'Missing action in request body'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    switch (action) {
      case 'start':
        SyncStatusHandler.updateStatus(
          const SyncStatus(isSyncing: true, phase: 'contacts', currentCount: 0, totalCount: 0),
        );
        break;

      case 'progress':
        final phase = json['phase'] as String?;
        final current = json['currentCount'] as int? ?? 0;
        final total = json['totalCount'] as int? ?? 0;
        SyncStatusHandler.updateStatus(
          SyncStatus(isSyncing: true, phase: phase, currentCount: current, totalCount: total),
        );
        break;

      case 'complete':
        final contactsSynced = json['contactsSynced'] as int?;
        final smsSynced = json['smsSynced'] as int?;
        final callsSynced = json['callsSynced'] as int?;

        // Update sync timestamps
        final now = DateTime.now().millisecondsSinceEpoch;
        if (contactsSynced != null && contactsSynced > 0) {
          await storageService.setLastSyncTimestamp(DataSource.contacts, now);
        }
        if (smsSynced != null && smsSynced > 0) {
          await storageService.setLastSyncTimestamp(DataSource.sms, now);
        }
        if (callsSynced != null && callsSynced > 0) {
          await storageService.setLastSyncTimestamp(DataSource.callLog, now);
        }

        SyncStatusHandler.updateStatus(
          SyncStatus(
            isSyncing: false,
            phase: 'completed',
            contactsSynced: contactsSynced,
            smsSynced: smsSynced,
            callsSynced: callsSynced,
          ),
        );
        break;

      default:
        return Response(
          400,
          body: jsonEncode({'error': 'Invalid action: $action'}),
          headers: {'Content-Type': 'application/json'},
        );
    }

    return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid request body: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
