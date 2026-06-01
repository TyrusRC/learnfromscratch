---
title: macOS sandbox escape
slug: macos-sandbox-escape
---

> **TL;DR:** Sandboxed code escapes by reaching an out-of-sandbox helper via Mach/XPC, by exploiting a kernel surface the profile still exposes (notably IOKit), or by hijacking a more-privileged signed binary the sandbox lets it launch.

## What it is
The macOS sandbox (Sandbox.kext + `libsystem_sandbox`) enforces a compiled **seatbelt profile** per process. The profile is a Scheme-like allow/deny list over filesystem paths, Mach service lookups, IOKit user-client classes, sysctls, signals, network endpoints, and so on. An "escape" means executing code in a context not bound by your current profile — typically by piggybacking on a non-sandboxed daemon or by triggering a bug in something the profile lets you talk to.

## Preconditions / where it applies
- You already have code execution inside the sandbox — usually browser renderer, Mail rules, document parser, or a sandboxed app (App Store apps run under the App Sandbox).
- Your profile permits at least one reachable Mach service or IOKit class. Pure deny-all profiles are vanishingly rare in practice.
- Relevant as the second stage of macOS exploit chains; see [[mach-and-xpc]], [[iokit-attack-surface]], [[entitlements-and-codesigning]].

## Technique
Map your reachable surface first:

```bash
# Inside the sandboxed process (e.g. by debugging a renderer):
sandbox-exec -p '(version 1)(deny default)' /usr/bin/true  # toy reference
# Real profile compiled from /System/Library/Sandbox/Profiles or app-embedded
ls /System/Library/Sandbox/Profiles
```

Then pick an escape class:

1. **XPC service abuse**
   - Find services in `allow mach-lookup` (e.g. `com.apple.cfprefsd.daemon`, `com.apple.tccd`).
   - Look for memory-safety or logic bugs in those daemons triggerable by your malformed XPC message. Examples: cfprefsd plist parsing, tccd DB injection paths.
2. **IOKit driver bug**
   - The profile typically allows a handful of `IOServiceOpen` classes. If any has a kernel bug, you go from sandboxed userspace to kernel — see [[iokit-attack-surface]].
3. **launching-a-helper trick**
   - Some profiles allow exec of specific helper binaries. If you can influence args/environment, exec a signed Apple binary that has a more permissive profile or no profile at all (e.g. older `mdworker` patterns).
4. **Filesystem-mediated**
   - Profile allows write to a shared directory whose contents are processed by a privileged daemon (e.g. `~/Library/Preferences/`, mailbox state, Spotlight metadata). Plant a poisoned file, daemon parses, RCE in daemon context.
5. **Entitlement-laundering through a host app**
   - If you can load a dylib into a co-running app that holds extra entitlements (camera/full-disk), you inherit those grants while still inside its sandbox — but often that sandbox is wider than yours.

Practical recon: read the embedded profile from the running process. Inside lldb on the target binary:

```
(lldb) memory read --binary --outfile prof.bin <profile_addr> --count <n>
```

Or extract from the binary itself with `jtool2 -l` to find `__TEXT.__sandbox` or via the open-source [sandblaster](https://github.com/malus-security/sandblaster) decompiler.

Modern escapes increasingly chain: a logic bug in a small daemon (no memory corruption needed) gives a file write, which triggers a daemon misparse, which yields the entitlement you actually wanted. See [[macos-tcc]] and [[macos-privesc]] for follow-on stages.

## Detection and defence
- EndpointSecurity events on `ES_EVENT_TYPE_NOTIFY_EXEC` and `ES_EVENT_TYPE_NOTIFY_OPEN` from sandboxed PIDs to unusual targets.
- Defenders correlate WebContent/renderer PIDs talking to non-standard XPC services; Safari renderer talking to `tccd` is suspicious.
- For developers: minimise your `mach-lookup` allow-list; never enable `com.apple.security.temporary-exception.*` in shipping builds.

## References
- [Sandblaster — decompile macOS sandbox profiles](https://github.com/malus-security/sandblaster) — read profiles offline.
- [Project Zero — A Survey of Recent iOS Kernel Exploits](https://googleprojectzero.blogspot.com/2020/06/a-survey-of-recent-ios-kernel-exploits.html) — many chained from sandbox.
- [HackTricks — macOS Sandbox](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-sandbox/index.html) — escape technique catalogue.
