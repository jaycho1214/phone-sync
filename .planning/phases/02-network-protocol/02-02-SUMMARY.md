---
phase: 02-network-protocol
plan: 02
subsystem: network
tags: [tls, https, ssl, pairing, pin, authentication, session-token, shelf]

# Dependency graph
requires:
  - phase: 02-01
    provides: HTTP server with shelf, data endpoints, mDNS discovery
provides:
  - TLS certificate generation with basic_utils
  - HTTPS server with self-signed certificate
  - PIN-based pairing flow
  - Session token authentication for data endpoints
  - PIN display UI with countdown timer
affects: [desktop-client, phase-03]

# Tech tracking
tech-stack:
  added: [basic_utils, pointycastle]
  patterns: [shelf-middleware-auth, pin-pairing-flow, securitycontext-https]

key-files:
  created:
    - apps/android_provider/lib/services/certificate_service.dart
    - apps/android_provider/lib/services/pairing_service.dart
    - apps/android_provider/lib/services/server/handlers/pairing_handler.dart
    - apps/android_provider/lib/services/server/middleware/auth_middleware.dart
    - apps/android_provider/lib/providers/pairing_provider.dart
  modified:
    - apps/android_provider/pubspec.yaml
    - apps/android_provider/lib/services/server/http_server.dart
    - apps/android_provider/lib/services/server/routes.dart
    - apps/android_provider/lib/providers/server_provider.dart
    - apps/android_provider/lib/screens/home_screen.dart

key-decisions:
  - "basic_utils + pointycastle for pure Dart X509 certificate generation"
  - "SharedPreferences for TLS cert persistence with 365-day validity"
  - "6-digit PIN with 5-minute expiry for pairing"
  - "32-char hex session token for post-pairing authentication"
  - "Shelf Pipeline middleware pattern for auth"

patterns-established:
  - "PIN pairing flow: generate PIN -> display -> validate -> issue token"
  - "Bearer token auth: Authorization: Bearer {token}"
  - "Exempt endpoints from auth via path check in middleware"

# Metrics
duration: 5min
completed: 2026-02-03
---

# Phase 02 Plan 02: TLS and PIN Pairing Summary

**HTTPS server with self-signed TLS certificates and 6-digit PIN pairing flow for secure desktop-to-phone authentication**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-03T09:10:48Z
- **Completed:** 2026-02-03T09:16:06Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- TLS certificate generation using basic_utils with 365-day validity, persisted in SharedPreferences
- HTTPS server using SecurityContext with generated self-signed certificate
- PIN-based pairing: 6-digit code with 5-minute expiry, POST /pair returns session token
- Auth middleware protecting /contacts, /sms, /calls (401 without valid Bearer token)
- Home screen UI with server status, large PIN display, countdown timer, and pairing status

## Task Commits

Each task was committed atomically:

1. **Task 1: Add TLS certificate generation** - `e73b755` (feat)
2. **Task 2: Implement PIN pairing and session token authentication** - `3c0e9a8` (feat)
3. **Task 3: Add pairing UI to home screen** - `61a0388` (feat)

## Files Created/Modified

Created:
- `apps/android_provider/lib/services/certificate_service.dart` - TLS cert generation and SecurityContext creation
- `apps/android_provider/lib/services/pairing_service.dart` - PIN/token generation and validation
- `apps/android_provider/lib/services/server/handlers/pairing_handler.dart` - POST /pair endpoint
- `apps/android_provider/lib/services/server/middleware/auth_middleware.dart` - Bearer token validation
- `apps/android_provider/lib/providers/pairing_provider.dart` - UI state with countdown timer

Modified:
- `apps/android_provider/pubspec.yaml` - Added basic_utils, pointycastle dependencies
- `apps/android_provider/lib/services/server/http_server.dart` - Accept SecurityContext for HTTPS
- `apps/android_provider/lib/services/server/routes.dart` - Add /pair, wrap with auth middleware
- `apps/android_provider/lib/providers/server_provider.dart` - Inject certificate and pairing services
- `apps/android_provider/lib/screens/home_screen.dart` - Server card, PIN display, pairing UI

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| basic_utils + pointycastle for cert generation | Pure Dart, no external dependencies like OpenSSL |
| SharedPreferences for cert persistence | Simple persistence, certs regenerated if lost |
| 6-digit PIN (not 4) | Balance of security and usability |
| 5-minute PIN expiry | Short enough for security, long enough for manual entry |
| 32-char hex session token | Sufficient entropy (128 bits) |
| Path-based auth exemption in middleware | Simple, explicit - /pair and /health exempt |

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all dependencies installed cleanly, code compiled without errors.

## User Setup Required

None - no external service configuration required. All certificates are generated at runtime.

## Next Phase Readiness

Ready for Phase 03 (Desktop Client):
- HTTPS server with TLS encryption running
- mDNS discovery advertising service on local network
- PIN pairing flow complete: Android displays PIN, desktop can POST /pair
- Data endpoints protected with session token authentication
- Desktop client will need to handle self-signed certificate (badCertificateCallback)

**Note:** Desktop client must trust the self-signed certificate. Either:
- Use `badCertificateCallback` to accept any cert (OK for local network)
- Or extract and pin the certificate fingerprint during pairing

---
*Phase: 02-network-protocol*
*Completed: 2026-02-03*
