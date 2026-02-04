<div align="center">

<img src=".github/logo.png" alt="PhoneSync" width="128" height="128">

# PhoneSync

**Extract your Android phone data to Excel. On your terms.**

[한국어](README.ko.md)

---

</div>

## The Problem

Your phone holds years of contacts, messages, and call history. Getting that data out shouldn't require:

- Cloud accounts you don't trust
- Expensive backup software
- Technical knowledge of ADB commands
- Sending your personal data through third-party servers

## The Solution

PhoneSync creates a **direct, encrypted connection** between your Android phone and your computer over your local WiFi network. No cloud. No accounts. No middleman.

```
┌─────────────┐         WiFi (TLS)         ┌─────────────┐
│   Android   │ ◄──────────────────────► │   Desktop   │
│   (Server)  │     PIN Authentication     │   (Client)  │
└─────────────┘                            └─────────────┘
                                                  │
                                                  ▼
                                           ┌─────────────┐
                                           │    .xlsx    │
                                           │   Export    │
                                           └─────────────┘
```

## Who Should Use This

| You should use PhoneSync if... | You probably don't need this if... |
|-------------------------------|-----------------------------------|
| You want a local backup of phone data | You're happy with Google/Samsung backup |
| You need data in Excel for analysis | You just need contact sync |
| You distrust cloud backup services | You don't mind third-party access |
| You're migrating phones and want records | You've never needed your SMS history |
| You work with Korean phone numbers (010-xxxx) | N/A |

## Features

### What Gets Exported

| Data Type | Fields |
|-----------|--------|
| **Contacts** | Name, all phone numbers, emails |
| **SMS** | Sender/recipient, message body, timestamp, type (sent/received) |
| **Call Log** | Number, duration, timestamp, type (incoming/outgoing/missed) |

### Smart Filtering

- **Korean Mobile Only**: Filter to 010-xxxx-xxxx numbers (skip landlines, international)
- **Date Range**: Export only messages/calls after a specific date
- **Selective Export**: Choose which data types to include

### Security

- **PIN Pairing**: 6-digit code expires in 5 minutes
- **TLS Encryption**: All data transferred over HTTPS
- **Local Network**: Never leaves your WiFi
- **No Persistence**: Android app holds no exported data

## Download

Get the latest release from [GitHub Releases](https://github.com/jljm/phone-sync/releases):

| Platform | Download |
|----------|----------|
| Android | `android_provider-x.x.x.apk` |
| Windows | `desktop_client-windows-x.x.x.zip` |
| Linux | `desktop_client-linux-x.x.x.tar.gz` |

**macOS**: Requires local build (Apple Developer certificate needed for distribution). See [Building from Source](#building-from-source).

## Quick Start

### Requirements

- **Android phone** (API 23+ / Android 6.0+) — iOS is not supported
- Windows or Linux computer (macOS requires local build)
- Both devices on the same WiFi network

### Setup

1. **Install the Android app** on your phone
2. **Install the Desktop app** on your computer
3. **Grant permissions** when prompted on Android (Contacts, SMS, Phone)
4. **Enter the PIN** shown on your phone into the desktop app
5. **Export** — select what you want and save to Excel

## Architecture

```
phone-sync/
├── apps/
│   ├── android_provider/     # Flutter Android app (HTTPS server)
│   │   ├── lib/
│   │   │   ├── services/     # Contacts, SMS, Call extraction
│   │   │   ├── providers/    # Riverpod state management
│   │   │   └── screens/      # UI
│   │   └── ...
│   │
│   └── desktop_client/       # Flutter desktop app (HTTPS client)
│       ├── lib/
│       │   ├── services/     # mDNS discovery, sync, export
│       │   ├── providers/    # Session, export state
│       │   └── screens/      # Discovery, pairing, home
│       └── ...
```

### Tech Stack

- **Framework**: Flutter 3.x
- **State**: Riverpod 2.x
- **Server**: Shelf (self-signed TLS)
- **Discovery**: mDNS/DNS-SD via `nsd` package
- **Export**: `excel` package for .xlsx generation

## Building from Source

```bash
# Clone
git clone https://github.com/jljm/phone-sync.git
cd phone-sync

# Android
cd apps/android_provider
flutter pub get
flutter build apk --release

# Desktop (Windows)
cd apps/desktop_client
flutter pub get
flutter build windows --release

# Desktop (Linux)
flutter build linux --release

# Desktop (macOS) - requires local build
flutter build macos --release
```

## FAQ

**Q: Why does the Android app run a server instead of the desktop?**

Mobile networks and firewalls make incoming connections to desktops unreliable. Running the server on Android with mDNS advertisement ensures the desktop can always find and connect to the phone.

**Q: Is my data safe?**

Your data never leaves your local network. The connection uses TLS encryption with a self-signed certificate. The PIN ensures only your desktop can connect.

**Q: Why Excel format?**

Excel (.xlsx) is universally readable, works offline, and lets you sort/filter/search your data however you want. No proprietary format lock-in.

**Q: Can I export incrementally?**

Yes. Use the date filter to export only new messages/calls since your last export.

**Q: Why no macOS release?**

Apple requires a $99/year Developer certificate to distribute macOS apps. You can build locally using `flutter build macos --release`.

---

<div align="center">

**PhoneSync** — Your data. Your network. Your file.

</div>
