import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for session data.
/// Persists pairing information across app restarts.
class SessionStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _deviceNameKey, value: deviceName);
    await _storage.write(key: _deviceHostKey, value: deviceHost);
    await _storage.write(key: _devicePortKey, value: devicePort.toString());
  }

  /// Load saved session.
  /// Returns null values if no session saved.
  Future<({String? token, String? deviceName, String? deviceHost, int? devicePort})> loadSession() async {
    final token = await _storage.read(key: _tokenKey);
    final deviceName = await _storage.read(key: _deviceNameKey);
    final deviceHost = await _storage.read(key: _deviceHostKey);
    final devicePortStr = await _storage.read(key: _devicePortKey);

    return (
      token: token,
      deviceName: deviceName,
      deviceHost: deviceHost,
      devicePort: devicePortStr != null ? int.tryParse(devicePortStr) : null,
    );
  }

  /// Check if a session is saved.
  Future<bool> hasSession() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Clear saved session (unpair).
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _deviceNameKey);
    await _storage.delete(key: _deviceHostKey);
    await _storage.delete(key: _devicePortKey);
  }
}
