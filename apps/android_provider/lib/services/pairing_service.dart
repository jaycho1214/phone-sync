import 'dart:math';

/// State for PIN pairing
class PairingState {
  final String pin;
  final DateTime expiresAt;
  final String? sessionToken;
  final DateTime? pairedAt;
  final String? clientName;

  PairingState({
    required this.pin,
    required this.expiresAt,
    this.sessionToken,
    this.pairedAt,
    this.clientName,
  });

  bool get isPaired => sessionToken != null;
  bool get isPinExpired => DateTime.now().isAfter(expiresAt);
}

/// Callback for pairing state changes
typedef PairingCallback = void Function(PairingState state);

/// Callback for when session is reset (unpair or timeout)
typedef SessionResetCallback = void Function();

/// Service for PIN pairing and session token management
class PairingService {
  PairingState? _state;
  PairingCallback? _onPairingComplete;
  SessionResetCallback? _onSessionReset;
  DateTime? _lastActivityTime;

  /// Session timeout duration - reset if no activity for this long
  /// Desktop sends heartbeat every 10 seconds, so 30 seconds allows for some network delay
  static const Duration sessionTimeout = Duration(seconds: 30);

  /// Get the current pairing state
  PairingState? get state => _state;

  /// Set callback for when pairing completes
  void setOnPairingComplete(PairingCallback? callback) {
    _onPairingComplete = callback;
  }

  /// Set callback for when session is reset
  void setOnSessionReset(SessionResetCallback? callback) {
    _onSessionReset = callback;
  }

  /// Update last activity time (called on each request from desktop)
  void updateLastActivity() {
    _lastActivityTime = DateTime.now();
  }

  /// Check if session has timed out due to inactivity
  bool get isSessionTimedOut {
    if (_lastActivityTime == null || _state?.sessionToken == null) {
      return false;
    }
    return DateTime.now().difference(_lastActivityTime!) > sessionTimeout;
  }

  /// Check and handle session timeout
  /// Returns true if session was reset due to timeout
  bool checkSessionTimeout() {
    if (isSessionTimedOut) {
      reset();
      return true;
    }
    return false;
  }

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

  /// Complete pairing with a session token and optional client name
  void completePairing({String? clientName}) {
    if (_state == null) return;
    final token = generateSessionToken();
    _state = PairingState(
      pin: _state!.pin,
      expiresAt: _state!.expiresAt,
      sessionToken: token,
      pairedAt: DateTime.now(),
      clientName: clientName,
    );
    // Set initial activity time
    _lastActivityTime = DateTime.now();
    // Notify listener that pairing completed
    _onPairingComplete?.call(_state!);
  }

  /// Reset pairing state (unpair or timeout)
  void reset() {
    final wasPaired = _state?.isPaired ?? false;
    _state = null;
    _lastActivityTime = null;
    // Notify listener if we were paired
    if (wasPaired) {
      _onSessionReset?.call();
    }
  }
}
