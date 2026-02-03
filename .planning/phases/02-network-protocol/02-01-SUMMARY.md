# Phase 02 Plan 01: HTTP Server and mDNS Discovery Summary

HTTP server using shelf serving /contacts, /sms, /calls endpoints with mDNS advertisement via nsd package for local network discovery.

## What Was Done

### Task 1: Add network dependencies and Android permissions
- Added shelf ^1.4.2, shelf_router ^1.1.4, nsd ^4.1.0 to pubspec.yaml
- Added INTERNET, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE permissions
- Verified with flutter pub get

### Task 2: Create HTTP server with shelf and data endpoints
- Created PhoneSyncServer class with start/stop using shelf_io.serve
- Created Router with GET /contacts, /sms, /calls, /health endpoints
- Implemented handlers calling existing extraction services:
  - contacts_handler.dart: Returns all contacts with phones as JSON
  - sms_handler.dart: Returns SMS messages with ?since= support
  - calls_handler.dart: Returns call log with ?since= support
- Created ServerNotifier with Riverpod provider for server state management
- Server uses port 0 for dynamic assignment, exposes actual port via getter

### Task 3: Create mDNS service advertisement
- Created DiscoveryService using nsd package
- Advertises as _phonesync._tcp service type
- TXT records include version and device name
- Integrates with ServerNotifier lifecycle

## Key Files

Created:
- `apps/android_provider/lib/services/server/http_server.dart` - PhoneSyncServer class
- `apps/android_provider/lib/services/server/routes.dart` - Router configuration
- `apps/android_provider/lib/services/server/handlers/contacts_handler.dart`
- `apps/android_provider/lib/services/server/handlers/sms_handler.dart`
- `apps/android_provider/lib/services/server/handlers/calls_handler.dart`
- `apps/android_provider/lib/services/discovery_service.dart` - mDNS registration
- `apps/android_provider/lib/providers/server_provider.dart` - State management

Modified:
- `apps/android_provider/pubspec.yaml` - Added network dependencies
- `apps/android_provider/android/app/src/main/AndroidManifest.xml` - Network permissions

## Verification Results

- flutter pub get: Dependencies installed successfully
- flutter analyze: No issues found
- flutter build apk --debug: APK builds successfully
- Network permissions present in AndroidManifest.xml

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Dynamic port with port 0 | Avoids port conflicts, actual port advertised via mDNS |
| _phonesync._tcp service type | Custom service type for protocol identification |
| shelf + shelf_router | Lightweight HTTP server suitable for mobile |
| nsd package | Cross-platform mDNS that works on Android |

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

### API Response Format
All endpoints return JSON:
```json
{
  "data": [...],
  "count": 123,
  "timestamp": 1770109548000
}
```

### Incremental Sync
- /sms and /calls support `?since=<timestamp>` for incremental sync
- /contacts always returns full data (no timestamp filtering in flutter_contacts)

### mDNS Service
- Service type: `_phonesync._tcp`
- TXT records: `version=1.0`, `device=<name>`
- Desktop clients discover via mDNS, no manual IP entry needed

## Next Phase Readiness

Ready for Plan 02-02 (TLS/Authentication):
- Server infrastructure in place
- Endpoints functional
- Need to add TOTP authentication and optional TLS

## Metrics

- Duration: 3 minutes
- Tasks: 3/3 complete
- Commits: 3 atomic commits
