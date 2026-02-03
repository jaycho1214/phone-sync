import 'dart:math';

/// State for PIN pairing
class PairingState {
  final String pin;
  final DateTime expiresAt;
  final String? sessionToken;
  final DateTime? pairedAt;

  PairingState({
    required this.pin,
    required this.expiresAt,
    this.sessionToken,
    this.pairedAt,
  });

  bool get isPaired => sessionToken != null;
  bool get isPinExpired => DateTime.now().isAfter(expiresAt);
}

/// Service for PIN pairing and session token management
class PairingService {
  PairingState? _state;

  /// Get the current pairing state
  PairingState? get state => _state;

  /// Generate a new 6-digit PIN valid for 5 minutes
  String generatePin() {
    final random = Random.secure();
    final pin = List.generate(6, (_) => random.nextInt(10)).join();
    _state = PairingState(
      pin: pin,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    return pin;
  }

  /// Generate a 32-character hex session token
  String generateSessionToken() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Validate a submitted PIN
  bool isValidPin(String submitted) {
    if (_state == null) return false;
    if (_state!.isPinExpired) return false;
    return _state!.pin == submitted;
  }

  /// Validate a session token
  bool isValidSession(String? token) {
    if (token == null || _state == null) return false;
    return _state!.sessionToken == token;
  }

  /// Complete pairing with a session token
  void completePairing() {
    if (_state == null) return;
    final token = generateSessionToken();
    _state = PairingState(
      pin: _state!.pin,
      expiresAt: _state!.expiresAt,
      sessionToken: token,
      pairedAt: DateTime.now(),
    );
  }

  /// Reset pairing state
  void reset() {
    _state = null;
  }
}
