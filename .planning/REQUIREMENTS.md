# Requirements: jljm-phonesync

**Defined:** 2026-02-03
**Core Value:** Phone numbers from Android device synced to desktop and exported to Excel on demand, securely over local network

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Data Extraction

- [ ] **DATA-01**: Android app extracts phone numbers from contacts
- [ ] **DATA-02**: Android app extracts phone numbers from SMS messages (sender/recipient)
- [ ] **DATA-03**: Android app extracts phone numbers from call history
- [ ] **DATA-04**: Android app supports incremental sync (only records newer than last sync timestamp)

### Transfer & Pairing

- [ ] **XFER-01**: Desktop app discovers Android devices on local network via mDNS
- [ ] **XFER-02**: Android app displays PIN code; desktop pairs by entering PIN
- [ ] **XFER-03**: Data transfer uses TLS encryption over local network
- [ ] **XFER-04**: Android app serves data via HTTP server when paired

### Export

- [ ] **EXPO-01**: Desktop app exports synced data to Excel (.xlsx) file
- [ ] **EXPO-02**: Phone numbers normalized to consistent format
- [ ] **EXPO-03**: Deduplication removes duplicate phone numbers across sources
- [ ] **EXPO-04**: Export handles large datasets (50,000+ rows) without memory issues
- [ ] **EXPO-05**: Export can filter to phone numbers starting with "010" (Korean mobile)

### Platform

- [ ] **PLAT-01**: Android app works as data provider
- [ ] **PLAT-02**: Windows desktop app works as data consumer
- [ ] **PLAT-03**: Mac desktop app works as data consumer

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Session Management

- **SESS-01**: Desktop remembers previously paired devices
- **SESS-02**: Quick reconnect to known devices without re-pairing

### Export Options

- **EXPO-06**: CSV export option in addition to Excel
- **EXPO-07**: Custom filter patterns beyond "010" prefix

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud sync | Local network only — internal security requirement |
| Multiple phones to one desktop | Single phone pairing sufficient for use case |
| Browse/filter UI on desktop | Direct export only — no need to preview data |
| Scheduled/automatic sync | On-demand only — user triggers sync manually |
| Bidirectional sync | Phone to desktop only — no write-back needed |
| SMS content/message body | Only phone numbers needed for campaigns |
| Play Store distribution | SMS/call permissions prohibited — APK sideloading only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 1 | Pending |
| DATA-02 | Phase 1 | Pending |
| DATA-03 | Phase 1 | Pending |
| DATA-04 | Phase 1 | Pending |
| XFER-01 | Phase 2 | Pending |
| XFER-02 | Phase 2 | Pending |
| XFER-03 | Phase 2 | Pending |
| XFER-04 | Phase 2 | Pending |
| EXPO-01 | Phase 3 | Pending |
| EXPO-02 | Phase 3 | Pending |
| EXPO-03 | Phase 3 | Pending |
| EXPO-04 | Phase 3 | Pending |
| EXPO-05 | Phase 3 | Pending |
| PLAT-01 | Phase 1 | Pending |
| PLAT-02 | Phase 3 | Pending |
| PLAT-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0

---
*Requirements defined: 2026-02-03*
*Last updated: 2026-02-03 after roadmap creation*
