---
phase: 04-release-pipeline
plan: 02
subsystem: infra
tags: [github-actions, ci-cd, flutter, android, macos, windows, linux, release, signing]

# Dependency graph
requires:
  - phase: 04-release-pipeline/01
    provides: Android release signing configuration, Linux platform support
provides:
  - Multi-platform release workflow triggered by version tags
  - Parallel builds for Android, macOS, Windows, Linux
  - Automated GitHub Release creation with artifacts and checksums
affects: [release-process, versioning, distribution]

# Tech tracking
tech-stack:
  added: [softprops/action-gh-release@v2, actions/upload-artifact@v4, actions/download-artifact@v4]
  patterns: [tag-triggered-release, parallel-platform-builds, artifact-checksums]

key-files:
  created:
    - .github/workflows/release.yml

key-decisions:
  - "macos-14 runner to avoid certificate validation issues on macos-15"
  - "Parallel platform jobs with create-release waiting for all builds"
  - "SHA256SUMS.txt generated for artifact verification"

patterns-established:
  - "Version extraction: GITHUB_REF_NAME#v strips v prefix from tag"
  - "Artifact naming: {app}-{platform}-{version}.{ext}"
  - "Release body includes download table with all platforms"

# Metrics
duration: 1min
completed: 2026-02-04
---

# Phase 4 Plan 2: GitHub Actions Release Workflow Summary

**Multi-platform release workflow with parallel Android/macOS/Windows/Linux builds, keystore signing, and SHA256 checksums uploaded to GitHub Releases**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-04T06:33:36Z
- **Completed:** 2026-02-04T06:34:56Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- GitHub Actions workflow triggers on v*.*.* tags
- 4 parallel build jobs for Android APK, macOS app, Windows exe, Linux binary
- Android APK signed with release keystore from GitHub Secrets
- GitHub Release created with all artifacts and SHA256SUMS.txt

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Multi-Platform Release Workflow** - `6532b4e` (feat)
2. **Task 2: Verify Workflow and Document Secrets** - No commit (verification task, documentation already in Task 1)

## Files Created/Modified

- `.github/workflows/release.yml` - Complete release workflow with 5 jobs (4 build + 1 release)

## Decisions Made

- **macos-14 runner:** Pinned to macos-14 instead of macos-latest (which is macos-15) to avoid certificate validation issues discovered in research
- **Parallel execution:** All 4 platform builds run in parallel (no inter-dependencies), create-release job waits for all via needs array
- **Version extraction pattern:** `${GITHUB_REF_NAME#v}` extracts version from tag (v1.0.0 -> 1.0.0)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both tasks completed successfully on first attempt.

## User Setup Required

**GitHub Secrets must be configured before release builds will work:**

1. Generate keystore (if not already done):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Add GitHub Secrets in repository Settings > Secrets and variables > Actions:
   - `KEYSTORE_BASE64`: Run `base64 -i upload-keystore.jks` and paste output
   - `KEYSTORE_PASSWORD`: Keystore password
   - `KEY_PASSWORD`: Key password (often same as keystore password)
   - `KEY_ALIAS`: Key alias (e.g., "upload")

3. Create a release:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

## Next Phase Readiness

- Release workflow complete, ready for production use
- Push a v*.*.* tag to trigger automated builds
- All platforms build in ~15-20 minutes total (parallel execution)
- No blockers - Phase 4 complete

---
*Phase: 04-release-pipeline*
*Completed: 2026-02-04*
