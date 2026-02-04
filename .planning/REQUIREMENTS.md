# Requirements: jljm-phonesync

**Defined:** 2026-02-03, updated 2026-02-04
**Core Value:** Phone numbers from Android device synced to desktop and exported to Excel on demand, securely over local network

## v1.0 Requirements (MVP - Complete)

### Data Extraction

- [x] **DATA-01**: Android app extracts phone numbers from contacts
- [x] **DATA-02**: Android app extracts phone numbers from SMS messages (sender/recipient)
- [x] **DATA-03**: Android app extracts phone numbers from call history
- [x] **DATA-04**: Android app supports incremental sync (only records newer than last sync timestamp)

### Transfer & Pairing

- [x] **XFER-01**: Desktop app discovers Android devices on local network via mDNS
- [x] **XFER-02**: Android app displays PIN code; desktop pairs by entering PIN
- [x] **XFER-03**: Data transfer uses TLS encryption over local network
- [x] **XFER-04**: Android app serves data via HTTP server when paired

### Export

- [x] **EXPO-01**: Desktop app exports synced data to Excel (.xlsx) file
- [x] **EXPO-02**: Phone numbers normalized to consistent format
- [x] **EXPO-03**: Deduplication removes duplicate phone numbers across sources
- [x] **EXPO-04**: Export handles large datasets (50,000+ rows) without memory issues
- [x] **EXPO-05**: Export can filter to phone numbers starting with "010" (Korean mobile)

### Platform

- [x] **PLAT-01**: Android app works as data provider
- [x] **PLAT-02**: Windows desktop app works as data consumer
- [x] **PLAT-03**: Mac desktop app works as data consumer

## v1.1 Requirements (CI/CD & Linux)

### CI/CD Pipeline

- [ ] **CICD-01**: Release builds trigger on git tag push (v*.*.* pattern)
- [ ] **CICD-02**: Pipeline builds Android APK
- [ ] **CICD-03**: Pipeline builds macOS app
- [ ] **CICD-04**: Pipeline builds Windows app
- [ ] **CICD-05**: Pipeline builds Linux app
- [ ] **CICD-06**: All platform builds run in parallel
- [ ] **CICD-07**: Flutter SDK cached to avoid 5+ min downloads
- [ ] **CICD-08**: GitHub Release created with all platform artifacts
- [ ] **CICD-09**: SHA256 checksums generated for each artifact
- [ ] **CICD-10**: Version extracted from git tag (v1.0.0 → 1.0.0)

### Android Signing

- [ ] **SIGN-01**: Android APK signed with release keystore
- [ ] **SIGN-02**: Keystore secrets stored securely in GitHub Secrets
- [ ] **SIGN-03**: Signed APK installable on Android devices

### Platform (Addition)

- [ ] **PLAT-04**: Linux desktop app works as data consumer

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Packaging

- **PKG-01**: macOS app packaged as DMG with drag-to-Applications
- **PKG-02**: Linux app packaged as AppImage for universal compatibility
- **PKG-03**: Windows app packaged as MSIX installer

### Code Signing

- **SIGN-04**: macOS app signed and notarized (eliminates Gatekeeper warnings)
- **SIGN-05**: Windows app signed (eliminates SmartScreen warnings)

### Release Automation

- **REL-01**: Auto-generated changelog from commit messages
- **REL-02**: Pre-release detection for -rc, -beta tags
- **REL-03**: Draft releases for review before publishing

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
| iOS app | Not needed, Android-only data source |
| Store publishing | Direct distribution via GitHub Releases |
| macOS notarization | Complexity vs benefit (add if users report Gatekeeper issues) |
| Windows MSIX signing | Complexity vs benefit (add if users report SmartScreen issues) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 1 | Complete |
| DATA-02 | Phase 1 | Complete |
| DATA-03 | Phase 1 | Complete |
| DATA-04 | Phase 1 | Complete |
| XFER-01 | Phase 2 | Complete |
| XFER-02 | Phase 2 | Complete |
| XFER-03 | Phase 2 | Complete |
| XFER-04 | Phase 2 | Complete |
| EXPO-01 | Phase 3 | Complete |
| EXPO-02 | Phase 3 | Complete |
| EXPO-03 | Phase 3 | Complete |
| EXPO-04 | Phase 3 | Complete |
| EXPO-05 | Phase 3 | Complete |
| PLAT-01 | Phase 1 | Complete |
| PLAT-02 | Phase 3 | Complete |
| PLAT-03 | Phase 3 | Complete |
| CICD-01 | Phase 4 | Pending |
| CICD-02 | Phase 4 | Pending |
| CICD-03 | Phase 4 | Pending |
| CICD-04 | Phase 4 | Pending |
| CICD-05 | Phase 4 | Pending |
| CICD-06 | Phase 4 | Pending |
| CICD-07 | Phase 4 | Pending |
| CICD-08 | Phase 4 | Pending |
| CICD-09 | Phase 4 | Pending |
| CICD-10 | Phase 4 | Pending |
| SIGN-01 | Phase 4 | Pending |
| SIGN-02 | Phase 4 | Pending |
| SIGN-03 | Phase 4 | Pending |
| PLAT-04 | Phase 4 | Pending |

**Coverage:**
- v1.0 requirements: 16 total (Complete)
- v1.1 requirements: 14 total
- Mapped to phases: 30
- Unmapped: 0

---
*Requirements defined: 2026-02-03*
*Last updated: 2026-02-04 — Added v1.1 CI/CD requirements*
