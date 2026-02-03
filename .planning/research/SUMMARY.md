# Project Research Summary

**Project:** jljm-phonesync
**Domain:** Cross-platform phone data extraction and sync tool (Android to Desktop)
**Researched:** 2026-02-03
**Confidence:** HIGH

## Executive Summary

This project is a Flutter monorepo enabling Android-to-desktop phone data extraction for SMS campaigns. The Android app extracts phone numbers from contacts, SMS, and call logs, while desktop apps (Windows/Mac) receive this data over the local network and export it to Excel. Research reveals a clear technical path using established Flutter packages and patterns, but with one critical constraint: Google Play Store prohibits SMS/call log permissions for non-default handler apps, requiring APK sideloading distribution.

The recommended architecture uses a Flutter monorepo (Melos + pub workspaces) with the Android device acting as an HTTP server that advertises itself via mDNS. The desktop client discovers the device automatically, pairs via PIN, then fetches data over HTTP and exports to .xlsx using the `excel` package. This pattern is well-documented, with high-quality packages available for all key functions (flutter_contacts, call_log, another_telephony, nsd, excel).

The primary risks are: (1) Play Store rejection if distribution strategy isn't planned upfront, (2) memory exhaustion when querying large SMS/call log datasets without pagination, (3) platform-specific mDNS configuration issues, and (4) incremental sync missing deleted records. All of these have well-known mitigations that must be implemented from the start rather than retrofitted.

## Key Findings

### Recommended Stack

Flutter 3.27+ with Dart 3.6+ provides native pub workspace support, eliminating the need for pubspec_overrides hacks. Melos 7.4.0 builds on this foundation as the industry standard for Flutter monorepos. For state management, Riverpod 3.x is the 2026 community default, offering compile-time safety and less boilerplate than BLoC (which is overkill for this scope).

**Core technologies:**
- **Flutter 3.27+ / Dart 3.6+**: Cross-platform framework with mature desktop support and native workspace support
- **Melos 7.4.0**: Monorepo management with CI/CD integration, versioning, and workspace linking
- **Riverpod 3.x**: State management with compile-time safety and built-in async handling
- **flutter_contacts / call_log / another_telephony**: Platform-specific data access packages with comprehensive APIs
- **nsd 4.1.0**: mDNS service discovery across all target platforms (Android/Windows/Mac)
- **dart:io Socket/SecureSocket**: Native TCP/TLS for custom protocol, no external dependencies
- **excel 4.0.6**: Pure Dart Excel generation, cross-platform, no licensing required

**Critical version requirements:**
- Flutter 3.27+ required for stable desktop support
- Dart 3.6+ required for pub workspaces (eliminates pubspec_overrides)
- another_telephony 0.4.1 (April 2025) is the maintained fork of deprecated telephony package

**Distribution constraint:** READ_SMS, READ_CALL_LOG, and READ_CONTACTS permissions disqualify apps from Google Play Store unless they are default handlers. This project MUST target APK sideloading, F-Droid, or enterprise distribution from day one.

### Expected Features

Research across similar tools (SMS Import/Export, Dr.Fone, Contact To Excel) reveals clear feature tiers.

**Must have (table stakes):**
- Extract contacts with phone numbers - users expect this as core functionality
- Extract SMS sender/recipient numbers - primary value proposition for promotional leads
- Extract call log numbers - completes the phone number universe
- Export to Excel-compatible format - user specified Excel; CSV/XLSX are standard
- Local network transfer (no cloud) - security requirement
- No root required - modern Android restricts root access
- One-click export workflow - "on-demand, direct export" per requirements

**Should have (competitive):**
- Phone number deduplication - same number appears across sources, export unique list
- Phone number normalization - consistent E.164 or local format
- Source tagging - know where each number came from (contact/SMS/call)
- Merge with contact names - export "Name, Phone" not just numbers
- Date range filtering - only numbers from last N days
- Wireless auto-discovery - mDNS eliminates manual IP entry

**Defer (v2+):**
- Incremental export (new numbers only) - full export is fast enough initially
- Scheduled/automatic export - on-demand sufficient for internal use
- Native XLSX with styling - CSV works in Excel, native XLSX is polish
- Multiple export formats - start with CSV, add XLSX later
- Browse/filter UI on phone - user explicitly requested "no browse/filter UI"

**Anti-features (explicitly avoid):**
- Cloud sync - security requirement mandates local network only
- Message content export - privacy concern, only need phone numbers
- Backup/restore - different product category
- Edit/delete capabilities - read-only extraction minimizes risk

### Architecture Approach

The architecture enables a Flutter monorepo with platform-specific apps sharing common code through packages. The Android device acts as both data source and HTTP server, while the desktop app acts as HTTP client and Excel exporter.

**Major components:**
1. **android_provider app** — Accesses phone data (SMS/calls/contacts), runs HTTP server, advertises via mDNS
2. **desktop_consumer app** — Discovers devices via mDNS, fetches data over HTTP, exports to Excel
3. **core package** — Shared data models (Contact, CallLog, SMS), constants, utilities
4. **network_protocol package** — API contract (routes, request/response models, PIN auth)

**Data flow:**
1. Android advertises `_phonesync._tcp` service via mDNS on startup
2. Desktop discovers service automatically, displays discovered devices
3. User initiates pairing - Android generates 6-digit PIN, desktop prompts for entry
4. Desktop sends POST /pair with PIN, Android validates and returns session token
5. Desktop calls GET /sms, GET /calls, GET /contacts with session token
6. Desktop processes responses, writes to .xlsx using excel package

**Key patterns:**
- **Monorepo with Melos + Pub Workspaces** - eliminates pubspec_overrides, standard approach for multi-package Flutter projects
- **Android as HTTP Server (dart:io)** - embedded server pattern for mobile device providing data to other devices
- **mDNS Service Discovery (nsd package)** - zero-config networking, cross-platform support
- **PIN-based pairing** - simple authentication without certificate management
- **Paginated content provider queries** - LIMIT/OFFSET to avoid O(n²) cursor behavior with large datasets

### Critical Pitfalls

Research identified 14 pitfalls across criticality levels. The top 5 that could cause rewrites or major issues:

1. **Google Play Store SMS/Call Log Rejection** — Apps requesting READ_SMS or READ_CALL_LOG without being default handlers are rejected. Prevention: Plan for APK sideloading distribution from Phase 1, not after development completes.

2. **Cursor Memory Exhaustion** — Querying SMS/call logs with 50,000+ entries causes OutOfMemory errors due to O(n²) CursorWindow paging. Prevention: Implement LIMIT/OFFSET pagination from day one in Phase 2, always close cursors, stream processing.

3. **Incremental Sync Missing Deleted Records** — Timestamp-based sync ("modified since X") doesn't capture deletions, causing "ghost" records. Prevention: Design tombstone awareness or ID reconciliation into sync protocol in Phase 3.

4. **Platform Channel Type Mismatch** — Dart/Kotlin type mismatches only surface at runtime, causing crashes. Prevention: Document contracts, use only StandardMessageCodec types, integration test actual calls not mocks.

5. **mDNS Discovery Platform Differences** — Works in simulator but fails on real devices due to platform-specific requirements (iOS Info.plist, macOS entitlements, Android service name format). Prevention: Configure all platforms early in Phase 4, test on real hardware.

**Additional moderate pitfalls:**
- macOS networking entitlements not configured (blocks socket connections)
- Excel generation with 50,000+ rows causes OOM (need async save and dispose)
- Android permission dialogs not showing on certain versions (need retry logic)
- Phone + call log permission coupling on Android 9+ (users confused by grouped requests)

## Implications for Roadmap

Based on research, suggested phase structure follows technical dependencies and risk mitigation:

### Phase 1: Foundation & Monorepo Setup
**Rationale:** Must establish build infrastructure before any feature development. Critical distribution decision (APK vs Play Store) must be made now to avoid later rework.

**Delivers:**
- Flutter 3.27+ with Dart 3.6+ workspace
- Melos 7.4.0 configured with proper scripts
- Package structure (core, network_protocol)
- Distribution strategy documented (APK sideloading)

**Addresses:**
- Play Store rejection risk (Pitfall 1) by deciding distribution upfront
- Monorepo confusion (Pitfall 10) by establishing patterns early

**Avoids:**
- Discovering Play Store incompatibility after development
- Workspace configuration issues causing dependency conflicts

### Phase 2: Android Data Access Layer
**Rationale:** Data extraction is the core value. Must implement pagination from start to avoid memory issues. Android app can be tested independently before network layer exists.

**Delivers:**
- Permission handling (READ_SMS, READ_CALL_LOG, READ_CONTACTS)
- Contacts extraction via flutter_contacts (paginated)
- SMS extraction via another_telephony (paginated)
- Call log extraction via call_log (paginated)
- Data models in core package (freezed + json_serializable)

**Uses:**
- flutter_contacts 1.1.9+2, call_log 6.0.1, another_telephony 0.4.1
- permission_handler 12.0.1
- freezed 3.2.4, json_serializable 6.12.0

**Addresses:**
- Cursor memory exhaustion (Pitfall 3) via LIMIT/OFFSET from day one
- Permission dialog issues (Pitfall 8, 9) via testing on multiple Android versions
- Platform channel crashes (Pitfall 4) via documented contracts

**Avoids:**
- Retrofitting pagination after discovering OOM errors
- Permission handling bugs discovered in production

### Phase 3: Local Network Protocol
**Rationale:** Network layer depends on data models from Phase 2. Sync protocol design must account for deleted records from the start.

**Delivers:**
- mDNS service discovery (nsd package)
- HTTP server on Android (dart:io)
- PIN pairing authentication
- REST endpoints (/pair, /sms, /calls, /contacts)
- Session token management
- Sync protocol with tombstone awareness

**Uses:**
- nsd 4.1.0 for service registration (Android) and discovery (Desktop)
- dart:io HttpServer for embedded server
- dart:io SecureSocket for TLS (if adding encryption)

**Implements:**
- network_protocol package (API routes, request/response models)
- Tombstone tracking or ID reconciliation for deletions

**Addresses:**
- Missing deleted records (Pitfall 2) via tombstone/reconciliation design
- Interrupted sync state (Pitfall 12) via checkpoints and atomic commits
- mDNS platform differences (Pitfall 5) via proper configuration for each platform

**Avoids:**
- Discovering deleted records issue after launch
- Hardcoding IP addresses (poor UX)

### Phase 4: Desktop Client & Discovery
**Rationale:** Depends on working HTTP server from Phase 3. Platform-specific entitlements must be configured for macOS networking to work.

**Delivers:**
- Desktop app (Windows/Mac) with Riverpod state management
- mDNS discovery UI
- Pairing flow (PIN entry)
- Data sync service (HTTP client)
- Platform entitlements (macOS networking, Windows firewall handling)

**Uses:**
- nsd 4.1.0 for service discovery
- http or dio package for REST client
- Riverpod 3.2.0 for state management

**Addresses:**
- Desktop networking entitlements (Pitfall 6) for macOS
- mDNS real device testing (Pitfall 5)
- Unencrypted transfer (Pitfall 11) if adding TLS

**Avoids:**
- "Operation not permitted" errors on macOS
- Discovery working in emulator but failing on real devices

### Phase 5: Excel Export
**Rationale:** Export is the final output, depends on synced data from Phase 4. Memory management must be designed in from start.

**Delivers:**
- Excel generation (excel package)
- Multi-sheet workbook (SMS, Calls, Contacts)
- File save dialogs (file_picker)
- Async save with proper disposal
- Large dataset handling (50,000+ row testing)

**Uses:**
- excel 4.0.6 for .xlsx generation
- path_provider 2.1.5 for platform directories
- file_picker 10.3.10 for save dialogs

**Addresses:**
- Excel memory exhaustion (Pitfall 7) via async save and dispose
- Large dataset testing (test with realistic volumes)

**Avoids:**
- OOM crashes during export on real datasets
- Memory leaks from not disposing workbooks

### Phase 6: Polish & Packaging
**Rationale:** User-facing improvements after core functionality works end-to-end.

**Delivers:**
- Phone number deduplication and normalization
- Source tagging (contact/SMS/call)
- Contact name merging
- Date range filtering
- Windows MSIX packaging (msix package)
- macOS code signing
- APK signing and distribution documentation

**Uses:**
- msix 3.16.13 for Windows installer
- Native Flutter build tools for macOS

### Phase Ordering Rationale

- **Foundation before features:** Can't build apps without monorepo infrastructure
- **Data access before network:** Android data extraction can be tested independently, provides real data for protocol design
- **Protocol before clients:** HTTP server must exist before client can consume it
- **Sync before export:** Can't export what hasn't been synced
- **Core features before polish:** Deduplication and normalization add value but aren't blocking

This order minimizes rework by:
- Making critical decisions (distribution strategy) upfront
- Implementing patterns (pagination, tombstones) from the start rather than retrofitting
- Enabling independent testing of each layer before integration
- Addressing platform-specific issues (entitlements, permissions) when building that layer

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 3 (Network Protocol):** Custom sync protocol with tombstone tracking is non-standard, may need examples from CouchDB/Firebase
- **Phase 5 (Excel Export):** Performance optimization for very large exports (100,000+ rows) may need profiling

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Foundation):** Melos setup is well-documented, standard monorepo pattern
- **Phase 2 (Data Access):** Android ContentProvider queries are standard, packages have good docs
- **Phase 4 (Desktop Client):** HTTP client + mDNS discovery are standard patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All packages verified on pub.dev with recent updates, version compatibility confirmed |
| Features | MEDIUM-HIGH | Table stakes verified across multiple tools, differentiators synthesized from comparisons |
| Architecture | HIGH | Patterns verified via official docs (dart:io, nsd), similar implementations found in community |
| Pitfalls | HIGH | Critical pitfalls backed by official docs (Play Store policy, Android CursorWindow), moderate pitfalls verified via GitHub issues |

**Overall confidence:** HIGH

The technical path is clear with established packages and patterns. The primary uncertainty is in estimating effort for sync protocol complexity, but the architecture decisions are sound.

### Gaps to Address

Areas where research was inconclusive or needs validation during implementation:

- **Sync protocol complexity:** Tombstone tracking vs full ID reconciliation tradeoff needs prototyping in Phase 3
- **Excel performance at scale:** Research shows issues at 50,000+ rows, but exact threshold for this use case needs testing
- **TLS certificate management:** If adding encryption, self-signed certificate trust flow needs UX design (not covered in research)
- **Android foreground service necessity:** Whether long syncs require foreground service depends on dataset size (test in Phase 3)

## Sources

### Primary (HIGH confidence)
- [Melos 7.4.0](https://pub.dev/packages/melos) — Monorepo management verified
- [nsd 4.1.0](https://pub.dev/packages/nsd) — mDNS cross-platform support verified
- [flutter_contacts 1.1.9+2](https://pub.dev/packages/flutter_contacts) — Contacts API verified
- [call_log 6.0.1](https://pub.dev/packages/call_log) — Call log API verified
- [another_telephony 0.4.1](https://pub.dev/packages/another_telephony) — SMS API verified
- [excel 4.0.6](https://pub.dev/packages/excel) — Excel generation verified
- [Google Play Console: SMS/Call Log Policy](https://support.google.com/googleplay/android-developer/answer/10208820) — Permission restrictions
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels) — Type safety guidance
- [Android Large Database Queries](https://medium.com/androiddevelopers/large-database-queries-on-android-cb043ae626e8) — Cursor pagination

### Secondary (MEDIUM confidence)
- [Flutter Monorepo 2025/2026](https://medium.com/@sijalneupane5/flutter-monorepo-from-scratch-2025-going-into-2026-pub-workspaces-melos-explained-properly-fae98bfc8a6e) — Pub workspaces + Melos patterns
- [Couchbase Tombstones](https://docs.couchbase.com/sync-gateway/current/manage/managing-tombstones.html) — Deletion tracking patterns
- [Salesforce Mobile SDK Incremental Sync](https://developer.salesforce.com/docs/platform/mobile-sdk/guide/entity-framework-native-inc-sync.html) — Sync architecture patterns
- GitHub issues: flutter-permission-handler #115, #770; Flutter #166843, #177307; Syncfusion #448

---
*Research completed: 2026-02-03*
*Ready for roadmap: yes*
