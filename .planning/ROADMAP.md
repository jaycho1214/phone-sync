# Roadmap: jljm-phonesync

## Overview

This roadmap delivers a Flutter monorepo that extracts phone numbers from an Android device (SMS, calls, contacts) and exports them to Excel on a Windows or Mac desktop. Phases 1-3 (v1.0 MVP) built the core functionality: Android data extraction, network protocol with TLS/PIN security, and desktop client with Excel export. Phase 4 (v1.1) adds CI/CD automation and Linux support for automated multi-platform releases via GitHub Actions.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

**Milestone v1.0 (MVP) - Complete:**
- [x] **Phase 1: Android Data Provider** - Extract phone numbers from contacts, SMS, and call logs on Android
- [x] **Phase 2: Network Protocol** - Connect Android and desktop over local network with PIN pairing
- [x] **Phase 3: Desktop Client & Export** - Fetch data on Windows/Mac and export to Excel

**Milestone v1.1 (CI/CD & Linux):**
- [ ] **Phase 4: Release Pipeline** - Automated multi-platform builds with GitHub Actions, Android signing, Linux support

## Phase Details

### Phase 1: Android Data Provider
**Goal**: Android app can extract phone numbers from all three sources (contacts, SMS, call history) with incremental sync support
**Depends on**: Nothing (first phase)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, PLAT-01
**Success Criteria** (what must be TRUE):
  1. User can grant permissions and app reads contacts with phone numbers
  2. User can grant permissions and app reads SMS sender/recipient numbers
  3. User can grant permissions and app reads call log numbers
  4. App tracks "last sync" timestamp and can query only newer records
  5. Large datasets (50,000+ entries) load without memory errors
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md - Foundation & monorepo setup (Melos workspace, android_provider app, Android permissions)
- [x] 01-02-PLAN.md - Data extraction services (permissions, contacts, SMS, calls with pagination, UI)

### Phase 2: Network Protocol
**Goal**: Android app serves data via HTTP/TLS and advertises via mDNS for discovery (Android server-side only; desktop client in Phase 3)
**Depends on**: Phase 1
**Requirements**: XFER-01 (Android side), XFER-02 (Android side), XFER-03, XFER-04
**Success Criteria** (what must be TRUE):
  1. Android advertises via mDNS (_phonesync._tcp) for desktop discovery (desktop discovery client in Phase 3)
  2. Android displays 6-digit PIN on screen for pairing
  3. Data transfer uses TLS encryption (HTTPS with self-signed certificate)
  4. Android serves /sms, /calls, /contacts endpoints that return JSON data
  5. POST /pair with valid PIN returns session token; data endpoints require valid token
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md - HTTP server with shelf serving /contacts, /sms, /calls endpoints; mDNS advertisement
- [x] 02-02-PLAN.md - TLS encryption, PIN pairing with session tokens, pairing UI on home screen

### Phase 3: Desktop Client & Export
**Goal**: Desktop app (Windows and Mac) fetches data from Android and exports to Excel
**Depends on**: Phase 2
**Requirements**: PLAT-02, PLAT-03, EXPO-01, EXPO-02, EXPO-03, EXPO-04, EXPO-05
**Success Criteria** (what must be TRUE):
  1. Windows app can discover, pair with, and sync from Android device
  2. Mac app can discover, pair with, and sync from Android device
  3. User can export synced data to .xlsx file with phone number, name, source, and timestamp
  4. Phone numbers are normalized to consistent format in export
  5. Duplicate phone numbers across sources are deduplicated in export
  6. Export can filter to Korean mobile numbers (010 prefix)
  7. Export handles 50,000+ rows without memory issues
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md - Desktop app setup, mDNS discovery, PIN pairing flow with session persistence
- [x] 03-02-PLAN.md - Drift database, data sync with progress, phone normalization/dedup, Excel export

### Phase 4: Release Pipeline
**Goal**: Automated multi-platform releases via GitHub Actions with signed Android APK, Linux support, and artifact distribution
**Depends on**: Phase 3 (working apps to build)
**Requirements**: CICD-01, CICD-02, CICD-03, CICD-04, CICD-05, CICD-06, CICD-07, CICD-08, CICD-09, CICD-10, SIGN-01, SIGN-02, SIGN-03, PLAT-04
**Success Criteria** (what must be TRUE):
  1. Pushing a v*.*.* tag triggers automated builds for all 4 platforms (Android, macOS, Windows, Linux)
  2. All platform builds run in parallel and complete within 30 minutes
  3. GitHub Release is created with downloadable APK, macOS .app, Windows .exe, and Linux bundle
  4. Android APK is signed with release keystore and installable on devices
  5. Each artifact has SHA256 checksum for verification
**Plans**: TBD

Plans:
- [ ] 04-01-PLAN.md - TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Android Data Provider | 2/2 | Complete | 2026-02-03 |
| 2. Network Protocol | 2/2 | Complete | 2026-02-03 |
| 3. Desktop Client & Export | 2/2 | Complete | 2026-02-04 |
| 4. Release Pipeline | 0/? | Pending | - |

---
*Roadmap created: 2026-02-03*
*Last updated: 2026-02-04 - Added Phase 4 (v1.1 CI/CD & Linux)*
