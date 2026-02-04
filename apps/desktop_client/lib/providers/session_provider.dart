import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/session_storage.dart';
import '../services/sync_service.dart';

/// Connection status for the paired device
enum ConnectionStatus { connected, checking, disconnected }

/// State for the pairing session.
class SessionState {
  final String? token;
  final Device? device;
  final bool isPaired;
  final bool isLoading;
  final String? error;
  final SyncService? syncService;
  final ConnectionStatus connectionStatus;

  const SessionState({
    this.token,
    this.device,
    this.isPaired = false,
    this.isLoading = false,
    this.error,
    this.syncService,
    this.connectionStatus = ConnectionStatus.disconnected,
  });

  SessionState copyWith({
    String? token,
    Device? device,
    bool? isPaired,
    bool? isLoading,
    String? error,
    SyncService? syncService,
    ConnectionStatus? connectionStatus,
  }) {
    return SessionState(
      token: token ?? this.token,
      device: device ?? this.device,
      isPaired: isPaired ?? this.isPaired,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      syncService: syncService ?? this.syncService,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

/// Notifier for session state.
class SessionNotifier extends Notifier<SessionState> {
  late final SessionStorage _storage;
  SyncService? _syncService;
  Timer? _healthCheckTimer;
  int _failedHealthChecks = 0;
  static const int _maxFailedChecks = 3;
  static const Duration _healthCheckInterval = Duration(seconds: 10);
  bool _isDisposed = false;

  @override
  SessionState build() {
    _storage = SessionStorage();
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _stopHealthCheck();
      _syncService?.dispose();
    });
    // Schedule loading after build completes to avoid accessing state during build
    Future.microtask(() => _loadSession());
    return const SessionState(isLoading: true);
  }

  /// Get the sync service (if paired).
  SyncService? get syncService => _syncService;

  /// Load saved session from secure storage.
  Future<void> _loadSession() async {
    // isLoading is already true from initial state

    try {
      final session = await _storage.loadSession();

      if (session.token != null && session.deviceHost != null && session.devicePort != null) {
        final device = Device(
          name: session.deviceName ?? 'Paired Device',
          host: session.deviceHost!,
          port: session.devicePort!,
        );

        _syncService = SyncService(baseUrl: device.baseUrl, sessionToken: session.token);

        state = SessionState(
          token: session.token,
          device: device,
          isPaired: true,
          isLoading: false,
          syncService: _syncService,
          connectionStatus: ConnectionStatus.checking,
        );

        // Start health check and verify connection
        _startHealthCheck();
        _checkConnectionNow();
      } else {
        state = const SessionState(isLoading: false);
      }
    } catch (e) {
      state = SessionState(isLoading: false, error: 'Failed to load session: $e');
    }
  }

  /// Start periodic health check timer
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _failedHealthChecks = 0;
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _checkConnectionNow();
    });
  }

  /// Stop health check timer
  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Check connection status immediately
  Future<void> _checkConnectionNow() async {
    if (_syncService == null || !state.isPaired) return;

    try {
      final isOnline = await _syncService!.checkHealth();
      if (_isDisposed) return;

      if (isOnline) {
        _failedHealthChecks = 0;
        if (state.connectionStatus != ConnectionStatus.connected) {
          state = state.copyWith(connectionStatus: ConnectionStatus.connected);
        }
      } else {
        _onHealthCheckFailed();
      }
    } catch (_) {
      _onHealthCheckFailed();
    }
  }

  /// Handle failed health check
  void _onHealthCheckFailed() {
    if (_isDisposed) return;
    _failedHealthChecks++;

    if (_failedHealthChecks >= _maxFailedChecks) {
      state = state.copyWith(connectionStatus: ConnectionStatus.disconnected);
    } else if (state.connectionStatus == ConnectionStatus.connected) {
      state = state.copyWith(connectionStatus: ConnectionStatus.checking);
    }
  }

  /// Manually retry connection
  Future<void> retryConnection() async {
    if (_syncService == null) return;
    state = state.copyWith(connectionStatus: ConnectionStatus.checking);
    _failedHealthChecks = 0;
    await _checkConnectionNow();
  }

  /// Pair with a device using a PIN.
  Future<bool> pair(Device device, String pin) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Create sync service for pairing
      final syncService = SyncService(baseUrl: device.baseUrl);

      // Get computer name as client identifier
      String clientName;
      try {
        clientName = Platform.localHostname;
      } catch (_) {
        clientName = 'Desktop';
      }

      // Attempt to pair
      final token = await syncService.pair(pin, clientName: clientName);

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
        connectionStatus: ConnectionStatus.connected,
      );

      // Start health check for ongoing connection monitoring
      _startHealthCheck();

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Unpair from the current device.
  Future<void> unpair() async {
    _stopHealthCheck();

    // Notify Android device that we're unpairing
    await _syncService?.notifyUnpair();

    await _storage.clearSession();
    _syncService?.dispose();
    _syncService = null;

    state = const SessionState();
  }
}

/// Provider for session state.
final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
