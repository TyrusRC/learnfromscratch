---
title: iOS IPC and XPC — source audit
slug: ios-ipc-xpc-audit
aliases: [ios-ipc-audit, xpc-audit]
---

{% raw %}

> **TL;DR:** iOS apps talk to extensions, app groups, and (on macOS-Catalyst/SystemExtensions) XPC services. Source-audit risks: XPC interfaces with weak `NSSecureCoding` allow-lists (object substitution), `setExportedInterface` exposing too much, missing client audit-token validation, app-group shared containers used as untrusted inboxes, and Pasteboard as a "covert" IPC that anything on the device can sniff. Companion to [[ios-source-review-methodology]] and [[android-ipc-and-intent-source-audit]].

## Surfaces

| Surface | Where used |
|---|---|
| App Extensions (Share, Action, Today, Network) | always-on, sandboxed |
| App Groups (shared `Documents`, `UserDefaults`) | host ↔ extensions ↔ companion apps |
| XPC (`NSXPCConnection`) | system / network / file-provider extensions, macOS-Catalyst |
| Custom URL schemes / Universal Links | external IPC ([[ios-url-scheme-and-universal-link-audit]]) |
| Pasteboard | any-to-any, but with iOS 14+ system warnings |
| Mach ports (low-level) | rare in app code, common in SystemExtensions |

## XPC — the audit shape

```swift
let interface = NSXPCInterface(with: VaultServiceProtocol.self)
interface.setClasses(NSSet(objects: NSString.self, NSData.self) as! Set<AnyHashable>,
                     for: #selector(VaultServiceProtocol.store(_:value:reply:)),
                     argumentIndex: 1, ofReply: false)
let connection = NSXPCConnection(machServiceName: "com.example.vault", options: [])
connection.exportedInterface = interface
connection.exportedObject = VaultService()
connection.resume()
```

The four things to check:

### 1. Interface allow-lists (`setClasses`)
Without `setClasses`, decoded objects can be any `NSSecureCoding` class — including classes that aren't yours, leading to "object substitution" decode-time gadgets. Always allow-list types per argument.

### 2. Validate the peer
```swift
connection.exportedInterface?.setClasses(...)
// On every invocation, verify the caller:
if let token = connection.auditToken {
    let peer = SecCodeCopyGuestWithAttributes([... audit token ...])
    // verify peer signing identity is one you trust
}
```

Greps:
```bash
grep -rn 'auditToken\|SecCodeCopyGuestWithAttributes\|SecRequirementCreateWithString' .
```

Absence on a privileged service is a finding.

### 3. Don't trust the bundle identifier in a string
Calling code can lie about its identity via NSString fields. Identity comes from the audit token + code-signing requirement.

### 4. Interface surface

Look at the protocol. Every method is callable; each that touches sensitive state needs argument validation. Match Android's `onBind` rules.

## App Group shared containers

```swift
let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.shared")
let inbox = url!.appendingPathComponent("inbox/")
```

Files in the shared container are written by *any* app in the group. Treat reads from this container as untrusted input.

Bugs:
- Plist deserialisation of attacker-written file.
- Image decode of attacker-written file (libpng/libjpeg CVEs).
- "Restore my session from inbox/state.json" — config injection.

## Shared UserDefaults

```swift
let defs = UserDefaults(suiteName: "group.com.example.shared")
defs?.set(token, forKey: "authToken")
```

A second app in the group with a different threat model can read/write. Audit the *other* app's behaviour, not just yours.

## Pasteboard

```swift
UIPasteboard.general.string = code   // BAD: any app can read
```

Patterns:
- One-time codes copied for the user → another app on the device reads them.
- Tokens or secrets written even briefly → visible to other apps via `UIPasteboardChangedNotification`.

Mitigations:
- iOS 14+ warns when an app reads the pasteboard; users notice. Don't read in viewDidAppear.
- For sensitive flows use `UIPasteboard` with `setItems(_:options: [.expirationDate: Date()...])`.
- Use named pasteboards with `withName:create:` for app-group-scoped sharing.

## Extension boundary

Extensions are separate processes with their own entitlements. The host and extension talk through:
- The extension principal class API (`NSExtensionContext`).
- App-group shared containers.
- Optional XPC.

Bugs cluster on:
- Extension trusting `NSExtensionItem.userInfo` blindly.
- Host treating extension-returned data as fully trusted.

```bash
grep -rn 'NSExtensionContext\|NSExtensionItem' .
```

## Mach service names

```bash
grep -rn 'NSXPCConnection(machServiceName' .
```

A Mach service name not prefixed by your team ID can be hijacked. Use the team prefix and verify in `Info.plist`.

## Distributed Notifications and Darwin Notifications

`CFNotificationCenter` Darwin notifications are system-wide. They carry no payload but can leak event timing. Avoid using for "user logged in" events.

## Source-audit checklist
- [ ] Every `NSXPCInterface` uses `setClasses` per argument.
- [ ] Server validates client by audit token + code-signing requirement.
- [ ] App-group shared container reads treated as untrusted.
- [ ] Shared UserDefaults limited to non-sensitive data.
- [ ] No secrets ever in `UIPasteboard.general`.
- [ ] Mach service names team-prefixed and Info.plist-declared.
- [ ] Extension boundaries enforce input validation both ways.

## References
- [Apple — XPC services](https://developer.apple.com/documentation/xpc)
- [Apple — App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [OWASP MASTG — iOS network communication and IPC](https://mas.owasp.org/MASTG/0x06h-Testing-Platform-Interaction/)
- See also: [[ios-source-review-methodology]], [[ios-url-scheme-and-universal-link-audit]], [[ios-wkwebview-audit]]

{% endraw %}
