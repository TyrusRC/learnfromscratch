---
title: iOS source review methodology
slug: ios-source-review-methodology
aliases: [ios-source-audit, ios-whitebox]
---

{% raw %}

> **TL;DR:** iOS source review reads Info.plist + entitlements first (the OS-enforced trust map), then walks the URL scheme / universal link handlers, IPC (XPC, app groups, custom URL schemes), WebViews (WKWebView), Keychain usage, and the Objective-C/Swift bridge. Different vocabulary from Android, same shape of bugs. Companion to [[android-source-review-methodology]].

## Inputs
- `*.xcodeproj` / `*.xcworkspace` (build settings).
- `Info.plist` (the trust map).
- `<App>.entitlements` (sandbox + capability grants).
- `*.swift` / `*.m` / `*.mm` / `*.h`.
- `Podfile` / `Package.swift` — dependencies.
- `Build Settings` → especially `Hardened Runtime`, `App Sandbox`, `Allow Arbitrary Loads`.

## Step 1 — Info.plist triage

The five keys you must look at:

| Key | What it does |
|---|---|
| `CFBundleURLTypes` | Custom URL schemes the app handles |
| `LSApplicationQueriesSchemes` | Schemes the app can probe with `canOpenURL:` |
| `NSAppTransportSecurity` | TLS exception policy |
| `NSCameraUsageDescription` etc. | Sensitive permissions the app declares |
| `UIBackgroundModes` | Background execution capabilities |

```bash
plutil -p Info.plist | grep -E 'URLSchemes|ApplicationQueriesSchemes|AppTransportSecurity|UsageDescription|BackgroundModes'
```

If `NSAllowsArbitraryLoads = true`, the app talks plaintext HTTP. Flag.
If `CFBundleURLTypes` has any schemes, walk to the URL handler — see [[ios-url-scheme-and-universal-link-audit]].

## Step 2 — entitlements

```bash
codesign -d --entitlements :- App.app 2>/dev/null
# or in source:
cat App.entitlements
```

Capabilities to note:
- `com.apple.security.application-groups` — shared keychain/app-group container with other apps from the same team.
- `com.apple.developer.associated-domains` (`applinks:`) — universal link domains.
- `keychain-access-groups` — keychain sharing.
- `com.apple.security.cs.*` — Hardened Runtime exemptions (allow JIT, disable library validation).

A `com.apple.security.cs.disable-library-validation` entitlement means unsigned dylibs can load — sandbox escape primitive.

## Step 3 — entry points

```bash
grep -rn '@UIApplicationMain\|@main\|application(_:open:options:)\|application(_:continue:restorationHandler:)\|scene(_:openURLContexts:)\|scene(_:continue:)' .
```

These are the OS-level "incoming intent" callbacks:
- `application(_:open:options:)` — custom URL scheme delivery.
- `application(_:continue:restorationHandler:)` — universal link or NSUserActivity.
- `scene(_:openURLContexts:)` — same as above, scene-based.

For each, trace the URL/userActivity to where it lands. Treat the URL as fully attacker-controlled.

## Step 4 — Keychain
See [[ios-keychain-and-secure-enclave-audit]]. Grep:
```bash
grep -rn 'SecItemAdd\|SecItemCopyMatching\|SecItemUpdate\|kSecAttrAccessible\|kSecAccessControl' .
```

Wrong `kSecAttrAccessible` constant → background-readable secrets. Missing access control → no biometric gate.

## Step 5 — IPC / XPC

See [[ios-ipc-xpc-audit]]. Grep:
```bash
grep -rn 'NSXPCConnection\|NSXPCInterface\|XPCService\|MachService' .
grep -rn 'audit_token_t\|valueForAuditToken' .
```

XPC on macOS is heavily used; on iOS limited but present (system extensions, file providers, network extensions).

## Step 6 — WebView (WKWebView)

See [[ios-wkwebview-audit]]. Grep:
```bash
grep -rn 'WKWebView\|loadHTMLString\|loadFileURL\|userContentController\|WKUserScript\|WKScriptMessageHandler' .
```

## Step 7 — networking

```bash
grep -rn 'URLSession\|URLRequest\|Alamofire\|Moya' .
grep -rn 'serverTrustChallenge\|URLAuthenticationChallenge' .
```

Server trust callbacks that return `.useCredential` with a stolen `URLCredential(trust:)` from any cert → broken TLS validation.

## Step 8 — Obj-C / Swift bridging

See [[ios-objc-runtime-bridging-audit]]. Grep:
```bash
grep -rn '@objc\|@objcMembers\|NSSelectorFromString\|performSelector\|class_addMethod\|method_exchangeImplementations' .
```

Anything `performSelector` with a runtime-string selector is suspicious.

## Step 9 — sensitive data lifecycle

```bash
grep -rn 'UserDefaults\.standard\|UserDefaults(suiteName' .
grep -rn 'FileManager\.default\.urls(for:\.documentDirectory\|cachesDirectory\|temporaryDirectory' .
grep -rn 'NSKeyedArchiver\|NSKeyedUnarchiver\|JSONEncoder' .
```

UserDefaults = plist on disk. Anything sensitive in UserDefaults is a finding. Documents and tmp directories are backed up to iCloud unless excluded.

## Step 10 — third-party SDKs

```bash
cat Podfile Podfile.lock Package.resolved 2>/dev/null
```

Note auth SDKs (Auth0, Firebase, Okta), analytics (Mixpanel, Segment) — each is a separate trust evaluation, and out-of-date SDKs carry CVEs.

## Output structure

Same as Android: `where → what → why bad → repro`.

## References
- [Apple — App Security Overview](https://developer.apple.com/documentation/security)
- [OWASP MASTG — iOS testing](https://mas.owasp.org/MASTG/0x06b-iOS-Security-Testing/)
- [Apple — Universal Links](https://developer.apple.com/ios/universal-links/)
- See also: [[ios-url-scheme-and-universal-link-audit]], [[ios-keychain-and-secure-enclave-audit]], [[ios-ipc-xpc-audit]], [[ios-wkwebview-audit]], [[ios-objc-runtime-bridging-audit]], [[mobile-cert-pinning-source-audit]]

{% endraw %}
