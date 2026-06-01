---
title: TCC — Transparency, Consent, Control
slug: macos-tcc
---

> **TL;DR:** TCC is the userspace privacy layer: `tccd` plus per-user/system SQLite stores that record which signed binary is allowed to touch which "service" — Documents, Desktop, Camera, Microphone, Full Disk Access, Accessibility, Screen Recording, etc.

## What it is
**Transparency, Consent, and Control** is the access-control plane for personal data and high-power capabilities. Two databases:
- **User**: `~/Library/Application Support/com.apple.TCC/TCC.db`
- **System**: `/Library/Application Support/com.apple.TCC/TCC.db` (SIP-protected)

Each row maps a `service` (e.g. `kTCCServiceSystemPolicyAllFiles`, `kTCCServiceCamera`) to a `client` (bundle ID or path) plus the **client code-signing requirement**, the **auth_value** (deny/allow/limited), and metadata. The daemon `tccd` is consulted whenever a process tries to access a protected API; it identifies the caller by its code signature and looks up the row.

## Preconditions / where it applies
- Always — TCC sits between every unprivileged process and protected data on modern macOS.
- Root does not equal TCC — even `sudo` cannot bypass TCC on a user's Documents/Desktop. The kernel itself rejects access unless TCC has granted it (via SIP+sandbox enforcement on the path).
- Relevant for: phishing payloads after a sandbox escape, EDR/agents needing Full Disk Access, exfil chains. See [[tcc-bypasses]] and [[entitlements-and-codesigning]].

## Technique
Inspect TCC state on a user account:

```bash
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "select client, service, auth_value, last_modified from access;"
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "select client, service, auth_value from access;"
```

How requests flow:
1. App calls a protected API (e.g. `[NSWorkspace requestAuthorizationToShareItems]` or any AddressBook API).
2. The framework invokes `tccd` via XPC, passing the **audit token** of the calling process.
3. `tccd` resolves the audit token to a code-signing identity, queries the DB, returns allow/deny.
4. If no row exists and the operation is interactive, `tccd` triggers a UI prompt; the user's choice writes a new row.

Attacker-relevant facts:
- TCC keys on the code-signing identity. If you can run inside a process that already has the grant (DYLD injection, plugin loading), you inherit the grant without prompting. This is why `disable-library-validation` and `get-task-allow` are so dangerous — see [[entitlements-and-codesigning]].
- TCC stores the bundle path/identifier; renaming or relocating a granted bundle can invalidate the grant. Conversely, replacing the content while preserving identifier+signature would inherit it (Apple closed many such races).
- Some services (Full Disk Access, Accessibility) cannot be silently granted — Apple requires user gesture in System Settings.

Reset state during research:

```bash
tccutil reset All com.example.app   # nuke per-bundle grants
```

For known bypass classes, see [[tcc-bypasses]]. Persistence often abuses already-granted apps (Terminal with FDA, IDEs with Accessibility).

## Detection and defence
- Unified-log `com.apple.TCC` subsystem records every decision: `log stream --predicate 'subsystem == "com.apple.TCC"'`.
- EDR monitors writes to `TCC.db` files and unusual `tccd` XPC connectors.
- Hardening: minimise Full Disk Access / Accessibility grants; never grant FDA to Terminal on production endpoints. Use MDM PPPCP profiles to allow-list specific signed binaries.
- For research targets: enable Lockdown Mode; restrict admin accounts.

## References
- [Apple Platform Security — App data protection](https://support.apple.com/guide/security/protecting-app-access-to-user-data-secfb4815c8d/web) — official TCC model.
- [Rainforest QA — Reverse engineering TCC](https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive) — DB layout deep dive.
- [Csaba Fitzl — TCC research index](https://theevilbit.github.io/) — repeated bypass writeups.
