# Project Research Summary

**Project:** jljm-phonesync
**Domain:** GitHub Actions CI/CD for Flutter multi-platform releases
**Milestone:** v1.1 - Automated release pipeline
**Researched:** 2026-02-04
**Confidence:** HIGH

## Executive Summary

Building a multi-platform Flutter release pipeline requires a single GitHub Actions workflow with parallel platform-specific jobs, unified artifact handling, and explicit job dependencies. The recommended pattern uses tag-triggered builds (v*.*.*) that spawn 4 parallel build jobs (Android on ubuntu-latest, macOS on macos-latest, Windows on windows-latest, Linux on ubuntu-latest), each uploading uniquely-named artifacts to a final release job that creates a GitHub Release with all platform binaries.

The technology stack is mature and well-documented: GitHub Actions with v5+ cache actions (v4 deprecated), subosito/flutter-action@v2 with built-in caching, Flutter 3.38.x stable, Java 17 for Android, and softprops/action-gh-release@v2 for release automation. Each platform has specific requirements: Android needs Java 17 with Gradle 8.x, Linux requires manual dependency installation (clang, cmake, ninja-build, libgtk-3-dev), and macOS builds consume 10x GitHub Actions minutes due to runner costs.

Critical risks include Java/Gradle version mismatches breaking Android builds, missing Linux dependencies causing CMake failures, and macOS certificate validation issues on macos-15 runners. Prevention strategies: explicitly set Java 17 via actions/setup-java, install Linux dependencies before Flutter build, and pin to macos-14 until certificate issues are resolved. The pipeline should prioritize unsigned builds for sideloading initially, deferring Android signing and macOS notarization to later phases once basic automation works.

## Key Findings

### Recommended Stack

The research identifies a battle-tested CI/CD stack using GitHub-hosted runners and official Flutter actions. The core pattern uses actions/checkout@v6 (Node.js 24, latest security patches), subosito/flutter-action@v2 (built-in Flutter/pub caching), actions/setup-java@v5 (Temurin JDK 17), actions/cache@v5 (required, v4 deprecated Feb 2025), and softprops/action-gh-release@v2 (draft releases, multi-artifact uploads). Flutter 3.38.x stable (channel: stable) with bundled Dart 3.10.x matches project requirements. Melos 7.1.0 via bluefireteam/melos-action@v3 handles monorepo bootstrap.

**Core technologies:**
- **Flutter SDK 3.38.x stable** — current stable with Impeller default, supports all target platforms; use `channel: stable` for automatic security patches
- **Java 17 (Temurin)** — required for Android Gradle 8.x builds; explicitly set to avoid version drift
- **GitHub Actions (v5+ actions)** — cache v5 required (80% faster, 10GB+ limit), v6 checkout (Node.js 24); old versions deprecated
- **subosito/flutter-action@v2** — official Flutter environment with built-in pub/SDK caching; eliminates manual cache configuration
- **softprops/action-gh-release@v2** — standard release automation with draft support and file glob uploads; handles multi-artifact releases cleanly
- **Melos 7.1.0** — monorepo workspace management already configured; use for bootstrap, skip melos exec for platform builds

**Version compatibility notes:**
- Melos 7.x requires Dart 3.6+ (project uses ^3.10.0, compatible)
- Java 17 matches android/app/build.gradle JavaVersion.VERSION_17
- macos-latest = macOS 15 as of Aug 2025 (has certificate issues, pin to macos-14)
- actions/cache@v4 deprecated Feb 2025, must use v5

### Expected Features

Release automation for Flutter follows a standard pattern: tag-triggered builds are the industry norm, multi-platform parallel builds are expected, SDK/dependency caching prevents 5-10 minute delays, and GitHub Releases provide artifact hosting. Android signing is table stakes (unsigned APKs won't install on most devices), while macOS code signing and notarization are differentiators that eliminate Gatekeeper warnings but add significant complexity (Apple Developer Program, certificate handling, notarization API).

**Must have (table stakes):**
- Tag-triggered builds — standard `on: push: tags: ["v*.*.*"]` pattern users expect
- Multi-platform matrix — build Android APK, macOS app, Windows app, Linux app in parallel
- Flutter SDK caching — `cache: true` in flutter-action prevents 5+ min SDK downloads
- GitHub Release creation — users expect downloadable artifacts on Releases page
- Artifact upload — all platform builds attached to release with unique names
- Version extraction from tag — release name/version matches git tag

**Should have (competitive):**
- Changelog generation — `generate_release_notes: true` auto-generates from commits
- Pre-release handling — pattern match on `-rc`, `-beta` tags, set `prerelease: true`
- Draft releases — `draft: true` allows review before publishing
- Artifact checksums — SHA256 for each binary for security verification
- Build metadata — include git SHA, build date for debugging production issues

**Defer (v2+):**
- Android signed APKs — requires keystore secrets, base64 encoding (defer until unsigned pipeline works)
- macOS code signing — requires Apple Developer Program ($99/yr), certificate handling, adds 5-10 min
- macOS notarization — requires Apple ID, app-specific password, team ID (complex setup)
- DMG creation for macOS — professional packaging adds 2-3 min, use raw .app zip initially
- Windows MSIX signing — requires certificate, similar complexity to macOS signing
- Linux AppImage — universal package format, defer to v2 (tar.gz sufficient initially)
- Store publishing — Play Store, Mac App Store add API keys, review processes (not needed for direct distribution)
- Melos version automation — conventional commits + `melos version` (overkill for small team)

### Workflow Architecture

The workflow architecture uses a single file (.github/workflows/release.yml) with 6 jobs: one test job, four platform-specific build jobs, and one release job. This pattern enables job synchronization via `needs: [build-android, build-macos, build-windows, build-linux]`, artifact passing via upload-artifact@v4/download-artifact@v4, single trigger point (tag push), and automatic failure handling (release skipped if any build fails). Separate jobs are preferred over matrix strategy because different apps (android_provider vs desktop_client), different build commands (apk/macos/windows/linux), different artifact paths, and different dependencies per platform make matrices complex. Builds run in parallel after test passes, then release waits for all builds.

**Major components:**
1. **Test job** (ubuntu-latest) — runs `melos bootstrap`, `melos run analyze`, `melos run test` before any builds start
2. **Build jobs** (platform-native runners) — each uses `defaults.run.working-directory` to target correct app, runs `flutter build [platform]`, packages output (zip/tar.gz), uploads with unique artifact name
3. **Release job** (ubuntu-latest) — downloads all artifacts with `merge-multiple: true`, creates GitHub Release with `softprops/action-gh-release@v2`, uploads all binaries

**Artifact flow pattern:**
```
build-android → [android-apk]
build-macos   → [macos-app]      → download (merge) → release job → GitHub Release
build-windows → [windows-app]
build-linux   → [linux-app]
```

**Critical v4 change:** Each artifact name must be unique (cannot upload to same name from multiple jobs). Use descriptive names: `android-apk`, `macos-app`, `windows-app`, `linux-app`.

### Critical Pitfalls

The top pitfalls break builds or cause silent failures: Java/Gradle version mismatches cause "Unsupported class file major version" errors (Flutter 3.38+ requires Java 17, explicitly set via actions/setup-java@v5 with Temurin distribution). Missing Linux dependencies cause "CMake was unable to find Ninja" errors (ubuntu runners don't include GTK3/Ninja, must `apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` before flutter build linux). macOS certificate validation fails intermittently on macos-15 runners (pin to macos-14 or implement proper keychain setup). Android keystore misconfiguration results in unsigned APKs (base64 encode keystore, decode in workflow, pass passwords via environment variables).

1. **Java/Gradle version mismatch** — explicitly set Java 17 via `actions/setup-java@v5` with `distribution: temurin`, verify Gradle wrapper uses 8.x, Android Studio Flamingo+ bundles Java 17 but CI may differ
2. **Missing Linux build dependencies** — install BEFORE flutter build: `sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`
3. **Building platform on wrong runner** — macOS MUST use macos-latest, Windows MUST use windows-latest, Linux/Android use ubuntu-latest
4. **macOS certificate validation on macos-15** — pin to `macos-14` until certificate issues resolved, or implement proper temporary keychain setup
5. **Artifact name collisions in v4** — use unique artifact names per platform, download with `merge-multiple: true` in release job
6. **Release job running before builds complete** — use `needs: [build-android, build-macos, build-windows, build-linux]` to wait for all
7. **Not setting workflow timeouts** — set `timeout-minutes: 30` per job to prevent stuck builds consuming minutes (macOS at 10x multiplier)
8. **Not caching dependencies** — enable `cache: true` in flutter-action to avoid 5-10 min SDK downloads per build

## Implications for Roadmap

Based on research, the implementation should follow a 3-phase approach: basic unsigned releases first, Android signing second, advanced packaging third. This ordering validates the core pipeline before adding signing complexity and minimizes risk.

### Phase 1: Basic Multi-Platform Release Pipeline
**Rationale:** Establish the foundational workflow structure and validate tag-triggered builds work for all platforms before adding signing complexity. Unsigned builds are sufficient for sideloading and internal testing.

**Delivers:** Tag-triggered release pipeline that builds unsigned Android APK, macOS .app (zipped), Windows executable (zipped), Linux bundle (tar.gz) and uploads all to GitHub Release with auto-generated release notes.

**Addresses:**
- Table stakes: tag-triggered builds, multi-platform matrix, Flutter SDK caching, GitHub Release creation, artifact upload
- Workflow architecture: single file with parallel jobs, artifact flow, job dependencies
- Cost awareness: parallel builds minimize wall time, caching reduces minutes usage

**Avoids:**
- Java/Gradle mismatch by explicitly setting Java 17 in Android job
- Linux dependency errors by installing clang/cmake/ninja-build/libgtk-3-dev before build
- Platform runner mismatch by using correct runs-on per platform
- macOS certificate issues by pinning to macos-14 initially
- Artifact collisions by using unique names per platform

**Implementation notes:**
- Single workflow file: `.github/workflows/release.yml`
- Trigger: `on: push: tags: ["v*.*.*"]`
- Jobs: test → [build-android, build-macos, build-windows, build-linux] → release
- Each build job sets `working-directory` to correct app (android_provider vs desktop_client)
- Cache strategy: `cache: true` in subosito/flutter-action@v2
- Set `timeout-minutes: 30` per job
- Use `generate_release_notes: true` for automatic changelogs

### Phase 2: Android Signing
**Rationale:** After validating the basic pipeline works, add Android signing to produce installable APKs. This is the highest-priority signing need because unsigned Android APKs won't install on most devices.

**Delivers:** Signed Android APK releases using keystore secrets, ready for direct distribution.

**Uses:**
- Keystore base64 encoding pattern from PITFALLS-CICD.md
- Environment variable pattern for KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
- Existing android/app/build.gradle signingConfigs

**Addresses:**
- Table stakes: signed Android APK (unsigned won't install on most devices)
- Secret management: KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD

**Avoids:**
- Keystore misconfiguration by validating base64 encoding/decoding works locally first
- Committing secrets by using GitHub Secrets properly
- Silent unsigned builds by verifying signingConfig applied in build.gradle

**Implementation notes:**
- Decode keystore before flutter build: `echo "$KEYSTORE_BASE64" | base64 --decode > android/app/keystore.jks`
- Pass secrets via environment variables to match build.gradle expectations
- Test locally first: generate keystore, encode, decode, build signed APK
- Update build.gradle to read from environment if not already configured

### Phase 3: Advanced Packaging (Optional)
**Rationale:** Improve distribution experience with professional packaging formats. This is optional because raw .app zips and .zip/.tar.gz bundles work for direct distribution, but DMG/AppImage provide better UX.

**Delivers:** macOS DMG (unsigned initially), Linux AppImage, improved Windows packaging.

**Uses:**
- `create-dmg` tool for macOS DMG creation
- AppImage tools for Linux universal package
- Existing platform build outputs as source

**Addresses:**
- Differentiators: professional packaging formats
- User experience: easier installation, better first impression

**Defers:**
- macOS code signing and notarization (complex, requires Apple Developer Program)
- Windows MSIX signing (complex, requires certificate)
- Store publishing (not needed for direct distribution)

**Implementation notes:**
- Add packaging steps to build jobs after flutter build
- DMG creation adds 2-3 min to macOS build
- AppImage tools available via apt-get on ubuntu-latest
- Can iterate on packaging without affecting core pipeline

### Phase Ordering Rationale

- **Phase 1 first** because it establishes the core workflow structure and validates all platform builds work without signing complexity. Unsigned builds are sufficient for sideloading and internal testing. This allows catching workflow structure issues (job dependencies, artifact flow, runner selection) early.

- **Phase 2 second** because Android signing is the highest-priority enhancement (unsigned APKs won't install on most devices), and the implementation is well-documented with clear prevention strategies from PITFALLS-CICD.md. Android signing is lower complexity than macOS signing (no notarization, no Apple Developer Program required).

- **Phase 3 deferred** because DMG/AppImage are nice-to-have packaging improvements, not blockers. Raw .app zips and tar.gz bundles work for direct distribution. This phase can be added later based on user feedback about installation UX.

- **Code signing deferred** because macOS notarization and Windows MSIX signing require external accounts (Apple Developer Program, certificate authorities), add 5-10 minutes to builds, and introduce failure modes (certificate expiration, notarization timeouts). Unsigned builds work for sideloading initially; add signing only if users report Gatekeeper/SmartScreen issues.

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Well-documented in Flutter official docs and GitHub Actions marketplace. All actions have recent updates (2024-2026) and active maintenance. Pattern used by thousands of Flutter projects.
- **Phase 2:** Android signing in CI is a solved problem with multiple tutorials. Keystore handling pattern is standardized.
- **Phase 3:** DMG creation and AppImage packaging have established tooling (create-dmg, appimagetool) with clear documentation.

**No phases require deeper research.** The research phase has already validated all technical approaches with official documentation (Flutter docs, GitHub Actions marketplace) and verified real-world usage patterns. Implementation can proceed directly to roadmap creation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All actions verified with GitHub Marketplace (subosito/flutter-action v2.21.0, softprops/action-gh-release v2.5.0, actions/cache v5 required). Flutter 3.38.x stable is current. Version compatibility matrix cross-verified with official docs. |
| Features | HIGH | Table stakes identified from Flutter CD docs and established CI/CD patterns. Differentiators based on community best practices (20+ Medium articles, GitHub discussions). Anti-features clearly scoped (no iOS target, no store publishing needed). |
| Architecture | HIGH | Single workflow pattern verified with official GitHub Actions docs on job dependencies. Artifact flow pattern documented in actions/upload-artifact@v4 migration guide. Platform runner requirements from Flutter platform setup docs. |
| Pitfalls | HIGH | Java/Gradle mismatch verified via Flutter issue #168896 and Android migration guide. Linux dependencies from Flutter Linux setup docs. macOS certificate issues from GitHub runner-images issues #12960, #12861 (current as of Jan 2026). All pitfalls have verified prevention strategies. |

**Overall confidence:** HIGH

The research combines official documentation (Flutter 3.38.6 docs, GitHub Actions docs, action marketplace listings) with verified community patterns (20+ tutorials, GitHub issues with maintainer responses, runner-images issue tracker). All recommended actions have recent updates (2024-2026) and active maintenance. Version compatibility matrix cross-referenced across multiple sources. Pitfalls validated with specific GitHub issue numbers and official migration guides.

### Gaps to Address

**Cost monitoring:** GitHub Actions minutes usage estimation (92 min per release with macOS 10x multiplier) needs validation during first release. Monitor actual usage and adjust caching strategy if approaching free tier limits (2000 min/month). Consider building macOS less frequently if costs become an issue.

**macOS certificate validation:** macos-15 certificate issues documented in runner-images tracker (issues #12960, #12861) as of Jan 2026. Current recommendation is to pin to macos-14. Monitor runner-images repo for resolution and migrate to macos-15 when stable. Alternative: implement proper temporary keychain setup (adds complexity).

**Melos version update:** Project uses `melos ^7.0.0-dev.1` which is a dev version. Update to stable `^7.1.0` before implementing CI (noted in STACK-CICD.md compatibility matrix). Verify melos scripts (analyze, test) work with stable version locally before running in CI.

**Android keystore location:** Project structure doesn't show existing android/app/keystore.jks or android/key.properties. Phase 2 requires generating a release keystore and configuring build.gradle signingConfigs. This is a prerequisite for Phase 2, not a research gap.

## Sources

### Primary (HIGH confidence)
- [Flutter Deployment - Windows](https://docs.flutter.dev/deployment/windows) — Flutter 3.38.6 docs, updated Sept 2025
- [Flutter Deployment - macOS](https://docs.flutter.dev/deployment/macos) — Updated Oct 2025
- [Flutter macOS Setup](https://docs.flutter.dev/platform-integration/macos/setup) — Updated Jan 2026
- [Flutter Linux Setup](https://docs.flutter.dev/platform-integration/linux/setup) — Linux dependencies
- [Flutter Android Java Gradle Migration Guide](https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide) — Official migration guide
- [Flutter 3.38 Release Notes](https://docs.flutter.dev/release/release-notes/release-notes-3.38.0) — Nov 2025
- [GitHub Actions Workflow Syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) — Official docs
- [GitHub Actions: Using jobs in a workflow](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/using-jobs-in-a-workflow) — Job dependencies
- [GitHub Actions Runner Pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing) — Cost multipliers
- [actions/checkout v6.0.1](https://github.com/actions/checkout) — Dec 2025
- [actions/cache v5](https://github.com/actions/cache) — Required Feb 2025
- [actions/setup-java v5](https://github.com/actions/setup-java) — Temurin support
- [actions/upload-artifact v4](https://github.com/actions/upload-artifact) — Artifact changes
- [subosito/flutter-action v2](https://github.com/subosito/flutter-action) — v2.21.0
- [softprops/action-gh-release v2](https://github.com/softprops/action-gh-release) — v2.5.0
- [bluefireteam/melos-action v3](https://github.com/bluefireteam/melos-action) — v3.5.0

### Secondary (MEDIUM confidence)
- [Flutter Issue #168896](https://github.com/flutter/flutter/issues/168896) — Java/Gradle mismatch
- [Flutter Issue #59750](https://github.com/flutter/flutter/issues/59750) — CMake/Ninja missing
- [Flutter Issue #121052](https://github.com/flutter/flutter/issues/121052) — APK differences across OS
- [Flutter Issue #130343](https://github.com/flutter/flutter/issues/130343) — GTK dependencies
- [GitHub Runner Images #12960](https://github.com/actions/runner-images/issues/12960) — macOS 15 cert issues
- [GitHub Runner Images #12861](https://github.com/actions/runner-images/issues/12861) — Intermittent cert errors
- [GitHub Community Discussion #27028](https://github.com/orgs/community/discussions/27028) — GITHUB_TOKEN triggers
- [macOS-latest Migration](https://github.blog/changelog/2025-07-11-upcoming-changes-to-macos-hosted-runners-macos-latest-migration-and-xcode-support-policy-updates/) — July 2025
- [Medium: Automating Flutter Android Builds](https://medium.com/@abhayshankur/automating-flutter-android-builds-with-github-actions-77c172653525) — Dec 2025
- [Angelo Cassano: Flutter Desktop GitHub Actions](https://angeloavv.medium.com/how-to-distribute-flutter-desktop-app-binaries-using-github-actions-f8d0f9be4d6b) — Community guide
- [ProAndroidDev: Secure Android Signing](https://proandroiddev.com/how-to-securely-build-and-sign-your-android-app-with-github-actions-ad5323452ce) — Community tutorial
- [Revelo: Reduce Flutter CI Time by 20%](https://www.revelo.com/blog/how-we-reduced-our-flutter-ci-execution-time-by-around-20) — Caching strategies

---
*Research completed: 2026-02-04*
*Ready for roadmap: yes*
