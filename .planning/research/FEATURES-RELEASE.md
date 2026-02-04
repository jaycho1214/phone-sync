# Features Research: Release Automation

**Domain:** GitHub Actions CI/CD for Flutter Multi-Platform Releases
**Researched:** 2026-02-04
**Confidence:** HIGH (verified with official docs and established patterns)

## Table Stakes

Features users expect from any Flutter release automation. Missing these means the pipeline feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Tag-triggered builds | Standard release pattern; `on: push: tags: ["v*"]` | Low | Use `push` event with tag filter, not `release` event |
| Multi-platform matrix | Build all targets (Android, macOS, Windows, Linux) in parallel | Low | Each platform needs its own runner OS |
| Flutter SDK caching | Every CI expects dependency caching to avoid 5+ min SDK downloads | Low | `subosito/flutter-action` has built-in `cache: true` |
| Signed Android APK | Unsigned APKs won't install on most devices | Medium | Requires keystore base64 encoding, secrets management |
| GitHub Release creation | Users expect downloadable artifacts on GitHub Releases page | Low | `softprops/action-gh-release` is the standard |
| Artifact upload to release | All built artifacts attached to the GitHub Release | Low | Use glob patterns in `files` input |
| Version extraction from tag | Release name/version should match the git tag | Low | `github.ref_name` gives you `v1.0.0` directly |
| Build failure notifications | Know when releases fail | Low | GitHub's built-in email notifications suffice |
| Pub dependency caching | Cache `~/.pub-cache` to speed up `flutter pub get` | Low | Standard Actions cache or flutter-action built-in |

## Differentiators

Nice-to-have automation that improves DX but isn't strictly required for functional releases.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Changelog generation | Auto-generate release notes from commits | Medium | `softprops/action-gh-release` has `generate_release_notes: true` |
| macOS code signing | Required for non-Gatekeeper-blocked distribution | High | Apple Developer Program ($99/yr), certificate handling, notarization |
| macOS notarization | Apps pass Gatekeeper without warnings | High | Requires Apple ID, app-specific password, team ID |
| Windows MSIX signing | Required for Microsoft Store or trusted installs | High | Similar complexity to macOS signing |
| DMG creation for macOS | Professional packaging vs raw .app bundle | Medium | Use `create-dmg` tool, adds 2-3 min to build |
| Linux AppImage | Universal Linux package format | Medium | AppImage tools available, good portability |
| Pre-release handling | Automatic pre-release flag for `-rc`, `-beta` tags | Low | Pattern match on tag, set `prerelease: true` |
| Draft releases | Review before publishing | Low | `draft: true` in gh-release action |
| Build number from run | Auto-increment build numbers via `github.run_number` | Low | Useful for tracking builds without manual version bumps |
| Melos integration | Monorepo versioning with conventional commits | Medium | Already using Melos; can add `melos version` |
| Artifact checksums | SHA256 for each artifact | Low | Simple `sha256sum` commands |
| Build metadata | Include git SHA, build date in artifacts | Low | Useful for debugging production issues |

## Anti-Features

Things to deliberately NOT build. These add complexity without proportional value or introduce maintenance burden.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Automatic version bumping from commits | Complex semantic-release setup, easy to break, overkill for small team | Use manual tags; Melos can help if needed later |
| iOS builds | You have no iOS target in this project | Skip entirely; don't add "just in case" |
| Store publishing (Play Store, Mac App Store) | High complexity (API keys, review processes), not needed for direct distribution | Distribute via GitHub Releases |
| Parallel package publishing to pub.dev | These are private apps, not packages | `publish_to: 'none'` is already set correctly |
| Complex matrix with multiple Flutter versions | One Flutter version is sufficient for release builds | Only test multiple versions in PR CI, not release |
| Self-hosted runners | Security risks, maintenance burden | Use GitHub-hosted runners |
| Artifact storage beyond GitHub Releases | S3/GCS hosting adds complexity | GitHub Releases provides sufficient hosting |
| Slack/Discord notifications | Adds integration maintenance | GitHub email notifications are sufficient |
| Automatic rollback on failure | Releases are immutable; just fix forward | Create new release if issues found |
| Windows Store publishing | Complex certification process, not needed for direct distribution | Distribute MSIX or ZIP via GitHub Releases |
| Linux Snap/Flatpak publishing | Store submission adds complexity | AppImage or tar.gz via GitHub Releases |

## Common Patterns

How established Flutter projects handle release automation.

### Pattern 1: Tag-Triggered Matrix Build

The most common pattern for multi-platform Flutter releases.

```yaml
on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          cache: true
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-macos:
    runs-on: macos-latest
    # Similar pattern...

  build-windows:
    runs-on: windows-latest
    # Similar pattern...

  build-linux:
    runs-on: ubuntu-latest
    # Similar pattern...

  release:
    needs: [build-android, build-macos, build-windows, build-linux]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            android-apk/*
            macos-app/*
            windows-app/*
            linux-app/*
```

### Pattern 2: Keystore Handling for Android Signing

Standard pattern for secure Android signing in CI.

```yaml
- name: Decode Keystore
  env:
    KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
  run: echo $KEYSTORE_BASE64 | base64 -d > android/app/keystore.jks

- name: Create key.properties
  run: |
    echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" > android/key.properties
    echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
    echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/key.properties
    echo "storeFile=keystore.jks" >> android/key.properties
```

### Pattern 3: Version from Tag

Extract version from git tag for use in build.

```yaml
- name: Get version from tag
  id: version
  run: echo "VERSION=${GITHUB_REF_NAME#v}" >> $GITHUB_OUTPUT

# Use: ${{ steps.version.outputs.VERSION }}
```

### Pattern 4: Monorepo App Selection

Build specific app from monorepo structure.

```yaml
- name: Build Android Provider
  working-directory: apps/android_provider
  run: flutter build apk --release

- name: Build Desktop Client
  working-directory: apps/desktop_client
  run: flutter build macos --release
```

### Pattern 5: Conditional macOS Signing

Only sign when certificates are available.

```yaml
- name: Sign macOS App
  if: secrets.MACOS_CERTIFICATE != ''
  run: |
    # Decode certificate
    # Import to keychain
    # Sign app
    # Notarize
```

## Recommended Phase Structure

Based on feature complexity and dependencies:

### Phase 1: Basic Release Pipeline (Table Stakes)
- Tag-triggered workflow
- Build all 4 platforms in parallel
- Upload unsigned artifacts to GitHub Release
- SDK caching

### Phase 2: Android Signing
- Keystore secrets setup
- Signed APK builds
- key.properties generation

### Phase 3: Desktop Packaging (Optional)
- macOS DMG creation (unsigned initially)
- Windows ZIP packaging
- Linux tar.gz or AppImage

### Phase 4: Code Signing (If Needed)
- macOS Developer ID signing
- macOS notarization
- Windows MSIX signing

**Recommendation:** Start with Phase 1-2. Phase 3-4 can be deferred unless users report Gatekeeper/SmartScreen issues.

## Project-Specific Considerations

Based on the existing codebase structure:

| Aspect | Finding | Implication |
|--------|---------|-------------|
| Melos monorepo | Already configured with `apps/*` and `packages/*` | Can use `working-directory` in workflow; Melos scripts available |
| Two apps | `android_provider` and `desktop_client` | Need separate build jobs or matrix for each |
| Shared package | `packages/core` | Bootstrap via Melos before building apps |
| Flutter 3.10.x | SDK version constraint in pubspec | Pin version in `subosito/flutter-action` |
| No existing CI | `.github/workflows` doesn't exist | Clean slate for implementation |

## Sources

- [Flutter Official: Continuous Delivery](https://docs.flutter.dev/deployment/cd)
- [subosito/flutter-action](https://github.com/subosito/flutter-action) - Flutter environment for GitHub Actions
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - GitHub Release creation
- [GitHub Actions Workflow Syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)
- [Melos Action](https://github.com/marketplace/actions/melos-action) - Melos integration for GitHub Actions
- [Flutter Desktop Distribution Guide](https://medium.com/fludev/packaging-distributing-flutter-desktop-apps-a-complete-guide-for-macos-windows-and-linux-4a115085195e)
- [Android Signing in GitHub Actions](https://damienaicheh.github.io/flutter/github/actions/2021/04/29/build-sign-flutter-android-github-actions-en.html)
- [macOS Code Signing Automation](https://federicoterzi.com/blog/automatic-code-signing-and-notarization-for-macos-apps-using-github-actions/)
- [GitHub Actions CI/CD Best Practices](https://github.com/github/awesome-copilot/blob/main/instructions/github-actions-ci-cd-best-practices.instructions.md)
- [Fastforge (Flutter Distributor)](https://github.com/fastforgedev/fastforge) - All-in-one packaging tool
