import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Service for communicating with the PhoneSync Android server.
class SyncService {
  final Dio _dio;
  final String baseUrl;

  SyncService({
    required this.baseUrl,
    String? sessionToken,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(minutes: 5),
          headers: sessionToken != null
              ? {'Authorization': 'Bearer $sessionToken'}
              : null,
        )) {
    // Trust self-signed certificate from Android server
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }

  /// Update the session token (after successful pairing).
  void setSessionToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Pair with the Android device using a PIN.
  /// Returns the session token on success.
  /// Throws on failure.
  Future<String> pair(String pin) async {
    try {
      final response = await _dio.post(
        '/pair',
        data: {'pin': pin},
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'paired' && data['sessionToken'] != null) {
        final token = data['sessionToken'] as String;
        setSessionToken(token);
        return token;
      }

      throw Exception('Pairing failed: unexpected response');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid or expired PIN');
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout - is the device reachable?');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot connect to device - check network');
      }
      throw Exception('Pairing failed: ${e.message}');
    }
  }

  /// Check if the device is reachable and server is running.
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch contacts from the device.
  /// Returns list of contact objects with displayName and phones array.
  Future<List<Map<String, dynamic>>> fetchContacts({
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final response = await _dio.get(
        '/contacts',
        onReceiveProgress: onProgress,
      );

      final data = response.data as Map<String, dynamic>;
      final contacts = data['data'] as List<dynamic>?;
      return contacts?.cast<Map<String, dynamic>>() ?? [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired - please pair again');
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout while fetching contacts');
      }
      throw Exception('Failed to fetch contacts: ${e.message}');
    }
  }

  /// Fetch SMS messages from the device.
  /// Optionally specify [since] timestamp for incremental sync.
  Future<List<Map<String, dynamic>>> fetchSms({
    int? since,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null) {
        queryParams['since'] = since.toString();
      }

      final response = await _dio.get(
        '/sms',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        onReceiveProgress: onProgress,
      );

      final data = response.data as Map<String, dynamic>;
      final messages = data['data'] as List<dynamic>?;
      return messages?.cast<Map<String, dynamic>>() ?? [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired - please pair again');
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout while fetching SMS');
      }
      throw Exception('Failed to fetch SMS: ${e.message}');
    }
  }

  /// Fetch call logs from the device.
  /// Optionally specify [since] timestamp for incremental sync.
  Future<List<Map<String, dynamic>>> fetchCalls({
    int? since,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (since != null) {
        queryParams['since'] = since.toString();
      }

      final response = await _dio.get(
        '/calls',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        onReceiveProgress: onProgress,
      );

      final data = response.data as Map<String, dynamic>;
      final calls = data['data'] as List<dynamic>?;
      return calls?.cast<Map<String, dynamic>>() ?? [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired - please pair again');
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout while fetching calls');
      }
      throw Exception('Failed to fetch calls: ${e.message}');
    }
  }

  /// Dispose the Dio client.
  void dispose() {
    _dio.close();
  }
}
