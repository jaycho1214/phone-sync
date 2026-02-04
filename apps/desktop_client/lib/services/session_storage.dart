import 'package:shared_preferences/shared_preferences.dart';

/// Storage for session data using shared_preferences.
class SessionStorage {
  static const _tokenKey = 'session_token';
  static const _deviceNameKey = 'paired_device_name';
  static const _deviceHostKey = 'paired_device_host';
  static const _devicePortKey = 'paired_device_port';

  /// Save session after successful pairing.
  Future<void> saveSession({
    required String token,
    required String deviceName,
    required String deviceHost,
    required int devicePort,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_deviceNameKey, deviceName);
    await prefs.setString(_deviceHostKey, deviceHost);
    await prefs.setInt(_devicePortKey, devicePort);
  }

  /// Load saved session.
  Future<({String? token, String? deviceName, String? deviceHost, int? devicePort})>
  loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      token: prefs.getString(_tokenKey),
      deviceName: prefs.getString(_deviceNameKey),
      deviceHost: prefs.getString(_deviceHostKey),
      devicePort: prefs.getInt(_devicePortKey),
    );
  }

  /// Clear saved session (unpair).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_deviceNameKey);
    await prefs.remove(_deviceHostKey);
    await prefs.remove(_devicePortKey);
  }
}
