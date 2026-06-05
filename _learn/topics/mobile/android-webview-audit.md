---
title: Android WebView — source audit
slug: android-webview-audit
aliases: [webview-audit-android]
---

{% raw %}

> **TL;DR:** WebView is a small browser shipped inside your app. It runs HTML/JS with the app's privileges. Source-audit risks: `addJavascriptInterface` exposing app objects to JS, `setAllowFileAccess*` allowing `file://` to read app data, mixed-content / cleartext upgrades, custom URL handlers that pass URLs to other components without validation, and `shouldOverrideUrlLoading` that opens arbitrary schemes.

## The dangerous WebSettings

```bash
grep -rnE 'setJavaScriptEnabled\(true\)' src/
grep -rnE 'addJavascriptInterface' src/
grep -rnE 'setAllowFileAccess\(true\)|setAllowFileAccessFromFileURLs\(true\)|setAllowUniversalAccessFromFileURLs\(true\)' src/
grep -rnE 'setAllowContentAccess\(true\)|setMixedContentMode\(MIXED_CONTENT_ALWAYS_ALLOW\)' src/
grep -rnE 'setWebContentsDebuggingEnabled\(true\)' src/
```

| Setting | Why bad |
|---|---|
| `setJavaScriptEnabled(true)` + remote URL | XSS becomes app-context code |
| `addJavascriptInterface(obj, "name")` | JS can call methods on `obj` — see below |
| `setAllowFileAccessFromFileURLs(true)` | `file://x.html` reads any other `file://` — data exfil |
| `setAllowUniversalAccessFromFileURLs(true)` | `file://` reads HTTP — even worse |
| `setAllowContentAccess(true)` | WebView can fetch from `content://` providers |
| `setMixedContentMode(MIXED_CONTENT_ALWAYS_ALLOW)` | HTTP injected into HTTPS page |
| `setWebContentsDebuggingEnabled(true)` in release | chrome://inspect attaches to any device |

## `addJavascriptInterface` — the classic bug

```java
webView.addJavascriptInterface(new AppBridge(), "Android");
```

In the loaded page:
```js
Android.openExternalUrl(maliciousUrl);
```

If `AppBridge` exposes any method that touches sensitive state (start activities, read files, hit private APIs), JS in the WebView reaches them.

Pre-API-17 the implementation also exposed `Object#getClass()` reflectively → arbitrary code execution via reflection. Modern Android requires `@JavascriptInterface` annotation, which limits to annotated methods only. *But* the bridge still has whatever powers you annotate.

Source audit:
```bash
grep -rn 'addJavascriptInterface' src/ -B2 -A5
grep -rn '@JavascriptInterface' src/
```

For each annotated method: trace what app data or APIs it reaches.

## `loadUrl` with attacker-controlled URL

```kotlin
val url = intent.getStringExtra("url") ?: return
webView.loadUrl(url)             // BAD: attacker-controlled URL, any scheme
```

Mitigations:
- Validate the URL is HTTPS and host-matches an allowlist.
- Reject `file://`, `content://`, `javascript:`, `data:`.
- Reject URLs with `..` segments after canonicalisation.

## `shouldOverrideUrlLoading`

This callback decides whether the WebView handles a URL or hands it to the OS. A common bug:

```kotlin
override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
    val url = request.url
    val intent = Intent(Intent.ACTION_VIEW, url)
    startActivity(intent)        // BAD: any scheme reachable, including intent://
    return true
}
```

Custom schemes like `intent://#Intent;...`, `market://`, `whatsapp://`, and `javascript:` can be turned into surprising side effects.

## file://, content://, and the SOP

WebView treats every `file://` URL as a unique origin (so JS can't read other files) — but only if `setAllowFileAccessFromFileURLs` is false. Setting it true collapses file:// origins together. This is the canonical Android "local file read from a WebView" bug pattern.

```bash
grep -rn 'loadUrl\("file://\|loadUrl\(".*file://' src/
```

## Token leakage via WebView

A common SSO pattern: load the OAuth provider in a WebView, capture the redirect URL after auth. Bugs:
- Reading the access-token from the URL fragment via `evaluateJavascript("window.location.hash")` exposes the token to anything injected into that page.
- Persisting cookies cross-app if `CookieManager` is shared.

```bash
grep -rn 'CookieManager\.getInstance\|setAcceptCookie\|setAcceptThirdPartyCookies' src/
grep -rn 'evaluateJavascript' src/
```

## TLS errors handled silently

```java
@Override
public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
    handler.proceed();      // BAD: accept any cert
}
```

A `handler.proceed()` in `onReceivedSslError` makes the WebView blind to MITM. Sometimes added "for testing" and shipped.

```bash
grep -rn 'onReceivedSslError\|handler\.proceed' src/
```

## URL allowlist patterns

```kotlin
private val allowedHosts = setOf("app.example.com", "auth.example.com")

override fun shouldOverrideUrlLoading(view: WebView, req: WebResourceRequest): Boolean {
    val host = req.url.host ?: return true
    if (host !in allowedHosts) {
        Log.w("WV", "blocked $host"); return true
    }
    return false   // let WebView load it
}
```

Audit-time: does the allowlist include subdomain wildcards? Are there subdomains under your control that host user content (jsfiddle-style)?

## AndroidX `WebViewAssetLoader`

The modern recommendation. Loads local assets via an internal `https://appassets.androidplatform.net/` origin, isolating from `file://` issues.

If you see this, the app is doing the right thing. If you don't, and `setAllowFileAccess(true)` is set, flag for review.

## Source-audit checklist
- [ ] No `setAllowFileAccessFromFileURLs(true)` / `setAllowUniversalAccessFromFileURLs(true)`.
- [ ] No `setMixedContentMode(MIXED_CONTENT_ALWAYS_ALLOW)` in production builds.
- [ ] Every `addJavascriptInterface` bridge has a documented, minimal API surface.
- [ ] `shouldOverrideUrlLoading` rejects non-HTTPS or applies a host allowlist.
- [ ] No `handler.proceed()` in `onReceivedSslError`.
- [ ] `setWebContentsDebuggingEnabled(true)` is wrapped in `BuildConfig.DEBUG`.

## References
- [Android — WebView best practices](https://developer.android.com/reference/android/webkit/WebView)
- [AndroidX WebViewAssetLoader](https://developer.android.com/reference/androidx/webkit/WebViewAssetLoader)
- [OWASP MASTG — WebViews](https://mas.owasp.org/MASTG/0x05h-Testing-Platform-Interaction/)
- See also: [[android-source-review-methodology]], [[android-deeplink-source-audit]], [[mobile-cert-pinning-source-audit]]

{% endraw %}
