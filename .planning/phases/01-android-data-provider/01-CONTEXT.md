# Phase 1: Android Data Provider - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Android app extracts phone numbers from contacts, SMS messages, and call history. Supports incremental sync (only records newer than last sync). Must handle large datasets (50,000+ entries) with pagination to avoid memory issues.

Network communication and desktop client are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Permission Flow
- Request all 3 permissions (contacts, SMS, call log) at once
- Partial data OK — work with whatever permissions are granted, skip denied sources
- No explanation screen before requesting — directly show system permission dialogs
- If permanently denied ("Don't ask again") — guide user to app settings to enable manually

### Data Preview (Android UI)
- Headless approach — no list of extracted data on phone
- Show counts: "Contacts: X | SMS: Y | Calls: Z"
- Show sync progress when desktop is pulling data
- Main screen design is Claude's discretion

### Sync Tracking
- First sync: export ALL data (full history of contacts, SMS, calls)
- Ignore deletions — desktop keeps all synced data even if phone deletes records
- Incremental sync mechanism (timestamp vs ID) is Claude's discretion
- Who tracks sync state (Android vs desktop) is Claude's discretion

### Error Handling
- Permission revoked mid-sync: STOP entire sync, notify desktop
- Partial read failure: retry once, then fail
- Show errors on Android UI
- App killed mid-sync: start fresh on reconnect (no resume)

### Claude's Discretion
- Main screen layout design
- Sync mechanism implementation (timestamp-based vs ID-based)
- Sync state storage location (Android vs desktop)
- Progress indicator style
- Retry logic details

</decisions>

<specifics>
## Specific Ideas

- Internal tool, so UX can be utilitarian — focus on reliability over polish
- Large datasets are expected (lots of call history and messages) — pagination is critical
- APK sideloading required (Play Store rejects SMS/call log permissions)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-android-data-provider*
*Context gathered: 2026-02-03*
