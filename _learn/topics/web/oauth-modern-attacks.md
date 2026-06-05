---
title: OAuth — modern attacks
slug: oauth-modern-attacks
aliases: [oauth-attacks-modern, oauth-2025]
---

{% raw %}

> **TL;DR:** OAuth 2.0 / 2.1 / OIDC attacks in 2025-26: (1) redirect_uri parser quirks (path traversal, fragment confusion), (2) state and nonce mishandling, (3) PKCE downgrade and bypass, (4) authorization-code injection across clients, (5) refresh-token theft and rotation gaps, (6) DPoP misuse, (7) device-flow / CIBA abuse, (8) consent phishing. Many bugs are *application-level* misuse of OAuth, not OAuth spec flaws. Companion to [[oauth-flows]], [[pkce-downgrade-and-bypass]], [[oauth-authorization-code-injection]].

## Attack 1 — redirect_uri matching bugs

Apps register redirect URIs; the OAuth server compares the request's `redirect_uri` against the registered set. Parser bugs:

- **Prefix match** instead of full match: `https://app.example.com/cb` matches `https://app.example.com/cb.attacker.tld`.
- **Suffix match**: `https://app.example.com/cb` matches `https://attacker/cb`.
- **Path traversal**: `/cb/../leak` → server's normalisation differs from victim's.
- **URL fragment**: `redirect_uri=https://app.example.com/cb#@attacker.tld/`.
- **Userinfo abuse**: `https://app.example.com@attacker.tld/cb` — userinfo before host.
- **Open redirect chained**: registered URI is itself an open redirect → final landing is attacker.
- **Case sensitivity**: `Cb` vs `cb`.

Test:
```bash
# vary redirect_uri until the server accepts and lands the auth code at attacker
curl 'https://idp.example.com/oauth/authorize?client_id=...&redirect_uri=https://app.example.com@attacker.tld/cb&response_type=code'
```

## Attack 2 — state and nonce

`state` is the anti-CSRF token for the auth code. `nonce` is the anti-replay for ID tokens.

Bugs:
- App doesn't generate / validate `state` → CSRF login (attacker pre-authorises and tricks victim into completing).
- Same `state` reused across users → attacker swaps in their own state.
- `nonce` not checked → replay attacks.

Audit:
- Each `/authorize` call generates a fresh, unguessable state.
- Server stores state in session and validates on callback.

## Attack 3 — PKCE downgrade and bypass

PKCE (RFC 7636) binds the auth code exchange to a `code_verifier` only the legitimate client knows.

Bugs:
- Auth server accepts the auth code without PKCE if `code_challenge` was omitted from `/authorize` — downgrade.
- Server falls back to `plain` `code_challenge_method` when `S256` rejected.
- Single client supports both PKCE and non-PKCE flows → attacker requests non-PKCE.

See [[pkce-downgrade-and-bypass]].

## Attack 4 — authorization code injection

Attacker obtains a victim's auth code (via redirect_uri abuse, log leak, or browser history). If they can present it to *their own* client's redeem endpoint, they get the victim's tokens.

PKCE *should* defeat this. But:
- Server doesn't check the verifier matches the challenge stored with the code → bypass.
- Server's verifier cache uses the attacker's session, not the original client's.

See [[oauth-authorization-code-injection]].

## Attack 5 — refresh token rotation gaps

Refresh tokens should be single-use (rotated on each refresh). Bugs:
- Server doesn't rotate → token reusable indefinitely.
- Rotation race: two near-simultaneous refreshes generate two valid sets.
- Token bound to client ID but not session → cross-app use.

Audit: simulate a refresh; immediately reuse the old refresh token; expect rejection. If accepted, finding.

## Attack 6 — DPoP misuse

DPoP (RFC 9449) binds access tokens to a public key. Holder must sign proof on every API call.

Bugs:
- API accepts tokens without DPoP proof when DPoP header missing.
- Proof signature not validated (sig presence checked, not validity).
- Proof nonce caching broken (replay window too long).
- Key thumbprint compared to wrong field.

Test: replay a proof from a previous request; expect rejection.

## Attack 7 — device flow / CIBA abuse

Device flow: a CLI shows a code to the user, user enters it on a separate authenticated device.

Bugs:
- No rate-limit on the user_code → brute force.
- user_code format is short (8 chars) → guessable.
- No proximity check; attacker socially-engineers victim to enter attacker's code.

CIBA (Client-Initiated Backchannel Authentication): similar attacks against the back-channel notification.

## Attack 8 — consent phishing

The IdP's consent screen shows "App X wants access to your data". Attacker registers a malicious app whose name mimics legit ("Microsoft Update", "Outlook Mobile") and tricks user to consent. Targeted Microsoft 365 attacks have hit this repeatedly.

Defence (M365 specific): admin consent required for delegated permissions to read mail / files; user consent disabled by default for new apps.

## Attack 9 — OAuth in OAuth — federation abuse

Many sites accept "Sign in with Google" / "Sign in with Microsoft". Attacker who controls a Google account with the victim's email-claim (rare but possible via misconfigured providers) signs in as victim.

Bug: app trusts `email` claim from IdP without verifying it; IdP's verification of email was incomplete.

## Attack 10 — open-redirect-in-app-as-redirect-uri

A registered redirect URI is itself an open redirect on the app (`/cb?next=...`). Final landing of auth code: `https://app.example.com/cb?next=https://attacker.tld/`. The app's `/cb` extracts the code, then redirects to `next` — leaking the code via Referer or via direct fetch.

## Tools

- **Burp Suite OAuth scanner extension**.
- **AuthSnacks / oauth-pentest** suites.
- **mitmproxy** with custom scripts.

## Source-audit angle

```bash
grep -rn 'redirect_uri\|redirectUri\|RedirectUri' src/
grep -rn 'code_verifier\|code_challenge' src/
grep -rn 'access_token\|refresh_token' src/
grep -rn 'oauth\|oidc\|openid' src/
```

For each:
- Where does the redirect URI come from? Validated against an allowlist?
- Is state generated and validated?
- Is PKCE required, and is the verifier stored per-session?

## OSCP/OSEP/OSWE relevance

OSWE: OAuth chains are *the* canonical auth-bypass story for modern SaaS source review.
Bug bounty: high-impact, high-payout class.

## References
- [RFC 6749 — OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc6749)
- [RFC 8252 — OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252)
- [OAuth 2.0 Security BCP — draft-ietf-oauth-security-topics](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
- [PortSwigger — OAuth labs](https://portswigger.net/web-security/oauth)
- [Google research — OAuth real-world bugs](https://googleprojectzero.blogspot.com/)
- See also: [[oauth-flows]], [[pkce-downgrade-and-bypass]], [[oauth-authorization-code-injection]], [[oauth-token-theft]], [[mobile-auth-token-handling-audit]]

{% endraw %}
