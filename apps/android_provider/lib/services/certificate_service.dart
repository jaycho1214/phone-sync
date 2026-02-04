import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for TLS certificate generation and persistence
class CertificateService {
  static const _certPemKey = 'tls_cert_pem';
  static const _keyPemKey = 'tls_key_pem';
  static const _certExpiryKey = 'tls_cert_expiry';

  /// Generate or load existing TLS certificate
  /// Returns a record with certPem and keyPem strings
  Future<({String certPem, String keyPem})> generateOrLoadCertificate() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if certs exist and are not expired
    final existingCert = prefs.getString(_certPemKey);
    final existingKey = prefs.getString(_keyPemKey);
    final expiryTimestamp = prefs.getInt(_certExpiryKey);

    if (existingCert != null &&
        existingKey != null &&
        expiryTimestamp != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      if (DateTime.now().isBefore(expiryDate)) {
        // Certificate is valid, return it
        return (certPem: existingCert, keyPem: existingKey);
      }
    }

    // Generate new self-signed certificate
    final result = await _generateCertificate();

    // Store in SharedPreferences
    final expiryDate = DateTime.now().add(const Duration(days: 365));
    await prefs.setString(_certPemKey, result.certPem);
    await prefs.setString(_keyPemKey, result.keyPem);
    await prefs.setInt(_certExpiryKey, expiryDate.millisecondsSinceEpoch);

    return result;
  }

  /// Generate a new self-signed TLS certificate
  Future<({String certPem, String keyPem})> _generateCertificate() async {
    // Generate 2048-bit RSA key pair
    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;

    // Create CSR (Certificate Signing Request)
    final dn = {'CN': 'PhoneSync Device', 'O': 'JLJM PhoneSync'};
    final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);

    // Generate self-signed certificate valid for 365 days
    final certPem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      365,
      serialNumber: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    // Convert private key to PEM
    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    return (certPem: certPem, keyPem: keyPem);
  }

  /// Create a SecurityContext from PEM certificate and key
  SecurityContext createSecurityContext(String certPem, String keyPem) {
    final context = SecurityContext();
    context.useCertificateChainBytes(utf8.encode(certPem));
    context.usePrivateKeyBytes(utf8.encode(keyPem));
    return context;
  }
}
