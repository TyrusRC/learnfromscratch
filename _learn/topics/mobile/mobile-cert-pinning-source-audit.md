---
title: Mobile certificate pinning — source audit
slug: mobile-cert-pinning-source-audit
aliases: [cert-pinning-source-audit, mobile-pinning-audit]
---

{% raw %}

> **TL;DR:** From source, certificate pinning is either (1) configured declaratively (Android Network Security Config, iOS info.plist pin set in modern SDKs) or (2) implemented in code via `X509TrustManager`/`OkHttpClient.certificatePinner` (Android) or `URLSessionDelegate.didReceive challenge:` (iOS). Common audit findings: pin missing for sensitive hosts, pin code that returns true on any error path, pin disabled in debug builds and the conditional that ships to prod, and SDKs that bypass the app's pinning entirely. Companion to [[ssl-pinning-bypass]] (attacker angle).

## Android — Network Security Config

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
  <domain-config>
    <domain includeSubdomains="true">api.example.com</domain>
    <pin-set expiration="2026-12-31">
      <pin digest="SHA-256">...primary key SPKI hash...</pin>
      <pin digest="SHA-256">...backup key SPKI hash...</pin>
    </pin-set>
    <trust-anchors>
      <certificates src="system"/>
    </trust-anchors>
  </domain-config>
  <debug-overrides>
    <trust-anchors>
      <certificates src="user"/>      <!-- accept user CAs in debug -->
    </trust-anchors>
  </debug-overrides>
</network-security-config>
```

Audit:
- Every sensitive host has a `domain-config` with `pin-set`.
- At least two pins (primary + backup) so rotation doesn't brick clients.
- `expiration` is far enough out but not so far it lives past the cert's own lifetime.
- `debug-overrides` only active under `android:debuggable="true"`.

```bash
grep -rn 'networkSecurityConfig' AndroidManifest.xml
find . -name 'network_security_config.xml'
```

## Android — OkHttp `CertificatePinner`

```kotlin
val client = OkHttpClient.Builder()
    .certificatePinner(
        CertificatePinner.Builder()
            .add("api.example.com", "sha256/...primary...")
            .add("api.example.com", "sha256/...backup...")
            .build()
    )
    .build()
```

Audit:
- Pins added for *every* OkHttpClient instance that talks to the sensitive backend.
- No `.dispatcher(...)` or `addInterceptor(...)` that swap in a different client at runtime.
- No third-party SDK creating its own OkHttpClient without pinning (analytics SDKs, payment SDKs).

## Android — custom `X509TrustManager` traps

```kotlin
val trustAll = object : X509TrustManager {
    override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
    override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}   // BAD
    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
}
```

If the `checkServerTrusted` body is empty or always returns successfully, there is no validation. Search:
```bash
grep -rn 'X509TrustManager\|HostnameVerifier\|ALLOW_ALL_HOSTNAME_VERIFIER' src/
grep -rn 'checkServerTrusted' src/ -A5
```

## iOS — URLSession server trust challenge

```swift
func urlSession(_ session: URLSession,
                didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
          let trust = challenge.protectionSpace.serverTrust else {
        completionHandler(.cancelAuthenticationChallenge, nil); return
    }
    // pin the leaf or SPKI
    if pinMatches(trust) {
        completionHandler(.useCredential, URLCredential(trust: trust))
    } else {
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
```

Trap forms:
- `completionHandler(.useCredential, URLCredential(trust: trust))` without `pinMatches` — accept any cert.
- `pinMatches` that only compares the *issuer CN* — a rogue CA issues anything.
- Pin check that returns true on Keychain lookup error.

```bash
grep -rn 'didReceive challenge\|serverTrust\|URLCredential(trust:' .
```

## iOS — App Transport Security exceptions

ATS pinning (`NSPinnedDomains` in iOS 14+):

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSPinnedDomains</key>
  <dict>
    <key>api.example.com</key>
    <dict>
      <key>NSPinnedLeafIdentities</key>
      <array><dict><key>SPKI-SHA256-BASE64</key><string>...</string></dict></array>
    </dict>
  </dict>
</dict>
```

This is declarative pinning enforced by NSURLSession. Audit Info.plist for presence + correctness.

## Cross-cutting bugs

### Pin only on first request
Some libraries check the pin only on the first request and cache trust; subsequent requests go through a cached `SecTrustRef` without re-verification.

### Debug-bypass shipped to production
```kotlin
if (BuildConfig.DEBUG || someFlag) {
    // skip pinning
}
```
A "flag" that's not strictly `BuildConfig.DEBUG` may ship enabled (toggled by a remote config feature flag, or by accident).

### Third-party SDKs
Each SDK has its own HTTP stack. Audit:
- Analytics SDKs (Firebase, Mixpanel, Segment).
- Auth SDKs (Auth0, Okta).
- Payment SDKs (Stripe, Braintree).
Each should be pinning the SDK's backend host, or at least not breaking your app's pin checks.

### WebView and `WKWebViewConfiguration`
WKWebView uses NSURLSession-backed networking but ignores your URLSessionDelegate. iOS 13+ supports `WKWebsiteDataStore` and ATS pinning for content; older builds may bypass. See [[ios-wkwebview-audit]].

## Pin source choice

| Type | Lifetime | Rotation cost |
|---|---|---|
| Leaf cert pin | Until cert expires (1y typical) | Each renewal |
| Intermediate cert pin | Years | Few renewals |
| SPKI (Subject Public Key Info) pin | Until key rotation | Rare |
| Root CA pin | Years/decades | Almost never |

Industry preference: **SPKI pin** with two pins (current key + backup key) and a process to swap before expiry.

## Source-audit checklist
- [ ] Sensitive hosts pinned via declarative config or in code.
- [ ] At least one backup pin per host.
- [ ] Pin expiry tracked in CI.
- [ ] No empty `checkServerTrusted` / always-true trust manager.
- [ ] iOS `URLSessionDelegate` actually rejects on mismatch (not cancel-then-retry).
- [ ] Debug overrides limited to `BuildConfig.DEBUG`/`#if DEBUG`.
- [ ] Third-party SDK HTTP stacks reviewed.

## References
- [Android — Network security config](https://developer.android.com/training/articles/security-config)
- [OkHttp — CertificatePinner](https://square.github.io/okhttp/3.x/okhttp/okhttp3/CertificatePinner.html)
- [Apple — Identity pinning with NSURLSession](https://developer.apple.com/news/?id=g9ejcf8y)
- [OWASP MASTG — TLS pinning](https://mas.owasp.org/MASTG/0x04f-Testing-Network-Communication/)
- See also: [[ssl-pinning-bypass]], [[android-source-review-methodology]], [[ios-source-review-methodology]]

{% endraw %}
