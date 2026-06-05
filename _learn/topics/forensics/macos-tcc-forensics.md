---
title: macOS TCC forensics
slug: macos-tcc-forensics
aliases: [tcc-forensics, macos-privacy-db-forensics, tcc-db-analysis]
---

> **TL;DR:** Transparency, Consent, and Control (TCC) is macOS's privacy framework — the per-resource permission model (Camera, Microphone, Contacts, Full Disk Access, Accessibility). Permission state is stored in SQLite databases. For IR, TCC artefacts reveal which apps gained access to which resources and when — and TCC compromise patterns are a known macOS attacker tradecraft class. Companion to [[macos-tcc]] and [[macos-forensics-fsevents-spotlight]].

## What TCC tracks

Per-resource, per-app permission state:
- Camera, Microphone, Screen Recording.
- Contacts, Calendars, Reminders, Photos.
- Documents, Downloads, Desktop folders.
- Full Disk Access (most powerful).
- Accessibility (input automation).
- Automation (controlling other apps via AppleScript).
- AppleEvents (related to Automation).
- BluetoothAlways, Location, Reminders, SiriBundleID, etc.

Each grant is timestamped and tied to the app's bundle identifier (or `csrutil`-relevant code-signing identity).

## Where it's stored

- **System-wide**: `/Library/Application Support/com.apple.TCC/TCC.db` (SIP-protected on modern macOS).
- **Per-user**: `~/Library/Application Support/com.apple.TCC/TCC.db`.

Both are SQLite. Schema:
- `access` table — one row per (app, resource, allowed?) grant.
- `access_overrides`, `policies`, others — additional state.
- Includes `client` (bundle ID), `service` (resource), `auth_value` (allowed / denied), `auth_reason`, timestamps.

## Reading TCC.db

With Terminal having Full Disk Access:

```sh
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client, service, auth_value, datetime(last_modified, 'unixepoch') FROM access;"
```

System-wide DB requires SIP-relevant access; in a forensic image, mount and read directly.

Columns to watch:
- `kTCCServiceCamera`, `kTCCServiceMicrophone` — sensitive.
- `kTCCServiceSystemPolicyAllFiles` — Full Disk Access (FDA). Highest-impact.
- `kTCCServiceAccessibility` — input automation, can read screen / inject keystrokes.

## What attackers do with TCC

### Granting TCC to attacker process

If attacker can write to TCC.db (requires bypassing SIP / Full Disk Access), they can:
- Self-grant Camera, Microphone, FDA.
- Bypass the user prompts.

Historically several TCC bypass CVEs allowed this: `tccd` race conditions, symlink attacks, library injection chains.

### Inheriting TCC from a trusted app

If attacker runs code within a trusted app's process (via library injection, plugin abuse), the code inherits the app's TCC grants. Common chain:
- User grants Terminal FDA.
- Malware loads as Terminal dylib via `DYLD_INSERT_LIBRARIES` (now restricted) or via altered binary in Apps folder.
- Inherits FDA.

### Persistence via LaunchAgent in trusted context

LaunchAgents under a TCC-granted user account run with those grants on next login.

## TCC forensic flow

For an IR:

1. **Acquire** TCC.db (system + user).
2. **Enumerate grants** — focus on Camera, Microphone, FDA, Accessibility.
3. **Map grants to apps** — when each grant was issued, by which client.
4. **Cross-check with `macl` xattrs** on files (TCC sometimes records granular access).
5. **Correlate with Unified Logs** — `subsystem == com.apple.TCC` shows TCC events in real-time.
6. **Hunt for anomalies** — grants to unusual / unsigned apps, grants without user-visible prompt timing.

## Specific anomalies

- TCC grant to **unsigned binary**.
- TCC grant outside business hours.
- TCC grant **without** a matching prompt event in `tccd` logs (TCC.db write but no user interaction → bypass attempt).
- FDA to a non-IT-tool process.
- Accessibility granted to a process that's not an assistive technology.

## Unified Log queries

```sh
log show --predicate 'subsystem == "com.apple.TCC"' --info --debug --last 24h
```

Watch for `TCC: access prompt` events without corresponding user UI, indicating bypass.

## Common attacker tradecraft

- **`tccutil reset`** abuse to reset and re-prompt while the user is busy.
- **Hidden `.plist`** for LaunchAgents under user's Application Support that re-runs with TCC.
- **`/usr/libexec/PlistBuddy`** abuse to write LaunchAgent with TCC-relevant paths.
- **CVE-2023-32369 (Migraine)** — TCC bypass via migrationtool.

## Defensive baseline

- Use macOS 14+ (latest TCC bug patches).
- Monitor `~/Library/Application Support/com.apple.TCC/` for changes via `fs_usage` or `endpointsecurity`.
- EDR with TCC awareness (CrowdStrike, SentinelOne, Jamf Protect).
- For high-risk users: don't grant FDA to Terminal or general-purpose dev tools.

## Workflow to study

1. On a test mac, enable Camera for a benign app. Read TCC.db; observe entry.
2. Try writing directly to TCC.db (you'll need to escape SIP or have FDA already) — observe what's required.
3. Test TCC bypass PoCs from public CVE writeups (in a VM).
4. Practice queries: who has FDA? when was each grant issued?

## Tooling

- **mac_apt** parses TCC.db automatically.
- **`tcc`** Python utilities by researchers.
- **`tccplus`** — interact with TCC.
- **Jamf Protect**, **Mosyle**, **Kandji** — MDM with TCC visibility.
- **endpointsecurity API** — programmatic monitoring (apps with appropriate entitlements).

## Related

- [[macos-tcc]] — TCC overview.
- [[macos-tcc]] / [[tcc-bypasses]] — bypass class.
- [[macos-forensics-fsevents-spotlight]] — adjacent artefacts.
- [[macos-unified-logs-forensics]] — adjacent log subsystem.
- [[ios-mobile-device-forensics]] — iOS adjacency.

## References
- [Wojciech Reguła — TCC research](https://wojciechregula.blog/)
- [Patrick Wardle — Objective-See](https://objective-see.org/)
- [Sarah Edwards — mac4n6](https://www.mac4n6.com/)
- [Apple — TCC documentation](https://developer.apple.com/documentation/security/protecting_user_data_with_app_sandbox)
- See also: [[macos-tcc]], [[tcc-bypasses]], [[macos-forensics-fsevents-spotlight]], [[macos-unified-logs-forensics]]
