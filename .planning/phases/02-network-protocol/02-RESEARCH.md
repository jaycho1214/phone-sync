# Phase 2: Network Protocol - Research

**Researched:** 2026-02-03
**Domain:** Local network communication, mDNS service discovery, HTTP server, TLS encryption, PIN-based pairing
**Confidence:** HIGH

## Summary

Phase 2 implements the network communication layer between the Android data provider (from Phase 1) and desktop clients. The architecture consists of four components: (1) mDNS service advertisement for automatic discovery, (2) an embedded HTTP server on Android serving JSON endpoints, (3) PIN-based pairing for device authentication, and (4) TLS encryption for secure data transfer.

The standard approach uses the `nsd` package for cross-platform mDNS (supports Android, Windows, macOS), `shelf` + `shelf_router` for the embedded HTTP server (pure Dart, works on Android), and `basic_utils` for programmatic self-signed TLS certificate generation. The project's existing STACK.md already identified `nsd` and `dart:io SecureSocket` as the preferred choices, which this research confirms and expands upon.

**Primary recommendation:** Use `shelf` with `shelf_router` for HTTP endpoints, `nsd` for mDNS discovery/registration, and `basic_utils` + `pointycastle` for runtime TLS certificate generation. The PIN pairing should use a simple 6-digit code displayed on Android that the desktop user enters - no complex cryptographic exchange needed since TLS handles the encryption.

## Standard Stack

The established libraries/tools for this domain:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shelf | 1.4.2 | HTTP server framework | Official Dart team package, composable middleware, works on all platforms |
| shelf_router | 1.1.4 | HTTP routing | Companion to shelf, supports URL parameters, nested routers |
| nsd | 4.1.0 | mDNS discovery & registration | Cross-platform (Android/Windows/macOS), both discovery and registration |
| basic_utils | 5.8.2 | TLS certificate generation | Pure Dart, generates self-signed certs without external tools |
| pointycastle | 4.0.0 | Cryptographic primitives | Required by basic_utils for RSA key generation |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| json_serializable | 6.12.0 | JSON encoding/decoding | Already in project - serialize data models for HTTP responses |
| freezed | 3.2.4 | Data models | Already in project - define request/response models |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| shelf | dart:io HttpServer | Lower level, more boilerplate - shelf abstracts this cleanly |
| nsd | multicast_dns | multicast_dns is lower level, requires more implementation |
| basic_utils | openssl CLI | External dependency, harder to bundle, basic_utils is pure Dart |

**Installation:**
```yaml
# In android_provider/pubspec.yaml
dependencies:
  shelf: ^1.4.2
  shelf_router: ^1.1.4
  nsd: ^4.1.0
  basic_utils: ^5.8.2
  pointycastle: ^4.0.0
```

## Architecture Patterns

### Recommended Project Structure

```
apps/android_provider/lib/
  services/
    contacts_service.dart      # Existing
    sms_service.dart           # Existing
    call_log_service.dart      # Existing
    server/
      http_server.dart         # Shelf server setup
      routes.dart              # Route definitions
      handlers/
        contacts_handler.dart  # /contacts endpoint
        sms_handler.dart       # /sms endpoint
        calls_handler.dart     # /calls endpoint
        pairing_handler.dart   # /pair endpoint
  providers/
    server_provider.dart       # Server state management
    pairing_provider.dart      # PIN generation, pairing state
    discovery_provider.dart    # mDNS registration state
  models/
    pairing_state.dart         # PIN, paired device info
    server_state.dart          # Running/stopped, port, etc.
```

### Pattern 1: Embedded HTTP Server with Shelf

**What:** Use shelf to run an HTTP server inside the Flutter app on Android
**When to use:** Always - this is the core of the data serving capability
**Example:**
```dart
// Source: https://pub.dev/packages/shelf
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class PhoneSyncServer {
  HttpServer? _server;
  final Router _router = Router();

  PhoneSyncServer() {
    _router.get('/contacts', _handleContacts);
    _router.get('/sms', _handleSms);
    _router.get('/calls', _handleCalls);
    _router.post('/pair', _handlePair);
  }

  Future<void> start({required int port, SecurityContext? securityContext}) async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      securityContext: securityContext,
    );
  }

  Response _handleContacts(Request request) {
    // Verify pairing, return JSON data
    return Response.ok(
      jsonEncode(contacts),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
```

### Pattern 2: mDNS Service Registration with TXT Records

**What:** Advertise the server on the local network so desktop can discover it
**When to use:** After server starts, before pairing
**Example:**
```dart
// Source: https://pub.dev/packages/nsd
import 'package:nsd/nsd.dart';
import 'dart:typed_data';
import 'dart:convert';

class DiscoveryService {
  Registration? _registration;

  Future<void> advertise({
    required String deviceName,
    required int port,
    String? pairingId,
  }) async {
    final service = Service(
      name: deviceName,
      type: '_phonesync._tcp',  // Custom service type
      port: port,
      txt: {
        'version': utf8.encode('1.0'),
        'device': utf8.encode(deviceName),
        if (pairingId != null) 'pairingId': utf8.encode(pairingId),
      },
    );

    _registration = await register(service);
  }

  Future<void> stopAdvertising() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }
}
```

### Pattern 3: PIN-Based Pairing Flow

**What:** Simple 6-digit PIN displayed on Android, entered on desktop for authentication
**When to use:** Before allowing data access
**Example:**
```dart
// Pairing state model
class PairingState {
  final String pin;  // 6-digit numeric code
  final DateTime expiresAt;
  final String? pairedDeviceId;

  bool get isPaired => pairedDeviceId != null;
  bool get isPinExpired => DateTime.now().isAfter(expiresAt);
}

// PIN generation
String generatePin() {
  final random = Random.secure();
  return List.generate(6, (_) => random.nextInt(10)).join();
}

// Pairing endpoint handler
Response handlePairRequest(Request request, String submittedPin) {
  if (pairingState.isPinExpired) {
    return Response(401, body: jsonEncode({'error': 'PIN expired'}));
  }
  if (submittedPin != pairingState.pin) {
    return Response(401, body: jsonEncode({'error': 'Invalid PIN'}));
  }
  // Mark as paired, return success with session token
  return Response.ok(jsonEncode({
    'status': 'paired',
    'sessionToken': generateSessionToken(),
  }));
}
```

### Pattern 4: Self-Signed TLS Certificate Generation

**What:** Generate TLS certificates at runtime for HTTPS
**When to use:** On first app launch or when certificates expire
**Example:**
```dart
// Source: https://pub.dev/packages/basic_utils
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';

Future<({String certPem, String keyPem})> generateSelfSignedCert() async {
  // Generate RSA key pair
  final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final privateKey = keyPair.privateKey as RSAPrivateKey;
  final publicKey = keyPair.publicKey as RSAPublicKey;

  // Create CSR (Certificate Signing Request)
  final dn = {
    'CN': 'PhoneSync Device',
    'O': 'JLJM PhoneSync',
  };
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

// Load into SecurityContext for shelf server
SecurityContext createSecurityContext(String certPem, String keyPem) {
  final context = SecurityContext();
  context.useCertificateChainBytes(utf8.encode(certPem));
  context.usePrivateKeyBytes(utf8.encode(keyPem));
  return context;
}
```

### Anti-Patterns to Avoid

- **Hardcoding port numbers:** Use port 0 to let the OS assign an available port, then advertise the actual port via mDNS
- **Storing PIN in plain text permanently:** PINs should be ephemeral with short expiration (5 minutes max)
- **Trusting client-side validation only:** Always validate PIN server-side before allowing data access
- **Running HTTP server without TLS:** Even on local network, use HTTPS for the data transfer endpoints

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| mDNS advertisement | Raw UDP multicast | nsd package | Platform-specific APIs (NsdManager on Android), conflict resolution |
| HTTP routing | String parsing | shelf_router | URL parameters, middleware, error handling |
| TLS certificates | OpenSSL subprocess | basic_utils | Pure Dart, no external dependency, cross-platform |
| JSON serialization | Manual toString | json_serializable | Type safety, null handling, nested objects |
| Random PIN | Math.random | Random.secure() | Cryptographically secure randomness |

**Key insight:** The "simple" parts of network programming (service discovery, certificate generation) have platform-specific edge cases that packages handle. Focus implementation effort on the business logic (data extraction, sync state).

## Common Pitfalls

### Pitfall 1: Android mDNS Service Name Conflicts

**What goes wrong:** Android may change your service name if another device has the same name
**Why it happens:** mDNS requires unique names; Android NsdManager auto-resolves conflicts
**How to avoid:** Include device-specific identifier in service name (e.g., "PhoneSync-{deviceId}")
**Warning signs:** Service discovered with unexpected name like "PhoneSync (1)"

### Pitfall 2: Port Already in Use

**What goes wrong:** Server fails to start because port is occupied
**Why it happens:** Hardcoded port, previous server instance not cleaned up
**How to avoid:** Use port 0 for auto-assignment, properly stop server in dispose()
**Warning signs:** SocketException: Address already in use

### Pitfall 3: mDNS Not Working on Older Android

**What goes wrong:** Service discovery fails on Android 12 and below
**Why it happens:** Known Android NSD API flakiness on older versions
**How to avoid:** Test on multiple Android versions; nsd package handles most issues
**Warning signs:** Discovery works on Android 13+ but fails on 11/12

### Pitfall 4: Self-Signed Certificate Rejection

**What goes wrong:** Desktop client refuses to connect due to certificate validation
**Why it happens:** Default HTTP clients reject untrusted certificates
**How to avoid:** Desktop client must use `badCertificateCallback` or custom SecurityContext
**Warning signs:** CERTIFICATE_VERIFY_FAILED errors on client

### Pitfall 5: Server Killed in Background

**What goes wrong:** HTTP server stops when app goes to background
**Why it happens:** Android aggressive background process killing
**How to avoid:** Use foreground service notification when server is active
**Warning signs:** Connection lost when user switches away from app

### Pitfall 6: Missing Network Permissions

**What goes wrong:** mDNS or server fails silently
**Why it happens:** Missing INTERNET, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE permissions
**How to avoid:** Declare all network permissions in AndroidManifest.xml
**Warning signs:** Service registration succeeds but discovery fails

## Code Examples

Verified patterns from official sources:

### Complete Server Startup Flow

```dart
// Source: Combined from shelf, nsd, basic_utils documentation
class PhoneSyncNetworkService {
  PhoneSyncServer? _server;
  DiscoveryService? _discovery;
  SecurityContext? _securityContext;

  Future<void> start() async {
    // 1. Generate or load TLS certificate
    final certs = await _loadOrGenerateCerts();
    _securityContext = createSecurityContext(certs.certPem, certs.keyPem);

    // 2. Start HTTP server with TLS
    _server = PhoneSyncServer();
    await _server!.start(
      port: 0,  // Let OS assign port
      securityContext: _securityContext,
    );
    final actualPort = _server!.port;

    // 3. Advertise via mDNS
    _discovery = DiscoveryService();
    await _discovery!.advertise(
      deviceName: 'PhoneSync-${_getDeviceId()}',
      port: actualPort,
    );
  }

  Future<void> stop() async {
    await _discovery?.stopAdvertising();
    await _server?.stop();
  }
}
```

### JSON Endpoint Handler

```dart
// Source: shelf_router documentation
import 'dart:convert';
import 'package:shelf/shelf.dart';

Response handleContactsRequest(Request request, ContactsService service) async {
  // Check authorization header for session token
  final authHeader = request.headers['Authorization'];
  if (!isValidSession(authHeader)) {
    return Response(401, body: jsonEncode({'error': 'Unauthorized'}));
  }

  // Extract query parameters for pagination
  final since = request.url.queryParameters['since'];
  final sinceTimestamp = since != null ? int.tryParse(since) : null;

  // Get data from existing service
  final contacts = await service.extractContacts(sinceTimestamp: sinceTimestamp);

  // Return as JSON
  return Response.ok(
    jsonEncode({
      'data': contacts.map((c) => c.toJson()).toList(),
      'count': contacts.length,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
```

### Desktop Client Discovery

```dart
// Source: nsd package documentation
import 'package:nsd/nsd.dart';

class DeviceDiscovery {
  Discovery? _discovery;
  final List<Service> discoveredDevices = [];

  Future<void> startDiscovery() async {
    _discovery = await startDiscovery('_phonesync._tcp');
    _discovery!.addServiceListener((service, status) {
      if (status == ServiceStatus.found) {
        discoveredDevices.add(service);
      } else if (status == ServiceStatus.lost) {
        discoveredDevices.removeWhere((s) => s.name == service.name);
      }
    });
  }

  Future<void> stopDiscovery() async {
    await _discovery?.stop();
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Raw dart:io HttpServer | shelf framework | Stable since 2020 | Cleaner API, middleware support |
| multicast_dns package | nsd package | 2023 | Better platform support, registration |
| OpenSSL CLI for certs | basic_utils pure Dart | 2022 | No external dependencies |
| Provider for state | Riverpod | 2023 | Better async handling (already using) |

**Deprecated/outdated:**
- `flutter_nsd`: Doesn't support service registration, only discovery
- `telephony` package: Unmaintained, use `another_telephony` (already using)
- HTTP without TLS: Even local network should be encrypted

## Open Questions

Things that couldn't be fully resolved:

1. **Foreground service for server persistence**
   - What we know: Android kills background processes; foreground service with notification keeps server alive
   - What's unclear: Best Flutter package for this; `flutter_background_service` vs `flutter_background`
   - Recommendation: Test with `flutter_background_service` first; add foreground service type `dataSync` to manifest

2. **Certificate persistence across reinstalls**
   - What we know: Self-signed certs can be regenerated; desktop must trust them
   - What's unclear: Should certs be stored in secure storage or regenerated each session?
   - Recommendation: Generate once, store in app data; if lost, re-pair devices

3. **Session token lifetime**
   - What we know: After PIN pairing, need to track session
   - What's unclear: How long should session last? Per-sync or persistent?
   - Recommendation: Start with per-sync (session valid until server stops); add persistence in v2 if needed

## Sources

### Primary (HIGH confidence)
- [shelf 1.4.2](https://pub.dev/packages/shelf) - HTTP server framework documentation
- [shelf_router 1.1.4](https://pub.dev/packages/shelf_router) - Routing documentation
- [nsd 4.1.0](https://pub.dev/packages/nsd) - mDNS registration and discovery
- [basic_utils 5.8.2](https://pub.dev/packages/basic_utils) - X509 certificate generation
- [Dart SecurityContext](https://api.flutter.dev/flutter/dart-io/SecurityContext-class.html) - TLS configuration

### Secondary (MEDIUM confidence)
- [Android NsdManager](https://developer.android.com/reference/android/net/nsd/NsdManager) - Platform API reference
- [shelf GitHub issue #222](https://github.com/dart-lang/shelf/issues/222) - HTTPS setup examples
- [nsd GitHub examples](https://github.com/sebastianhaberey/nsd/blob/main/nsd/example/lib/main.dart) - Registration with TXT records

### Tertiary (LOW confidence)
- Android mDNS issues on older versions - Community reports, needs validation
- Foreground service best practices - Multiple sources with varying recommendations

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified via pub.dev, official Dart team packages
- Architecture: HIGH - Standard patterns from official documentation
- Pitfalls: MEDIUM - Some based on community reports, core issues verified

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - stable packages, well-established patterns)
