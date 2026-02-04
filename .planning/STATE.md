# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-04)

**Core value:** Phone numbers from Android device exported to Excel on demand, securely over local network
**Current focus:** Milestone v1.1 — CI/CD & Linux

## Current Position

Phase: 4 - Release Pipeline
Plan: 1/2 complete
Status: In progress
Last activity: 2026-02-04 — Completed 04-01-PLAN.md

Progress: [####################] 100% (v1.0) | [##########----------] 50% (v1.1)

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: 6 min
- Total execution time: 0.75 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 2/2 | 18 min | 9 min |
| 2 | 2/2 | 8 min | 4 min |
| 3 | 2/2 | 14 min | 7 min |
| 4 | 1/2 | 3 min | 3 min |

**Recent Trend:**
- Last 5 plans: 5 min, 7 min, 7 min, 3 min
- Trend: Stable/Fast

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

**v1.0 MVP (complete):**
- flutter_riverpod 2.6.1 (not 3.x) for riverpod_generator compatibility
- compileSdk 36 required by plugin dependencies
- Core library desugaring enabled for call_log package
- Permission.phone covers call log on Android 9+
- 500 record batch size for data extraction pagination
- Timestamp-based incremental sync stored in SharedPreferences
- Dynamic port with port 0 for HTTP server (avoids conflicts)
- _phonesync._tcp service type for mDNS discovery
- shelf + shelf_router for HTTP server (lightweight, suitable for mobile)
- basic_utils + pointycastle for pure Dart TLS certificate generation
- SharedPreferences for TLS cert persistence with 365-day validity
- 6-digit PIN with 5-minute expiry for pairing security
- 32-char hex session token for post-pairing authentication
- nsd with IpLookupType.any for desktop mDNS discovery
- Dio badCertificateCallback for self-signed cert trust
- flutter_secure_storage for session token persistence (shared_preferences on macOS)
- Drift with sqlite3_flutter_libs for cross-platform SQLite
- Phone number as primary key for automatic deduplication
- Isolate.run for Excel export (no UI freeze on 50k+ rows)
- Korean numbers digits-only, international E.164 format

**v1.1 CI/CD (in progress):**
- GitHub Actions CI/CD for automated multi-platform builds on tag push
- Tag-based versioning (v1.0.0 -> 1.0.0)
- Single workflow file with parallel platform jobs
- Android APK signing with keystore in GitHub Secrets
- Conditional signing: release signingConfig if key.properties exists, else debug
- Linux binary name: desktop_client

### Pending Todos

None - Phase 4 Plan 1 complete.

### Blockers/Concerns

- APK sideloading required (Play Store rejects SMS/call log permissions) - plan distribution from Phase 1
- macOS certificate validation issues on macos-15 runners (pin to macos-14)

## Session Continuity

Last session: 2026-02-04
Stopped at: Completed 04-01-PLAN.md
Resume file: None
Next action: Execute 04-02-PLAN.md (GitHub Actions workflow)

## Previous Milestone (v1.0 MVP)

**Delivered:**
- Phase 1: Android data extraction (contacts, SMS, call logs) with HTTP server
- Phase 2: TLS/HTTPS security with PIN pairing and session tokens
- Phase 3: Desktop client with sync, local storage, and Excel export

**Key Features:**
- mDNS discovery of Android device on local network
- Secure pairing via 6-digit PIN
- Phone number normalization and deduplication
- Korean mobile filter (010 prefix) for export
- Excel export runs in isolate for large datasets
- Session persistence survives app restart
