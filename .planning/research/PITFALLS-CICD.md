# Pitfalls Research: Flutter CI/CD with GitHub Actions

**Domain:** Multi-platform Flutter release automation
**Platforms:** Android, macOS, Windows, Linux
**Researched:** 2026-02-04
**Confidence:** HIGH (verified with official docs and community issues)

---

## Critical Pitfalls

Issues that will break builds or cause release failures.

---

### Pitfall 1: Java/Gradle Version Mismatch (Android)

**What goes wrong:** Build fails with "Unsupported class file major version 61" or "65" errors. Flutter's Android builds fail cryptically.

**Why it happens:** Android Studio Flamingo (and later) bundles Java 17, but older Gradle versions (< 7.3) cannot run with Java 17. Flutter 3.38+ requires Java 17 minimum.

**Warning signs:**
- `flutter doctor` shows Java version different from expected
- Build errors mentioning "class file major version"
- Works locally but fails in CI (different Java versions)

**Prevention:**
```yaml
# Explicitly set Java version in workflow
- uses: actions/setup-java@v4
  with:
    distribution: 'temurin'
    java-version: '17'

# Ensure android/gradle/wrapper/gradle-wrapper.properties uses compatible version
# Gradle 8.x for Java 17-21, AGP 8.x for Flutter 3.35+
```

**Which setup step:** Android build job, before Flutter setup

**Sources:**
- [Flutter Android Java Gradle Migration Guide](https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide)
- [Flutter Issue #168896](https://github.com/flutter/flutter/issues/168896)

---

### Pitfall 2: Missing Linux Build Dependencies

**What goes wrong:** Linux builds fail with "CMake was unable to find a build program corresponding to Ninja" or "GTK 3.0 development libraries are required."

**Why it happens:** Ubuntu runners don't include Flutter Linux desktop dependencies by default.

**Warning signs:**
- CMake errors about missing Ninja
- Flutter doctor reports missing Linux toolchain
- Build works on macOS/Windows but fails on Linux

**Prevention:**
```yaml
# Add BEFORE flutter build linux
- name: Install Linux dependencies
  run: |
    sudo apt-get update -y
    sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

**Which setup step:** Linux build job, after checkout but before Flutter build

**Sources:**
- [subosito/flutter-action README](https://github.com/subosito/flutter-action)
- [Flutter Issue #59750](https://github.com/flutter/flutter/issues/59750)

---

### Pitfall 3: macOS Code Signing Certificate Failures

**What goes wrong:** macOS builds fail with "No valid code signing certificates were found" or intermittent certificate validation errors.

**Why it happens:** macOS 15 runners have known certificate validation issues. Certificates must be properly imported into a temporary keychain.

**Warning signs:**
- Build works on macos-14 but fails on macos-15
- Intermittent failures that pass on retry
- "errSecInternalComponent" errors

**Prevention:**
```yaml
# Option 1: Pin to macos-14 until macos-15 issues resolved
runs-on: macos-14

# Option 2: Proper keychain setup
- name: Install certificates
  env:
    CERTIFICATE_BASE64: ${{ secrets.MACOS_CERTIFICATE }}
    CERTIFICATE_PASSWORD: ${{ secrets.MACOS_CERTIFICATE_PASSWORD }}
  run: |
    # Create temporary keychain
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    security create-keychain -p "" $KEYCHAIN_PATH
    security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
    security unlock-keychain -p "" $KEYCHAIN_PATH

    # Import certificate
    echo $CERTIFICATE_BASE64 | base64 --decode > certificate.p12
    security import certificate.p12 -k $KEYCHAIN_PATH -P $CERTIFICATE_PASSWORD -T /usr/bin/codesign

    # Allow codesign access
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" $KEYCHAIN_PATH
    security list-keychain -d user -s $KEYCHAIN_PATH
```

**Which setup step:** macOS build job, dedicated certificate installation step

**Sources:**
- [GitHub Actions Runner Images Issue #12960](https://github.com/actions/runner-images/issues/12960)
- [GitHub Actions Runner Images Issue #12861](https://github.com/actions/runner-images/issues/12861)

---

### Pitfall 4: GITHUB_TOKEN Cannot Trigger Other Workflows

**What goes wrong:** Release workflow creates a release but doesn't trigger dependent workflows. Automated releases don't trigger release event handlers.

**Why it happens:** GitHub prevents GITHUB_TOKEN from triggering other workflows to avoid infinite loops.

**Warning signs:**
- Release created but no deployment triggered
- Other workflows show "not triggered"
- Manual re-trigger works

**Prevention:**
```yaml
# Use a Personal Access Token (PAT) instead of GITHUB_TOKEN for release creation
- uses: softprops/action-gh-release@v2
  with:
    files: |
      build/*.apk
      build/*.dmg
  env:
    GITHUB_TOKEN: ${{ secrets.RELEASE_PAT }}  # PAT with contents:write scope
```

**Which setup step:** Release job, token configuration

**Sources:**
- [GitHub Community Discussion #27028](https://github.com/orgs/community/discussions/27028)
- [GitHub Documentation on GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

---

### Pitfall 5: Keystore/Signing Secrets Misconfiguration (Android)

**What goes wrong:** Android release builds fail because keystore file not found or signing configuration fails silently.

**Why it happens:** Keystore must be base64 encoded for secrets, then decoded in workflow. Environment variables must match build.gradle expectations.

**Warning signs:**
- "Keystore file not found" errors
- APK generated but unsigned
- Works in debug, fails in release

**Prevention:**
```yaml
# 1. Encode keystore: openssl base64 < keystore.jks | tr -d '\n' > keystore_base64.txt
# 2. Add secrets: KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD

- name: Decode Keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/keystore.jks

- name: Build Android Release
  env:
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
    KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  run: flutter build apk --release

# Ensure android/app/build.gradle reads from environment:
# signingConfigs {
#   release {
#     storeFile file("keystore.jks")
#     storePassword System.getenv("KEYSTORE_PASSWORD")
#     keyAlias System.getenv("KEY_ALIAS")
#     keyPassword System.getenv("KEY_PASSWORD")
#   }
# }
```

**Which setup step:** Android build job, before flutter build

**Sources:**
- [ProAndroidDev: Securely Build and Sign Android App](https://proandroiddev.com/how-to-securely-build-and-sign-your-android-app-with-github-actions-ad5323452ce)
- [Damien Aicheh: Flutter Android GitHub Actions](https://damienaicheh.github.io/flutter/github/actions/2021/04/29/build-sign-flutter-android-github-actions-en.html)

---

### Pitfall 6: Building Platform on Wrong Runner OS

**What goes wrong:** Workflow attempts to build macOS app on ubuntu-latest or Windows app on macos runner. Build fails immediately.

**Why it happens:** Flutter desktop builds require native compilation. macOS builds need macOS, Windows builds need Windows.

**Warning signs:**
- "Target macos not supported on this platform"
- Workflow uses wrong `runs-on` value
- Single job trying to build all platforms

**Prevention:**
```yaml
# Each platform MUST run on its native OS
jobs:
  build-android:
    runs-on: ubuntu-latest  # Android can build on any OS, but Linux is cheapest

  build-linux:
    runs-on: ubuntu-latest

  build-windows:
    runs-on: windows-latest  # Windows MUST use Windows runner

  build-macos:
    runs-on: macos-14  # macOS MUST use macOS runner
```

**Which setup step:** Job configuration, `runs-on` values

---

## Platform-Specific Gotchas

### Android

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| AGP/Gradle mismatch | "Could not determine AGP version" | Match AGP to Gradle: AGP 8.9.1 with Gradle 8.11.1 |
| Android SDK version | "requires compileSdk 34 or later" | Update android/app/build.gradle compileSdkVersion |
| Different APKs per OS | APK built on Windows differs from Linux | Always build Android on ubuntu-latest for consistency |
| NDK version mismatch | Native build failures | Flutter 3.38 requires NDK r28 |

**Sources:**
- [Flutter Issue #121052](https://github.com/flutter/flutter/issues/121052) - APK differences across OS

### macOS

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Xcode version | Build failures with newer Xcode | Pin Xcode: `sudo xcode-select -s /Applications/Xcode_15.4.app` |
| Notarization timeout | Notarization hangs or times out | Use `xcrun notarytool` with `--wait` flag and set timeout |
| Apple Silicon runners | Flutter < 3.0 fails | Use Flutter 3.0+ on Apple Silicon self-hosted runners |
| Manual vs auto signing | Signing failures | Disable automatic signing in Xcode project |

**Sources:**
- [Medium: Flutter macOS Desktop GitHub Actions](https://medium.com/flutter-community/build-sign-and-deliver-flutter-macos-desktop-applications-on-github-actions-5d9b69b0469c)

### Windows

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Missing yq | Version file parsing fails | Use flutter-action 2.18.0+ (auto-installs yq) |
| Visual Studio missing | Build fails | Windows-latest includes VS, but verify C++ workload |
| MSIX certificate | MSIX creation fails | Store certificate as base64 secret |
| Long paths | Build failures with long package names | Enable long paths: `git config --system core.longpaths true` |

**Sources:**
- [Flutter Build and Release Windows](https://docs.flutter.dev/deployment/windows)
- [YehudaKremer/msix](https://github.com/YehudaKremer/msix)

### Linux

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| GTK version | "Cannot find GTK" | Install libgtk-3-dev (not gtk4) |
| Display server | Integration tests fail | Use `xvfb-run` for tests requiring display |
| Missing fonts | Text rendering issues | Install fonts-liberation or similar |

**Sources:**
- [Flutter Issue #130343](https://github.com/flutter/flutter/issues/130343) - GTK dependencies

---

## Common Mistakes

### Mistake 1: Not Caching Dependencies

**Mistake:** Every build downloads Flutter SDK and pub packages fresh.

**Impact:** 5-10 minutes wasted per build, costs more on paid plans.

**Fix:**
```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable
    cache: true
    cache-key: "flutter-:os:-:channel:-:version:-:arch:-:hash:"
    pub-cache-key: "flutter-pub-:os:-:channel:-:version:-:arch:-:hash:"
```

**Sources:**
- [subosito/flutter-action](https://github.com/subosito/flutter-action)
- [Revelo: Reduce Flutter CI Time by 20%](https://www.revelo.com/blog/how-we-reduced-our-flutter-ci-execution-time-by-around-20)

---

### Mistake 2: Using `actions/upload-artifact@v4` with Same Name Across Jobs

**Mistake:** Multiple jobs uploading to same artifact name.

**Impact:** v4+ doesn't support uploading to same artifact multiple times. Build artifacts get overwritten or fail.

**Fix:** Use unique artifact names per platform:
```yaml
# In build-android job:
- uses: actions/upload-artifact@v4
  with:
    name: android-apk  # Unique per platform
    path: build/app/outputs/flutter-apk/app-release.apk

# In build-macos job:
- uses: actions/upload-artifact@v4
  with:
    name: macos-app  # Different name
    path: build/macos/Build/Products/Release/*.app
```

**Sources:**
- [actions/upload-artifact](https://github.com/actions/upload-artifact)

---

### Mistake 3: Release Job Running Before All Builds Complete

**Mistake:** Release job creates release with partial artifacts.

**Impact:** Release missing platform builds, users get incomplete release.

**Fix:** Use `needs` to wait for all builds:
```yaml
release:
  needs: [build-android, build-macos, build-windows, build-linux]
  runs-on: ubuntu-latest
  steps:
    - uses: actions/download-artifact@v4
      with:
        path: artifacts/

    - uses: softprops/action-gh-release@v2
      with:
        files: artifacts/**/*
```

---

### Mistake 4: Not Setting Workflow Timeouts

**Mistake:** Relying on default 6-hour timeout.

**Impact:** Stuck builds consume minutes, macOS at 10x multiplier burns budget fast.

**Fix:**
```yaml
jobs:
  build:
    runs-on: macos-14
    timeout-minutes: 30  # Set reasonable timeout
```

---

### Mistake 5: Ignoring Tag/Release Trigger Semantics

**Mistake:** Using `on: release: types: [published]` but creating draft releases.

**Impact:** Workflow never triggers because drafts don't fire `published` event.

**Fix:**
```yaml
# For draft-then-publish flow:
on:
  release:
    types: [released]  # Fires when draft is published

# For tag-based releases (simpler):
on:
  push:
    tags:
      - 'v*'
```

**Sources:**
- [GitHub Community Discussion #45144](https://github.com/orgs/community/discussions/45144)
- [GitHub Documentation on Release Events](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#release)

---

### Mistake 6: Hardcoding Flutter Version

**Mistake:** Pinning exact Flutter version that becomes outdated.

**Impact:** Miss security fixes, dependency conflicts over time.

**Better:**
```yaml
# Use version file (preferred - keeps CI in sync with local dev)
- uses: subosito/flutter-action@v2
  with:
    flutter-version-file: pubspec.yaml  # Requires exact version in pubspec

# Or use channel for latest stable
- uses: subosito/flutter-action@v2
  with:
    channel: stable
```

---

### Mistake 7: Not Checking Workflow File at Tag Commit

**Mistake:** Fixing CI workflow after creating release tag.

**Impact:** Tag points to commit without working workflow. Workflow never runs.

**Fix:**
1. Always test workflow changes on a branch first
2. After fixing CI, create a new tag (or move the tag to the fixed commit)
3. Tags point to specific commits - the workflow at THAT commit runs

**Sources:**
- [GitHub Community Discussion #27028](https://github.com/orgs/community/discussions/27028)

---

## Prevention Strategies

### Strategy 1: Cost-Aware Runner Selection

| Platform | Runner | Cost Multiplier | Optimization |
|----------|--------|-----------------|--------------|
| Android | ubuntu-latest | 1x | Default |
| Linux | ubuntu-latest | 1x | Default |
| Windows | windows-latest | 2x | Cache aggressively |
| macOS | macos-14 | 10x | Cache everything, minimize jobs |

**macOS cost mitigation:**
- Use `macos-14` (not `latest` which may point to more expensive runners)
- Cache Flutter SDK and pub packages
- Set strict timeouts (30 min max)
- Consider self-hosted runners for high-volume projects

**Sources:**
- [GitHub Actions Runner Pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)

---

### Strategy 2: Structured Release Workflow Pattern

```
                    Tag Push (v*)
                         |
         +---------------+---------------+
         |               |               |
         v               v               v
    +---------+    +---------+    +---------+
    | Android |    | Windows |    |  Linux  |
    | ubuntu  |    | windows |    | ubuntu  |
    +---------+    +---------+    +---------+
         |               |               |
         |          +---------+          |
         |          |  macOS  |          |
         |          | macos   |          |
         |          +---------+          |
         |               |               |
         v               v               v
    +------------------------------------+
    |        Upload Artifacts            |
    |   (unique names per platform)      |
    +------------------------------------+
                         |
                         v
    +------------------------------------+
    |          Release Job               |
    |   needs: [all build jobs]          |
    |   - Download all artifacts         |
    |   - Create GitHub Release          |
    |   - Upload all to release          |
    +------------------------------------+
```

---

### Strategy 3: Secret Management Checklist

Before first release build, ensure these secrets are configured:

**Android:**
- [ ] `KEYSTORE_BASE64` - Android keystore (base64 encoded)
- [ ] `KEYSTORE_PASSWORD` - Keystore password
- [ ] `KEY_ALIAS` - Key alias in keystore
- [ ] `KEY_PASSWORD` - Key password

**macOS (if code signing):**
- [ ] `MACOS_CERTIFICATE` - macOS signing certificate (base64)
- [ ] `MACOS_CERTIFICATE_PASSWORD` - Certificate password

**Windows (if MSIX signing):**
- [ ] `WINDOWS_CERTIFICATE` - Windows signing certificate (base64)
- [ ] `WINDOWS_CERTIFICATE_PASSWORD` - Certificate password

**Release Automation (if chaining workflows):**
- [ ] `RELEASE_PAT` - PAT for release creation (if triggering other workflows)

---

### Strategy 4: Version Matrix for Compatibility Testing

Before locking versions, test across Flutter/SDK versions:
```yaml
strategy:
  matrix:
    flutter-version: ['3.35.0', '3.38.0']
    include:
      - flutter-version: '3.35.0'
        java-version: '17'
      - flutter-version: '3.38.0'
        java-version: '17'
```

---

### Strategy 5: Fail-Fast with Local Validation

**Before pushing to CI:** Verify builds work locally
```bash
# Run same commands CI will run
flutter build apk --release
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

---

## Workflow Debugging Checklist

When builds fail:

1. **Check runner OS matches platform:**
   - macOS builds MUST use macos-* runner
   - Windows builds MUST use windows-* runner

2. **Check version compatibility:**
   - Java version matches Gradle requirements
   - Flutter version matches AGP requirements
   - Android SDK version matches dependency requirements

3. **Check secrets are set:**
   - View workflow run, check secret masking indicators
   - Secrets show as `***` in logs when used

4. **Check dependencies installed:**
   - Linux: ninja-build, libgtk-3-dev
   - Android: proper Java version
   - macOS: correct Xcode version

5. **Check artifact paths:**
   - APK: `build/app/outputs/flutter-apk/app-release.apk`
   - AAB: `build/app/outputs/bundle/release/app-release.aab`
   - macOS: `build/macos/Build/Products/Release/*.app`
   - Windows: `build/windows/x64/runner/Release/`
   - Linux: `build/linux/x64/release/bundle/`

---

## Sources

### Official Documentation
- [Flutter Android Java Gradle Migration Guide](https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide)
- [Flutter Build and Release Windows](https://docs.flutter.dev/deployment/windows)
- [GitHub Actions Runner Pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)
- [GitHub Actions Workflow Triggers](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)

### GitHub Actions
- [subosito/flutter-action](https://github.com/subosito/flutter-action) - Primary Flutter action
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - Release creation
- [actions/upload-artifact](https://github.com/actions/upload-artifact) - Artifact handling
- [actions/download-artifact](https://github.com/actions/download-artifact) - Artifact retrieval

### Issue Trackers (Verified Problems)
- [Flutter #168896](https://github.com/flutter/flutter/issues/168896) - Java/Gradle version mismatch
- [Flutter #59750](https://github.com/flutter/flutter/issues/59750) - CMake/Ninja missing
- [Flutter #121052](https://github.com/flutter/flutter/issues/121052) - APK differences across OS
- [Flutter #130343](https://github.com/flutter/flutter/issues/130343) - GTK dependencies
- [Runner Images #12960](https://github.com/actions/runner-images/issues/12960) - macOS 15 certificate issues
- [Runner Images #12861](https://github.com/actions/runner-images/issues/12861) - Intermittent certificate errors
- [softprops/action-gh-release #165](https://github.com/softprops/action-gh-release/issues/165) - Multi-job releases

### Community Guides
- [Angelo Cassano: Flutter Desktop GitHub Actions](https://angeloavv.medium.com/how-to-distribute-flutter-desktop-app-binaries-using-github-actions-f8d0f9be4d6b)
- [ProAndroidDev: Secure Android Signing](https://proandroiddev.com/how-to-securely-build-and-sign-your-android-app-with-github-actions-ad5323452ce)
- [Localazy: macOS App Signing](https://localazy.com/blog/how-to-automatically-sign-macos-apps-using-github-actions)
- [Revelo: Reduce Flutter CI Time by 20%](https://www.revelo.com/blog/how-we-reduced-our-flutter-ci-execution-time-by-around-20)
- [Flutter Community: macOS Desktop GitHub Actions](https://medium.com/flutter-community/build-sign-and-deliver-flutter-macos-desktop-applications-on-github-actions-5d9b69b0469c)
