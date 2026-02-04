# Stack Research: GitHub Actions Flutter CI/CD

**Project:** jljm-phonesync
**Researched:** 2026-02-04
**Focus:** Multi-platform release pipeline (Android APK, macOS, Windows, Linux)
**Trigger:** Git tag push (v*.*.* format)
**Overall Confidence:** HIGH

---

## Recommended Stack

### Core GitHub Actions

| Action | Version | Purpose | Why This Version |
|--------|---------|---------|------------------|
| `actions/checkout` | `v6` | Clone repository | v6.0.1 (Dec 2025) runs on Node.js 24, improved performance, security patches. Requires runner v2.327.1+. |
| `subosito/flutter-action` | `v2` | Setup Flutter SDK | Current stable. v2.21.0 is latest tag (June 2024), but `@v2` tracks latest v2.x. Auto-installs yq on Windows since v2.18.0. |
| `actions/setup-java` | `v5` | Java for Android builds | v5 supports cache v5 backend, Temurin/Zulu distributions. Required for Gradle. |
| `softprops/action-gh-release` | `v2` | Create GitHub releases | v2.5.0 (Dec 2024) is latest. Supports draft-until-complete, file glob uploads. |
| `bluefireteam/melos-action` | `v3` | Bootstrap monorepo | v3.5.0 (Feb 2026) latest. Auto-runs `melos bootstrap`, handles workspace setup. |
| `actions/cache` | `v5` | Cache dependencies | v5 required (Feb 2025 deprecation of old backend). 80% faster uploads, 10GB+ limit. |

### Flutter/Dart Versions

| Component | Version | Notes |
|-----------|---------|-------|
| Flutter SDK | `3.38.x` (stable) | Current stable. Supports iOS 26, Xcode 26, macOS 26. Impeller default on Android API 29+. |
| Dart SDK | `3.10.x` | Bundled with Flutter 3.38.x. Your project already requires `^3.10.0`. |

**Version Specification Strategy:**
```yaml
# Use channel: stable to get latest stable (currently 3.38.x)
- uses: subosito/flutter-action@v2
  with:
    channel: stable
    cache: true

# OR pin to specific version for reproducibility
- uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.38.6'
    cache: true
```

**Recommendation:** Use `channel: stable` for CI to automatically get security patches. Pin version only if you encounter breaking changes.

---

## Platform Requirements

### Android (APK)

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| Runner | `ubuntu-latest` | Ubuntu 24.04 as of Jan 2026 |
| Java | JDK 17 (Temurin) | Your project uses `JavaVersion.VERSION_17`. JDK 21 possible but may need gradle config changes. |
| Android SDK | Pre-installed on runner | No setup needed; flutter-action handles it |
| Gradle Cache | Enabled via setup-java | `cache: 'gradle'` for faster builds |

**Build Command:**
```bash
cd apps/android_provider && flutter build apk --release
```

**Output:** `apps/android_provider/build/app/outputs/flutter-apk/app-release.apk`

### macOS Desktop

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| Runner | `macos-latest` | Points to macOS 15 (since Aug 2025). ARM64 only for macos-26. |
| Xcode | Pre-installed (16.4 default) | No manual setup needed on macos-15 |
| Code Signing | Optional for sideloading | Skip for unsigned builds; add later if distributing via notarization |

**Build Command:**
```bash
cd apps/desktop_client && flutter build macos --release
```

**Output:** `apps/desktop_client/build/macos/Build/Products/Release/desktop_client.app`

**Packaging for Distribution:**
```bash
# Create a zip for the release artifact
cd apps/desktop_client/build/macos/Build/Products/Release
zip -r PhoneSync-macOS.zip "desktop_client.app"
```

### Windows Desktop

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| Runner | `windows-latest` | Windows Server 2022. Has VS 2022 Build Tools pre-installed. |
| Visual Studio | Pre-installed | Desktop C++ workload included |
| Flutter Windows | Enabled by default | Since Flutter 3.x |

**Build Command:**
```bash
cd apps/desktop_client && flutter build windows --release
```

**Output:** `apps/desktop_client/build/windows/x64/runner/Release/`

**Packaging for Distribution:**
```powershell
# Create a zip of the release folder
Compress-Archive -Path "apps/desktop_client/build/windows/x64/runner/Release/*" -DestinationPath "PhoneSync-Windows.zip"
```

### Linux Desktop (NEW)

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| Runner | `ubuntu-latest` | Ubuntu 24.04 |
| Dependencies | Must install manually | GTK3, Ninja, Clang, CMake |
| Flutter Linux | Enabled by default | Since Flutter 3.x |

**Required Dependencies:**
```bash
sudo apt-get update -y
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

**Build Command:**
```bash
cd apps/desktop_client && flutter build linux --release
```

**Output:** `apps/desktop_client/build/linux/x64/release/bundle/`

**Packaging for Distribution:**
```bash
# Create a tarball of the release bundle
cd apps/desktop_client/build/linux/x64/release
tar -czvf PhoneSync-Linux.tar.gz bundle/
```

---

## Version Compatibility Matrix

| Component | Minimum | Recommended | Maximum Tested |
|-----------|---------|-------------|----------------|
| Flutter SDK | 3.38.0 | 3.38.6 (stable) | 3.38.x |
| Dart SDK | 3.10.0 | 3.10.8 | 3.10.x |
| Java (Android) | 17 | 17 (Temurin) | 21 (with config) |
| Xcode (macOS) | 16.0 | 16.4 | 26.0 |
| Melos | 7.0.0 | 7.1.0 | 7.1.x |
| actions/checkout | v4 | v6 | v6 |
| actions/cache | v4 | v5 | v5 |
| actions/setup-java | v4 | v5 | v5 |

**Critical Compatibility Notes:**

1. **Melos 7.x requires Dart 3.6+** - Your project uses `^3.10.0`, so compatible.

2. **Your melos version is outdated**: `^7.0.0-dev.1` should be updated to `^7.1.0` (stable).

3. **Java 17 vs 21**: Your Android project is configured for Java 17. Keep using Java 17 in CI for consistency.

4. **macos-latest migration**: As of Aug 2025, `macos-latest` = macOS 15. If you need macOS 14, specify explicitly.

---

## Workflow Trigger Configuration

```yaml
on:
  push:
    tags:
      - 'v*.*.*'   # Matches v1.0.0, v2.1.3, etc.
    branches: []   # IMPORTANT: Prevents branch pushes from triggering
```

**Why This Pattern:**
- `v*.*.*` enforces semantic versioning (avoids triggering on `v1` or `v-beta`)
- `branches: []` explicitly disables branch triggers (otherwise `on: push` includes branches)
- Tag created locally, pushed with `git push origin v1.0.0`

---

## What to Avoid

### Actions to Skip

| Action/Approach | Why Avoid | Use Instead |
|-----------------|-----------|-------------|
| `actions/cache@v3` or older | Deprecated backend (Feb 2025). Workflows WILL fail. | `actions/cache@v5` |
| `actions/checkout@v4` or older | Missing security patches, slower | `actions/checkout@v6` |
| `actions/setup-java` with `adopt` distribution | AdoptOpenJDK discontinued, no updates | `temurin` distribution |
| Manual Flutter installation via shell | Slower, no caching, error-prone | `subosito/flutter-action@v2` |
| `flutter-actions/setup-flutter` | Less maintained than subosito | `subosito/flutter-action@v2` |
| Self-hosted runners for macOS | Complex, licensing issues | GitHub-hosted `macos-latest` |
| `macos-13` runner | Retired Dec 2025 | `macos-latest` (15) or `macos-14` |
| Intel macOS runners for Xcode 26 | Xcode 26 requires ARM64 | `macos-latest` (ARM64) |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Building all platforms in one job | Wastes minutes, slower | Parallel jobs per platform |
| Not caching Flutter/Gradle | 5-10 min wasted per build | Enable `cache: true` on actions |
| Using `flutter pub get` with melos | Redundant; melos bootstrap handles it | Just use `melos bootstrap` |
| Hardcoding Flutter version in workflow | Drift from local dev | Use `channel: stable` or `flutter-version-file` |
| Creating release before all builds complete | Partial releases | Use `draft: true`, finalize after all artifacts |

---

## Recommended Workflow Structure

```
.github/workflows/
  release.yml          # Main release workflow (tag trigger)
```

### Job Dependency Graph

```
[Tag Push v*.*.*]
        |
        v
  [build-android] ----+
  [build-macos]   ----+---> [create-release]
  [build-windows] ----+          |
  [build-linux]   ----+          v
                           [GitHub Release with 4 artifacts]
```

### Estimated Build Times (GitHub-hosted runners)

| Platform | Estimated Time | Notes |
|----------|---------------|-------|
| Android APK | 4-6 min | With Gradle cache |
| macOS | 5-8 min | Xcode compilation |
| Windows | 4-7 min | VS Build Tools |
| Linux | 3-5 min | Fastest (minimal deps) |
| **Total (parallel)** | **8-10 min** | All run simultaneously |

### GitHub Actions Minutes Usage (per release)

| Runner Type | Minutes | Cost (Free tier) |
|-------------|---------|------------------|
| Ubuntu (Android + Linux) | ~10 min | 1x multiplier |
| macOS | ~7 min | 10x multiplier = 70 min |
| Windows | ~6 min | 2x multiplier = 12 min |
| **Total per release** | ~92 min | Against 2000 free min/month |

**Note:** macOS runners are expensive (10x). For cost optimization, consider building macOS only on main releases, not pre-releases.

---

## Melos Integration

Your project uses Melos 7.x with workspaces. The workflow should:

1. **Use melos-action for bootstrap:**
```yaml
- uses: bluefireteam/melos-action@v3
  with:
    run-bootstrap: true
```

2. **Run melos scripts for analysis (optional CI step):**
```yaml
- run: melos run analyze
- run: melos run test
```

3. **Build specific apps directly:**
```yaml
# Don't use melos exec for builds - run directly in app directory
- run: cd apps/android_provider && flutter build apk --release
```

**Why not `melos exec` for builds?** Platform-specific builds only run on one platform. `melos exec` is for commands that should run across all packages.

---

## Environment Variables and Secrets

| Secret/Variable | Purpose | Required For |
|-----------------|---------|--------------|
| `GITHUB_TOKEN` | Create releases, upload artifacts | Auto-provided by GitHub |
| (none others needed) | Sideloading doesn't require signing secrets | All platforms |

**Future Secrets (if adding store distribution):**
- `ANDROID_KEYSTORE_BASE64` - For signed APKs
- `APPLE_CERTIFICATES` - For macOS notarization
- `APPLE_API_KEY` - For App Store Connect

---

## Complete Action Version Reference

| Action | Pin Version | Notes |
|--------|-------------|-------|
| `actions/checkout` | `@v6` | Latest stable, Dec 2025 |
| `actions/cache` | `@v5` | Required, old versions deprecated |
| `actions/setup-java` | `@v5` | With Temurin distribution |
| `actions/upload-artifact` | `@v4` | For inter-job artifact sharing |
| `actions/download-artifact` | `@v4` | Pair with upload-artifact |
| `subosito/flutter-action` | `@v2` | Tracks v2.x releases |
| `bluefireteam/melos-action` | `@v3` | Latest stable, Feb 2026 |
| `softprops/action-gh-release` | `@v2` | v2.5.0 latest |

---

## Sources

### Official Documentation
- [Flutter Deployment - Windows](https://docs.flutter.dev/deployment/windows) - Flutter 3.38.6 docs, updated Sept 2025
- [Flutter Deployment - macOS](https://docs.flutter.dev/deployment/macos) - Updated Oct 2025
- [Flutter macOS Setup](https://docs.flutter.dev/platform-integration/macos/setup) - Updated Jan 2026

### GitHub Actions/Marketplace
- [actions/checkout](https://github.com/actions/checkout) - v6.0.1, Dec 2025
- [actions/setup-java](https://github.com/actions/setup-java) - v5, Temurin support
- [actions/cache](https://github.com/actions/cache) - v5 required since Feb 2025
- [subosito/flutter-action](https://github.com/subosito/flutter-action) - v2.21.0+
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - v2.5.0
- [bluefireteam/melos-action](https://github.com/bluefireteam/melos-action) - v3.5.0

### GitHub Changelog
- [macOS-latest Migration](https://github.blog/changelog/2025-07-11-upcoming-changes-to-macos-hosted-runners-macos-latest-migration-and-xcode-support-policy-updates/) - July 2025
- [macOS 26 Image Preview](https://github.blog/changelog/2025-09-11-actions-macos-26-image-now-in-public-preview/) - Sept 2025
- [Cache Size Increase](https://github.blog/changelog/2025-11-20-github-actions-cache-size-can-now-exceed-10-gb-per-repository/) - Nov 2025
- [Cache Deprecation Notice](https://github.com/actions/cache/discussions/1510) - Feb 2025

### Flutter Release Notes
- [Flutter 3.38 Release Notes](https://docs.flutter.dev/release/release-notes/release-notes-3.38.0) - Nov 2025
- [What's New in Flutter 3.38](https://blog.flutter.dev/whats-new-in-flutter-3-38-3f7b258f9228) - Official blog

### Melos
- [Melos Documentation](https://melos.invertase.dev/) - Official docs
- [Melos 7.1.0 Changelog](https://pub.dev/packages/melos/versions/7.1.0/changelog) - Pub.dev
- [Melos Action](https://github.com/bluefireteam/melos-action) - GitHub

### Tutorials and Guides
- [Automating Flutter Android Builds with GitHub Actions](https://medium.com/@abhayshankur/automating-flutter-android-builds-with-github-actions-77c172653525) - Dec 2025
- [How to distribute Flutter Desktop app binaries using GitHub Actions](https://angeloavv.medium.com/how-to-distribute-flutter-desktop-app-binaries-using-github-actions-f8d0f9be4d6b) - Medium
- [Flutter CI/CD with GitHub Actions](https://blog.logrocket.com/flutter-ci-cd-using-github-actions/) - LogRocket
