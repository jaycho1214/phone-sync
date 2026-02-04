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

  const PairingUIState({
    this.pin,
    this.expiresAt,
    this.isPaired = false,
    this.timeRemaining,
  });

  PairingUIState copyWith({
    String? pin,
    DateTime? expiresAt,
    bool? isPaired,
    Duration? timeRemaining,
  }) {
    return PairingUIState(
      pin: pin ?? this.pin,
      expiresAt: expiresAt ?? this.expiresAt,
      isPaired: isPaired ?? this.isPaired,
      timeRemaining: timeRemaining ?? this.timeRemaining,
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

class PairingNotifier extends StateNotifier<PairingUIState> {
  final PairingService _pairingService;
  Timer? _countdownTimer;

  PairingNotifier(this._pairingService) : super(const PairingUIState());

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
    if (state.expiresAt == null) return;

    final remaining = state.expiresAt!.difference(DateTime.now());

    if (remaining.isNegative) {
      // PIN expired - auto-generate a new one
      generateNewPin();
    } else {
      state = state.copyWith(timeRemaining: remaining);
    }
  }

  /// Update state when pairing succeeds (called externally)
  void onPairingSuccess() {
    _countdownTimer?.cancel();
    state = state.copyWith(isPaired: true);
  }

  /// Sync state from PairingService
  void syncFromService() {
    final serviceState = _pairingService.state;
    if (serviceState != null) {
      state = PairingUIState(
        pin: serviceState.pin,
        expiresAt: serviceState.expiresAt,
        isPaired: serviceState.isPaired,
        timeRemaining: serviceState.expiresAt.difference(DateTime.now()),
      );
      if (!serviceState.isPaired && !serviceState.isPinExpired) {
        _startCountdown();
      }
    }
  }

  /// Reset pairing state
  void reset() {
    _countdownTimer?.cancel();
    _pairingService.reset();
    state = const PairingUIState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

/// Provider that uses PairingService from serverProvider
final pairingProvider = StateNotifierProvider<PairingNotifier, PairingUIState>(
  (ref) {
    final serverNotifier = ref.read(serverProvider.notifier);
    return PairingNotifier(serverNotifier.pairingService);
  },
);
