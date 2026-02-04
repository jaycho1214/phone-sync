---
phase: 04-release-pipeline
plan: 01
subsystem: infra
tags: [android, signing, keystore, linux, cmake, flutter, ci-cd]

# Dependency graph
requires:
  - phase: 03-desktop-client
    provides: Desktop client app for Windows/macOS
provides:
  - Android release signing configuration with key.properties
  - Conditional signing fallback (release or debug)
  - Linux platform support for desktop_client
  - CI/CD-ready build configurations
affects: [04-02, release-workflow, github-actions]

# Tech tracking
tech-stack:
  added: [CMake, GTK]
  patterns: [conditional-signing, key-properties-file]

key-files:
  created:
    - apps/desktop_client/linux/CMakeLists.txt
    - apps/desktop_client/linux/runner/main.cc
    - apps/desktop_client/linux/runner/my_application.cc
    - apps/desktop_client/linux/flutter/CMakeLists.txt
  modified:
    - apps/android_provider/android/app/build.gradle.kts

key-decisions:
  - "Conditional signing: use release signingConfig if key.properties exists, else debug"
  - "Linux binary name: desktop_client (matches app name)"

patterns-established:
  - "key.properties pattern: load properties file at build time for secrets"
  - "Fallback signing: CI can build without keystore for testing"

# Metrics
duration: 3min
completed: 2026-02-04
---

# Phase 4 Plan 1: Build Configuration Summary

**Android release signing with key.properties conditional fallback, Linux platform enabled with CMake/GTK build system**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-04T06:27:41Z
- **Completed:** 2026-02-04T06:30:48Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Android APK can be signed with release keystore when key.properties exists
- Android build falls back to debug signing without key.properties (CI flexibility)
- Linux platform fully enabled for desktop_client with GTK runner
- All platform build configurations ready for CI/CD workflow

## Task Commits

Each task was committed atomically:

1. **Task 1: Configure Android Release Signing** - `16607fc` (feat)
2. **Task 2: Enable Linux Platform for Desktop Client** - `de2dcc9` (feat)

## Files Created/Modified

- `apps/android_provider/android/app/build.gradle.kts` - Added signingConfigs and key.properties loading
- `apps/desktop_client/linux/CMakeLists.txt` - Top-level Linux build configuration
- `apps/desktop_client/linux/flutter/CMakeLists.txt` - Flutter integration for Linux
- `apps/desktop_client/linux/runner/main.cc` - Linux app entry point
- `apps/desktop_client/linux/runner/my_application.cc` - GTK application wrapper
- `apps/desktop_client/linux/runner/my_application.h` - GTK application header
- `apps/desktop_client/.metadata` - Updated with Linux platform registration

## Decisions Made

- **Conditional signing approach:** Build uses release signingConfig when key.properties exists, falls back to debug signing otherwise. This allows CI to build without keystore for PR testing while still supporting release builds when secrets are available.
- **Linux binary name:** Set to `desktop_client` matching the app name for consistency.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both tasks completed successfully on first attempt.

## User Setup Required

**External services require manual configuration for release builds:**

For Android release signing (required before creating signed APKs):
1. Generate upload keystore: `keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `apps/android_provider/android/key.properties`:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
3. For CI/CD, add GitHub Secrets:
   - `KEYSTORE_BASE64`: `base64 -i upload-keystore.jks`
   - `KEYSTORE_PASSWORD`: Store password
   - `KEY_PASSWORD`: Key password
   - `KEY_ALIAS`: upload

## Next Phase Readiness

- Android signing configuration complete, ready for release builds
- Linux platform enabled, ready for Linux builds
- Next plan (04-02) can create GitHub Actions workflow using these configurations
- No blockers or concerns

---
*Phase: 04-release-pipeline*
*Completed: 2026-02-04*
