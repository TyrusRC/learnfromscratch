---
title: iOS WKWebView — source audit
slug: ios-wkwebview-audit
aliases: [wkwebview-audit]
---

{% raw %}

> **TL;DR:** WKWebView is iOS's modern WebView. Source-audit risks: `addUserScript` injecting privileged JS, `WKScriptMessageHandler` callbacks trusting any postMessage caller, `loadFileURL` with attacker-controlled paths, `decidePolicyFor` callbacks that follow arbitrary schemes, and `serverTrustChallenge` accepting any cert. Companion to [[ios-source-review-methodology]] and [[android-webview-audit]].

## Greps

```bash
grep -rn 'WKWebView\|WKWebViewConfiguration' .
grep -rn 'WKUserContentController\|addUserScript\|add(_:name:)\|WKScriptMessageHandler\|WKScriptMessageHandlerWithReply' .
grep -rn 'loadFileURL\|loadHTMLString' .
grep -rn 'decidePolicyFor navigationAction\|decidePolicyFor navigationResponse' .
grep -rn 'didReceive challenge\|serverTrust' .
```

## The bridge — `WKScriptMessageHandler`

```swift
configuration.userContentController.add(self, name: "AppBridge")
// JS side:
// window.webkit.messageHandlers.AppBridge.postMessage({cmd: "openFile", arg: "..."})

func userContentController(_ uc: WKUserContentController, didReceive m: WKScriptMessage) {
    guard let body = m.body as? [String: Any],
          let cmd = body["cmd"] as? String else { return }
    switch cmd {
    case "openFile":
        if let path = body["arg"] as? String {
            try? FileManager.default.contents(atPath: path)   // BAD: arbitrary read
        }
    case "exec":
        ...
    }
}
```

Three problems:
1. JS in the WebView is the attacker if the page is remote or attacker-influenced.
2. No origin/frame check (`m.frameInfo.securityOrigin`).
3. The handler exposes filesystem semantics directly.

Fixes:
- Check `m.frameInfo.request.url.host` against an allowlist.
- Make commands type-safe (enum, schema-validated args).
- Never expose primitive FS/Network APIs through the bridge.

## `loadFileURL` and path-confined reads

```swift
let url = URL(fileURLWithPath: untrustedPath)
let dir = url.deletingLastPathComponent()
webView.loadFileURL(url, allowingReadAccessTo: dir)
```

`allowingReadAccessTo:` is the sandbox for the WebView. If `dir` is the user's whole Documents directory, every file under it becomes readable from in-WebView JS.

Audit:
- `allowingReadAccessTo` is the *tightest* directory that contains the loaded file.
- `untrustedPath` is validated against an allowlist or canonicalised.

## `decidePolicyFor`

```swift
func webView(_ wv: WKWebView, decidePolicyFor action: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if action.request.url?.scheme == "tel" {
        UIApplication.shared.open(action.request.url!)   // BAD if 'url' is attacker-shaped
        decisionHandler(.cancel); return
    }
    decisionHandler(.allow)
}
```

Bugs:
- Hand off any `URL` to `UIApplication.shared.open` → external scheme dispatch (mailto, tel, custom).
- Allow `javascript:` or `file://` for top-level navigations.
- Trust `_blank` targets and open them in a fresh, less-restricted WKWebView.

## Server trust challenge

```swift
func webView(_ wv: WKWebView, didReceive challenge: URLAuthenticationChallenge,
             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if let trust = challenge.protectionSpace.serverTrust {
        completionHandler(.useCredential, URLCredential(trust: trust))   // BAD: any cert
    }
}
```

Treats any `serverTrust` as valid → MITM. The right shape: use `SecTrustEvaluateWithError` and bail on failure, or pin via `URLSessionDelegate` (see [[mobile-cert-pinning-source-audit]]).

## User scripts injected at document-start

```swift
let script = WKUserScript(source: "window.appConfig = " + json,
                          injectionTime: .atDocumentStart, forMainFrameOnly: true)
configuration.userContentController.addUserScript(script)
```

Audit:
- `json` is a trusted server response or built from constants — not from URL parameters.
- `forMainFrameOnly: true` prevents injection into subframes.
- If injecting credentials or auth tokens via window globals — *never do this*. Use cookies/headers via `URLRequest`.

## Mixed content and `NSAppTransportSecurity`

A WKWebView inherits ATS rules. If `NSAllowsArbitraryLoads` is true, HTTP content loads inside an HTTPS-served page. Audit `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key><true/>     <!-- flag -->
  <key>NSExceptionDomains</key>
  <dict>
    <key>example.com</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>   <!-- per-domain HTTP -->
    </dict>
  </dict>
</dict>
```

## Process pool sharing

```swift
let pool = WKProcessPool()
configWebA.processPool = pool
configWebB.processPool = pool
```

Shared cookie/session storage across WKWebView instances. Useful — also a bug source if one webview is for first-party content and the other loads third-party.

## Source-audit checklist
- [ ] `WKScriptMessageHandler` callbacks validate `frameInfo` origin.
- [ ] Bridge commands are typed and constrained; no FS/network primitives exposed.
- [ ] `loadFileURL` confines `allowingReadAccessTo` to the smallest needed dir.
- [ ] `decidePolicyFor` rejects `file://`, `javascript:`, attacker-shaped external schemes.
- [ ] Server-trust challenge evaluates trust; no blanket `URLCredential(trust:)`.
- [ ] `NSAllowsArbitraryLoads` not set; per-domain exceptions justified.
- [ ] Process pool sharing intentional and documented.

## References
- [Apple — WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)
- [Apple — WKScriptMessageHandler](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler)
- [OWASP MASTG — iOS network communication](https://mas.owasp.org/MASTG/0x06g-Testing-Network-Communication/)
- See also: [[ios-source-review-methodology]], [[android-webview-audit]], [[mobile-cert-pinning-source-audit]]

{% endraw %}
