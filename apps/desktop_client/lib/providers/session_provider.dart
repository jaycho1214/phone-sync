import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/session_storage.dart';
import '../services/sync_service.dart';

/// State for the pairing session.
class SessionState {
  final String? token;
  final Device? device;
  final bool isPaired;
  final bool isLoading;
  final String? error;
  final SyncService? syncService;

  const SessionState({
    this.token,
    this.device,
    this.isPaired = false,
    this.isLoading = false,
    this.error,
    this.syncService,
  });

  SessionState copyWith({
    String? token,
    Device? device,
    bool? isPaired,
    bool? isLoading,
    String? error,
    SyncService? syncService,
  }) {
    return SessionState(
      token: token ?? this.token,
      device: device ?? this.device,
      isPaired: isPaired ?? this.isPaired,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      syncService: syncService ?? this.syncService,
    );
  }
}

/// Notifier for session state.
class SessionNotifier extends StateNotifier<SessionState> {
  final SessionStorage _storage = SessionStorage();
  SyncService? _syncService;

  SessionNotifier() : super(const SessionState()) {
    _loadSession();
  }

  /// Get the sync service (if paired).
  SyncService? get syncService => _syncService;

  /// Load saved session from secure storage.
  Future<void> _loadSession() async {
    state = state.copyWith(isLoading: true);

    try {
      final session = await _storage.loadSession();

      if (session.token != null &&
          session.deviceHost != null &&
          session.devicePort != null) {
        final device = Device(
          name: session.deviceName ?? 'Paired Device',
          host: session.deviceHost!,
          port: session.devicePort!,
        );

        _syncService = SyncService(
          baseUrl: device.baseUrl,
          sessionToken: session.token,
        );

        state = SessionState(
          token: session.token,
          device: device,
          isPaired: true,
          isLoading: false,
          syncService: _syncService,
        );
      } else {
        state = const SessionState(isLoading: false);
      }
    } catch (e) {
      state = SessionState(
        isLoading: false,
        error: 'Failed to load session: $e',
      );
    }
  }

  /// Pair with a device using a PIN.
  Future<bool> pair(Device device, String pin) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Create sync service for pairing
      final syncService = SyncService(baseUrl: device.baseUrl);

      // Attempt to pair
      final token = await syncService.pair(pin);

      // Save session to secure storage
      await _storage.saveSession(
        token: token,
        deviceName: device.name,
        deviceHost: device.host,
        devicePort: device.port,
      );

      _syncService = syncService;

      state = SessionState(
        token: token,
        device: device,
        isPaired: true,
        isLoading: false,
        syncService: _syncService,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Check if the paired device is online.
  Future<bool> checkDeviceOnline() async {
    if (_syncService == null) return false;

    try {
      return await _syncService!.checkHealth();
    } catch (_) {
      return false;
    }
  }

  /// Unpair from the current device.
  Future<void> unpair() async {
    await _storage.clearSession();
    _syncService?.dispose();
    _syncService = null;

    state = const SessionState();
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _syncService?.dispose();
    super.dispose();
  }
}

/// Provider for session state.
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
