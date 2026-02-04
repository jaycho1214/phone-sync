# Phase 3: Desktop Client & Export - Research

**Researched:** 2026-02-04
**Domain:** Flutter desktop app (Windows/Mac), mDNS discovery, HTTP client with TLS, local data storage, phone number normalization, Excel export
**Confidence:** HIGH

## Summary

Phase 3 implements a Flutter desktop application for Windows and Mac that discovers Android devices via mDNS, pairs using PIN entry, syncs phone data (contacts, SMS, call logs) over HTTPS, stores data locally in SQLite, and exports to Excel. The app persists synced data for offline export capability.

The standard approach uses:
- **nsd** package for cross-platform mDNS discovery (already used on Android for registration)
- **dio** with custom `HttpClient` for HTTPS with self-signed certificate trust
- **drift** (formerly Moor) for type-safe SQLite with built-in isolate support
- **excel** package for .xlsx generation with chunked writing for large datasets
- **phone_parser** for E.164 phone number normalization (pure Dart, works on desktop)
- **pinput** for the 6-digit PIN entry UI with auto-advance
- **flutter_secure_storage** for session token persistence

**Primary recommendation:** Use drift over raw sqflite for local storage - it provides type-safe queries, reactive streams, and built-in threading support essential for handling 50k+ records. Use isolates for Excel export to prevent UI freezing on large datasets.

## Standard Stack

The established libraries/tools for this domain:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nsd | 4.1.0 | mDNS discovery | Already in project for Android registration; supports Windows 10 19H1+ and macOS |
| dio | 5.8.0+ | HTTP client | Supports progress callbacks, interceptors, custom HttpClient for self-signed certs |
| drift | 2.31.0+ | SQLite ORM | Type-safe queries, built-in isolate threading, reactive streams |
| excel | 4.0.6 | Excel export | Pure Dart, cross-platform, full .xlsx support |
| phone_parser | 0.0.7 | Phone normalization | Pure Dart, E.164 format, works on all platforms |
| pinput | 6.0.1 | PIN input widget | 6-digit boxes, auto-advance, desktop support |
| flutter_secure_storage | 9.0.0+ | Token storage | Keychain on Mac, encrypted storage on Windows/Linux |
| file_picker | 10.3.10 | Save dialog | Already in project, saveFile() for export location |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| drift_dev | 2.31.0+ | Drift code generation | Dev dependency for database schema generation |
| sqlite3 | 2.9.4+ | SQLite bindings | Required by drift for native database access |
| intl | 0.19.0+ | Date formatting | Format timestamps in export filename |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| drift | sqflite + sqflite_common_ffi | Raw SQL, no type safety, manual threading |
| dio | http package | No interceptors, harder certificate handling |
| phone_parser | flutter_libphonenumber | Requires native bindings, phone_parser is pure Dart |
| pinput | pin_code_fields | Pinput has better desktop support and animations |
| flutter_secure_storage | shared_preferences | Not encrypted, security concern for tokens |

**Installation:**
```yaml
# In desktop_client/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  nsd: ^4.1.0
  dio: ^5.8.0
  drift: ^2.31.0
  sqlite3: ^2.9.4
  excel: ^4.0.6
  phone_parser: ^0.0.7
  pinput: ^6.0.1
  flutter_secure_storage: ^9.0.0
  file_picker: ^10.3.10
  path_provider: ^2.1.5
  intl: ^0.19.0
  core:
    path: ../../packages/core

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  drift_dev: ^2.31.0
  build_runner: ^2.4.15
```

## Architecture Patterns

### Recommended Project Structure

```
apps/desktop_client/lib/
  main.dart                    # Entry point, drift + security init
  app.dart                     # ProviderScope, MaterialApp
  screens/
    home_screen.dart           # Main screen with sync status
    discovery_screen.dart      # Device list when multiple found
    pairing_screen.dart        # PIN entry screen
    export_screen.dart         # Export options, filter toggle
  widgets/
    device_card.dart           # Device info display
    pin_input.dart             # 6-box PIN entry
    sync_progress.dart         # Progress bar with count
    phone_list_tile.dart       # Phone number row preview
  services/
    discovery_service.dart     # mDNS discovery
    sync_service.dart          # HTTP sync with progress
    export_service.dart        # Excel generation
  repositories/
    phone_repository.dart      # Drift database operations
  database/
    database.dart              # Drift database definition
    tables.dart                # Table definitions
    database.g.dart            # Generated code
  providers/
    discovery_provider.dart    # Device discovery state
    sync_provider.dart         # Sync state, progress
    export_provider.dart       # Export state, filters
    session_provider.dart      # Token, paired device
  models/
    device.dart                # Discovered device model
    phone_entry.dart           # Normalized phone entry
```

### Pattern 1: mDNS Discovery with IP Lookup

**What:** Discover Android devices advertising `_phonesync._tcp` service
**When to use:** On app launch and when user requests refresh
**Example:**
```dart
// Source: https://pub.dev/packages/nsd
import 'package:nsd/nsd.dart';

class DiscoveryService {
  Discovery? _discovery;
  final List<Service> devices = [];

  Future<void> startDiscovery({
    required void Function(List<Service>) onDevicesChanged,
  }) async {
    // Enable IP lookup to get address for HTTP client
    _discovery = await startDiscovery(
      '_phonesync._tcp',
      ipLookupType: IpLookupType.any,
    );

    _discovery!.addListener(() {
      devices.clear();
      devices.addAll(_discovery!.services);
      onDevicesChanged(devices);
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

### Pattern 2: HTTP Client with Self-Signed Certificate Trust

**What:** Create Dio client that trusts the Android server's self-signed cert
**When to use:** For all HTTPS requests to the Android server
**Example:**
```dart
// Source: https://api.flutter.dev/flutter/dart-io/HttpClient/badCertificateCallback.html
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

class SyncService {
  late final Dio _dio;

  SyncService({required String baseUrl, String? sessionToken}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      headers: sessionToken != null
          ? {'Authorization': 'Bearer $sessionToken'}
          : null,
    ));

    // Trust self-signed certificate from Android server
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }

  Future<List<Map<String, dynamic>>> fetchContacts({
    void Function(int received, int total)? onProgress,
  }) async {
    final response = await _dio.get(
      '/contacts',
      onReceiveProgress: onProgress,
    );
    return List<Map<String, dynamic>>.from(response.data['data']);
  }
}
```

### Pattern 3: Drift Database with Isolate Threading

**What:** Type-safe SQLite database that handles large datasets without blocking UI
**When to use:** All local data storage operations
**Example:**
```dart
// Source: https://drift.simonbinder.eu/
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class PhoneEntries extends Table {
  TextColumn get phoneNumber => text()(); // Primary key - normalized
  TextColumn get displayName => text().nullable()();
  TextColumn get sourceTypes => text()(); // JSON array: ["contact", "sms", "call"]
  IntColumn get earliestTimestamp => integer().nullable()();
  IntColumn get latestTimestamp => integer().nullable()();
  TextColumn get rawNumbers => text()(); // JSON array of original formats

  @override
  Set<Column> get primaryKey => {phoneNumber};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [PhoneEntries, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'phonesync.db'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // Upsert phone entries - handles deduplication
  Future<void> upsertPhoneEntry(PhoneEntriesCompanion entry) async {
    await into(phoneEntries).insertOnConflictUpdate(entry);
  }

  // Get all entries, optionally filtered
  Future<List<PhoneEntry>> getPhoneEntries({bool koreanMobileOnly = true}) async {
    if (koreanMobileOnly) {
      return (select(phoneEntries)
        ..where((t) => t.phoneNumber.like('+8210%')))
        .get();
    }
    return select(phoneEntries).get();
  }
}
```

### Pattern 4: Excel Export with Isolate

**What:** Generate Excel file in background isolate to prevent UI freeze
**When to use:** Exporting 50,000+ rows
**Example:**
```dart
// Source: https://pub.dev/packages/excel, https://dart.dev/language/isolates
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:isolate';

class ExportService {
  Future<void> exportToExcel({
    required List<PhoneEntry> entries,
    required String filePath,
    void Function(int current, int total)? onProgress,
  }) async {
    // Run in isolate for large datasets
    await Isolate.run(() async {
      final excel = Excel.createExcel();
      final sheet = excel['Phone Numbers'];

      // Header row
      sheet.appendRow([
        TextCellValue('Phone Number'),
        TextCellValue('Name'),
        TextCellValue('Sources'),
        TextCellValue('First Seen'),
        TextCellValue('Last Seen'),
      ]);

      // Data rows - process in chunks to report progress
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        sheet.appendRow([
          TextCellValue(entry.phoneNumber),
          TextCellValue(entry.displayName ?? ''),
          TextCellValue(entry.sourceTypes),
          entry.earliestTimestamp != null
              ? DateTimeCellValue.fromDateTime(
                  DateTime.fromMillisecondsSinceEpoch(entry.earliestTimestamp!))
              : TextCellValue(''),
          entry.latestTimestamp != null
              ? DateTimeCellValue.fromDateTime(
                  DateTime.fromMillisecondsSinceEpoch(entry.latestTimestamp!))
              : TextCellValue(''),
        ]);
      }

      // Remove default 'Sheet1' if exists
      excel.delete('Sheet1');

      // Save file
      final bytes = excel.save()!;
      await File(filePath).writeAsBytes(bytes);
    });
  }
}
```

### Pattern 5: Phone Number Normalization

**What:** Normalize Korean and international numbers to consistent format
**When to use:** When storing synced data in local database
**Example:**
```dart
// Source: https://pub.dev/packages/phone_parser
import 'package:phone_parser/phone_parser.dart';

class PhoneNormalizer {
  static const String koreaCountryCode = '+82';

  /// Normalize phone number to E.164 format
  /// Korean numbers: +821012345678
  /// International: +14155551234
  String? normalize(String rawNumber) {
    // Strip all non-digit characters except +
    final cleaned = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.isEmpty) return null;

    // Already E.164 format
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // Korean domestic format (010-xxxx-xxxx)
    if (cleaned.startsWith('010') && cleaned.length >= 10) {
      // Convert to E.164: +82 + number without leading 0
      return '$koreaCountryCode${cleaned.substring(1)}';
    }

    // Korean domestic with area code (02-xxxx-xxxx, etc.)
    if (cleaned.startsWith('0') && cleaned.length >= 9) {
      return '$koreaCountryCode${cleaned.substring(1)}';
    }

    // Try parsing with phone_parser for international
    try {
      final phone = PhoneNumber.parse(cleaned, callerCountry: IsoCode.KR);
      if (phone.isValid()) {
        return '+${phone.countryCode}${phone.nsn}';
      }
    } catch (_) {}

    // Fallback: assume Korean if looks like mobile
    if (cleaned.length == 10 || cleaned.length == 11) {
      return '$koreaCountryCode$cleaned';
    }

    return null; // Invalid
  }

  /// Check if number is Korean mobile (010 prefix)
  bool isKoreanMobile(String normalizedNumber) {
    return normalizedNumber.startsWith('+8210');
  }
}
```

### Pattern 6: PIN Entry with Auto-Advance

**What:** 6 separate input boxes that auto-advance on digit entry
**When to use:** Pairing screen
**Example:**
```dart
// Source: https://pub.dev/packages/pinput
import 'package:pinput/pinput.dart';

class PinInput extends StatelessWidget {
  final void Function(String) onCompleted;
  final void Function(String)? onChanged;

  const PinInput({
    required this.onCompleted,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.blue, width: 2),
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: Colors.blue.shade50,
      border: Border.all(color: Colors.blue),
    );

    return Pinput(
      length: 6,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      showCursor: true,
      onCompleted: onCompleted,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      autofocus: true,
    );
  }
}
```

### Anti-Patterns to Avoid

- **Blocking UI during export:** Use `Isolate.run()` for Excel generation with 50k+ rows
- **Storing session token in SharedPreferences:** Use flutter_secure_storage for encrypted storage
- **Raw sqflite queries:** Use drift for type safety and automatic threading
- **Trusting certificates globally:** Only bypass cert validation for the specific Android server host
- **Syncing without progress:** Always show "X / Y" progress for large syncs to indicate activity

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phone normalization | Regex parsing | phone_parser | E.164 edge cases, international formats, Korean specifics |
| PIN input boxes | 6 TextFields manually | pinput | Auto-advance, state animations, keyboard handling |
| SQLite on desktop | Raw SQL strings | drift | Type safety, isolate threading, migration support |
| Excel generation | CSV with .xlsx extension | excel package | Proper XLSX format, cell types, large file support |
| Certificate trust | Global HttpOverrides | Per-client badCertificateCallback | Security - only trust the specific server |
| Secure token storage | SharedPreferences | flutter_secure_storage | Encryption, Keychain/KeyStore integration |

**Key insight:** Phone number normalization and Excel generation are deceptively complex. Phone numbers have international variations, carrier formats, and country-specific rules. Excel has cell types, sheet management, and memory considerations for large files. Use the packages.

## Common Pitfalls

### Pitfall 1: Memory Issues with Large Excel Export

**What goes wrong:** App freezes or crashes when exporting 50,000+ rows
**Why it happens:** Excel generation blocks main isolate; entire dataset loaded in memory
**How to avoid:**
- Use `Isolate.run()` for export operation
- Consider chunked writing (process 1000 rows at a time)
- Show progress indicator during export
**Warning signs:** UI becomes unresponsive during export, "out of memory" errors

### Pitfall 2: mDNS Not Finding Devices on Windows

**What goes wrong:** Discovery returns no devices on Windows
**Why it happens:** Windows Firewall blocking mDNS multicast; missing network access dialog
**How to avoid:**
- First launch will show network access dialog - user must allow
- Ensure Windows 10 version 19H1 (1903) or later
- May need to allow app through Windows Firewall manually
**Warning signs:** Works on Mac but not Windows; no firewall prompt shown

### Pitfall 3: Self-Signed Certificate Rejection

**What goes wrong:** CERTIFICATE_VERIFY_FAILED error on HTTPS requests
**Why it happens:** Default HttpClient rejects untrusted certificates
**How to avoid:** Configure Dio with custom `createHttpClient` that returns true for `badCertificateCallback`
**Warning signs:** Connection works on HTTP but fails on HTTPS

### Pitfall 4: Session Token Lost on App Restart

**What goes wrong:** User must re-pair after restarting app
**Why it happens:** Token stored in memory only, not persisted
**How to avoid:**
- Store token in flutter_secure_storage after successful pairing
- Load token on app startup
- Check if device is still discoverable before auto-connecting
**Warning signs:** Works during single session, requires re-pairing after restart

### Pitfall 5: Korean Number Normalization Errors

**What goes wrong:** Same phone number appears as duplicates (010-1234-5678 vs +821012345678)
**Why it happens:** Inconsistent normalization before storage
**How to avoid:**
- Normalize ALL numbers to E.164 before storage
- Remove leading 0 from Korean numbers when adding +82
- Use normalized number as primary key
**Warning signs:** Duplicate rows with same number in different formats

### Pitfall 6: Database Blocking UI During Large Sync

**What goes wrong:** UI freezes while inserting 50,000 records
**Why it happens:** Database operations on main isolate
**How to avoid:**
- Drift's `NativeDatabase.createInBackground()` runs queries in separate isolate
- Use batch inserts rather than individual inserts
- Show progress during sync
**Warning signs:** Progress bar stuck, app not responding during sync

## Code Examples

Verified patterns from official sources:

### Complete Sync Flow with Progress

```dart
// Sync service with progress tracking
class SyncService {
  final Dio _dio;
  final AppDatabase _db;
  final PhoneNormalizer _normalizer = PhoneNormalizer();

  Future<void> syncAll({
    void Function(String phase, int current, int total)? onProgress,
  }) async {
    // 1. Sync contacts
    onProgress?.call('contacts', 0, 0);
    final contactsResponse = await _dio.get('/contacts');
    final contacts = List<Map<String, dynamic>>.from(contactsResponse.data['data']);

    for (var i = 0; i < contacts.length; i++) {
      await _processContact(contacts[i]);
      onProgress?.call('contacts', i + 1, contacts.length);
    }

    // 2. Sync SMS (with incremental since timestamp)
    onProgress?.call('sms', 0, 0);
    final lastSmsSync = await _db.getLastSyncTimestamp('sms');
    final smsResponse = await _dio.get('/sms', queryParameters: {
      if (lastSmsSync != null) 'since': lastSmsSync,
    });
    final messages = List<Map<String, dynamic>>.from(smsResponse.data['data']);

    for (var i = 0; i < messages.length; i++) {
      await _processSms(messages[i]);
      onProgress?.call('sms', i + 1, messages.length);
    }

    // 3. Sync calls (with incremental since timestamp)
    onProgress?.call('calls', 0, 0);
    final lastCallSync = await _db.getLastSyncTimestamp('calls');
    final callsResponse = await _dio.get('/calls', queryParameters: {
      if (lastCallSync != null) 'since': lastCallSync,
    });
    final calls = List<Map<String, dynamic>>.from(callsResponse.data['data']);

    for (var i = 0; i < calls.length; i++) {
      await _processCall(calls[i]);
      onProgress?.call('calls', i + 1, calls.length);
    }

    // Update sync timestamps
    await _db.setSyncTimestamp('sms', smsResponse.data['timestamp']);
    await _db.setSyncTimestamp('calls', callsResponse.data['timestamp']);
  }

  Future<void> _processContact(Map<String, dynamic> contact) async {
    final phones = List<Map<String, dynamic>>.from(contact['phones'] ?? []);
    for (final phone in phones) {
      final normalized = _normalizer.normalize(phone['number']);
      if (normalized != null) {
        await _db.upsertPhoneEntry(PhoneEntriesCompanion.insert(
          phoneNumber: normalized,
          displayName: Value(contact['displayName']),
          sourceTypes: '["contact"]',
          rawNumbers: '["${phone['number']}"]',
        ));
      }
    }
  }
}
```

### Save Dialog with Filename Format

```dart
// Source: https://pub.dev/packages/file_picker
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

Future<String?> showExportSaveDialog(String deviceName) async {
  final now = DateTime.now();
  final dateFormat = DateFormat('yyyy-MM-dd');
  final timeFormat = DateFormat('HHmmss');

  final filename = '${deviceName}_${dateFormat.format(now)}_${timeFormat.format(now)}.xlsx';

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Excel Export',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );

  return path;
}
```

### Session Persistence with Secure Storage

```dart
// Source: https://pub.dev/packages/flutter_secure_storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'session_token';
  static const _deviceNameKey = 'paired_device_name';
  static const _deviceHostKey = 'paired_device_host';

  Future<void> saveSession({
    required String token,
    required String deviceName,
    required String deviceHost,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _deviceNameKey, value: deviceName);
    await _storage.write(key: _deviceHostKey, value: deviceHost);
  }

  Future<({String? token, String? deviceName, String? deviceHost})> loadSession() async {
    return (
      token: await _storage.read(key: _tokenKey),
      deviceName: await _storage.read(key: _deviceNameKey),
      deviceHost: await _storage.read(key: _deviceHostKey),
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _deviceNameKey);
    await _storage.delete(key: _deviceHostKey);
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| sqflite raw SQL | drift type-safe ORM | 2023 | Compile-time safety, built-in threading |
| moor package | drift (renamed) | 2021 | Same library, new name |
| http package | dio | 2022 | Better progress callbacks, interceptors |
| flutter_libphonenumber | phone_parser | 2024 | Pure Dart, no native bindings |
| Manual PIN fields | pinput | 2023 | Auto-advance, animations, desktop support |

**Deprecated/outdated:**
- `moor` package: Renamed to `drift` - use drift
- Raw `sqflite` for desktop: Use `sqflite_common_ffi` or preferably `drift`
- `telephony` package: Use `another_telephony` (already using on Android)

## Open Questions

Things that couldn't be fully resolved:

1. **Excel memory usage for 50k+ rows**
   - What we know: excel package doesn't document memory usage patterns
   - What's unclear: Exact memory footprint per row, when chunking becomes necessary
   - Recommendation: Monitor memory during testing; implement streaming if needed

2. **Windows Firewall automatic prompting**
   - What we know: First network access triggers Windows dialog
   - What's unclear: Whether silent failure occurs if user denies; how to detect denial
   - Recommendation: Add manual IP entry fallback; document network permission requirement

3. **flutter_secure_storage on Windows encryption**
   - What we know: Uses encrypted storage but less documented than Mac Keychain
   - What's unclear: Exact encryption mechanism on Windows
   - Recommendation: Sufficient for session tokens; document limitation for future audit

## Recommended Export Columns

Based on Claude's discretion for column selection (balance usefulness with simplicity):

| Column | Description | Why Include |
|--------|-------------|-------------|
| Phone Number | E.164 normalized format | Primary data point |
| Name | Contact name if available | Useful context |
| Sources | Comma-separated (Contact, SMS, Call) | Shows data origin |
| First Seen | Earliest timestamp from all sources | Temporal context |
| Last Seen | Latest timestamp from all sources | Recency indicator |

**Excluded for simplicity:**
- Raw number formats (useful for debugging only)
- Individual source timestamps (merged into First/Last Seen)
- Call duration (rarely needed for phone number lists)
- SMS type (inbox/sent - not relevant for number collection)

## Sources

### Primary (HIGH confidence)
- [nsd 4.1.0](https://pub.dev/packages/nsd) - mDNS discovery/registration, platform support
- [drift 2.31.0](https://pub.dev/packages/drift) - Type-safe SQLite, desktop support
- [excel 4.0.6](https://pub.dev/packages/excel) - Excel generation
- [pinput 6.0.1](https://pub.dev/packages/pinput) - PIN input widget
- [phone_parser 0.0.7](https://pub.dev/packages/phone_parser) - Phone normalization
- [file_picker 10.3.10](https://pub.dev/packages/file_picker) - Save dialog
- [flutter_secure_storage 9.0.0](https://pub.dev/packages/flutter_secure_storage) - Secure token storage
- [Dio badCertificateCallback](https://api.flutter.dev/flutter/dart-io/HttpClient/badCertificateCallback.html) - Self-signed cert handling
- [Flutter Isolates](https://dart.dev/language/isolates) - Background computation

### Secondary (MEDIUM confidence)
- [Korean phone format](https://www.sent.dm/resources/kr) - E.164 conversion rules
- [Drift setup guide](https://drift.simonbinder.eu/setup/) - Desktop configuration
- [Self-signed TLS in Flutter](https://dev.to/remejuan/flutter-using-self-signed-ssl-certificates-in-development-20ce) - Dio configuration

### Tertiary (LOW confidence)
- Excel memory usage patterns - Not documented, needs testing
- Windows nsd firewall behavior - Community reports, needs validation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified via pub.dev, established packages
- Architecture: HIGH - Follows Flutter desktop best practices
- Pitfalls: MEDIUM - Some based on community reports, core issues verified
- Export columns: MEDIUM - Claude's discretion based on use case analysis

**Research date:** 2026-02-04
**Valid until:** 2026-03-04 (30 days - stable packages, well-established patterns)
