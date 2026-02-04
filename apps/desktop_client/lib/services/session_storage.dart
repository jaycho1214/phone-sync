import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage for session data.
/// Uses shared_preferences on macOS (avoids keychain entitlement issues).
/// Uses flutter_secure_storage on other platforms for encryption.
class SessionStorage {
  static const _tokenKey = 'session_token';
  static const _deviceNameKey = 'paired_device_name';
  static const _deviceHostKey = 'paired_device_host';
  static const _devicePortKey = 'paired_device_port';

  // Use shared_preferences on macOS to avoid keychain issues
  static final bool _usePlainStorage = Platform.isMacOS || Platform.isLinux;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Save session after successful pairing.
  Future<void> saveSession({
    required String token,
    required String deviceName,
    required String deviceHost,
    required int devicePort,
  }) async {
    if (_usePlainStorage) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_deviceNameKey, deviceName);
      await prefs.setString(_deviceHostKey, deviceHost);
      await prefs.setInt(_devicePortKey, devicePort);
    } else {
      await _secureStorage.write(key: _tokenKey, value: token);
      await _secureStorage.write(key: _deviceNameKey, value: deviceName);
      await _secureStorage.write(key: _deviceHostKey, value: deviceHost);
      await _secureStorage.write(key: _devicePortKey, value: devicePort.toString());
    }
  }

  /// Load saved session.
  /// Returns null values if no session saved.
  Future<({String? token, String? deviceName, String? deviceHost, int? devicePort})> loadSession() async {
    if (_usePlainStorage) {
      final prefs = await SharedPreferences.getInstance();
      return (
        token: prefs.getString(_tokenKey),
        deviceName: prefs.getString(_deviceNameKey),
        deviceHost: prefs.getString(_deviceHostKey),
        devicePort: prefs.getInt(_devicePortKey),
      );
    } else {
      final token = await _secureStorage.read(key: _tokenKey);
      final deviceName = await _secureStorage.read(key: _deviceNameKey);
      final deviceHost = await _secureStorage.read(key: _deviceHostKey);
      final devicePortStr = await _secureStorage.read(key: _devicePortKey);

      return (
        token: token,
        deviceName: deviceName,
        deviceHost: deviceHost,
        devicePort: devicePortStr != null ? int.tryParse(devicePortStr) : null,
      );
    }
  }

  /// Check if a session is saved.
  Future<bool> hasSession() async {
    if (_usePlainStorage) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      return token != null && token.isNotEmpty;
    } else {
      final token = await _secureStorage.read(key: _tokenKey);
      return token != null && token.isNotEmpty;
    }
  }

  /// Clear saved session (unpair).
  Future<void> clearSession() async {
    if (_usePlainStorage) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_deviceNameKey);
      await prefs.remove(_deviceHostKey);
      await prefs.remove(_devicePortKey);
    } else {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _deviceNameKey);
      await _secureStorage.delete(key: _deviceHostKey);
      await _secureStorage.delete(key: _devicePortKey);
    }
  }
}
