---
title: Credential Management API attacks
slug: cred-management-api-attacks
aliases: [credential-management-api-attacks, navigator-credentials-attacks]
---

> **TL;DR:** The Credential Management API (`navigator.credentials.*`) is the browser interface for storing and retrieving authentication credentials — federated, password, public-key (WebAuthn / passkey). Attack surface centres on origin checks, store / read race conditions, and confused-deputy patterns where a page tricks the browser into giving credentials for a different origin. Foundational for FedCM and passkey flows. Companion to [[fedcm-attacks]] and [[webauthn-api-hijacking-downgrade]].

## Why this API matters

- It's the **canonical interface** for browser-managed credentials.
- Underlies **FedCM**, **WebAuthn passkeys**, **password autofill**.
- New API; bug-class surface still emerging.
- Browser-vendor implementations diverge.

## The API surface

### `navigator.credentials.get(options)`

Retrieve a credential. Options:
- `password: true` — request a password credential.
- `federated: {providers: [...]}` — federated.
- `publicKey: {challenge, ...}` — WebAuthn.
- `identity: {providers: [...]}` — FedCM.
- `mediation` — `silent` / `optional` / `required`.

### `navigator.credentials.store(credential)`

Store after a successful auth (e.g., "Save this password?").

### `navigator.credentials.create(options)`

Create a new credential (passkey enrollment).

### `navigator.credentials.preventSilentAccess()`

Force user interaction next time.

## Class 1 — Origin check bypass

Each credential is bound to an origin. Bugs:
- `iframe` context confusion — credentials returned to wrong origin.
- `postMessage` channels expose credentials cross-origin.
- Service worker intercepting `get()` and forwarding.

The spec mandates same-origin enforcement; implementation bugs in browsers have been the historical source.

## Class 2 — Federated provider injection

For `federated` requests, an IdP list. If page is XSS'd, attacker can inject their own IdP:
- User sees attacker IdP in account picker.
- Attacker IdP collects credentials.

XSS escalates into credential-store compromise.

## Class 3 — WebAuthn relay

WebAuthn binds to origin. AitM via reverse proxy ([[aitm-evilginx-modern-phishing]]) typically fails because origin mismatch.

But:
- **Cross-device authentication (hybrid transports)** — passkey on phone authenticating to laptop browser. If the channel between them is attacked, relay is possible.
- **Caller-app credential** confusion in mobile WebViews — see [[webauthn-api-hijacking-downgrade]].

## Class 4 — Mediation handling

`mediation: silent` returns credential without user interaction (auto-fill). If the calling page is malicious and the user has previously consented to credentials for the origin:
- Page reads credentials silently.
- Combined with subdomain takeover or XSS in trusted subdomain, silent reads enable account compromise.

## Class 5 — Credential type confusion

`get()` returns a credential object. Different credential types have different methods. Bugs:
- A federated credential parsed as a password credential.
- An identity (FedCM) credential parsed as federated.

Type confusion in client code (rare; type-system mostly catches).

## Class 6 — Store-time race

When `store()` is called after a successful login, the browser prompts "Save?". Race:
- Page calls `store(maliciousCred)` immediately after legitimate login.
- User clicks "Save" thinking it's the legitimate credential.

Defence: browser ties the store to the recent auth event, displaying credential details.

## Class 7 — preventSilentAccess race

The opposite of Class 4: if a page sets `preventSilentAccess()`, the next `get()` requires interaction. Bug if:
- An attacker page calls `get()` first.
- Then legitimate page calls `preventSilentAccess()`.
- Race where attacker gets credential.

Modern browsers mitigate.

## Class 8 — Cross-tab leak

Multiple tabs of the same origin; one is compromised:
- Compromised tab calls `get()`; gets credential.
- Even without XSS in the other tab, the user "consented" once and silent reads succeed across tabs.

Defence: per-tab user activation requirements.

## Class 9 — Stored federated credentials with stale provider

Browser stored "Login with Google" preference for example.com. If the user later removes Google integration but browser still stores it:
- Page that loads malicious federated provider for example.com.
- Browser silently uses stored choice.

Defence: explicit revocation in browser settings; rare in practice.

## Real-world / disclosed issues

- WebKit / Blink had several origin-confusion bugs early in WebAuthn rollout.
- Firefox / Chrome cross-platform sync of passkeys has had edge cases.
- iCloud Keychain WebAuthn sync had a documented issue (2023).

The attack surface ages quickly; modern browsers have patched most published classes.

## Defensive baseline

For users:
- Use modern browsers.
- Watch the credential prompt — it shows origin and credential summary.
- Don't reuse passwords; use a password manager.
- Prefer passkeys where supported.

For sites:
- Use WebAuthn / passkey for high-value auth.
- Verify the credential's origin in server-side validation.
- Use `preventSilentAccess()` after sensitive actions.
- Tight CSP — defense in depth against XSS that could call `get()`.

## Workflow to study

1. Build a small page that calls `navigator.credentials.get` for password and WebAuthn.
2. Test storage / retrieval.
3. Try to call from `iframe` with different origins.
4. Examine browser behaviour in edge cases.

## Related

- [[webauthn-api-hijacking-downgrade]]
- [[passkey-mobile-ble-phish]]
- [[fedcm-attacks]]
- [[oauth-modern-attacks]]
- [[sso-attacks]]
- [[cross-site-scripting]]

## References
- [W3C Credential Management Level 1](https://www.w3.org/TR/credential-management-1/)
- [WebAuthn specification](https://www.w3.org/TR/webauthn-3/)
- [MDN — Credential Management API](https://developer.mozilla.org/en-US/docs/Web/API/Credential_Management_API)
- See also: [[webauthn-api-hijacking-downgrade]], [[fedcm-attacks]], [[passkey-mobile-ble-phish]], [[oauth-modern-attacks]]
