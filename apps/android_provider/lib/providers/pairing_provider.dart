import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pairing_service.dart';
import 'server_provider.dart';

/// UI-facing pairing state
class PairingUIState {
  final String? pin;
  final DateTime? expiresAt;
  final bool isPaired;
  final Duration? timeRemaining;
  final String? clientName;

  const PairingUIState({
    this.pin,
    this.expiresAt,
    this.isPaired = false,
    this.timeRemaining,
    this.clientName,
  });

  PairingUIState copyWith({
    String? pin,
    DateTime? expiresAt,
    bool? isPaired,
    Duration? timeRemaining,
    String? clientName,
  }) {
    return PairingUIState(
      pin: pin ?? this.pin,
      expiresAt: expiresAt ?? this.expiresAt,
      isPaired: isPaired ?? this.isPaired,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      clientName: clientName ?? this.clientName,
    );
  }

  /// Format remaining time as MM:SS
  String get formattedTimeRemaining {
    if (timeRemaining == null) return '--:--';
    final minutes = timeRemaining!.inMinutes;
    final seconds = timeRemaining!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if PIN is expired
  bool get isPinExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class PairingNotifier extends Notifier<PairingUIState> {
  late final PairingService _pairingService;
  Timer? _countdownTimer;
  Timer? _sessionCheckTimer;
  bool _isDisposed = false;

  @override
  PairingUIState build() {
    final serverNotifier = ref.read(serverProvider.notifier);
    _pairingService = serverNotifier.pairingService;
    _isDisposed = false;

    // Listen for pairing completion from HTTP handler
    _pairingService.setOnPairingComplete(_onPairingComplete);
    // Listen for session reset (unpair or timeout)
    _pairingService.setOnSessionReset(_onSessionReset);
    // Start periodic session timeout check
    _startSessionTimeoutCheck();

    // Register cleanup on dispose
    ref.onDispose(() {
      _isDisposed = true;
      _countdownTimer?.cancel();
      _sessionCheckTimer?.cancel();
      _pairingService.setOnPairingComplete(null);
      _pairingService.setOnSessionReset(null);
    });

    return const PairingUIState();
  }

  void _onPairingComplete(PairingState serviceState) {
    if (_isDisposed) return;
    _countdownTimer?.cancel();
    state = PairingUIState(
      pin: serviceState.pin,
      expiresAt: serviceState.expiresAt,
      isPaired: true,
      clientName: serviceState.clientName,
    );
  }

  void _onSessionReset() {
    if (_isDisposed) return;
    // Session was reset - generate new PIN and show pairing UI
    generateNewPin();
  }

  void _startSessionTimeoutCheck() {
    _sessionCheckTimer?.cancel();
    // Check every 10 seconds for session timeout (timeout is 30 seconds)
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isDisposed) return;
      if (state.isPaired) {
        _pairingService.checkSessionTimeout();
      }
    });
  }

  /// Generate a new PIN and start countdown timer
  void generateNewPin() {
    final pin = _pairingService.generatePin();
    final serviceState = _pairingService.state;

    state = PairingUIState(
      pin: pin,
      expiresAt: serviceState?.expiresAt,
      isPaired: false,
      timeRemaining: serviceState?.expiresAt.difference(DateTime.now()),
    );

    _startCountdown();
  }

  /// Start countdown timer to update timeRemaining
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
    });
  }

  void _updateTimeRemaining() {
    if (_isDisposed) return;
    if (state.expiresAt == null) return;

    final remaining = state.expiresAt!.difference(DateTime.now());

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      // PIN expired - auto-generate a new one
      generateNewPin();
    } else {
      state = state.copyWith(timeRemaining: remaining);
    }
  }

  /// Reset pairing state
  void reset() {
    _countdownTimer?.cancel();
    _pairingService.reset();
    state = const PairingUIState();
  }
}

/// Provider that uses PairingService from serverProvider
final pairingProvider = NotifierProvider<PairingNotifier, PairingUIState>(PairingNotifier.new);
