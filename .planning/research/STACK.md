# Technology Stack

**Project:** jljm-phonesync
**Researched:** 2026-02-03
**Overall Confidence:** HIGH (verified via pub.dev and official documentation)

## Executive Summary

This stack is designed for a Flutter monorepo containing an Android app (data source) and Windows/Mac desktop apps (data receivers/Excel exporters). The architecture uses local network communication with TLS encryption for security, mDNS for device discovery, and the `excel` package for spreadsheet generation.

**Critical constraint:** Google Play Store restricts SMS and Call Log permissions to apps that are designated default handlers. This project targets sideloading/APK distribution, not Play Store, making these permissions viable.

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Flutter | 3.27+ | Cross-platform framework | Stable desktop support, single codebase for Android/Windows/Mac | HIGH |
| Dart | 3.6+ | Language | Required for pub workspaces (monorepo), null safety mature | HIGH |
| Melos | 7.4.0 | Monorepo management | Industry standard, integrates with Dart 3.6 pub workspaces, CI/CD support | HIGH |

**Rationale:** Flutter 3.27+ with Dart 3.6+ is required for native pub workspaces support. Melos 7.4.0 builds on this foundation and is the de facto standard for Flutter monorepos. The combination eliminates the need for `pubspec_overrides.yaml` hacks.

### State Management

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| flutter_riverpod | 3.2.0 | State management | 2026 community standard, compile-time safety, less boilerplate than BLoC | HIGH |
| riverpod_annotation | 4.0.1 | Code generation annotations | Required for @riverpod annotation syntax | HIGH |
| riverpod_generator | 4.0.2 | Code generation | Generates provider code from annotations | HIGH |

**Rationale:** Riverpod 3.x is the modern default for Flutter state management in 2026. It offers compile-time safety (catches errors before runtime), built-in async handling, and significantly less boilerplate than BLoC. For a project of this scope (not enterprise/regulated), Riverpod is the right choice over BLoC.

### Data Serialization

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| freezed | 3.2.4 | Immutable data classes | Generates copyWith, equality, JSON serialization | HIGH |
| freezed_annotation | 2.4.1+ | Freezed annotations | Required for @freezed annotation | HIGH |
| json_serializable | 6.12.0 | JSON serialization | Works with freezed for fromJson/toJson | HIGH |
| json_annotation | 4.8.1+ | JSON annotations | Required for @JsonSerializable | HIGH |
| build_runner | 2.10.5 | Code generation runner | Executes freezed and json_serializable generators | HIGH |

**Rationale:** Freezed + json_serializable is the standard approach for type-safe data models in Flutter. Essential for the data transfer layer where SMS, contacts, and call log data must be serialized for network transfer and Excel export.

### Android Data Access

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| flutter_contacts | 1.1.9+2 | Read contacts | Full contact model support, CRUD operations, vCard export | HIGH |
| call_log | 6.0.1 | Read call history | Query with filters, export capability, Android-only (expected) | HIGH |
| another_telephony | 0.4.1 | Read SMS messages | Maintained fork, queries inbox/sent/draft, listens for incoming | MEDIUM |
| permission_handler | 12.0.1 | Permission management | Cross-platform permission API, handles all required permissions | HIGH |

**Rationale:**
- `flutter_contacts` is the most complete contacts package with comprehensive data model support.
- `call_log` is the standard choice for call history access on Android.
- `another_telephony` is a maintained fork (April 2025) of the deprecated `telephony` package - chosen over `sms_autofill` because we need to read actual SMS content, not just OTP codes.
- `permission_handler` provides unified permission management across platforms.

**CRITICAL NOTE:** These permissions (READ_SMS, READ_CALL_LOG, READ_CONTACTS) are restricted on Google Play Store. Apps must be default handlers to use them. **This project must target sideloading (APK distribution) rather than Play Store release.** See PITFALLS.md for details.

### Local Network Communication

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| nsd | 4.1.0 | mDNS service discovery | Cross-platform (Android/iOS/Mac/Windows), service registration + discovery | HIGH |
| dart:io Socket | (built-in) | TCP communication | Native Dart, no external dependency, full control over protocol | HIGH |
| dart:io SecureSocket | (built-in) | TLS encryption | Native TLS support, self-signed certificate support via SecurityContext | HIGH |

**Rationale:**
- `nsd` is the most complete mDNS package supporting all target platforms (Android, Windows, Mac). It handles both discovery and registration.
- Native `dart:io` Socket/SecureSocket is preferred over third-party packages because:
  1. No external dependency maintenance burden
  2. Full control over the custom protocol (PIN pairing, data transfer)
  3. SecureSocket supports self-signed certificates via `onBadCertificate` callback and custom `SecurityContext`

**Architecture:** Android app registers service via mDNS, desktop apps discover it. PIN displayed on both devices for verification. After PIN confirmation, establish TLS connection for data transfer.

### Excel Generation

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| excel | 4.0.6 | Create .xlsx files | Pure Dart, cross-platform, full Excel feature support | HIGH |

**Rationale:** The `excel` package is pure Dart (no native dependencies), works on all platforms, and supports all needed features: cell values, styling, multiple sheets. Syncfusion's alternative requires a commercial license.

**Alternative considered:** `syncfusion_flutter_xlsio` - more features (charts, formulas) but requires commercial license. Not needed for this use case (data export only).

### File System & Paths

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| path_provider | 2.1.5 | Get platform directories | Standard Flutter package, full desktop support | HIGH |
| file_picker | 10.3.10 | Save file dialogs | Cross-platform, uses native OS pickers | HIGH |

**Rationale:** Standard Flutter packages for file operations. `path_provider` gives access to Documents/Downloads folders. `file_picker` provides native save dialogs for choosing export location.

### Desktop Packaging

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| msix | 3.16.13 | Windows MSIX installer | Flutter Favorite, signing support, auto-update capability | HIGH |

**Rationale:** `msix` is a Flutter Favorite and the standard for Windows packaging. Creates proper installers with signing support. For macOS, use native `flutter build macos` and standard code signing.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| State Management | Riverpod 3.x | BLoC 9.x | BLoC is overkill for this scope; more boilerplate, better for large enterprise apps |
| State Management | Riverpod 3.x | Provider | Provider is Riverpod's predecessor; Riverpod fixes BuildContext dependency issues |
| Monorepo | Melos 7.x | None (manual) | Manual management doesn't scale; Melos provides versioning, CI filtering, workspace linking |
| SMS Reading | another_telephony | sms_autofill | sms_autofill is for OTP only; we need full SMS content access |
| SMS Reading | another_telephony | telephony | telephony is deprecated/unmaintained; another_telephony is the maintained fork |
| Network Discovery | nsd | flutter_nsd | flutter_nsd doesn't support service registration (only discovery) |
| Network Discovery | nsd | multicast_dns | Lower-level API, requires more implementation work |
| Excel | excel | syncfusion_flutter_xlsio | Syncfusion requires commercial license |
| TCP | dart:io Socket | tcp_socket_connection | Native dart:io gives more control, fewer dependencies |

---

## Monorepo Structure

```
jljm-phonesync/
  pubspec.yaml              # Root workspace definition
  melos.yaml                # Melos configuration
  apps/
    android/                # Android app (data source)
      pubspec.yaml
    desktop/                # Shared desktop app (Windows + Mac)
      pubspec.yaml
  packages/
    core/                   # Shared models, protocols
      pubspec.yaml
    network/                # mDNS, socket, TLS logic
      pubspec.yaml
```

**Root pubspec.yaml:**
```yaml
name: jljm_phonesync_workspace
environment:
  sdk: ">=3.6.0 <4.0.0"
workspace:
  - apps/*
  - packages/*
dev_dependencies:
  melos: ^7.4.0
```

---

## Installation

### Root Level
```bash
# Install melos globally
dart pub global activate melos

# Bootstrap workspace (from root)
melos bootstrap
```

### Android App (apps/android/pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.2.0
  riverpod_annotation: ^4.0.1
  flutter_contacts: ^1.1.9+2
  call_log: ^6.0.1
  another_telephony: ^0.4.1
  permission_handler: ^12.0.1
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  # Local packages
  core:
    path: ../../packages/core
  network:
    path: ../../packages/network

dev_dependencies:
  build_runner: ^2.10.5
  freezed: ^3.2.4
  json_serializable: ^6.12.0
  riverpod_generator: ^4.0.2
```

### Desktop App (apps/desktop/pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.2.0
  riverpod_annotation: ^4.0.1
  excel: ^4.0.6
  path_provider: ^2.1.5
  file_picker: ^10.3.10
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  # Local packages
  core:
    path: ../../packages/core
  network:
    path: ../../packages/network

dev_dependencies:
  build_runner: ^2.10.5
  freezed: ^3.2.4
  json_serializable: ^6.12.0
  riverpod_generator: ^4.0.2
  msix: ^3.16.13  # Windows only
```

### Shared Network Package (packages/network/pubspec.yaml)
```yaml
dependencies:
  nsd: ^4.1.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  core:
    path: ../core

dev_dependencies:
  build_runner: ^2.10.5
  freezed: ^3.2.4
  json_serializable: ^6.12.0
```

---

## Android Permissions

**AndroidManifest.xml:**
```xml
<!-- Contacts -->
<uses-permission android:name="android.permission.READ_CONTACTS" />

<!-- Call Log -->
<uses-permission android:name="android.permission.READ_CALL_LOG" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />

<!-- SMS -->
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />

<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

**CRITICAL:** These permissions disqualify the app from Google Play Store distribution. Plan for APK sideloading distribution.

---

## Platform-Specific Configuration

### iOS/macOS (Info.plist for mDNS)
```xml
<!-- Required for iOS 14+/macOS for local network access -->
<key>NSBonjourServices</key>
<array>
    <string>_phonesync._tcp</string>
</array>
<key>NSLocalNetworkUsageDescription</key>
<string>PhoneSync needs local network access to discover and connect to your phone.</string>
```

### Windows (No special mDNS config needed)
Windows native mDNS support via nsd package works out of the box on Windows 10 19H1+.

### macOS Sandbox (if distributing via App Store)
Local network entitlement required:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

---

## What NOT to Use

| Technology | Why Avoid |
|------------|-----------|
| GetX | Community consensus against it; poor architecture patterns, magic behavior |
| Provider (for new projects) | Superseded by Riverpod; BuildContext dependency causes issues |
| telephony package | Deprecated and unmaintained; use another_telephony fork instead |
| flutter_nsd | Doesn't support service registration, only discovery |
| syncfusion_flutter_xlsio | Commercial license required; excel package sufficient |
| WebSocket (for this use case) | TCP sockets give more control for custom protocol; WebSocket adds unnecessary HTTP overhead |
| HTTP/REST (for this use case) | Direct TCP with custom protocol is simpler for LAN-only, no server infrastructure |

---

## Sources

### Package Documentation (pub.dev - verified 2026-02-03)
- [Melos 7.4.0](https://pub.dev/packages/melos) - Monorepo management
- [flutter_riverpod 3.2.0](https://pub.dev/packages/flutter_riverpod) - State management
- [freezed 3.2.4](https://pub.dev/packages/freezed) - Immutable data classes
- [json_serializable 6.12.0](https://pub.dev/packages/json_serializable) - JSON serialization
- [flutter_contacts 1.1.9+2](https://pub.dev/packages/flutter_contacts) - Contacts access
- [call_log 6.0.1](https://pub.dev/packages/call_log) - Call history access
- [another_telephony 0.4.1](https://pub.dev/packages/another_telephony) - SMS access
- [permission_handler 12.0.1](https://pub.dev/packages/permission_handler) - Permission management
- [nsd 4.1.0](https://pub.dev/packages/nsd) - mDNS discovery/registration
- [excel 4.0.6](https://pub.dev/packages/excel) - Excel file generation
- [path_provider 2.1.5](https://pub.dev/packages/path_provider) - Platform directories
- [file_picker 10.3.10](https://pub.dev/packages/file_picker) - File save dialogs
- [msix 3.16.13](https://pub.dev/packages/msix) - Windows packaging

### Official Documentation
- [Flutter Desktop Support](https://docs.flutter.dev/platform-integration/desktop) - Desktop platform integration
- [Dart SecureSocket](https://api.flutter.dev/flutter/dart-io/SecureSocket-class.html) - TLS socket API
- [Google Play SMS/Call Log Policy](https://support.google.com/googleplay/android-developer/answer/10208820) - Permission restrictions

### Community Resources
- [Flutter Monorepo from Scratch (2025-2026)](https://medium.com/@sijalneupane5/flutter-monorepo-from-scratch-2025-going-into-2026-pub-workspaces-melos-explained-properly-fae98bfc8a6e) - Pub workspaces + Melos
- [Flutter State Management 2026](https://foresightmobile.com/blog/best-flutter-state-management) - Riverpod vs BLoC comparison
- [Multicast DNS in Flutter](https://medium.com/@punnyarthabanerjee/multicast-dns-in-flutter-connecting-devices-in-your-local-network-b33663d165c7) - mDNS implementation guide
