# Phase 4: Release Pipeline - Research

**Researched:** 2026-02-04
**Domain:** GitHub Actions CI/CD for Flutter multi-platform builds
**Confidence:** HIGH

## Summary

This research covers implementing automated multi-platform builds for a Flutter monorepo using GitHub Actions. The standard approach uses `subosito/flutter-action@v2` for Flutter SDK setup with caching, parallel jobs for each platform (Android, macOS, Windows, Linux), and `softprops/action-gh-release@v2` for creating GitHub Releases with artifacts.

Android APK signing requires storing the keystore as base64 in GitHub Secrets and decoding it during the workflow. The build.gradle.kts needs modification to support reading signing configuration from a key.properties file that is generated during CI. Linux builds require installing additional system dependencies (clang, cmake, ninja-build, libgtk-3-dev).

**Primary recommendation:** Single workflow file with parallel platform jobs, Flutter SDK caching, and automatic release creation on tag push. Use macos-14 runner to avoid certificate validation issues on macos-15.

## Standard Stack

The established tools for Flutter CI/CD:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| subosito/flutter-action | v2.21.0+ | Flutter SDK setup | Official action, supports caching, all platforms |
| softprops/action-gh-release | v2.5.0 | Create GitHub releases | Most used, supports multiple file uploads |
| actions/checkout | v4 | Repository checkout | GitHub official |
| actions/setup-java | v4 | Java for Android builds | GitHub official, required for Android |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| thedoctor0/zip-release | v0.7.5 | Archive artifacts | Zip macOS .app bundle for distribution |
| battila7/get-version-action | v2 | Extract version from tag | When you need version-without-v output |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| softprops/action-gh-release | ncipollo/release-action | Similar functionality, different API |
| thedoctor0/zip-release | Manual tar/zip commands | Shell commands work but action is cleaner |
| battila7/get-version-action | Shell parameter expansion | No external action needed, slightly more verbose |

**No installation needed:** All tools are GitHub Actions referenced in workflow YAML.

## Architecture Patterns

### Recommended Workflow Structure
```
.github/
└── workflows/
    └── release.yml    # Single workflow for all platforms
```

### Pattern 1: Parallel Platform Jobs
**What:** Each platform builds in its own job, running concurrently
**When to use:** Always for multi-platform builds
**Example:**
```yaml
# Source: subosito/flutter-action documentation
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter build apk --release
      # ... artifact handling

  build-macos:
    runs-on: macos-14  # NOT macos-15 due to certificate issues
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter build macos --release
      # ... artifact handling

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter build windows --release
      # ... artifact handling

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: |
          sudo apt-get update -y
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
      - run: flutter build linux --release
      # ... artifact handling

  create-release:
    needs: [build-android, build-macos, build-windows, build-linux]
    runs-on: ubuntu-latest
    steps:
      # Download all artifacts and create release
```

### Pattern 2: Version Extraction from Tag
**What:** Extract version number from git tag, removing 'v' prefix
**When to use:** For setting build version and naming artifacts
**Example:**
```yaml
# Source: GitHub Actions documentation
- name: Get version from tag
  id: get_version
  run: echo "VERSION=${GITHUB_REF_NAME#v}" >> $GITHUB_OUTPUT

- name: Use version
  run: |
    echo "Building version ${{ steps.get_version.outputs.VERSION }}"
    flutter build apk --build-name=${{ steps.get_version.outputs.VERSION }}
```

### Pattern 3: Android Keystore Handling in CI
**What:** Decode base64 keystore and create key.properties at build time
**When to use:** For signed release APK builds
**Example:**
```yaml
# Source: Flutter official docs + community patterns
- name: Decode Keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/upload-keystore.jks

- name: Create key.properties
  run: |
    echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" > android/key.properties
    echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
    echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/key.properties
    echo "storeFile=upload-keystore.jks" >> android/key.properties
```

### Pattern 4: SHA256 Checksum Generation
**What:** Generate SHA256 checksums for all release artifacts
**When to use:** For artifact verification
**Example:**
```yaml
# Source: Standard shell pattern
- name: Generate checksums
  run: |
    cd artifacts
    sha256sum *.apk *.zip > SHA256SUMS.txt
```

### Anti-Patterns to Avoid
- **Using macos-latest or macos-15:** Certificate validation issues; use macos-14
- **Committing keystore to repo:** Security risk; use GitHub Secrets with base64 encoding
- **Sequential platform builds:** Wastes time; use parallel jobs
- **Skipping Flutter SDK cache:** Adds 3-5 minutes per job; always enable cache: true
- **Using flutter format:** Deprecated; use dart format instead

## Don't Hand-Roll

Problems with existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Flutter SDK setup | Shell scripts to download Flutter | subosito/flutter-action | Handles versioning, caching, all platforms |
| Release creation | Manual API calls to GitHub | softprops/action-gh-release | Handles uploads, idempotent, well-tested |
| Archive creation | Complex tar/zip commands | thedoctor0/zip-release | Cross-platform, handles edge cases |
| Version parsing | Regex in workflow | battila7/get-version-action or simple shell | Pre-built, tested |
| Java setup for Android | Manual JDK download | actions/setup-java | Handles caching, multiple distributions |

**Key insight:** GitHub Actions has mature, well-tested actions for Flutter CI/CD. Using them saves debugging time and ensures compatibility across runner updates.

## Common Pitfalls

### Pitfall 1: macOS 15 Certificate Validation Failures
**What goes wrong:** Flutter builds fail with "No valid code signing certificates were found" on macos-15 runners
**Why it happens:** macOS 15 introduced security changes that break certificate validation; GitHub migrated macos-latest to macos-15 in August 2025
**How to avoid:** Explicitly specify `runs-on: macos-14`
**Warning signs:** Intermittent build failures, certificate-related error messages

### Pitfall 2: Missing Linux Dependencies
**What goes wrong:** Linux build fails with missing ninja, gtk, or compiler errors
**Why it happens:** Flutter Linux desktop requires system packages not pre-installed on ubuntu-latest
**How to avoid:** Install dependencies before flutter build: `sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev`
**Warning signs:** "ninja: not found" or GTK-related errors

### Pitfall 3: Unsigned APK Not Installable
**What goes wrong:** APK downloads but cannot be installed on devices
**Why it happens:** Release APKs must be signed; debug signing doesn't work for distribution
**How to avoid:** Configure proper release signing with production keystore
**Warning signs:** "App not installed" error on Android device

### Pitfall 4: Flutter SDK Download Timeout
**What goes wrong:** Job times out or fails during Flutter SDK download
**Why it happens:** Flutter SDK is ~700MB; without caching, each job downloads it fresh
**How to avoid:** Enable caching in flutter-action: `cache: true`
**Warning signs:** 5+ minute setup times, occasional timeout failures

### Pitfall 5: Windows Build Path Changed
**What goes wrong:** Artifact upload fails to find Windows build
**Why it happens:** Flutter added architecture to Windows build path (x64 subfolder)
**How to avoid:** Use correct path: `build/windows/x64/runner/Release/`
**Warning signs:** "File not found" when uploading Windows artifacts

### Pitfall 6: Monorepo Working Directory
**What goes wrong:** Flutter commands fail with "not a Flutter project"
**Why it happens:** Commands run from repo root, not app directory
**How to avoid:** Use `working-directory: apps/app_name` in workflow steps
**Warning signs:** pubspec.yaml not found errors

### Pitfall 7: Release Job Runs Before Builds Complete
**What goes wrong:** Release created with missing artifacts
**Why it happens:** Jobs run in parallel by default
**How to avoid:** Use `needs: [build-android, build-macos, ...]` on release job
**Warning signs:** Partial releases, missing platform downloads

## Code Examples

Verified patterns from official sources:

### Complete Android Signing Configuration (build.gradle.kts)
```kotlin
// Source: https://docs.flutter.dev/deployment/android
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jljm.android_provider"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jljm.android_provider"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### Flutter SDK with Caching
```yaml
# Source: https://github.com/subosito/flutter-action
- name: Set up Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: stable
    cache: true
```

### Upload to GitHub Release
```yaml
# Source: https://github.com/softprops/action-gh-release
- name: Create Release
  uses: softprops/action-gh-release@v2
  with:
    files: |
      artifacts/*.apk
      artifacts/*.zip
      artifacts/SHA256SUMS.txt
    generate_release_notes: true
```

### Build Output Paths
```yaml
# Android APK
apps/android_provider/build/app/outputs/flutter-apk/app-release.apk

# macOS App Bundle
apps/desktop_client/build/macos/Build/Products/Release/desktop_client.app

# Windows Executable
apps/desktop_client/build/windows/x64/runner/Release/

# Linux Bundle
apps/desktop_client/build/linux/x64/release/bundle/
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| macos-latest (was 13/14) | macos-14 explicit | Aug 2025 | Avoid certificate issues |
| flutter format | dart format | 2024 | flutter format deprecated |
| build/windows/runner/ | build/windows/x64/runner/ | 2023 | Architecture in path |
| Manual artifact upload | softprops/action-gh-release | Mature | Simpler workflow |

**Deprecated/outdated:**
- `flutter format`: Use `dart format` instead
- `macos-latest`: Pin to `macos-14` for stability
- `actions/upload-release-asset`: Superseded by `softprops/action-gh-release`

## Open Questions

Things that couldn't be fully resolved:

1. **Exact build times for this project**
   - What we know: Typical Flutter builds take 5-15 minutes per platform
   - What's unclear: Actual times for this specific monorepo
   - Recommendation: Monitor first few builds, optimize if needed

2. **macOS app bundle naming**
   - What we know: Output is in Build/Products/Release/
   - What's unclear: Exact app name (desktop_client.app vs Runner.app)
   - Recommendation: Build locally first to confirm exact path

3. **Linux distribution compatibility**
   - What we know: Bundle includes all dependencies
   - What's unclear: If users need additional runtime libraries
   - Recommendation: Test on fresh Ubuntu install

## Sources

### Primary (HIGH confidence)
- [subosito/flutter-action](https://github.com/subosito/flutter-action) - Flutter setup, caching configuration
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - Release creation, file uploads
- [Flutter Android deployment docs](https://docs.flutter.dev/deployment/android) - Signing configuration
- [Flutter Linux setup docs](https://docs.flutter.dev/platform-integration/linux/setup) - System dependencies

### Secondary (MEDIUM confidence)
- [actions/runner-images#12960](https://github.com/actions/runner-images/issues/12960) - macOS 15 certificate issues, macos-14 workaround
- [Flutter Windows build path change](https://docs.flutter.dev/release/breaking-changes/windows-build-architecture) - x64 in path

### Tertiary (LOW confidence)
- Community blog posts on workflow patterns - Verified against official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official GitHub Actions, well-documented
- Architecture: HIGH - Standard patterns, verified with official docs
- Pitfalls: HIGH - Documented in GitHub issues with confirmed workarounds

**Research date:** 2026-02-04
**Valid until:** 60 days (stable domain, unlikely to change rapidly)

## Required GitHub Secrets

For the workflow to function, these secrets must be configured:

| Secret | Purpose | How to Generate |
|--------|---------|-----------------|
| KEYSTORE_BASE64 | Base64-encoded .jks keystore | `base64 -i upload-keystore.jks` |
| KEYSTORE_PASSWORD | Keystore password | Set during keytool -genkey |
| KEY_PASSWORD | Key password (often same as keystore) | Set during keytool -genkey |
| KEY_ALIAS | Key alias in keystore | Set during keytool -genkey (e.g., "upload") |

**Keystore generation command:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
```
