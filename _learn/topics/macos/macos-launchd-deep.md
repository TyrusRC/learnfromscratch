---
title: macOS launchd deep
slug: macos-launchd-deep
aliases: [launchd-deep, macos-launchd-internals]
---

> **TL;DR:** launchd is PID 1 on macOS and the single service manager for daemons, agents, and XPC services. It is also, by a wide margin, the most common persistence mechanism abused by malware on Mac — which is why Apple bolted on the BackgroundTaskManagement framework in Ventura to surface every new persistent item to the user. This note pairs with [[macos-architecture]], [[macos-tcc-forensics]], and [[macos-unified-logs-forensics]] to give you the foreground theory and the forensic angle in one place.

## Why it matters

If you want to understand offense or defense on macOS, you need to understand launchd. cron is deprecated, SysV init never existed here, and systemd does not exist. Every long-running service — system or per-user — is supervised by launchd. That makes plist-based jobs both the dominant persistence vector and the single richest piece of telemetry for "what is autorun on this Mac".

Red teams care because every public macOS implant (XCSSET, Shlayer descendants, KandyKorn, BlueNoroff RustBucket family) drops a LaunchAgent or LaunchDaemon at some point. Blue teams care because if you understand the plist schema and BackgroundTaskManagement events, you can write detections that catch nearly every commodity macOS persistence attempt. See [[apt-tradecraft-dprk-lazarus]] for DPRK examples and [[edr-rules-as-code-from-attack-patterns]] for the detection-engineering wrap-around.

## Classes, patterns, process

### LaunchAgents vs LaunchDaemons

The first distinction is **scope and security context**.

- **LaunchDaemons** run as root (or another system user) in the system context. They start before any user logs in. They live in:
  - `/Library/LaunchDaemons/` (third-party, persisted)
  - `/System/Library/LaunchDaemons/` (Apple, SIP-protected — see [[sip]])
- **LaunchAgents** run as a specific user, only while that user is logged in to a graphical session. They live in:
  - `~/Library/LaunchAgents/` (this specific user)
  - `/Library/LaunchAgents/` (all users)
  - `/System/Library/LaunchAgents/` (Apple)

The path determines who can drop the file and what privileges the job inherits. Anything writing into `/Library/LaunchDaemons/` already had root; anything writing into `~/Library/LaunchAgents/` only needed user-level write, which a phishing payload or a notarised-but-malicious app can easily achieve — see [[gatekeeper-bypasses]] and [[entitlements-and-codesigning]] for how those payloads land.

### Plist anatomy

A launchd job is a property list (XML or binary plist) with a small set of keys. The minimum viable persistence:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.updater</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/Shared/.updater/agent</string>
        <string>--silent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Important keys to know cold:

- **Label** — reverse-DNS identifier, must be unique within scope. Malware loves `com.apple.*` labels for camouflage; this is itself an IOC.
- **ProgramArguments** — argv. First element is the executable; rest are args. If only `Program` is set, no argv splitting happens.
- **RunAtLoad** — fire immediately when launchd loads the job (boot for daemons, login for agents).
- **KeepAlive** — restart if it exits. Can be a boolean or a dict with conditions (`SuccessfulExit`, `NetworkState`, `PathState`, `Crashed`).
- **StartInterval** / **StartCalendarInterval** — cron-style scheduling without cron.
- **WatchPaths** / **QueueDirectories** — start the job when a path changes; classic for file-trigger persistence.
- **MachServices** — register Mach ports for XPC. See [[mach-and-xpc]].
- **LimitLoadToSessionType** — `Aqua`, `Background`, `LoginWindow`, `StandardIO`, `System` — controls which session loads the job.
- **UserName** / **GroupName** — only valid in daemons; lets root daemons drop privileges.

### Loading, unloading, the launchctl dance

Modern launchctl uses domain-prefixed targets. Forget the old `launchctl load` / `unload` syntax for anything beyond a quick test; the supported verbs are:

- `launchctl bootstrap <domain> <plist>` — install and start.
- `launchctl bootout <domain> <plist>` — stop and remove.
- `launchctl enable <domain/service>` / `disable` — persist the on/off state.
- `launchctl kickstart -k <domain/service>` — force start/restart, useful for triage and for testing your own detections.
- `launchctl print <domain>` — full state dump, including the resolved plist, last exit code, and TCC entitlements observed.

Domains you will type often:

- `system` — system daemons.
- `gui/<uid>` — the Aqua session of a logged-in user.
- `user/<uid>` — background per-user.

### Persistence-via-launchd as the dominant macOS vector

Patrick Wardle's "Art of Mac Malware" volumes, the Objective-See malware corpus, and Mandiant/Mitre ATT&CK telemetry all converge on the same finding: roughly 80 to 90 percent of macOS persistence is plist-based. The remaining tail is login items, cron leftovers, Periodic scripts, kext/system extensions (very rare since notarisation), and dyld insert tricks against specific apps.

Why so concentrated? Plist drop is:

- Documented, stable, and survives upgrades.
- Doesn't require kernel signing or extra entitlements.
- Works without exploiting [[sip]] or [[gatekeeper-and-notarisation]] — you only need write to one of three directories.
- Survives reboots automatically; no extra "registry run key" equivalent needed.

That concentration is also the defender's opportunity: monitor those directories well and you cover most threats. See [[detection-engineering-pyramid-of-pain]] for why this is "behaviour" not "hash" level coverage.

### BackgroundTaskManagement framework (Ventura+)

In macOS 13 Ventura, Apple shipped `btm` — the BackgroundTaskManagement daemon — and a corresponding user-facing surface in System Settings → General → Login Items & Extensions. Whenever a new persistent item is registered (LaunchAgent, LaunchDaemon, login item, SMAppService), btm:

1. Records the item in `/private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v*.btm` (sqlite-ish binary).
2. Sends the user a banner notification: "X added items that can run in the background."
3. Exposes the entry as toggleable in System Settings.

For defenders this is enormous: the OS now keeps a tamper-resistant catalogue of every persistent item, including the team identifier of the signer, the parent app that registered it, and the registration timestamp. Tools like `DumpBTM` (Objective-See) and Aaron Stratton's parsers turn the file into readable JSON. See [[macos-unified-logs-forensics]] for correlating the btm registration events with `subsystem == com.apple.backgroundtaskmanagement` log lines.

Caveats:

- Malware can race the notification, but the registration is still persisted and shows up in btm dumps.
- Some legitimate installers register dozens of items at once, generating notification fatigue — attackers piggyback on this.
- Disabling an item in System Settings does not delete the plist; the plist stays on disk with a disabled flag.

### Forensic visibility

For DFIR work on a suspect Mac, your launchd evidence sources are:

1. **All four LaunchAgents and LaunchDaemons directories** — collect plists, hash, and parse.
2. **`BackgroundItems-v*.btm`** — the authoritative registration ledger from Ventura on.
3. **Unified log** — subsystems `com.apple.xpc.launchd` and `com.apple.backgroundtaskmanagement` give load, exit, and registration events. See [[macos-unified-logs-forensics]] for log archive collection.
4. **`launchctl print system`** and `launchctl print gui/<uid>` snapshots — current runtime state, including resolved program path, last exit reason, and observed TCC requests.
5. **`/private/var/db/com.apple.xpc.launchd/disabled.plist`** — overrides for jobs the user or admin disabled.
6. **FSEvents** — file-creation events for plists; pairs with [[macos-forensics-fsevents-spotlight]].

A good triage script collects all of the above into a single archive, then offline-parses for: unsigned binaries, ad-hoc-signed binaries, binaries outside `/Applications` and `/Library`, plists where Label and binary path disagree, and any job that uses `WatchPaths` or `MachServices` to look like a system component.

## Defensive baseline

The minimum I recommend for a managed fleet:

- **MDM-deploy a baseline `disabled.plist`** that locks out cron and unused system jobs.
- **Endpoint Security client** (your EDR) subscribing to `ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD` — Apple shipped this event explicitly so defenders can log every persistence registration.
- **File-integrity monitoring** on the four launch directories; any new plist not signed by an approved team identifier raises a ticket.
- **Unified log forwarding** for the launchd and btm subsystems into your SIEM. Map to [[siem-detection-use-case-catalog]].
- **Block writable+executable in `/Users/Shared`, `~/Library/Application Support/<random>`**, and other common malware staging paths.
- **Periodic btm-dump audits** — diff weekly snapshots; investigate any new entry whose signer team ID is not on your allowlist.
- **User education** about the "items added in background" notification, so people do not click through it.

Tie this back to your detection pipeline via [[purple-team-feedback-loop]] and [[atomic-red-team-emulation-deep]] — Atomic Red Team's T1543.001 (LaunchAgent) and T1543.004 (LaunchDaemon) tests give you the exact emulation payloads.

## Workflow to study

1. Read Apple's `launchd.plist(5)` and `launchctl(1)` man pages end to end. They are short and authoritative.
2. Work through chapters on launchd in "*OS Internals" (Levin) volume 1 and "The Art of Mac Malware" volume 1 (Wardle). Build the mental map of how a job goes from disk to running process.
3. On a test VM, write five plists by hand: a daemon, an agent, a WatchPaths job, a StartCalendarInterval job, and an on-demand XPC service. Load, inspect with `launchctl print`, and unload each.
4. Install Objective-See's KnockKnock and BlockBlock; trigger your test plists and watch what fires.
5. Dump `BackgroundItems-v*.btm` before and after each test using DumpBTM and diff.
6. Build a tiny detection rule in your EDR (or in a script) that flags any new file in the four launch directories whose signer is not on an allowlist. Test it with the Atomic Red Team T1543 atomics. Cross-reference results in [[detection-engineering-pyramid-of-pain]].
7. Now pivot to offensive: replicate one real-world persistence chain from a published report — KandyKorn or BlueNoroff are good — and confirm your detection catches it.

## Related

- [[macos-architecture]]
- [[macos-tcc-forensics]]
- [[macos-unified-logs-forensics]]
- [[macos-forensics-fsevents-spotlight]]
- [[mach-and-xpc]]
- [[entitlements-and-codesigning]]
- [[gatekeeper-and-notarisation]]
- [[sip]]
- [[apt-tradecraft-dprk-lazarus]]
- [[atomic-red-team-emulation-deep]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[detection-engineering-pyramid-of-pain]]

## References

- Apple Developer, "Daemons and Services Programming Guide" — https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/Introduction.html
- Apple `launchd.plist(5)` man page, current — https://keith.github.io/xcode-man-pages/launchd.plist.5.html
- Patrick Wardle, "The Art of Mac Malware, Volume 1: Analysis", chapter on persistence — https://taomm.org/
- Objective-See, "DumpBTM" and BackgroundTaskManagement research — https://objective-see.org/blog/blog_0x6F.html
- MITRE ATT&CK T1543.001 Launch Agent and T1543.004 Launch Daemon — https://attack.mitre.org/techniques/T1543/001/
- SentinelOne Labs, "Reversing macOS Persistence" series — https://www.sentinelone.com/labs/
