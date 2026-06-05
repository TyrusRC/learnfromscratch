---
title: macOS Unified Logs forensics
slug: macos-unified-logs-forensics
aliases: [macos-unified-logging, log-show-forensics, tracev3-parsing]
---

> **TL;DR:** macOS Unified Logging is the modern replacement for syslog (since macOS 10.12). Every subsystem and library writes structured events with consistent format, queryable via `log show`. For IR, Unified Logs are the most comprehensive event source — capturing process spawn, network, security events, TCC prompts, code-signing verifications, kernel events. Persistence at `/var/db/diagnostics/`. Companion to [[macos-tcc-forensics]] and [[macos-forensics-fsevents-spotlight]].

## What Unified Logs capture

- **Process lifecycle** — exec, fork, exit (subsystem `com.apple.kernel.process`).
- **Network connections** — NetworkExtension, mDNSResponder, others.
- **Security events** — Gatekeeper, XProtect, code-signing, TCC.
- **Sandbox** — sandboxd events.
- **Authentication** — TouchID, Keychain.
- **Application messages** — apps that adopt unified logging.

Volume is high (gigabytes per day in normal use); subsystems and categories let you filter.

## Format

Each log line includes:
- Timestamp.
- Subsystem (e.g., `com.apple.kernel`).
- Category.
- Process / PID.
- Thread.
- Level (default, info, debug, error, fault).
- Message.
- Sometimes structured payload.

## Where stored

Persistent traces at `/var/db/diagnostics/`:
- `.tracev3` — binary log archive files.
- `Persist/` — survives reboot.
- `Special/` — special-category events.

Plus catalog metadata at `/var/db/uuidtext/`.

`log collect` packages into a `.logarchive` for offline analysis.

## Reading

Live:
```sh
log show --info --debug --last 30m
log show --predicate 'subsystem == "com.apple.TCC"' --last 1h
log stream --predicate 'eventMessage CONTAINS "denied"'
```

Common filters:
- `subsystem == "com.apple.kernel"` — kernel events.
- `subsystem == "com.apple.securityd"` — keychain.
- `subsystem == "com.apple.TCC"` — privacy framework.
- `subsystem == "com.apple.network"` — networking.
- `subsystem == "com.apple.sandbox"` — sandbox.
- `process == "ssh"` — events from a process.
- `eventMessage CONTAINS "denied"` — substring.

Offline:
```sh
log show --archive /path/to/logarchive --predicate ...
```

## What's useful for IR

### Process tree reconstruction

`log show --predicate 'subsystem == "com.apple.kernel" AND (category == "process" OR category == "exec")'` shows execs with arguments and parent PID. Build process tree.

### Network events

`log show --predicate 'subsystem == "com.apple.network"'` shows DNS resolution, connection setup. With NetworkExtension VPNs, more granular.

### Security and Gatekeeper

`subsystem == "com.apple.syspolicy"` shows code-signing verifications, Gatekeeper decisions, notarization checks. Useful for spotting attacker bypasses or unsigned binaries.

### TCC and sandbox

See [[macos-tcc-forensics]].

### Login / auth

`subsystem == "com.apple.opendirectoryd"` and `com.apple.LocalAuthentication` show user login attempts, TouchID prompts.

### Persistence

LaunchAgents / LaunchDaemons launching via `launchd` events.

## Limits

- **Retention varies** — typically a few days for high-volume subsystems; longer for `Persist/`.
- **Private redaction** — sensitive payloads may be redacted as `<private>` unless configured otherwise. For research, `sudo log config --mode 'private_data:on'` reveals; for forensic IR on production, redactions limit visibility.
- **`debug` level** disabled in production by default; useful events may be at `info` or `debug`.
- **Volume** — naive queries take minutes; filter aggressively.

## Workflow for IR

1. **`log collect --output incident.logarchive`** on the live system or before imaging.
2. **Move archive** to analysis workstation.
3. **Build the process tree** for the suspected compromise window.
4. **Filter security subsystems** — Gatekeeper, syspolicy, TCC, sandbox.
5. **Cross-correlate with FSEvents** for filesystem context.
6. **Cross-correlate with TCC.db** for permission grants.

## Tooling

- **`log` command** (built-in) — primary.
- **`mac_apt`** — parses tracev3 offline; good for batch.
- **`UnifiedLogReader`** — alternative parser.
- **`fs_usage`** / **`dtrace`** — adjacent live tracing.
- **Crowdstrike / SentinelOne / Jamf Protect** — commercial agents.

## Anti-forensic notes

- **`log erase`** clears Unified Logs (requires admin).
- Attackers don't typically erase Unified Logs because they're verbose and tampering is itself noisy.
- Some malware-specific events are silent (no subsystem registered); detection by absence is harder.

## Common attacker artefacts in Unified Logs

- `xpcproxy` spawning unsigned binaries from unusual paths.
- `securityd` denying code-signing verifications.
- `sandboxd` denial events for resource access.
- LaunchAgent loading from non-standard paths.
- Network connections to unfamiliar hosts from non-browser processes.

## Workflow to study

1. On a test mac, generate activity (download files, install apps, denied permissions).
2. `log show --info --debug --last 1h` and read.
3. Filter by subsystem; observe levels of detail.
4. Practice `mac_apt` against a saved logarchive.
5. Build a small Python parser of tracev3 (educational; mac_apt is the production tool).

## Related

- [[macos-tcc-forensics]] — TCC subset.
- [[macos-forensics-fsevents-spotlight]] — filesystem-side.
- [[macos-architecture]] — context.
- [[ir-from-source-signals]] — adjacent.

## References
- [Apple — Unified Logging documentation](https://developer.apple.com/documentation/os/logging)
- [Howard Oakley — eclectic light blog](https://eclecticlight.co/)
- [Sarah Edwards — mac4n6](https://www.mac4n6.com/)
- [Yogesh Khatri — mac_apt](https://github.com/ydkhatri/mac_apt)
- See also: [[macos-tcc-forensics]], [[macos-forensics-fsevents-spotlight]], [[macos-architecture]], [[ir-from-source-signals]]
