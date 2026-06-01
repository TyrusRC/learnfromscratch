---
title: Mach and XPC
slug: mach-and-xpc
---

> **TL;DR:** Mach is XNU's kernel-level IPC: tasks, threads, and *ports* with rights. XPC is the Apple-flavoured higher-level RPC built on top, with bplist-encoded messages, NSXPCConnection objects, and `launchd`-managed service endpoints. Most macOS LPE chains pivot through one or both.

## What it is
**Mach IPC** primitives:
- A **port** is a kernel-managed message queue. Tasks hold **rights** to ports: send, receive, send-once.
- `mach_msg(2)` sends/receives typed messages — they can carry inline data, OOL memory, and *port descriptors* (transferring rights).
- The **bootstrap server** (`launchd`) brokers named-service lookups: a daemon registers a port under a string ("com.apple.foo"), clients look it up.

**XPC** is the userspace layer:
- `xpc_connection_t` / `NSXPCConnection` wrap a Mach port pair, encode/decode messages as XPC dictionaries (bplist-like).
- `launchd` reads `LaunchDaemons`/`LaunchAgents` plists, owns the lifecycle, and applies entitlement-based access control on connect.
- Modern Apple services (`tccd`, `cfprefsd`, `nehelper`, `coreduetd`) all expose XPC endpoints.

## Preconditions / where it applies
- Local code execution as some user/process — Mach/XPC is the connective tissue between you and every privileged daemon.
- Sandbox-escape research nearly always begins with "what Mach services can I look up?". See [[macos-sandbox-escape]].
- Auditing third-party privileged helpers — they often expose XPC services with weak validation.

## Technique
Enumerate what is reachable:

```bash
launchctl print system | grep -A1 "name ="           # registered services
launchctl print user/$(id -u) | grep -A1 "name ="
sudo /usr/bin/sample tccd 1 2>/dev/null               # quick visibility of running daemon
```

Connect to a service from code (Objective-C):

```objc
NSXPCConnection *c = [[NSXPCConnection alloc]
    initWithMachServiceName:@"com.example.helper"
    options:NSXPCConnectionPrivileged];
c.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperProto)];
[c resume];
[[c remoteObjectProxy] doPrivilegedThing:input];
```

Common bug classes:
1. **Missing peer validation** — server does not check the client's **audit token** / code signature / entitlements. Any process can call the privileged method. Use `xpc_connection_get_audit_token` and `SecCodeCopyGuestWithAttributes` to validate; many helpers forget.
2. **Entitlement inheritance / privileged helper** — `SMJobBless` installs a helper running as root; if the helper uses a weak Designated Requirement, a different signed app can drive it.
3. **Object-graph deserialisation** — `NSXPCDecoder` allowed classes can be too permissive; combined with NS-class gadgets historically led to RCE-as-privileged-daemon (CVE-2019-8513 et al.).
4. **Mach port confusion** — passing a port rights descriptor and the receiver mis-handles the lifetime/right type (CVE-2019-8605 "SockPuppet" used a similar pattern in the kernel).
5. **Bootstrap-name squatting in agents** — if a service name is not exclusive, a user-context attacker can register first and impersonate.

For research, log XPC traffic with `xpcproxy` traces and inspect plists in `/System/Library/LaunchDaemons/` for `MachServices` keys and `JoinExistingSession`.

## Detection and defence
- EndpointSecurity surfaces process exec but not raw Mach messages — telemetry-blind for most XPC. Defenders rely on daemon-side validation and Apple's hardening.
- For developers: always check peer entitlements/audit token, use `NSXPCConnection.remoteObjectInterface` allowed-classes lists, run helpers with the least privilege, and prefer `SMAppService` over old `SMJobBless` patterns on modern macOS.
- See [[entitlements-and-codesigning]] for the identity side and [[macos-privesc]] for full privesc chains via XPC.

## References
- [Apple — Creating XPC Services](https://developer.apple.com/documentation/xpc/creating-xpc-services) — developer docs.
- [HackTricks — macOS XPC](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-proces-abuse/macos-ipc-inter-process-communication/macos-xpc.html) — bug-class taxonomy.
- [Wojciech Reguła — XPC attacks blog](https://wojciechregula.blog/) — series of real-world XPC bypasses.
