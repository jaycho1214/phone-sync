# Feature Landscape

**Domain:** Phone Data Sync/Extraction Tools (Android to Desktop)
**Researched:** 2026-02-03
**Focus:** Internal business tool for extracting phone numbers to Excel for SMS campaigns

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Extract contacts with phone numbers | Core data source for any phone extraction tool | Low | Standard Android API via contacts provider |
| Extract SMS sender/recipient numbers | Primary value proposition - promotional leads from incoming SMS | Medium | Requires SMS permissions; stored in telephony provider |
| Extract call log numbers | Completes the phone number universe on device | Low | Call log provider is straightforward |
| Export to Excel-compatible format | User specified Excel; CSV/XLSX are standard | Low | CSV is trivial; XLSX needs library |
| Local network transfer (no cloud) | Security requirement - data stays on-premises | Medium | HTTP server on phone or desktop; discovery needed |
| No root required | Root is barrier for business users; modern Android restricts it | N/A | Constraint, not feature - use standard APIs |
| Permission transparency | Users need to understand what app accesses | Low | Clear permission rationale in UI |
| One-click export workflow | "On-demand, direct export" - no complex UI | Low | Single action triggers full pipeline |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Phone number deduplication | Same number appears in contacts, SMS, calls - export unique list | Low | Normalize numbers, dedupe in memory |
| Phone number normalization | Consistent format (E.164 or local) across sources | Low | Parse and reformat; country code handling |
| Source tagging | Know where each number came from (contact/SMS/call) | Low | Add column indicating origin |
| Merge with contact names | Export "Name, Phone" not just phone numbers | Low | Cross-reference contact provider |
| Incremental export (new numbers only) | Avoid re-exporting same numbers | Medium | Track previously exported; timestamp-based |
| Scheduled/automatic export | Run overnight, have fresh numbers in morning | Medium | Android WorkManager; battery considerations |
| Multiple export formats | CSV, XLSX, JSON, vCard | Low-Med | Each format is simple; more = more testing |
| Configurable columns | Choose what fields to include | Low | UI overhead more than implementation |
| Date range filtering | Only numbers from last N days | Low | Query filter on timestamps |
| Wireless auto-discovery | Phone and desktop find each other on LAN | Medium | mDNS/Bonjour or simple broadcast |

## Anti-Features

Features to explicitly NOT build for this internal business tool.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Browse/filter UI on phone | User specified "no browse/filter UI"; adds complexity | Direct export to predefined format |
| Cloud sync | Security requirement - local network only | HTTP server on local network only |
| Message content export | Privacy concern; only need phone numbers | Export numbers only, not message bodies |
| Backup/restore functionality | Different product category; adds complexity | Single direction: phone to desktop |
| Multi-device support | "One phone to one desktop" specified | Simple pairing, not fleet management |
| Photo/media extraction | Out of scope - phone numbers only | Focus on contact/SMS/call data |
| Edit/delete capabilities | Read-only extraction; modification is risk | Export only, never modify phone data |
| Historical sync / full backup | On-demand export, not continuous sync | Each export is independent snapshot |
| Complex scheduling UI | Internal tool - config file is fine | Simple cron-like schedule if needed |
| User authentication | Internal network, internal use | Rely on network isolation for security |

## Feature Dependencies

```
Core Pipeline (must build in order):
  Android Permissions → Data Access → Extraction → Export Format → Transfer

Data Sources (independent, can build in any order):
  Contacts Provider ──┐
  SMS Provider ───────┼──→ Phone Number Extraction → Deduplication → Export
  Call Log Provider ──┘

Export Formats (independent):
  CSV Export ─────┐
  XLSX Export ────┼──→ File Ready for Transfer
  JSON Export ────┘

Transfer (requires export complete):
  Export File → HTTP Server → Desktop Client Download
```

## MVP Recommendation

For MVP, prioritize:

1. **Extract phone numbers from contacts** - Most reliable data source, simplest API
2. **Extract phone numbers from SMS (sender/recipient)** - Primary business value
3. **Extract phone numbers from call log** - Completes the picture
4. **Deduplicate and normalize** - Essential for usable output
5. **Export to CSV** - Excel opens CSV natively; simplest format
6. **HTTP transfer over local network** - Phone serves file, desktop downloads

**MVP is complete when:** User can tap one button on phone, then download CSV of all unique phone numbers on desktop.

Defer to post-MVP:
- **XLSX native export**: CSV works in Excel; native XLSX is polish
- **Scheduled exports**: On-demand is sufficient for internal use
- **Incremental exports**: Full export is fast enough for single device
- **Contact name merge**: Nice-to-have; numbers alone serve the use case
- **Auto-discovery**: Manual IP entry works for one phone to one desktop

## Complexity Assessment

| Feature Area | Complexity | Rationale |
|--------------|------------|-----------|
| Data extraction | Low | Standard Android ContentProvider APIs |
| Permissions | Low | Runtime permissions are well-documented |
| Deduplication | Low | In-memory set operations |
| CSV export | Low | String formatting |
| XLSX export | Medium | Requires library (Apache POI or similar) |
| HTTP server on Android | Medium | Need lightweight server (NanoHTTPD or Ktor) |
| Desktop client | Low | Simple HTTP download; could be curl/browser |
| mDNS discovery | Medium | Platform-specific; may need library |
| Scheduled export | Medium | WorkManager + battery optimization handling |

## Compliance Considerations

For promotional SMS campaigns, be aware:

| Consideration | Impact | Mitigation |
|---------------|--------|------------|
| TCPA consent | Numbers exported need prior consent for marketing | This tool extracts; consent tracking is separate |
| Data retention | Don't store numbers longer than needed | Tool exports; doesn't persist on desktop |
| DNC registry | Numbers must be scrubbed against Do Not Call list | Post-export step; separate tool/service |
| GDPR (if EU) | Data subject rights apply | Internal tool; document data handling |

**Note:** This extraction tool provides raw data. Compliance with SMS marketing regulations (TCPA, state laws, GDPR) is the responsibility of the marketing process, not this tool. Consider documenting that exported data must be scrubbed against DNC lists before use.

## Sources

Research based on:
- [SMS Import/Export (GitHub)](https://github.com/tmo1/sms-ie) - Open source Android app for SMS/contacts/call log export
- [SMS-MMS-deduplication (GitHub)](https://github.com/ragibson/SMS-MMS-deduplication) - Deduplication approaches for phone data
- [Dr.Fone Data Extraction](https://drfone.wondershare.com/android-data-recovery.html) - Commercial tool feature reference
- [Android Backup Extractor (GitHub)](https://github.com/nelenkov/android-backup-extractor) - ADB backup extraction reference
- [OSForensics Android Extraction](https://www.osforensics.com/faqs-and-tutorials/how-to-obtain-data-from-android-device.html) - Forensic extraction methods
- [TCPA Compliance Guide](https://www.textedly.com/sms-compliance-guide/tcpa-compliance-checklist) - SMS marketing regulations
- [Contact To Excel (Google Play)](https://play.google.com/store/apps/details?id=in.ajaykhatri.exportcontactstoexcel&hl=en_US) - Consumer app feature reference
- [MiniWebTool Phone Extractor](https://miniwebtool.com/phone-number-extractor/) - Phone number normalization/deduplication reference

**Confidence Level:** MEDIUM-HIGH
- Table stakes features verified across multiple tools (HIGH)
- Differentiators synthesized from tool comparisons (MEDIUM)
- Anti-features derived from project requirements (HIGH)
- Complexity estimates based on Android development experience (MEDIUM)
