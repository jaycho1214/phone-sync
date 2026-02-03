# Roadmap: jljm-phonesync

## Overview

This roadmap delivers a Flutter monorepo that extracts phone numbers from an Android device (SMS, calls, contacts) and exports them to Excel on a Windows or Mac desktop. Three phases build vertically: Phase 1 creates the Android data provider with extraction capabilities, Phase 2 adds network communication between devices, and Phase 3 delivers the desktop client with Excel export. Each phase produces a testable, coherent capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Android Data Provider** - Extract phone numbers from contacts, SMS, and call logs on Android
- [x] **Phase 2: Network Protocol** - Connect Android and desktop over local network with PIN pairing
- [ ] **Phase 3: Desktop Client & Export** - Fetch data on Windows/Mac and export to Excel

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
**Plans**: TBD (2-3 plans expected)

Plans:
- [ ] 03-01: Desktop app discovery and pairing flow
- [ ] 03-02: Data sync and Excel export with normalization/dedup

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Android Data Provider | 2/2 | Complete | 2026-02-03 |
| 2. Network Protocol | 2/2 | Complete | 2026-02-03 |
| 3. Desktop Client & Export | 0/2 | Not started | - |

---
*Roadmap created: 2026-02-03*
*Last updated: 2026-02-03 - Phase 2 complete*
