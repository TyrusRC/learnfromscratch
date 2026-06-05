---
title: Mobile auth token handling — source audit
slug: mobile-auth-token-handling-audit
aliases: [mobile-auth-audit, mobile-token-handling]
---

{% raw %}

> **TL;DR:** Mobile apps hold access tokens and refresh tokens. Source-audit risks: tokens in plain storage, refresh tokens with no rotation, tokens shared across user accounts on the same device, tokens leaked through deep links/logs/clipboard, biometric-bound tokens that aren't actually bound, and tokens that survive uninstall via Keychain accessibility. Companion to [[mobile-client-storage-source-audit]] and [[android-keystore-and-crypto-audit]] / [[ios-keychain-and-secure-enclave-audit]].

## What "good" looks like

- Access tokens — short-lived (≤ 1h), held in memory; persisted only if the app needs offline auth.
- Refresh tokens — single-use (rotated on every refresh), Keystore/Keychain-bound, biometric-gated if the threat model requires.
- Both stored in hardware-backed storage, wiped on logout, never logged, never copied to clipboard.

## Where to look

```bash
# Storage entry points
grep -rn 'token\|Token\|jwt\|accessToken\|refreshToken\|bearerToken' src/ -i

# Networking interceptors
grep -rn 'Interceptor\|RequestInterceptor\|URLProtocol\|adaptForRequest\|adapt(_:for:completion:)' .

# Auth flows
grep -rn 'login\|signIn\|signOut\|logout\|refresh' src/ -i
```

## Bug class 1 — refresh token stored badly

The most common finding:
```kotlin
prefs.edit().putString("refresh_token", token).apply()    // BAD
```

Fix: Keystore-encrypted prefs or `EncryptedSharedPreferences`. See [[android-keystore-and-crypto-audit]].

## Bug class 2 — refresh token *not* rotated

Refresh tokens should be single-use; the IdP issues a fresh one on each `/token` call. Apps that re-use the same refresh token across logins violate OAuth best practice and turn token theft into long-term access.

Audit the refresh flow:
```kotlin
val newAccess = api.refresh(currentRefresh)
saveAccess(newAccess.access_token)
saveRefresh(newAccess.refresh_token)   // must overwrite the old one
```

Missing `saveRefresh` is a finding.

## Bug class 3 — tokens leaked through logs

```bash
grep -rn 'Log\.[diwev]\|println\|NSLog\|os_log\|print(' . | grep -i 'token\|password\|secret'
```

`Log.d("AUTH", "got token $token")` ships in release if logging isn't stripped. Verify ProGuard rules / R8 strip `android.util.Log.d/v/i` calls in release.

```bash
grep -rn 'assumenosideeffects' proguard-rules.pro
```

On iOS, search for `os_log` with `%@` formatting of tokens; the system log persists across reboots.

## Bug class 4 — tokens in URL parameters

```kotlin
val url = "https://api.example.com/me?token=$token"
```

URLs end up in:
- Crash reports.
- WebView history.
- Analytics logs.
- Referrer headers to third parties.

Always send tokens in `Authorization` headers, never query strings.

## Bug class 5 — tokens shared across users on the same device

If the app supports multiple accounts, tokens for account A must not be readable when account B is active. Mistake patterns:
- One `prefs` file storing both accounts' tokens; the active account is selected by a flag.
- Keychain items keyed only by `kSecAttrService` without `kSecAttrAccount`, so the lookup returns either user's token.

Audit:
- Tokens keyed by user ID.
- `SecItemCopyMatching` queries include `kSecAttrAccount`.

## Bug class 6 — tokens that survive uninstall

iOS Keychain items with `kSecAttrAccessible` = `Always` or `AfterFirstUnlock` survive app uninstall on some iOS versions. A user uninstalls a banking app, reinstalls — and the old token is still valid until it expires.

Fix: on first launch, wipe any pre-existing Keychain items belonging to the app.

```swift
let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
SecItemDelete(q as CFDictionary)
```

## Bug class 7 — biometric "binding" that isn't binding

App shows a `BiometricPrompt` / Face ID prompt. On success, reads the token from Keychain and uses it. The bug: the Keychain item is *not* bound to the biometric — the read succeeded because the device was unlocked. A malicious process running while the device is unlocked also reads it.

Fix: bind the cipher (Android) or use `kSecAccessControl` with `.biometryCurrentSet` (iOS). See [[android-keystore-and-crypto-audit]] / [[ios-keychain-and-secure-enclave-audit]].

## Bug class 8 — token in clipboard

```bash
grep -rn 'ClipboardManager\|setPrimaryClip\|UIPasteboard\.general\.string' .
```

OAuth flows that "copy the code to paste in the app" — flag, since clipboard is system-wide. Use deep-link-back patterns instead.

## Bug class 9 — refresh flow race

If multiple HTTP requests happen near token expiry, each spawns its own refresh and the rotation races. Surface bugs:
- The IdP invalidates the older refresh token; some in-flight requests use a now-invalid access token; user is signed out.
- Token race uses an old refresh after rotation; replay attack window opens.

Audit refresh interceptors for a mutex / single-flight pattern:
```kotlin
private val refreshMutex = Mutex()
suspend fun refresh() = refreshMutex.withLock { ... }
```

## Bug class 10 — JWT validation client-side only

A client-side check of an access token's expiry or signature is *not* a security control. The bug is treating it as one.

```kotlin
if (jwt.isValid()) sendAuthorizedRequest()    // BAD: trust on the client
```

The backend must validate. The client's only legitimate use of expiry is "should I refresh proactively?" — never "should I trust this token?".

## Source-audit checklist
- [ ] Refresh tokens in Keystore/Keychain, never in SharedPreferences/UserDefaults.
- [ ] Refresh rotation: every refresh saves the new refresh token.
- [ ] No tokens in logs (verify R8/strip rules).
- [ ] No tokens in URL parameters.
- [ ] Per-user keying for multi-account apps.
- [ ] Wipe Keychain/Keystore on first launch to clear post-uninstall residue.
- [ ] Biometric binding actually binds the crypto operation.
- [ ] No token-in-clipboard flows.
- [ ] Single-flight refresh.
- [ ] Server is the only authoritative validator.

## References
- [OAuth 2.0 for Mobile and Native Apps (RFC 8252)](https://datatracker.ietf.org/doc/html/rfc8252)
- [OAuth 2.0 Security Best Current Practice](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
- [OWASP MASTG — authentication](https://mas.owasp.org/MASTG/0x04e-Testing-Authentication-and-Session-Management/)
- See also: [[mobile-client-storage-source-audit]], [[android-keystore-and-crypto-audit]], [[ios-keychain-and-secure-enclave-audit]], [[mobile-cert-pinning-source-audit]]

{% endraw %}
