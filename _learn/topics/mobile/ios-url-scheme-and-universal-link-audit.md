---
title: iOS URL schemes and universal links — source audit
slug: ios-url-scheme-and-universal-link-audit
aliases: [ios-deeplink-audit, ios-url-scheme-audit]
---

{% raw %}

> **TL;DR:** iOS apps register custom URL schemes (`myapp://`) and universal links (`https://app.example.com/...`). Schemes are first-come-first-served and trivially squatted by other apps; universal links are verified via `apple-app-site-association` (AASA). Source-audit risks: trusting URL parameters, NSUserActivity injection, scheme races for OAuth, AASA misconfiguration, and `openURL` redirect chains. Companion to [[ios-source-review-methodology]] and [[android-deeplink-source-audit]].

## The two intake callbacks

```swift
// Custom URL scheme (myapp://)
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool

// Universal Link (https://...) and NSUserActivity
func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
```

Scene-based equivalents:
```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
func scene(_ scene: UIScene, continue userActivity: NSUserActivity)
```

Greps:
```bash
grep -rn 'application(_:open:options:)\|scene(_:openURLContexts:)' .
grep -rn 'application(_:continue:restorationHandler:)\|scene(_:continue:)' .
```

## Custom URL scheme — the squat risk

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>myapp</string></array>
  </dict>
</array>
```

Any other app on the device can register `myapp://`. iOS resolves "first install wins" in most cases; user-facing chooser appears in others. Either way, custom schemes are *not* an authentication boundary.

Consequence: never use `myapp://oauth-callback?code=...` as the only OAuth return path. PKCE must be applied so the intercepted code is unredeemable without the verifier.

## Universal Links — the AASA file

```text
https://app.example.com/.well-known/apple-app-site-association
```

```json
{
  "applinks": {
    "details": [{
      "appIDs": ["ABCDE12345.com.example.app"],
      "components": [{ "/": "/r/*" }]
    }]
  }
}
```

Audit:
- Served over HTTPS, no redirects.
- `Content-Type: application/json`.
- `appIDs` contains only intended bundle IDs (team prefix + bundle).
- `components` paths are tight; `"/*"` collapses universal-link routing to the whole host.
- `Associated Domains` capability in entitlements lists matching `applinks:app.example.com`.

Common bug: AASA exists but `appIDs` contains a *previous* bundle ID; the new app's universal links fail to verify and fall back to Safari → URL leakage via clipboard, screenshots, or extension hooks.

## Handler safety

```swift
func application(_ app: UIApplication, open url: URL, options: [...]) -> Bool {
    guard url.scheme == "myapp" else { return false }
    switch url.host {
    case "reset":
        guard let token = url.queryParam("token") else { return false }
        navigate(to: .reset(token: token))    // OK — server validates token
        return true
    case "open":
        if let target = url.queryParam("next") {
            UIApplication.shared.open(URL(string: target)!)   // BAD: open redirect / scheme abuse
        }
        return true
    default: return false
    }
}
```

Bugs to look for:
- `URL(string: someUrlParam)` then `UIApplication.shared.open(...)` — open redirect.
- Decoding a JSON blob from a URL parameter and calling `init(from: decoder)` on it — type confusion / over-injection.
- `webView.load(URLRequest(url: untrustedURL))` — `file://` and `javascript:` reachable.

## NSUserActivity injection

`NSUserActivity` carries `userInfo: [AnyHashable : Any]`. When delivered through `continue userActivity:`, treat:
- `activityType` — string controlled by caller.
- `webpageURL` — URL the OS provides for universal links; for system-shared activities the user/source controls it.
- `userInfo` — fully attacker-controlled if the activity came over Handoff (rare on iOS, more relevant cross-Mac).

Trust pattern:
```swift
guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = userActivity.webpageURL,
      let host = url.host, allowedHosts.contains(host) else { return false }
```

## `LSApplicationQueriesSchemes`

The Info.plist list of schemes the app may probe with `canOpenURL:`. From iOS 9 this is required for probing. Audit because:
- It's a manifest of "apps we care about" — useful triage indicator.
- The list itself doesn't grant trust; absence doesn't prevent attacker from sending you a URL.

## OAuth callbacks on iOS

Prefer:
1. `ASWebAuthenticationSession` — system-managed; redirects to your custom scheme but the OS guarantees only your app receives.
2. Universal Links — AASA-verified.

Avoid:
- Plain custom schemes for OAuth without PKCE.
- WKWebView-hosted OAuth where you scrape the redirect URL.

```bash
grep -rn 'ASWebAuthenticationSession\|SFAuthenticationSession\|OAuthSwift' .
```

## URL parsing pitfalls

```swift
if url.host?.hasSuffix("example.com") == true { allow() }   // BAD: subdomain bypass
```

Same trap as Android — anchor full hostname comparisons.

## Source-audit checklist
- [ ] Sensitive flows (auth, payments, password reset) ride Universal Links + AASA, not custom schemes.
- [ ] AASA `appIDs` lists only current bundles; `components` paths are tight.
- [ ] No `UIApplication.shared.open(URL(string: paramFromURL)!)` chains.
- [ ] OAuth uses `ASWebAuthenticationSession` with PKCE.
- [ ] URL host comparisons use exact match, not `hasSuffix`.
- [ ] `NSUserActivity` callbacks check `activityType` and host before trusting `userInfo`.

## References
- [Apple — Supporting Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Apple — ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [OWASP MASTG — iOS platform interaction](https://mas.owasp.org/MASTG/0x06h-Testing-Platform-Interaction/)
- See also: [[ios-source-review-methodology]], [[ios-wkwebview-audit]], [[android-deeplink-source-audit]]

{% endraw %}
