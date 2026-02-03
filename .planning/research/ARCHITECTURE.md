# Architecture Patterns

**Domain:** Flutter cross-platform monorepo with local network sync (Android provider + Desktop consumer)
**Researched:** 2026-02-03
**Confidence:** HIGH (verified via pub.dev and official documentation)

## Executive Summary

This architecture enables a Flutter monorepo where an Android app serves phone data (SMS, calls, contacts) over the local network, and a desktop app (Windows/Mac) consumes that data and exports it to Excel. The key architectural decisions are:

1. **Monorepo with Melos** - Shared code in packages, platform-specific apps in apps/
2. **Android as HTTP Server** - Using dart:io HttpServer to serve REST endpoints
3. **Desktop as HTTP Client** - Standard HTTP client consuming Android's API
4. **mDNS Service Discovery** - Using `nsd` package for zero-config device discovery
5. **PIN-based Pairing** - Custom authentication layer over HTTP

## Recommended Architecture

```
jljm-phonesync/
├── apps/
│   ├── android_provider/          # Android app - serves data
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── services/
│   │   │   │   ├── http_server_service.dart    # Runs HttpServer
│   │   │   │   ├── sms_service.dart            # SMS data access
│   │   │   │   ├── call_log_service.dart       # Call log access
│   │   │   │   ├── contacts_service.dart       # Contacts access
│   │   │   │   └── mdns_service.dart           # Advertises service
│   │   │   └── screens/
│   │   └── android/
│   │
│   └── desktop_consumer/          # Windows/Mac app - fetches & exports
│       ├── lib/
│       │   ├── main.dart
│       │   ├── services/
│       │   │   ├── discovery_service.dart      # Discovers Android devices
│       │   │   ├── sync_service.dart           # Fetches data from Android
│       │   │   └── excel_export_service.dart   # Writes .xlsx files
│       │   └── screens/
│       ├── windows/
│       └── macos/
│
├── packages/
│   ├── core/                      # Shared business logic
│   │   └── lib/
│   │       ├── models/            # Data models (Contact, CallLog, SMS)
│   │       ├── constants/         # Service type, ports, etc.
│   │       └── utils/             # Shared utilities
│   │
│   ├── network_protocol/          # Shared network protocol
│   │   └── lib/
│   │       ├── api_routes.dart    # Route definitions
│   │       ├── request_models.dart
│   │       ├── response_models.dart
│   │       └── auth/
│   │           └── pin_auth.dart  # PIN verification logic
│   │
│   └── ui_kit/                    # Shared UI components (optional)
│       └── lib/
│           └── widgets/
│
├── melos.yaml                     # Melos configuration
└── pubspec.yaml                   # Workspace root
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `android_provider` | Access phone data (SMS, calls, contacts), run HTTP server, advertise via mDNS | `core`, `network_protocol` packages |
| `desktop_consumer` | Discover devices via mDNS, fetch data over HTTP, export to Excel | `core`, `network_protocol` packages |
| `core` package | Data models, shared constants, utilities | None (pure Dart) |
| `network_protocol` package | API contract (routes, request/response models, PIN auth) | `core` package |
| `ui_kit` package | Shared widgets (optional, may not be needed) | Flutter SDK |

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LOCAL NETWORK                                      │
│                                                                              │
│  ┌──────────────────────────────┐        ┌───────────────────────────────┐  │
│  │     ANDROID PROVIDER         │        │      DESKTOP CONSUMER          │  │
│  │                              │        │                                │  │
│  │  ┌─────────────────────┐     │        │     ┌──────────────────────┐   │  │
│  │  │ Phone Data Sources  │     │        │     │  Discovery Service   │   │  │
│  │  │ - SMS Inbox         │     │        │     │  (nsd package)       │   │  │
│  │  │ - Call Log          │     │        │     └──────────┬───────────┘   │  │
│  │  │ - Contacts          │     │        │                │               │  │
│  │  └─────────┬───────────┘     │        │                │ 1. mDNS       │  │
│  │            │                 │        │                │    query      │  │
│  │            ▼                 │        │                ▼               │  │
│  │  ┌─────────────────────┐     │   ◄────┼────  mDNS Discovery            │  │
│  │  │   Data Services     │     │        │                                │  │
│  │  │ - SmsService        │     │        │     ┌──────────────────────┐   │  │
│  │  │ - CallLogService    │     │        │     │   Pairing Service    │   │  │
│  │  │ - ContactsService   │     │        │     │   (PIN entry)        │   │  │
│  │  └─────────┬───────────┘     │        │     └──────────┬───────────┘   │  │
│  │            │                 │        │                │               │  │
│  │            ▼                 │        │                │ 2. POST       │  │
│  │  ┌─────────────────────┐     │        │                │    /pair      │  │
│  │  │   HTTP Server       │     │   ◄────┼────────────────┘               │  │
│  │  │   (dart:io)         │     │        │                                │  │
│  │  │                     │     │        │     ┌──────────────────────┐   │  │
│  │  │   Routes:           │     │        │     │   Sync Service       │   │  │
│  │  │   POST /pair        │────►│────────┼────►│   (HTTP client)      │   │  │
│  │  │   GET  /sms         │     │        │     └──────────┬───────────┘   │  │
│  │  │   GET  /calls       │     │        │                │               │  │
│  │  │   GET  /contacts    │     │        │                │ 3. GET        │  │
│  │  │   GET  /health      │     │   ◄────┼────────────────┘    /sms,etc   │  │
│  │  └─────────────────────┘     │        │                                │  │
│  │            │                 │        │     ┌──────────────────────┐   │  │
│  │            ▼                 │        │     │   Excel Export       │   │  │
│  │  ┌─────────────────────┐     │        │     │   (excel package)    │   │  │
│  │  │   mDNS Advertiser   │     │        │     └──────────┬───────────┘   │  │
│  │  │   (nsd package)     │────►│        │                │               │  │
│  │  │   _phonesync._tcp   │     │        │                ▼               │  │
│  │  └─────────────────────┘     │        │         📄 Export.xlsx         │  │
│  │                              │        │                                │  │
│  └──────────────────────────────┘        └───────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Flow Steps:**
1. **Discovery:** Android advertises `_phonesync._tcp` service via mDNS. Desktop discovers it.
2. **Pairing:** User enters PIN on desktop. Desktop sends `POST /pair` with PIN. Android validates and returns session token.
3. **Sync:** Desktop calls `GET /sms`, `GET /calls`, `GET /contacts` with session token.
4. **Export:** Desktop writes data to `.xlsx` file using `excel` package.

## Patterns to Follow

### Pattern 1: Monorepo with Melos + Pub Workspaces

**What:** Use Melos 7.x with Flutter 3.27+ native Pub Workspaces for dependency management.

**When:** Multi-package Flutter projects sharing code between apps.

**Configuration:**

```yaml
# melos.yaml
name: jljm_phonesync
repository: https://github.com/your/repo

packages:
  - apps/*
  - packages/*

command:
  bootstrap:
    usePubspecOverrides: false  # Use native pub workspaces

scripts:
  analyze:
    run: melos exec -- dart analyze
  test:
    run: melos exec -- flutter test
  build:android:
    run: cd apps/android_provider && flutter build apk
  build:desktop:
    run: |
      cd apps/desktop_consumer
      flutter build windows  # or macos
```

```yaml
# Root pubspec.yaml
name: jljm_phonesync_workspace
publish_to: none

environment:
  sdk: '>=3.6.0 <4.0.0'

workspace:
  - apps/android_provider
  - apps/desktop_consumer
  - packages/core
  - packages/network_protocol
```

**Confidence:** HIGH - verified via [Melos 7.4.0 pub.dev](https://pub.dev/packages/melos) and [Melos official docs](https://melos.invertase.dev/).

### Pattern 2: Android as HTTP Server with dart:io

**What:** Run an embedded HTTP server on Android that serves REST endpoints.

**When:** Mobile device needs to provide data to other devices on the same network.

**Example:**

```dart
// android_provider/lib/services/http_server_service.dart
import 'dart:io';
import 'dart:convert';

class HttpServerService {
  HttpServer? _server;
  final int port;
  final String? sessionToken;  // Set after pairing

  HttpServerService({this.port = 8080});

  Future<void> start() async {
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,  // Listen on all interfaces
      port,
    );

    await for (HttpRequest request in _server!) {
      _handleRequest(request);
    }
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    // CORS headers for local network
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    try {
      if (method == 'POST' && path == '/pair') {
        await _handlePairing(request);
      } else if (!_isAuthenticated(request)) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('{"error": "Not paired"}');
      } else if (method == 'GET' && path == '/sms') {
        await _handleGetSms(request);
      } else if (method == 'GET' && path == '/calls') {
        await _handleGetCalls(request);
      } else if (method == 'GET' && path == '/contacts') {
        await _handleGetContacts(request);
      } else if (method == 'GET' && path == '/health') {
        request.response.write('{"status": "ok"}');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await request.response.close();
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
```

**Confidence:** HIGH - verified via [dart:io HttpServer docs](https://api.flutter.dev/flutter/dart-io/HttpServer-class.html).

### Pattern 3: mDNS Service Discovery with nsd Package

**What:** Advertise and discover services on local network without manual IP configuration.

**When:** Devices need to find each other automatically on the same LAN.

**Example - Android (Advertiser):**

```dart
// android_provider/lib/services/mdns_service.dart
import 'package:nsd/nsd.dart';

class MdnsAdvertiserService {
  Registration? _registration;

  Future<void> advertise({required int port}) async {
    _registration = await register(
      Service(
        name: 'PhoneSync-${_getDeviceName()}',
        type: '_phonesync._tcp',
        port: port,
      ),
    );
  }

  Future<void> stopAdvertising() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }
}
```

**Example - Desktop (Discoverer):**

```dart
// desktop_consumer/lib/services/discovery_service.dart
import 'package:nsd/nsd.dart';

class DiscoveryService {
  Discovery? _discovery;
  final void Function(Service) onServiceFound;

  DiscoveryService({required this.onServiceFound});

  Future<void> startDiscovery() async {
    _discovery = await startDiscovery(
      '_phonesync._tcp',
      ipLookupType: IpLookupType.any,
    );

    _discovery!.addServiceListener((service, status) {
      if (status == ServiceStatus.found) {
        onServiceFound(service);
      }
    });
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }
}
```

**Platform Requirements:**

| Platform | Configuration |
|----------|---------------|
| Android | Add `INTERNET` and `CHANGE_WIFI_MULTICAST_STATE` to AndroidManifest.xml |
| Windows | User will see network access dialog on first launch |
| macOS | Add `NSLocalNetworkUsageDescription` and `NSBonjourServices` to Info.plist |

**Confidence:** HIGH - verified via [nsd 4.1.0 pub.dev](https://pub.dev/packages/nsd).

### Pattern 4: PIN-Based Pairing

**What:** Simple PIN code for securing local network connections without certificates.

**When:** Need to prevent unauthorized access but want simple UX.

**Example:**

```dart
// packages/network_protocol/lib/auth/pin_auth.dart
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PinAuthService {
  String? _currentPin;
  String? _sessionToken;
  DateTime? _pinExpiry;

  /// Generate a 6-digit PIN valid for 5 minutes
  String generatePin() {
    final random = Random.secure();
    _currentPin = List.generate(6, (_) => random.nextInt(10)).join();
    _pinExpiry = DateTime.now().add(Duration(minutes: 5));
    return _currentPin!;
  }

  /// Validate PIN and return session token
  String? validatePin(String pin) {
    if (_currentPin == null || _pinExpiry == null) return null;
    if (DateTime.now().isAfter(_pinExpiry!)) {
      _currentPin = null;
      return null;
    }
    if (pin != _currentPin) return null;

    // Generate session token
    final bytes = utf8.encode('${DateTime.now().millisecondsSinceEpoch}$pin');
    _sessionToken = sha256.convert(bytes).toString();
    _currentPin = null;  // Invalidate PIN after use

    return _sessionToken;
  }

  bool validateSession(String? token) {
    return token != null && token == _sessionToken;
  }
}
```

**Confidence:** MEDIUM - pattern is common but implementation is custom.

### Pattern 5: Excel Export with excel Package

**What:** Write phone data to .xlsx files for easy viewing/sharing.

**When:** User wants to export synced data to a spreadsheet.

**Example:**

```dart
// desktop_consumer/lib/services/excel_export_service.dart
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:core/models/sms_message.dart';
import 'package:core/models/call_log_entry.dart';
import 'package:core/models/contact.dart';

class ExcelExportService {
  Future<File> exportToExcel({
    required List<SmsMessage> messages,
    required List<CallLogEntry> calls,
    required List<Contact> contacts,
    required String outputPath,
  }) async {
    final excel = Excel.createExcel();

    // SMS Sheet
    final smsSheet = excel['SMS'];
    smsSheet.appendRow([
      TextCellValue('From/To'),
      TextCellValue('Message'),
      TextCellValue('Date'),
      TextCellValue('Type'),
    ]);
    for (final msg in messages) {
      smsSheet.appendRow([
        TextCellValue(msg.address),
        TextCellValue(msg.body),
        DateTimeCellValue.fromDateTime(msg.date),
        TextCellValue(msg.type.name),
      ]);
    }

    // Calls Sheet
    final callsSheet = excel['Calls'];
    callsSheet.appendRow([
      TextCellValue('Number'),
      TextCellValue('Name'),
      TextCellValue('Date'),
      TextCellValue('Duration (sec)'),
      TextCellValue('Type'),
    ]);
    for (final call in calls) {
      callsSheet.appendRow([
        TextCellValue(call.number),
        TextCellValue(call.name ?? ''),
        DateTimeCellValue.fromDateTime(call.date),
        IntCellValue(call.duration),
        TextCellValue(call.type.name),
      ]);
    }

    // Contacts Sheet
    final contactsSheet = excel['Contacts'];
    contactsSheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Email'),
    ]);
    for (final contact in contacts) {
      contactsSheet.appendRow([
        TextCellValue(contact.displayName),
        TextCellValue(contact.phones.join(', ')),
        TextCellValue(contact.emails.join(', ')),
      ]);
    }

    // Remove default sheet
    excel.delete('Sheet1');

    // Save
    final bytes = excel.save();
    final file = File(outputPath);
    await file.writeAsBytes(bytes!);

    return file;
  }
}
```

**Confidence:** HIGH - verified via [excel 4.0.6 pub.dev](https://pub.dev/packages/excel).

## Anti-Patterns to Avoid

### Anti-Pattern 1: Putting Server Logic in UI Layer

**What:** Mixing HTTP server handling code directly in widgets or screens.

**Why bad:** Makes code untestable, violates separation of concerns, causes state management issues.

**Instead:** Use service classes injected via dependency injection (Provider, Riverpod, GetIt).

### Anti-Pattern 2: Hardcoding IP Addresses

**What:** Requiring users to manually enter IP addresses to connect devices.

**Why bad:** Poor UX, error-prone, breaks when devices get new IPs.

**Instead:** Use mDNS service discovery for zero-config networking.

### Anti-Pattern 3: Running Server on Main Isolate

**What:** Running HTTP server and heavy data processing on the main UI isolate.

**Why bad:** Causes UI jank, ANRs on Android, poor responsiveness.

**Instead:** Use `compute()` or `Isolate.spawn()` for heavy work. Consider running server in background isolate.

### Anti-Pattern 4: No Session Timeout

**What:** Session tokens that never expire after pairing.

**Why bad:** Security risk if device is left unattended.

**Instead:** Implement session timeout (e.g., 30 minutes of inactivity) and require re-pairing.

### Anti-Pattern 5: Monolith Shared Package

**What:** Putting all shared code in a single `shared` package.

**Why bad:** Causes unnecessary dependencies, slower builds, tight coupling.

**Instead:** Split into focused packages: `core` (models), `network_protocol` (API contract), `ui_kit` (widgets).

## Build Order Implications

Based on component dependencies, the recommended build order is:

```
Phase 1: Foundation
├── packages/core (models, constants)
└── packages/network_protocol (API contract)

Phase 2: Android Provider
├── HTTP server with routes
├── Phone data services (SMS, calls, contacts)
├── mDNS advertising
└── PIN generation/validation

Phase 3: Desktop Consumer
├── mDNS discovery
├── HTTP client + pairing flow
├── Sync service
└── Excel export

Phase 4: Integration & Polish
├── End-to-end testing
├── Error handling
└── UI refinement
```

**Rationale:**
- Core and network_protocol must exist before apps can import them
- Android provider must be working before desktop can consume its API
- Discovery and sync are prerequisites for export
- Integration testing requires both apps functional

## Platform-Specific Considerations

### Android Provider Requirements

| Requirement | Implementation |
|-------------|----------------|
| SMS access | `flutter_sms_inbox` + `READ_SMS` permission |
| Call log access | `call_log` + `READ_CALL_LOG`, `READ_PHONE_STATE`, `READ_PHONE_NUMBERS` permissions |
| Contacts access | `flutter_contacts` + `READ_CONTACTS` permission |
| Network server | `dart:io` HttpServer |
| mDNS advertising | `nsd` + `INTERNET`, `CHANGE_WIFI_MULTICAST_STATE` permissions |
| Background operation | Consider foreground service for reliable operation |

**Critical Note on SMS/Call Log:** Google Play restricts SMS and call log access. Apps must declare as default SMS/Phone handler OR request special approval. For personal use / sideloading, this is not an issue.

### Desktop Consumer Requirements

| Requirement | Windows | macOS |
|-------------|---------|-------|
| mDNS discovery | `nsd` (uses mdns library) | `nsd` (uses Bonjour) |
| HTTP client | `http` or `dio` package | Same |
| Excel export | `excel` package | Same |
| File save dialog | `file_picker` or `file_selector` | Same |

**macOS Info.plist additions:**

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to discover your Android device.</string>
<key>NSBonjourServices</key>
<array>
  <string>_phonesync._tcp</string>
</array>
```

## Sources

### Official/Authoritative (HIGH confidence)
- [Melos 7.4.0 - pub.dev](https://pub.dev/packages/melos)
- [Melos Official Documentation](https://melos.invertase.dev/)
- [nsd 4.1.0 - pub.dev](https://pub.dev/packages/nsd)
- [shelf 1.4.2 - pub.dev](https://pub.dev/packages/shelf)
- [excel 4.0.6 - pub.dev](https://pub.dev/packages/excel)
- [call_log 6.0.1 - pub.dev](https://pub.dev/packages/call_log)
- [flutter_contacts 1.1.9 - pub.dev](https://pub.dev/packages/flutter_contacts)
- [flutter_sms_inbox 1.0.4 - pub.dev](https://pub.dev/packages/flutter_sms_inbox)
- [dart:io HttpServer - Flutter API docs](https://api.flutter.dev/flutter/dart-io/HttpServer-class.html)
- [Flutter Desktop Support - flutter.dev](https://docs.flutter.dev/platform-integration/desktop)

### Community/WebSearch (MEDIUM confidence)
- [Flutter Monorepo from Scratch 2025/2026 - Medium](https://medium.com/@sijalneupane5/flutter-monorepo-from-scratch-2025-going-into-2026-pub-workspaces-melos-explained-properly-fae98bfc8a6e)
- [Flutter at Scale: Code Sharing using a Monorepo - Medium](https://adityadroid.medium.com/flutter-at-scale-code-sharing-using-a-monorepo-a7a46c427141)
- [HTTP Server on Mobile with Flutter - Medium](https://medium.com/@naik.rpsn/http-server-running-on-a-mobile-app-with-flutter-1ef1e717dda1)
- [Implementing Local Network Discovery (mDNS) in Flutter - vibe-studio.ai](https://vibe-studio.ai/insights/implementing-local-network-discovery-(mdns)-in-flutter)
