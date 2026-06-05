---
title: OAuth authorization code injection
slug: oauth-authorization-code-injection
aliases: [oauth-code-injection, authz-code-replay]
---

{% raw %}

> **TL;DR:** Authorization code injection is the attack PKCE was designed to prevent: attacker obtains a valid auth code (via referrer leak, network MitM on mobile, or a benign-looking referrer), then redeems it on their own session against a victim's account. Without PKCE, the code is a bearer credential between auth + token exchange. Common in public clients (SPAs, native apps) and any flow where the redirect URI isn't strictly bound.

## What it is
The flow:
1. Victim's client starts OAuth: `GET /authorize?client_id=...&redirect_uri=https://app/callback&...`.
2. Authorization server issues code, redirects to `https://app/callback?code=ABC`.
3. Client exchanges code: `POST /token` with `code=ABC&client_id=...&redirect_uri=...`.
4. Server issues access token bound to victim's identity.

Injection: attacker captures step 2's code somehow, replays step 3 on their own session before victim's client gets there. Server issues token for victim's identity → attacker takes over victim's account in the client.

## How the code leaks

### 1. Referrer leak
Authorization callback URL contains code in query string. If callback page references third-party resources (analytics, CDN, ads), the browser may send `Referer: https://app/callback?code=ABC...` to those origins. Modern browsers redact path on cross-origin referrer by default (strict-origin-when-cross-origin), but older policies (`no-referrer-when-downgrade`) leak.
- Fix: `Referrer-Policy: no-referrer` or `same-origin`; no third-party resources on callback page.

### 2. Open redirect on callback
Client's callback page redirects to attacker URL based on `state` or other param. Code passed in URL travels via Location header / Referer to attacker.
- Fix: no open redirect on callback; treat `state` as opaque ID, not URL.

### 3. Browser history + shared device
Code in URL bar is saved to history. Shared device → next user sees URL in autocomplete; attacker who borrowed laptop reads history.
- Fix: PKCE makes captured code unusable.

### 4. Custom URL scheme hijacking (mobile)
Native app registers `myapp://callback`. Another app on the device registers the same scheme (Android: first installer wins, but reinstall race possible; iOS: alert + user choice). Hostile app reads the code on dispatch.
- Fix: PKCE + ASWebAuthenticationSession (iOS) / Custom Tabs (Android) + Universal/App Links (verified by domain).

### 5. Proxy / network logs
HTTPS terminator logs URLs. Code visible to operator. Internal observability tooling commonly logs full URL.
- Fix: PKCE; code in POST body for token exchange (auth code itself is still in URL on the redirect).

### 6. Server logs
Authorization server's HTTP logs see codes in the redirect URL. Any log access (SRE, DBA, exporter to third-party SIEM) exposes them.
- Fix: redact codes from logs.

### 7. CSRF on the callback
Attacker initiates the OAuth flow themselves, gets a code from their authorization session, then tricks victim into visiting `https://app/callback?code=ATTACKER_CODE`. Victim's session at `app` now uses attacker's code → app exchanges → token is for the attacker's identity. This is a *login CSRF* / *session fixation* variant: victim ends up logged into attacker's account at the OAuth provider's side, where attacker has been silently observing victim's actions.
- Fix: `state` parameter MUST be checked. State is a CSRF token for the OAuth flow.

### 8. Reverse: attacker injects victim's code
The classic. Attacker phishes a victim into visiting attacker's site that triggers OAuth at the authorization server, capture the code in callback (or via referrer). Replay against the legitimate client's callback before victim's client finishes.
- Fix: PKCE binds code to client's secret verifier. Attacker without verifier can't redeem.

## Why PKCE is the answer
- Code alone isn't sufficient — token exchange needs `code_verifier`.
- Verifier is kept secret by client, never sent over the wire in the redirect.
- Captured code is useless without it.

But PKCE only works if:
- Server enforces it ([[pkce-downgrade-and-bypass]]).
- Client uses CSPRNG verifier.
- `S256` method, not `plain`.

## Other binding mechanisms
- `state` parameter — CSRF defence; not a substitute for PKCE.
- `nonce` (OIDC) — binds ID token to original auth request; CSRF + replay defence at token level.
- DPoP (RFC 9449) — proof-of-possession tokens; client proves it holds a private key for each request.
- mTLS-bound tokens (RFC 8705) — token only usable with client cert.

## Testing methodology

### Black-box
1. Capture an auth flow. Identify all parameters: `state`, `nonce`, `code_challenge`.
2. Try removing `state` on the authorization request and replay-attacking the callback.
3. Try removing `code_challenge` — if accepted, PKCE not enforced.
4. Look at the callback page for third-party resources that could see `Referer`.
5. Look at server logs (if accessible in scope) for code persistence.

### Source review
1. Find the token exchange handler — what does it use to bind code to client?
2. Find the state validation — present and correct?
3. Find the callback page — third-party scripts, referrer policy.
4. Find the auth code storage — TTL, single-use enforcement.

## References
- [OAuth 2.0 Security BCP (RFC 9700)](https://datatracker.ietf.org/doc/html/rfc9700)
- [Daniel Fett — Authorization code injection writeup](https://danielfett.de/)
- [PortSwigger — OAuth attacks lab](https://portswigger.net/web-security/oauth)
- See also: [[pkce-downgrade-and-bypass]], [[oauth-flows]], [[oauth-token-leak-vectors]], [[oauth-token-theft]]

{% endraw %}
