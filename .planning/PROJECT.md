# jljm-phonesync

## What This Is

A Flutter-based internal tool for syncing phone numbers from an Android device. The monorepo contains Android, Windows, Mac, and Linux apps that communicate over local network. Android serves SMS, call history, and contacts; desktop apps perform incremental sync (only new records) and export to Excel for use in promotional SMS campaigns.

## Current Milestone: v1.1 CI/CD & Linux

**Goal:** Automated release builds via GitHub Actions for all platforms (Android APK, macOS, Windows, Linux)

**Target features:**
- GitHub Actions workflow triggered by version tags
- Automated builds for Android (APK), macOS, Windows, Linux
- GitHub Release creation with all artifacts uploaded
- Version derived from git tag

## Core Value

Phone numbers from the Android device can be exported to Excel on demand, securely over local network.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Android app reads SMS messages and extracts phone numbers
- [ ] Android app reads call history and extracts phone numbers
- [ ] Android app reads contacts and extracts phone numbers
- [ ] Android app displays pairing PIN code
- [ ] Android app serves data over local network when paired
- [ ] Android app supports incremental sync (only new records since last sync)
- [ ] Desktop app discovers Android devices on local network
- [ ] Desktop app pairs with Android via PIN code entry
- [ ] Desktop app fetches SMS, call, and contact data from paired Android
- [ ] Desktop app tracks sync state per paired device
- [ ] Desktop app fetches only new records on subsequent syncs
- [ ] Desktop app exports data to Excel file
- [ ] Excel export includes: phone number, contact name, source type, date/timestamp
- [ ] All entries preserved (no deduplication across sources)
- [ ] Windows build works
- [ ] Mac build works
- [ ] Linux build works
- [ ] GitHub Actions builds all platforms on version tag
- [ ] GitHub Release created with APK, macOS, Windows, Linux artifacts

### Out of Scope

- Cloud sync — local network only, internal security requirement
- Multiple phones to one desktop — single phone pairing sufficient
- Browse/filter UI on desktop — direct export only
- Scheduled/automatic sync — on-demand only (user triggers sync)
- Bidirectional sync — phone to desktop only
- SMS content/message body — only phone numbers needed

## Context

- Internal business tool, not consumer-facing
- End goal: collect phone numbers for promotional SMS campaigns
- Monorepo structure: single codebase for Android + Windows + Mac
- Flutter chosen for cross-platform development
- Local network requirement for data privacy/security

## Constraints

- **Platform**: Flutter (Dart) for all platforms
- **Network**: Local network only, no internet/cloud dependencies
- **Security**: PIN-based pairing between devices
- **Android permissions**: SMS, call logs, contacts access required
- **Export format**: Excel (.xlsx)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter monorepo | Single codebase for Android + Windows + Mac | — Pending |
| Local network discovery | Privacy, no third-party cloud services | — Pending |
| PIN pairing | Security without complex auth infrastructure | — Pending |
| Keep all entries (no dedup) | Preserve source information for each phone number | — Pending |
| Direct export (no browse UI) | Simplicity, user just needs Excel output | — Pending |
| Incremental sync | Large datasets; only fetch new records since last sync | — Pending |
| GitHub Actions CI/CD | Automated multi-platform builds on tag push | — Pending |
| Tag-based versioning | Version from git tag (v1.0.0 → 1.0.0), explicit control | — Pending |

---
*Last updated: 2026-02-04 after milestone v1.1 start*
