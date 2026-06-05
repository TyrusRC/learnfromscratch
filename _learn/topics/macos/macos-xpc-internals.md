---
title: macOS XPC internals
slug: macos-xpc-internals
aliases: [xpc-internals, macos-xpc-deep]
---

> **TL;DR:** XPC is Apple's blessed inter-process plumbing on macOS and iOS — a launchd-managed, Mach-port-backed RPC layer wrapped in friendly `NSXPCConnection` / `xpc_connection_t` APIs. Almost every privilege boundary you care about (a privileged helper from `SMJobBless`, a system daemon, a sandboxed app talking to a system service) is an XPC boundary, and almost every "macOS LPE" or "sandbox escape" of the last decade is an XPC service that trusted the wrong field on an incoming message. This note is the deep companion to [[mach-and-xpc]] and [[ios-ipc-xpc-audit]]; pair it with [[entitlements-and-codesigning]], [[macos-sandbox-escape]], and [[macos-privesc]].

## Why it matters

XPC sits underneath a huge amount of the macOS attack surface:

- **Privileged helpers.** Any app that uses `SMJobBless` or `SMAppService` to install a root helper exposes that helper as an XPC service in `/Library/LaunchDaemons` or the app's `Contents/MacOS/...`. If the helper does not verify its caller, you have a one-shot LPE primitive — see [[macos-privesc]].
- **Sandbox escapes.** A sandboxed app cannot do much directly, but it can talk to system XPC services that *are* privileged. If those services trust attacker-controlled state, you have a sandbox escape — see [[macos-sandbox-escape]] and [[macos-tcc]].
- **TCC and entitlements.** `tccd`, `bird` (iCloud), `nsurlsessiond`, `securityd`, `installd` are all XPC peers. Many TCC bypasses are XPC-shaped: convince a service with `kTCCServiceSystemPolicyAllFiles` to do work on your behalf. See [[macos-tcc]] and [[entitlements-and-codesigning]].
- **iOS parity.** The exact same patterns apply on iOS, but the attacker side is reversing daemons under `launchd` rather than user-writable helpers. See [[ios-ipc-xpc-audit]] and [[ios-vs-macos-divergence]].

If you only learn one offensive macOS userland concept after Mach ports, learn XPC.

## XPC architecture

### Layers in the stack

There are three things people all call "XPC" and you must keep them separated:

1. **`libxpc` / `xpc_*` C API.** The low-level dictionary-based API: `xpc_connection_create_mach_service`, `xpc_connection_set_event_handler`, `xpc_dictionary_create`, `xpc_connection_send_message`. This is what most system daemons actually use.
2. **`NSXPCConnection` / `NSXPCInterface`.** Foundation's Objective-C wrapper that lets you expose a `@protocol` and call it like remote method invocation. Almost all third-party privileged helpers use this because the tutorials do.
3. **XPC Services bundle type.** A `.xpc` bundle inside an app (`Contents/XPCServices/Foo.xpc`) that `launchd` launches on demand, on behalf of the parent app. Different lifecycle from a LaunchDaemon — same `libxpc` underneath.

All three are Mach messages under the hood, routed via `launchd` (PID 1), with `bootstrap_look_up` resolving a string name (the `MachServices` key in the plist) to a send right on a Mach port.

### launchd and Mach service registration

A LaunchDaemon or LaunchAgent plist declares:

```xml
<key>MachServices</key>
<dict>
  <key>com.example.privhelper</key>
  <true/>
</dict>
```

`launchd` owns the receive right and hands out send rights to anyone who calls `bootstrap_look_up("com.example.privhelper", ...)`. There is **no inherent ACL** on who can look up a Mach service by name — access control is the service's job, performed *after* the connection arrives. This is the single most important fact in this note. See [[mach-and-xpc]] for the Mach side.

### NSXPCConnection lifecycle

A typical Objective-C server looks like:

```objc
- (BOOL)listener:(NSXPCListener *)listener
    shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    newConnection.exportedInterface =
        [NSXPCInterface interfaceWithProtocol:@protocol(PrivHelperProto)];
    newConnection.exportedObject = self;
    [newConnection resume];
    return YES;
}
```

That `return YES` is where the audit happens — or where it does not, in CVE writeups. Everything below is about what should go inside that method.

## Access control patterns

### 1. Codesigning requirement (the modern way)

The blessed pattern is to check the peer's code signing requirement using `SecCodeCopyGuestWithAttributes` keyed by the peer's audit token, then `SecCodeCheckValidity` against a `SecRequirementRef` built from a string like:

```
anchor apple generic and identifier "com.example.app"
  and certificate leaf[subject.OU] = "ABCDE12345"
  and info ["CFBundleShortVersionString"] >= "2.0"
```

The critical piece: the audit token must come from the **connection**, not from a message. On modern macOS, use `xpc_connection_get_audit_token` (private but stable enough that Apple themselves use it) or, for `NSXPCConnection`, `[connection auditToken]` / `processIdentifier`. Pass that token into `SecCodeCopyGuestWithAttributes` via `kSecGuestAttributeAudit`.

### 2. Entitlement checks

Once you have a validated `SecCodeRef` for the peer, you can read its entitlements with `SecCodeCopySigningInformation(code, kSecCSRequirementInformation, ...)` and require specific entitlements (e.g. `com.example.client`). This is how Apple gates many system services. See [[entitlements-and-codesigning]].

### 3. UID and EUID

Necessary but never sufficient. `xpc_connection_get_euid` tells you the caller's EUID, but on macOS a non-root sandboxed process can still be your attacker. Use UID checks as a coarse filter, never as the only gate.

## The classic bugs

### audit-token-from-message vs audit-token-from-connection

This is *the* macOS XPC bug class. There are two ways to get an audit token in a handler:

- **From the connection** (`xpc_connection_get_audit_token`): the kernel-provided token of the peer that opened the Mach connection. Trustworthy.
- **From the message** (`xpc_dictionary_get_audit_token`, or pulling an `audit_token_t` field out of the message body): attacker-controlled in some configurations.

For years, sample code and even Apple frameworks used the message-derived token, which an attacker could spoof by constructing a message that embeds the audit token of a *different* process (e.g. a privileged Apple binary). The fix is to always read the token from the connection. Samuel Groß, Csaba Fitzl, Wojciech Reguła and others have published a long list of CVEs of exactly this shape — see references.

`NSXPCConnection` historically had the same problem: `processIdentifier` came from a field that was settable. Modern advice: do not trust `processIdentifier`; pull the audit token off the connection via private API and re-derive the PID from it with `audit_token_to_pid`.

### PID reuse races

Even if you correctly get the PID from the audit token, calling `SecCodeCopyGuestWithAttributes` with `kSecGuestAttributePid` is racy: the original process can exit, PID can be reused by an unsigned attacker, and you validate the *wrong* process. The audit token is the only stable identifier — it includes PID-generation count (`pidversion`). Always pass the full token, not the PID.

### Trust-on-first-use protocols

Some helpers check the client only on first connection, then trust all subsequent messages. An attacker who can hijack the connection (rare) or who can convince the helper to re-use a cached client identity wins. Re-validate per-message for anything dangerous.

### Overly-broad `NSXPCInterface`

`NSXPCInterface` lets you whitelist classes for arguments with `setClasses:forSelector:argumentIndex:ofReply:`. If you do not call this, decoding falls back to a default that may allow `NSData` blobs to deserialize into objects you never intended. NSKeyedUnarchiver on untrusted input has been a CVE source repeatedly. Always pin the class list.

### Missing entitlement checks on system services

A few Apple daemons historically accepted any caller, on the assumption that the entitlement to even talk to them was scarce. When TCC or a sandbox profile failed open, that assumption broke. Always defense-in-depth: re-check entitlements inside the handler.

## CVE pattern catalog

A non-exhaustive taxonomy. Treat these as templates when auditing a helper:

- **CVE-2019-8513-class** — `diagnosticd` and friends accepted audit tokens from message body.
- **CVE-2020-9971** — `coreduetd` audit token confusion (Cedric Owens / others wrote it up).
- **CVE-2021-30746** — `smbd` XPC related, codesign check skipped on certain entitlements.
- **CVE-2022-26706** — `Office` macro sandbox escape via LaunchServices XPC.
- **CVE-2023-32369 (Migraine)** — `systemmigrationd` XPC abused to bypass [[sip]].
- **CVE-2024-44243** — another SIP bypass via Storage Kit daemon XPC.
- **Many third-party helpers** — VPN clients, antivirus, Docker Desktop, Zoom (CVE-2022-28756), `SecureUpdater`-pattern helpers. The common thread: `SMJobBless`-installed root helper that did not pin a code requirement to the calling app.

For each: figure out *which* of the bug patterns above applied. That is the quickest path to internalising XPC auditing.

## Defensive baseline

If you are writing or reviewing a privileged XPC service:

- Use `NSXPCListener` only for services you actually expose; do not listen on more endpoints than you need.
- In `shouldAcceptNewConnection:`, immediately:
  - Read the audit token from the connection (not from any message).
  - Resolve a `SecCodeRef` with `kSecGuestAttributeAudit`.
  - Validate with `SecCodeCheckValidity` against a pinned `SecRequirementRef`. Include team ID, identifier, and minimum version.
  - Optionally enforce a specific entitlement on the peer.
- Set `exportedInterface` with a tightly scoped `@protocol`. For every selector that takes object arguments, call `setClasses:forSelector:argumentIndex:ofReply:` with the *minimum* class set (e.g. `[NSSet setWithObjects:[NSString class], nil]`).
- Validate every argument: paths must be canonicalised with `realpath` and re-checked, URLs must have schemes you expect, no symlink traversal, etc.
- Log peer audit tokens to the unified log on every privileged operation. See [[macos-unified-logs-forensics]].
- For a deployable hardening checklist, cross-reference [[macos-userland-mitigations]] and [[entitlements-and-codesigning]].

## Workflow to study XPC services

1. **Enumerate.** `launchctl list | grep -i <vendor>`, plus `ls /Library/LaunchDaemons /Library/LaunchAgents ~/Library/LaunchAgents`. Parse each plist for `MachServices` and `Program(Arguments)`.
2. **Triangulate the binary.** Open it in Hopper / IDA / Ghidra. Look for `NSXPCListener`, `xpc_connection_set_event_handler`, the protocol it implements.
3. **Find the gate.** Search for `SecCodeCopyGuestWithAttributes`, `SecRequirementCreateWithString`, `SecCodeCheckValidity`, `audit_token`, `processIdentifier`. Is the audit token connection-derived?
4. **Replay.** Write a tiny client that calls `xpc_connection_create_mach_service` against the helper's name and sends a probe. If the helper crashes, you have a research target; if it returns useful output, you have a primitive.
5. **Map the protocol.** For `NSXPCConnection`, you can dump the protocol from the Objective-C runtime metadata in the binary (class-dump-style tools, or `objc_copyProtocolList` from a loaded `dylib`). For C-level `libxpc`, you reverse the dictionary keys handled in the event handler.
6. **Audit each selector.** For each remote method, check: is the peer re-validated? Are arguments validated? Does any path eventually call something that runs as root (e.g. `posix_spawn`, `unlink`, `chown`)?
7. **Chain.** XPC bugs by themselves often need a planted file or symlink. Combine with [[macos-sandbox-escape]] tradecraft (sandboxed write into a writable location the helper trusts) for full impact.

See [[case-study-portswigger-top-10-pattern]] for how to write the eventual finding up, and [[reading-public-pocs-effectively]] for ingesting the existing literature.

## Tooling

- `xpcspy` (Frida-based, by Hubert Jasudowicz) — log XPC traffic in/out of a target process. Excellent for mapping unknown protocols.
- `procexp` and `lsmp` — list Mach ports and connections.
- `launchctl print` — exhaustive state of a service, including peers.
- `codesign -d --entitlements - --xml /path/to/binary` — see what the peer claims.
- Frida + `Interceptor` on `xpc_connection_send_message` — generic XPC sniffer/fuzzer base.
- `class-dump` / `ktool` — recover Objective-C protocol metadata from binaries.

## Related

- [[mach-and-xpc]]
- [[ios-ipc-xpc-audit]]
- [[macos-architecture]]
- [[macos-sandbox-escape]]
- [[macos-privesc]]
- [[macos-tcc]]
- [[entitlements-and-codesigning]]
- [[macos-userland-mitigations]]
- [[macos-unified-logs-forensics]]
- [[sip]]
- [[sip-bypasses]]
- [[ios-vs-macos-divergence]]
- [[iokit-attack-surface]]

## References

- Apple, "Creating XPC Services" and "Defining the XPC Service Interface" — https://developer.apple.com/documentation/xpc
- Wojciech Reguła, "Learn XPC exploitation" series — https://wojciechregula.blog/post/learn-xpc-exploitation-part-1-broken-cryptography/
- Csaba Fitzl, "20+ ways to bypass your macOS privacy mechanisms" (Objective by the Sea) — https://objectivebythesea.org/v4/talks/OBTS_v4_cFitzl.pdf
- Samuel Groß, "Auditing macOS XPC services" — https://saelo.github.io/presentations/warcon18_dont_trust_the_pixel.pdf
- Apple, `xpc_connection_get_audit_token` reference (Darwin source) — https://opensource.apple.com/source/libxpc/
- Project Zero, "A walk through Project Zero metrics" and various macOS XPC writeups — https://googleprojectzero.blogspot.com/
