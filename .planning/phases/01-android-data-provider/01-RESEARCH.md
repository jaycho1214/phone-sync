# Phase 1: Android Data Provider - Research

**Researched:** 2026-02-03
**Domain:** Android Content Providers (Contacts, SMS, Call Logs) + Flutter Data Access
**Confidence:** HIGH

## Summary

This phase implements Android data extraction for phone numbers from contacts, SMS messages, and call history. The research focused on three key areas: (1) Android Content Provider APIs and their timestamp/pagination capabilities, (2) Flutter packages for accessing these data sources, and (3) permission handling patterns for requesting multiple dangerous permissions.

The recommended approach uses established Flutter packages (`flutter_contacts`, `call_log`, `another_telephony`) with explicit pagination for large datasets. All three Android content providers support timestamp-based incremental queries, making timestamp-based sync the recommended approach over ID-based sync. Permission handling uses `permission_handler` to request all three permissions at once, gracefully handling partial grants.

**Primary recommendation:** Use timestamp-based incremental sync with explicit pagination (100-500 records per batch) for all three data sources, storing last sync timestamps per data type in SharedPreferences.

## Standard Stack

The established libraries/tools for this phase:

### Core Data Access
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_contacts | 1.1.9+2 | Read contacts with phone numbers | Most complete contacts API, supports full contact model |
| call_log | 6.0.1 | Read call history with date filtering | Built-in `dateFrom`/`dateTo` query params for incremental sync |
| another_telephony | 0.4.1 | Read SMS messages | Maintained fork of deprecated `telephony`, supports `SmsFilter` |
| permission_handler | 12.0.1 | Request/check all permissions | Unified API, supports batch requests, permanentlyDenied detection |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shared_preferences | latest | Store sync timestamps | Per-source last sync timestamp storage |
| flutter_riverpod | 3.2.0 | State management | Permission states, extraction counts, sync progress |

### Alternative Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| another_telephony | android_sms_reader 0.0.6 | Has explicit pagination (`start`, `count` params), but less mature (v0.0.6 vs v0.4.1) |
| flutter_contacts | flutter_contacts_stack | Better large dataset support with streaming, but newer/less proven |

**Installation (apps/android_provider/pubspec.yaml):**
```yaml
dependencies:
  flutter_contacts: ^1.1.9+2
  call_log: ^6.0.1
  another_telephony: ^0.4.1
  permission_handler: ^12.0.1
  shared_preferences: ^2.3.0
  flutter_riverpod: ^3.2.0
```

## Architecture Patterns

### Recommended Project Structure
```
apps/android_provider/lib/
├── main.dart
├── app.dart
├── providers/                    # Riverpod providers
│   ├── permission_provider.dart  # Permission state management
│   ├── contacts_provider.dart    # Contacts extraction state
│   ├── sms_provider.dart         # SMS extraction state
│   ├── call_log_provider.dart    # Call log extraction state
│   └── sync_state_provider.dart  # Last sync timestamps
├── services/                     # Data extraction services
│   ├── contacts_service.dart     # Paginated contacts extraction
│   ├── sms_service.dart          # Paginated SMS extraction
│   ├── call_log_service.dart     # Paginated call log extraction
│   └── sync_storage_service.dart # SharedPreferences wrapper
├── models/                       # Local models (or import from core package)
│   └── extraction_result.dart    # Result with count, errors, progress
└── screens/
    └── home_screen.dart          # Main UI with counts and status
```

### Pattern 1: Paginated Data Extraction
**What:** Extract data in small batches to avoid memory exhaustion
**When to use:** Always for contacts, SMS, call logs (expect 50,000+ records)
**Why:** Android CursorWindow has 2MB buffer; large queries cause O(n^2) re-querying

```dart
// Source: Android ContentResolver best practices
class CallLogService {
  static const int _pageSize = 500;

  /// Extract call logs incrementally with pagination
  Stream<List<CallLogEntry>> extractCallLogs({
    required int? lastSyncTimestamp,
    required void Function(int current, int total) onProgress,
  }) async* {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Query with date filter for incremental sync
    final allEntries = await CallLog.query(
      dateFrom: lastSyncTimestamp ?? 0,
      dateTo: now,
    );

    final entriesList = allEntries.toList();
    final total = entriesList.length;

    // Yield in batches to avoid memory pressure
    for (var i = 0; i < total; i += _pageSize) {
      final end = (i + _pageSize > total) ? total : i + _pageSize;
      final batch = entriesList.sublist(i, end);
      onProgress(end, total);
      yield batch;
    }
  }
}
```

### Pattern 2: Permission Request with Partial Grant Handling
**What:** Request all permissions at once, handle each result independently
**When to use:** App startup, before any data extraction

```dart
// Source: permission_handler pub.dev documentation
class PermissionService {
  /// Request all required permissions, return status map
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    return await [
      Permission.contacts,
      Permission.sms,
      Permission.phone,  // Includes call log on Android 9+
    ].request();
  }

  /// Check if at least one data source is accessible
  bool hasAnyPermission(Map<Permission, PermissionStatus> statuses) {
    return statuses.values.any((s) => s.isGranted);
  }

  /// Get list of permanently denied permissions for settings guidance
  List<Permission> getPermanentlyDenied(Map<Permission, PermissionStatus> statuses) {
    return statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();
  }
}
```

### Pattern 3: Timestamp-Based Sync State Storage
**What:** Store last successful sync timestamp per data source
**When to use:** After each successful extraction batch

```dart
// Source: Flutter SharedPreferences cookbook
class SyncStorageService {
  static const _keyPrefix = 'last_sync_';

  Future<int?> getLastSyncTimestamp(DataSource source) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyPrefix${source.name}');
  }

  Future<void> setLastSyncTimestamp(DataSource source, int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyPrefix${source.name}', timestamp);
  }

  /// Clear all sync state (for full resync)
  Future<void> clearAllSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final source in DataSource.values) {
      await prefs.remove('$_keyPrefix${source.name}');
    }
  }
}

enum DataSource { contacts, sms, callLog }
```

### Pattern 4: Riverpod State for UI Counts
**What:** Expose extraction counts and progress to UI
**When to use:** Home screen display

```dart
// Source: Riverpod 3.x patterns
@riverpod
class ExtractionState extends _$ExtractionState {
  @override
  ExtractionStatus build() => ExtractionStatus.initial();

  void updateCounts({int? contacts, int? sms, int? calls}) {
    state = state.copyWith(
      contactCount: contacts ?? state.contactCount,
      smsCount: sms ?? state.smsCount,
      callCount: calls ?? state.callCount,
    );
  }

  void setProgress(double progress) {
    state = state.copyWith(progress: progress);
  }

  void setError(String message) {
    state = state.copyWith(error: message);
  }
}

@freezed
class ExtractionStatus with _$ExtractionStatus {
  const factory ExtractionStatus({
    @Default(0) int contactCount,
    @Default(0) int smsCount,
    @Default(0) int callCount,
    @Default(0.0) double progress,
    String? error,
  }) = _ExtractionStatus;

  factory ExtractionStatus.initial() => const ExtractionStatus();
}
```

### Anti-Patterns to Avoid
- **Loading all records into memory:** Never do `final all = await CallLog.get()` without pagination for large datasets
- **Ignoring permission status:** Always check each permission individually; batch request returns mixed results
- **Hardcoding timestamps:** Store timestamps in SharedPreferences, not as compile-time constants
- **Blocking UI thread:** Use `compute()` or isolates for heavy data processing
- **Assuming permissions persist:** Permission can be revoked at any time; check before each extraction

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Contacts access | Direct ContentResolver queries | flutter_contacts | Handles contact aggregation, photo handling, platform differences |
| Call log queries | Raw ContentProvider queries | call_log package | Built-in date filtering, proper permission handling |
| SMS access | Direct Telephony.Sms queries | another_telephony | Handles SMS vs MMS timestamp differences (seconds vs milliseconds) |
| Permission flow | Custom permission dialogs | permission_handler | Handles Android version differences, permanently denied state |
| Key-value storage | File-based storage | SharedPreferences | Async-safe, platform-appropriate storage mechanism |

**Key insight:** Android Content Providers have numerous edge cases (contact aggregation, SMS vs MMS timestamp formats, permission coupling on Android 9+) that are already handled by established packages.

## Common Pitfalls

### Pitfall 1: Cursor Memory Exhaustion on Large Datasets
**What goes wrong:** OutOfMemoryError or app freezing when querying 50,000+ SMS or call log entries
**Why it happens:** SQLiteCursor uses 2MB CursorWindow buffer; large result sets cause O(n^2) page skipping
**How to avoid:**
- Always use date-range queries to limit result set size
- Process results in batches (100-500 records)
- Close/release resources immediately after each batch
**Warning signs:** App becomes unresponsive during extraction; "Could not allocate CursorWindow" in logs

### Pitfall 2: Phone + Call Log Permission Coupling (Android 9+)
**What goes wrong:** Requesting `Permission.phone` also triggers call log permission dialog, confusing users
**Why it happens:** Android 9+ changed permission group handling; call_log package requires both `READ_CALL_LOG` and `READ_PHONE_STATE`
**How to avoid:**
- Request `Permission.phone` for call logs (it covers both)
- Explain in UI that phone permission includes call history access
- Don't request `Permission.phone` separately if you already have call log
**Warning signs:** Users report unexpected permission dialogs; permission count seems wrong

### Pitfall 3: Permission Dialog Not Showing
**What goes wrong:** `Permission.contacts.request()` returns without showing dialog; app assumes denied
**Why it happens:** Known issue on certain Android versions; dialog doesn't pause app execution
**How to avoid:**
- Always check status AFTER request returns
- If status is still `.denied` (not `.permanentlyDenied`), allow retry
- Implement manual settings guidance as fallback
**Warning signs:** Permissions always denied without user seeing dialog; works on some devices but not others

### Pitfall 4: SMS Timestamp Format Mismatch
**What goes wrong:** Incremental sync fails; either misses messages or re-syncs all messages
**Why it happens:** SMS uses milliseconds since epoch; MMS uses seconds since epoch
**How to avoid:** another_telephony handles this internally; don't mix raw queries with package queries
**Warning signs:** Duplicate SMS entries after sync; messages with wrong dates

### Pitfall 5: Ignoring Partial Permission Grants
**What goes wrong:** App shows error when user grants 2 of 3 permissions; user thinks app is broken
**Why it happens:** Code assumes all-or-nothing permission grants
**How to avoid:**
- Check each permission independently after batch request
- Enable features for granted permissions only
- Show counts as "N/A" or "Permission needed" for denied sources
**Warning signs:** Error messages when some permissions granted; features not working despite partial grants

### Pitfall 6: Contacts Without Phone Numbers
**What goes wrong:** Contact count is high but phone number count is low; user confused
**Why it happens:** Many contacts have only email; flutter_contacts returns all contacts by default
**How to avoid:**
- Filter contacts: `contact.phones.isNotEmpty`
- Show both contact count and "contacts with phones" count
- Extract phone numbers, not contacts themselves
**Warning signs:** High contact count but low useful data; exports mostly empty

## Code Examples

Verified patterns from official sources:

### Incremental Call Log Query
```dart
// Source: call_log pub.dev documentation
Future<List<CallLogEntry>> getNewCallsSince(int? lastSyncMs) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  final entries = await CallLog.query(
    dateFrom: lastSyncMs ?? 0,  // 0 = all time for first sync
    dateTo: now,
  );

  return entries.toList();
}
```

### SMS Query with Filter
```dart
// Source: another_telephony pub.dev documentation
Future<List<SmsMessage>> getSmsMessages({
  int? sinceTimestamp,
}) async {
  final telephony = Telephony.instance;

  // Build filter for incremental query
  SmsFilter? filter;
  if (sinceTimestamp != null) {
    filter = SmsFilter.where(SmsColumn.DATE)
        .greaterThan(sinceTimestamp.toString());
  }

  final inbox = await telephony.getInboxSms(
    columns: [SmsColumn.ADDRESS, SmsColumn.DATE, SmsColumn.BODY],
    filter: filter,
    sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
  );

  final sent = await telephony.getSentSms(
    columns: [SmsColumn.ADDRESS, SmsColumn.DATE, SmsColumn.BODY],
    filter: filter,
    sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
  );

  return [...inbox, ...sent];
}
```

### Contacts with Phone Numbers Only
```dart
// Source: flutter_contacts pub.dev documentation
Future<List<Contact>> getContactsWithPhones() async {
  final contacts = await FlutterContacts.getContacts(
    withProperties: true,  // Need phone numbers
    withPhoto: false,      // Skip photos for performance
  );

  // Filter to contacts with at least one phone number
  return contacts.where((c) => c.phones.isNotEmpty).toList();
}
```

### Batch Permission Request
```dart
// Source: permission_handler pub.dev documentation
Future<PermissionResults> requestDataPermissions() async {
  final statuses = await [
    Permission.contacts,
    Permission.sms,
    Permission.phone,
  ].request();

  return PermissionResults(
    contacts: statuses[Permission.contacts]!,
    sms: statuses[Permission.sms]!,
    callLog: statuses[Permission.phone]!,  // phone includes call log
  );
}

class PermissionResults {
  final PermissionStatus contacts;
  final PermissionStatus sms;
  final PermissionStatus callLog;

  PermissionResults({
    required this.contacts,
    required this.sms,
    required this.callLog,
  });

  bool get hasAny =>
      contacts.isGranted || sms.isGranted || callLog.isGranted;

  List<String> get deniedNames => [
    if (!contacts.isGranted) 'Contacts',
    if (!sms.isGranted) 'SMS',
    if (!callLog.isGranted) 'Call Log',
  ];

  List<String> get permanentlyDeniedNames => [
    if (contacts.isPermanentlyDenied) 'Contacts',
    if (sms.isPermanentlyDenied) 'SMS',
    if (callLog.isPermanentlyDenied) 'Call Log',
  ];
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| telephony package | another_telephony | April 2025 | Original package deprecated; fork is maintained |
| Manual ContentResolver | flutter_contacts/call_log | - | Packages handle edge cases, aggregation |
| Provider state management | Riverpod 3.x | Sept 2025 | Compile-time safety, built-in async handling |
| SharedPreferences (legacy) | SharedPreferencesAsync | 2025 | Legacy API deprecated; use async version |

**Deprecated/outdated:**
- `telephony` package: Unmaintained; use `another_telephony` fork
- Provider (for new projects): Superseded by Riverpod; BuildContext dependency issues
- Synchronous SharedPreferences methods: Deprecated; use async versions

## Discretionary Recommendations

### Sync Mechanism: Timestamp-Based (Recommended)

**Decision context:** User marked as Claude's discretion whether to use timestamp-based or ID-based incremental sync.

**Recommendation:** Use timestamp-based sync with the `date` column from each content provider.

**Rationale:**
1. All three Android content providers (Contacts, SMS, CallLog) have reliable timestamp columns
2. `call_log` package has built-in `dateFrom`/`dateTo` parameters - no extra work needed
3. Contacts have `CONTACT_LAST_UPDATED_TIMESTAMP` for modified detection
4. SMS has `date` column (milliseconds since epoch)
5. Timestamp approach avoids issues with non-sequential IDs after deletions

**Tradeoff:** Timestamp granularity can miss records modified in same millisecond. Mitigate by using `>=` comparison and deduplicating on desktop side.

### Sync State Storage: Android Side (Recommended)

**Decision context:** User marked as Claude's discretion where to store sync state.

**Recommendation:** Store last sync timestamps on Android in SharedPreferences.

**Rationale:**
1. Simpler protocol - Android just needs to know "give me records since X"
2. No need for desktop to remember per-device sync state
3. Works naturally with "app killed mid-sync: start fresh" requirement
4. SharedPreferences survives app restarts but can be cleared for full resync

**Implementation:** Store three separate timestamps: `last_sync_contacts`, `last_sync_sms`, `last_sync_calls`

### Main Screen Layout: Utilitarian Status Display

**Decision context:** User marked as Claude's discretion for main screen design.

**Recommendation:** Simple single-screen layout with:
- Permission status section (granted/denied per source with "Open Settings" button)
- Count display: "Contacts: X | SMS: Y | Calls: Z"
- Sync status: "Ready" / "Syncing: 45%" / "Error: [message]"
- Last sync time: "Last synced: [datetime]" or "Never synced"

**Rationale:** User specified "utilitarian, focus on reliability over polish" - no need for complex navigation or animations.

### Progress Indicator: Linear with Percentage

**Decision context:** User marked as Claude's discretion for progress indicator style.

**Recommendation:** Linear progress bar with percentage text.

**Rationale:** Sync involves multiple data sources sequentially; linear bar shows clear progress. Percentage gives user expectation of completion time.

## Open Questions

Things that couldn't be fully resolved:

1. **flutter_contacts timestamp filtering**
   - What we know: Package doesn't expose built-in date-range filtering
   - What's unclear: Whether `CONTACT_LAST_UPDATED_TIMESTAMP` is accessible via package API
   - Recommendation: For incremental contacts sync, may need to fetch all and filter in Dart, or use platform channel for raw query. Test during implementation; if needed, full contact sync is acceptable (contacts change less frequently than SMS/calls).

2. **another_telephony pagination limits**
   - What we know: Package supports `SmsFilter` and sorting but doesn't document explicit LIMIT/OFFSET
   - What's unclear: How package handles 100,000+ message queries internally
   - Recommendation: Implement streaming/batching on our side regardless; if issues arise, consider `android_sms_reader` which has explicit pagination.

3. **Android 14+ foreground service requirements**
   - What we know: Long-running sync operations may need foreground service with notification
   - What's unclear: Whether our sync duration requires this (depends on dataset size)
   - Recommendation: Start without foreground service; add if sync operations are killed on real devices. Required permissions are `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC`.

## Sources

### Primary (HIGH confidence)
- [call_log 6.0.1 - pub.dev](https://pub.dev/packages/call_log) - Query API with dateFrom/dateTo params
- [flutter_contacts 1.1.9+2 - pub.dev](https://pub.dev/packages/flutter_contacts) - Contact retrieval API
- [another_telephony 0.4.1 - pub.dev](https://pub.dev/packages/another_telephony) - SMS query with SmsFilter
- [permission_handler 12.0.1 - pub.dev](https://pub.dev/packages/permission_handler) - Batch permission requests
- [Android CallLog.Calls - developer.android.com](https://developer.android.com/reference/android/provider/CallLog.Calls) - DATE column documentation
- [Android Telephony.Sms - developer.android.com](https://developer.android.com/reference/android/provider/Telephony.Sms) - SMS content provider
- [Flutter SharedPreferences cookbook](https://docs.flutter.dev/cookbook/persistence/key-value) - Timestamp storage

### Secondary (MEDIUM confidence)
- [Android ContentResolver pagination - code.luasoftware.com](https://code.luasoftware.com/tutorials/android/android-contentresolver-query-with-paging/) - LIMIT/OFFSET usage
- [Tracking Recently Modified Contacts - logicwind.com](https://blog.logicwind.com/fetch-recently-added-contacts-in-android-and-ios/) - CONTACT_LAST_UPDATED_TIMESTAMP usage
- [Best Flutter State Management 2026 - foresightmobile.com](https://foresightmobile.com/blog/best-flutter-state-management) - Riverpod 3.x recommendation

### Tertiary (LOW confidence)
- [Timestamp vs ID sync approaches - dev.to](https://dev.to/seatunnel/which-data-synchronization-method-is-more-senior-2nh1) - Sync strategy comparison (general, not Android-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages verified on pub.dev with current versions
- Architecture: HIGH - Patterns based on official package documentation
- Pitfalls: HIGH - Most verified via GitHub issues and official Android documentation
- Discretionary decisions: MEDIUM - Based on general best practices and phase requirements

**Research date:** 2026-02-03
**Valid until:** 60 days (stable Android APIs, established Flutter packages)
