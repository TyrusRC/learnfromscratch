---
title: Android deep link / App Link — source audit
slug: android-deeplink-source-audit
aliases: [android-deeplink-audit, app-link-audit]
---

{% raw %}

> **TL;DR:** Deep links are intents that open your app from a URL. From source: check the intent-filter (scheme, host, pathPattern), confirm the Activity validates URI segments before dispatch, and confirm sensitive endpoints (password reset, OAuth callbacks) require verified App Links — not bare custom schemes. Pair with [[android-deeplink-abuse]] (attacker angle) and [[android-source-review-methodology]].

## Intent-filter triage

```xml
<activity android:name=".LinkRouter" android:exported="true">
  <intent-filter android:autoVerify="true">                ← App Link?
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https"
          android:host="app.example.com"
          android:pathPattern="/r/.*"/>
  </intent-filter>
  <intent-filter>                                            ← custom scheme
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="myapp" android:host="reset"/>
  </intent-filter>
</activity>
```

Three classes of filter:

| Class | Strength |
|---|---|
| `android:autoVerify="true"` + matching `/.well-known/assetlinks.json` on the host | App Link — only your app can handle, *if* assetlinks.json is correct |
| `scheme="https"`, no autoVerify | Any app on the device that filters `https` + host can receive |
| Custom scheme `myapp://` | Any app that registers the same scheme receives — **scheme hijacking** |

## assetlinks.json (the App Link "lock")

```text
https://app.example.com/.well-known/assetlinks.json
```

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.app",
    "sha256_cert_fingerprints": ["AA:BB:..."]
  }
}]
```

Audit:
- The signing-cert fingerprint matches release builds.
- For staged rollouts, debug build fingerprints are *not* in the production file.
- The path `/.well-known/assetlinks.json` is HTTPS, no redirects, valid JSON.

Failure modes:
- assetlinks.json missing → Android falls back to the disambiguation chooser; user can pick the malicious app.
- assetlinks.json present but wrong fingerprint → verification fails silently for the user; same chooser appears.
- `pathPattern="/.*"` covers the whole host, so a malicious link `https://app.example.com/anything` opens your router activity.

## The Activity that handles the link

```kotlin
class LinkRouter : Activity() {
    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        val uri = intent.data ?: return finish()
        when (uri.path) {
            "/r/login"        -> startActivity(LoginActivity.intent(this, uri))
            "/r/reset"        -> startActivity(ResetActivity.intent(this, uri))
            "/r/payments"     -> startActivity(PaymentsActivity.intent(this, uri))
            else              -> finish()
        }
    }
}
```

Audit angles:

### 1. Trust of URI parameters
```kotlin
val token = uri.getQueryParameter("token")
PasswordResetActivity.start(this, token)
```
Token may be attacker-supplied (the URL came from the network). The downstream activity must validate it server-side, not trust it.

### 2. Open redirect via deep link

```kotlin
val next = uri.getQueryParameter("next") ?: "/"
webView.loadUrl(next)                  // BAD: any URL
```

Same SSRF/open-redirect pattern as web — but worse because some users have FaceID/biometric auto-unlock and the WebView runs with the app's network identity.

### 3. Intent extraction from query

```kotlin
val raw = uri.getQueryParameter("intent") ?: return
val i = Intent.parseUri(raw, Intent.URI_INTENT_SCHEME)
startActivity(i)                       // BAD: intent redirection from URL
```

`Intent.parseUri` will happily parse `#Intent;...;component=com.example/.SensitiveActivity;end` and reach inside your unexported components.

## Custom-scheme deep links

A scheme like `myapp://reset?token=...` is registered by *any* app that filters for `myapp`. The OS shows a chooser to the user — and many users tap the wrong icon. For sensitive flows (OAuth callbacks, password reset) prefer App Links with autoVerify and assetlinks.json.

## OAuth callbacks specifically

If the OAuth provider redirects to `myapp://oauth-callback?code=...`:
1. A malicious app registers the same scheme.
2. User completes OAuth in browser; the browser dispatches the callback URL.
3. The malicious app intercepts the `code`.
4. Exchange code for tokens at the IdP — depending on PKCE state, this may succeed.

Defence — PKCE (RFC 7636) tied to a verifier known only to your app; verifies the exchange even if the code is intercepted. Audit `code_verifier`/`code_challenge` handling.

## URI parsing pitfalls

```kotlin
val host = uri.host
if (host == "app.example.com") allow()
```

Trap: `https://app.example.com.attacker.tld/path` — but `Uri#getHost` returns `app.example.com.attacker.tld` (full). So the check is safe *as written*. The dangerous variant:

```kotlin
if (host?.endsWith("example.com") == true) allow()  // BAD: anything.example.com.attacker.tld
```

Always anchor and compare full hostnames.

## Source-audit checklist
- [ ] Every sensitive deep link uses an App Link (autoVerify) backed by a correct assetlinks.json.
- [ ] No custom schemes for OAuth or password reset.
- [ ] Activity that handles links uses path matching on a hard-coded allowlist — not free-form parsing.
- [ ] No `Intent.parseUri(...)` from a URL parameter.
- [ ] No `loadUrl(getQueryParameter("next"))` chains.
- [ ] Host comparisons use `==`, not `endsWith`.

## References
- [Android App Links docs](https://developer.android.com/training/app-links)
- [Android — Digital Asset Links](https://developers.google.com/digital-asset-links)
- [OWASP MASTG — deep links](https://mas.owasp.org/MASTG/0x05h-Testing-Platform-Interaction/)
- See also: [[android-source-review-methodology]], [[android-deeplink-abuse]], [[android-webview-audit]], [[android-ipc-and-intent-source-audit]]

{% endraw %}
