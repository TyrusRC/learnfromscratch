---
title: iOS mobile device forensics
slug: ios-mobile-device-forensics
aliases: [ios-forensics, iphone-forensics, ios-mdf]
---

> **TL;DR:** iOS forensics is harder than macOS or Android: Apple has hardened against physical extraction, and most apps run under Data Protection class keys that lock at first lock. Three acquisition modes — logical (iTunes-style backup), file-system (jailbroken or BootROM-vulnerable devices), and full (physical, very limited on modern devices). For most investigations, **iTunes encrypted backup** is the realistic option, parsed by tools (mvt-mobile, iLEAPP, Cellebrite). Companion to [[ios-bootrom-checkm8]] and [[ios-source-review-methodology]].

## What makes iOS forensics difficult

- **Hardware-bound keys** in Secure Enclave; can't extract.
- **Data Protection classes** encrypt most data at first lock — only available when device unlocked.
- **Sealed Key Protection** in modern iOS.
- **Limited public physical-extraction methods**.
- **Commercial extraction tools** (Cellebrite UFED, GrayKey) advance / are countered by Apple in waves.

## Acquisition methods

### Logical (iTunes-style backup)

Most realistic for non-jailbroken modern iPhone:
- `idevicebackup2 backup --full <path>` (libimobiledevice) or iTunes.
- Encrypted backup option (recommended; reveals Keychain).
- Doesn't get every file (sandboxed app data subject to backup-exclude flag).

What you get:
- Apps' backup-flagged data.
- Photos, Messages, Call History, Notes, Contacts.
- Safari history (mostly).
- Some health data.
- WiFi settings.
- Keychain entries (if encrypted backup).

### File-system (jailbroken or BootROM-vulnerable)

For older devices (iPhone X / 8 / earlier — see [[ios-bootrom-checkm8]]):
- checkm8/checkra1n → SSH → `tar` or `rsync` filesystem.
- Get app sandboxes, more system artefacts.
- Get Unified Logs, FSEvents-style traces.

For non-checkm8 devices: needs vendor-bug jailbreak (palera1n, others) or vendor extraction tool.

### Physical (full disk)

Modern devices: very limited.
- Cellebrite Premium / GrayKey: closed-source, periodic.
- Even when working, secure-enclave-protected data not retrievable.

### iCloud

Many users sync to iCloud:
- iCloud backup contains iTunes-backup-equivalent.
- Apple Production accounts can access with legal process.
- Photos, Messages in iCloud, iCloud Drive, Notes.

## Artefacts in iTunes backup

A backup is a directory of files. Critical:
- `Manifest.db` — SQLite mapping file ID to original path.
- `Info.plist` — device metadata.
- `Status.plist`.
- Files keyed by SHA-1 of original path.

Parsed by:
- **iLEAPP** — open-source, modern.
- **mvt-mobile** (Mobile Verification Toolkit) — security-focused.
- **Cellebrite Reader** — commercial.

iLEAPP outputs HTML reports with timeline.

## Specific data sources

### Messages

`HomeDomain/Library/SMS/sms.db` (SQLite). Tables: `message`, `chat`, `handle`, `attachment`. iMessage and SMS combined.

### Call history

`HomeDomain/Library/CallHistoryDB/CallHistory.storedata` (Core Data SQLite).

### Browser history

Safari: `HomeDomain/Library/Safari/History.db`.
Chrome: per-app backup data (sometimes).

### Photos

`CameraRollDomain/Media/PhotoData/Photos.sqlite` — Photos library DB. Includes deleted-but-recoverable items in some cases.

### Contacts

`HomeDomain/Library/AddressBook/AddressBook.sqlitedb`.

### Health

`HealthDomain/...` — large SQLite + protobuf data. Useful for location-time-of-day correlation.

### Location

`HomeDomain/Library/Caches/com.apple.routined/Cache.sqlite` — significant locations.
`HomeDomain/Library/Application Support/com.apple.routined/Cloud-V2.sqlite` — sync.
Other: `consolidated.db` (legacy), Cell Tower locations.

### Keychain

In encrypted backup. Apps' stored credentials, certificates. Decrypt with the backup password.

### App-specific

WhatsApp, Signal, Telegram each have their own SQLite stores in their containers (in file-system acquisition). In logical backup, only what the app marks for backup.

## Pegasus / Predator IoC scanning

mvt-mobile (Mobile Verification Toolkit) was built specifically for this:
- Parse iTunes backup.
- Check against published Pegasus / Predator / Triangulation IoCs.
- Look for tell-tale artefacts (DataUsage process anomalies, suspicious WebKit caches).

Standard for journalists / activists suspected to be targeted.

## Anti-forensics

- **Auto-delete in Messages** (settings).
- **Fresh-install device** wipes most.
- **iCloud-not-synced** — data only on device.
- **Modern iOS Lockdown Mode** restricts attack surface (more relevant for forensic IR target — limits what could have been extracted).

## Workflow to study

1. Pull an iTunes encrypted backup of a test iPhone.
2. Run iLEAPP; explore the report.
3. Identify timestamps across SMS, Photos, location.
4. Practice mvt-mobile on a clean backup (no IoCs expected).
5. If you have a checkm8-vulnerable iPhone: file-system acquisition via checkra1n + SSH; explore the broader filesystem.

## Legal note

Forensic acquisition of someone else's iPhone requires authorisation (warrant, employer policy, consent). Doing it without authorisation is computer-crime in most jurisdictions; see [[responsible-disclosure-across-jurisdictions]].

## Related

- [[ios-bootrom-checkm8]] — physical access via BootROM bug.
- [[ios-source-review-methodology]].
- [[ios-keychain-and-secure-enclave-audit]].
- [[macos-forensics-fsevents-spotlight]] — macOS sibling.
- [[case-study-okta-2023-support-system]] — adjacent context.

## References
- [iLEAPP](https://github.com/abrignoni/iLEAPP)
- [mvt-mobile](https://docs.mvt.re/)
- [Sarah Edwards — mac4n6 / iOS](https://www.mac4n6.com/)
- [Jonathan Zdziarski — iOS Forensic Analysis](https://www.zdziarski.com/) (older but foundational)
- [Apple — Platform Security guide](https://support.apple.com/guide/security/welcome/web)
- See also: [[ios-bootrom-checkm8]], [[ios-source-review-methodology]], [[macos-forensics-fsevents-spotlight]], [[responsible-disclosure-across-jurisdictions]]
