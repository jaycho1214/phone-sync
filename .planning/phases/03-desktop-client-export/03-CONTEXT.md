# Phase 3: Desktop Client & Export - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Desktop application (Windows and Mac) that discovers Android device on local network, pairs via PIN, fetches phone data, stores it locally, and exports to Excel. The app persists synced data so exports can happen anytime without re-syncing.

</domain>

<decisions>
## Implementation Decisions

### Discovery & Pairing
- Auto-discovery via mDNS first, with manual IP entry fallback if nothing found
- When multiple devices found, show list and let user pick (no auto-connect)
- PIN entry: 6 separate input boxes with auto-advance to next box
- Remember session token after successful pairing — auto-connect on next launch if device found
- Session persists until token expires or user manually unpairs

### Export File Structure
- Single sheet with all phone numbers (source indicated in column)
- Data only in sheet — no summary rows
- Filename format: `{DeviceName}_{YYYY-MM-DD}_{HHMMSS}.xlsx`
- Include device name and timestamp in filename for organization

### Deduplication Strategy
- Keep one row per phone number, merge info from all sources
- Name from contacts (if exists), timestamps combined from all sources
- Normalization: strip to digits only for Korean numbers
- International numbers (non-Korean): use E.164 format
- Korean mobile filter (010 prefix) ON by default, user can disable
- Numbers without names: include with blank name column

### Desktop App Interface
- Persistent app that stores synced data locally
- Can export at any time from stored data (no need to re-sync)
- Modern/minimal visual style (Linear/Notion aesthetic)
- Progress bar with count during sync: "Syncing contacts... 15,000 / 50,000"
- File save dialog on each export — user picks location every time

### Claude's Discretion
- Exact column selection for export (balance usefulness with simplicity)
- Local data storage format (SQLite, JSON, etc.)
- Specific UI component choices within modern/minimal style
- Error handling and retry behavior
- How to handle sync conflicts if data changes between syncs

</decisions>

<specifics>
## Specific Ideas

- PIN boxes should auto-advance when digit entered (fast typing experience)
- "Synced at some point" means the app remembers what was synced and can export from local cache
- Modern/minimal means clean cards, subtle shadows — not cluttered

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-desktop-client-export*
*Context gathered: 2026-02-03*
