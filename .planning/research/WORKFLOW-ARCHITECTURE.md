# Architecture Research: GitHub Actions Workflow Structure

**Project:** jljm-phonesync
**Researched:** 2026-02-04
**Dimension:** CI/CD workflow structure for multi-platform Flutter builds
**Confidence:** HIGH (based on official documentation and verified patterns)

## Executive Summary

For a Flutter monorepo building 4 platforms (Android APK + macOS/Windows/Linux desktop), the recommended architecture uses a **single workflow file with multiple jobs** rather than multiple workflow files. This pattern provides explicit job dependencies, unified artifact handling, and a single release creation point.

Key insight: Android builds on `ubuntu-latest`, but desktop builds require platform-native runners (macOS must build on `macos-latest`, Windows on `windows-latest`). This necessitates separate jobs per platform rather than a single matrix job.

## Workflow Design

### Recommendation: Single Workflow, Multiple Jobs

**Use one workflow file** (`.github/workflows/release.yml`) with these jobs:

```
[test] -----> [build-android] ----\
         |                         \
         |--> [build-macos] ---------> [release]
         |                         /
         |--> [build-windows] ----/
         |                       /
         |--> [build-linux] ----/
```

**Rationale:**
1. **Job synchronization** - The release job must wait for ALL builds to complete. This is only possible with jobs in the same workflow using `needs: [job1, job2, ...]`
2. **Artifact passing** - Build artifacts flow naturally between jobs via `upload-artifact`/`download-artifact`
3. **Single trigger** - One tag push triggers the entire release pipeline
4. **Failure handling** - If any build fails, the release job is automatically skipped

**Why not multiple workflows:**
- Cannot synchronize completion across workflows without complex `workflow_dispatch` or `workflow_run` chains
- Artifact sharing between workflows requires external storage or release assets as intermediaries
- More complex to reason about and debug

### Workflow File Structure

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write

jobs:
  test:
    # Runs tests before any builds

  build-android:
    needs: test
    runs-on: ubuntu-latest

  build-macos:
    needs: test
    runs-on: macos-latest

  build-windows:
    needs: test
    runs-on: windows-latest

  build-linux:
    needs: test
    runs-on: ubuntu-latest

  release:
    needs: [build-android, build-macos, build-windows, build-linux]
    runs-on: ubuntu-latest
```

## Build Matrix vs Separate Jobs

### Recommendation: Separate Jobs (Not Matrix)

For this project, use **separate named jobs** rather than a matrix strategy.

**Why not a matrix for builds:**

1. **Different source directories** - Android builds from `apps/android_provider/`, desktop builds from `apps/desktop_client/`. A matrix would require complex conditional logic.

2. **Different build commands:**
   - Android: `flutter build apk`
   - macOS: `flutter build macos`
   - Windows: `flutter build windows`
   - Linux: `flutter build linux`

3. **Different artifact paths:**
   - Android APK: `build/app/outputs/flutter-apk/`
   - macOS: `build/macos/Build/Products/Release/`
   - Windows: `build/windows/x64/runner/Release/`
   - Linux: `build/linux/x64/release/bundle/`

4. **Different dependencies:**
   - Linux requires `apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev`
   - macOS/Windows have native toolchains pre-installed

**When matrix IS appropriate:**
- Testing the same code on multiple Flutter versions
- Testing the same code on multiple OS runners
- Building the same app with different configurations (flavors)

### Job Structure Detail

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - uses: bluefireteam/melos-action@v3
      - run: melos run analyze
      - run: melos run test

  build-android:
    needs: test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/android_provider
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: apps/android_provider/build/app/outputs/flutter-apk/app-release.apk

  build-macos:
    needs: test
    runs-on: macos-latest
    defaults:
      run:
        working-directory: apps/desktop_client
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build macos --release
      - name: Package macOS app
        run: |
          cd build/macos/Build/Products/Release
          zip -r PhoneSync-macos.zip "PhoneSync.app"
      - uses: actions/upload-artifact@v4
        with:
          name: macos-app
          path: apps/desktop_client/build/macos/Build/Products/Release/PhoneSync-macos.zip

  build-windows:
    needs: test
    runs-on: windows-latest
    defaults:
      run:
        working-directory: apps/desktop_client
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build windows --release
      - name: Package Windows app
        run: Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath PhoneSync-windows.zip
      - uses: actions/upload-artifact@v4
        with:
          name: windows-app
          path: apps/desktop_client/PhoneSync-windows.zip

  build-linux:
    needs: test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/desktop_client
    steps:
      - uses: actions/checkout@v4
      - name: Install Linux dependencies
        run: |
          sudo apt-get update -y
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build linux --release
      - name: Package Linux app
        run: |
          cd build/linux/x64/release
          tar -czvf PhoneSync-linux.tar.gz bundle/
      - uses: actions/upload-artifact@v4
        with:
          name: linux-app
          path: apps/desktop_client/build/linux/x64/release/PhoneSync-linux.tar.gz

  release:
    needs: [build-android, build-macos, build-windows, build-linux]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: artifacts
          merge-multiple: true
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            artifacts/**/*
          generate_release_notes: true
```

## Artifact Flow

### Upload/Download Pattern

**Critical v4 change:** With `actions/upload-artifact@v4`, each artifact name must be unique. You cannot upload to the same artifact name from multiple jobs.

```
build-android ──upload──> [android-apk]
build-macos   ──upload──> [macos-app]      ──download──> release job ──> GitHub Release
build-windows ──upload──> [windows-app]
build-linux   ──upload──> [linux-app]
```

### Artifact Naming Convention

Use descriptive, unique names that indicate platform:

| Job | Artifact Name | Contents |
|-----|---------------|----------|
| build-android | `android-apk` | `app-release.apk` |
| build-macos | `macos-app` | `PhoneSync-macos.zip` |
| build-windows | `windows-app` | `PhoneSync-windows.zip` |
| build-linux | `linux-app` | `PhoneSync-linux.tar.gz` |

### Download Configuration

In the release job, use `merge-multiple: true` to download all artifacts into a single directory:

```yaml
- uses: actions/download-artifact@v4
  with:
    path: artifacts
    merge-multiple: true
```

This downloads:
```
artifacts/
  app-release.apk
  PhoneSync-macos.zip
  PhoneSync-windows.zip
  PhoneSync-linux.tar.gz
```

### Artifact Retention

Default retention is 90 days. For release artifacts, this is acceptable since they are uploaded to the GitHub Release which has no expiration.

## Caching Strategy

### Recommendation: Use `subosito/flutter-action` Built-in Caching

```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable
    cache: true
```

This automatically caches:
- Flutter SDK installation
- Pub dependency cache (`.pub-cache`)

### Cache Keys

The action generates cache keys using:
- `:os:` - Operating system
- `:channel:` - Flutter channel (stable/beta)
- `:version:` - Flutter version
- `:arch:` - Architecture
- `:hash:` - Hash of pubspec.lock

### Cache Hit Detection

Check cache status to conditionally skip operations:

```yaml
- uses: subosito/flutter-action@v2
  id: flutter
  with:
    channel: stable
    cache: true

- name: Bootstrap (if cache miss)
  if: steps.flutter.outputs.PUB-CACHE-HIT != 'true'
  run: melos bootstrap
```

### Melos Integration

When using Melos, the `bluefireteam/melos-action@v3` runs `melos bootstrap` automatically unless disabled:

```yaml
- uses: subosito/flutter-action@v2
  with:
    cache: true
- uses: bluefireteam/melos-action@v3
  # Automatically runs: melos bootstrap
```

For build jobs that don't need full monorepo bootstrap (they only build one app), skip melos and use direct `flutter pub get`:

```yaml
# In build-android job - only needs android_provider dependencies
- run: flutter pub get
  working-directory: apps/android_provider
```

### Per-Platform Cache Isolation

Each runner maintains its own cache. The cache key includes `:os:`, so:
- `ubuntu-latest` has its own Flutter/pub cache
- `macos-latest` has its own Flutter/pub cache
- `windows-latest` has its own Flutter/pub cache

This is correct behavior - platform-specific native artifacts should not be shared across platforms.

## Release Creation

### Trigger: Tag Push

```yaml
on:
  push:
    tags:
      - 'v*.*.*'  # e.g., v1.0.0, v2.1.3
```

### Release Action: `softprops/action-gh-release@v2`

**Configuration:**

```yaml
- uses: softprops/action-gh-release@v2
  with:
    files: |
      artifacts/**/*
    generate_release_notes: true
    draft: false
    prerelease: false
```

**Key inputs:**
- `files` - Glob patterns for assets to upload
- `generate_release_notes` - Auto-generate notes from commits
- `draft` - Create as draft (requires manual publish)
- `prerelease` - Mark as pre-release

**Required permissions:**

```yaml
permissions:
  contents: write
```

### Release Notes Options

1. **Auto-generated** (recommended for most cases):
   ```yaml
   generate_release_notes: true
   ```

2. **From file** (for detailed changelogs):
   ```yaml
   body_path: CHANGELOG.md
   ```

## Job Dependencies Summary

```yaml
jobs:
  test:
    # No dependencies - runs first

  build-android:
    needs: test

  build-macos:
    needs: test

  build-windows:
    needs: test

  build-linux:
    needs: test

  release:
    needs: [build-android, build-macos, build-windows, build-linux]
```

**Execution order:**
1. `test` runs first
2. After `test` succeeds, all 4 build jobs run **in parallel**
3. After ALL builds succeed, `release` runs
4. If ANY job fails, downstream jobs are skipped

### Parallel Execution

Build jobs run in parallel because:
- They all depend only on `test`
- They don't depend on each other
- GitHub Actions runs independent jobs concurrently

Estimated timeline (assuming builds take ~5 min each):
- Sequential: ~25 minutes (test + 4 builds + release)
- Parallel: ~10 minutes (test + longest build + release)

## Platform-Specific Notes

### Android

- Runs on `ubuntu-latest`
- No additional system dependencies needed
- Signing consideration: Add keystore setup for signed release APKs

### macOS

- MUST run on `macos-latest`
- Consider code signing with Apple Developer certificate for distribution
- Output is `.app` bundle, typically zipped for distribution

### Windows

- MUST run on `windows-latest`
- Output is folder in `build/windows/x64/runner/Release/`
- Typically zipped or packaged with MSIX for distribution

### Linux

- Runs on `ubuntu-latest`
- Requires system packages: `clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev`
- Output is bundle folder, typically tar.gz for distribution

## Alternative Patterns Considered

### Pattern: Reusable Workflows

Could extract common Flutter setup into reusable workflow:

```yaml
# .github/workflows/flutter-setup.yml (reusable)
on:
  workflow_call:
    inputs:
      working-directory:
        required: true
        type: string
```

**When to use:** If you have multiple repositories with similar CI needs.
**For this project:** Unnecessary complexity for a single monorepo.

### Pattern: Manual Dispatch + Auto Release

Separate workflows for:
1. `ci.yml` - Runs on every PR
2. `release.yml` - Manual dispatch or tag-triggered

**When to use:** When you want human approval before releases.
**For this project:** Tag-triggered automatic release is simpler and sufficient.

### Pattern: Matrix with Include

Could use matrix with explicit includes:

```yaml
strategy:
  matrix:
    include:
      - os: ubuntu-latest
        app: android_provider
        build_cmd: flutter build apk
      - os: macos-latest
        app: desktop_client
        build_cmd: flutter build macos
      # etc.
```

**Rejected because:** Still requires complex conditionals for different artifact paths, post-build packaging, and Linux dependencies. Separate jobs are clearer.

## Complete Workflow Template

See the "Job Structure Detail" section above for the complete, production-ready workflow.

## Workflow for PRs (Separate File)

In addition to the release workflow, create a CI workflow for pull requests:

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - uses: bluefireteam/melos-action@v3
      - run: melos run analyze

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - uses: bluefireteam/melos-action@v3
      - run: melos run test
```

This provides fast feedback on PRs without running full platform builds.

## Sources

**HIGH confidence (official documentation):**
- [Flutter Linux Setup](https://docs.flutter.dev/platform-integration/linux/setup) - Linux dependencies
- [subosito/flutter-action](https://github.com/subosito/flutter-action) - Flutter CI action with caching
- [GitHub Actions: Using jobs in a workflow](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/using-jobs-in-a-workflow) - Job dependencies
- [actions/upload-artifact@v4](https://github.com/actions/upload-artifact) - Artifact handling
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - Release creation
- [bluefireteam/melos-action](https://github.com/bluefireteam/melos-action) - Melos CI integration

**MEDIUM confidence (community best practices):**
- [How to Create a Release with Multiple Artifacts Using Matrix Strategy](https://www.lucavall.in/blog/how-to-create-a-release-with-multiple-artifacts-from-a-github-actions-workflow-using-the-matrix-strategy) - Build/release pattern
- [GitHub Actions Matrix Builds](https://www.blacksmith.sh/blog/matrix-builds-with-github-actions) - Matrix strategy guidance
- [Single workflow vs multiple workflows](https://github.com/orgs/community/discussions/25482) - Workflow design decisions
