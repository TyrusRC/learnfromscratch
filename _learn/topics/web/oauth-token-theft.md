---
title: OAuth token theft
slug: oauth-token-theft
---

> **TL;DR:** Loose `redirect_uri` validation, missing `state`, referrer leaks, and open-redirect chains let an attacker capture the victim's access / refresh tokens at the authorisation server's callback.

## What it is
OAuth 2.0 authorisation code and (legacy) implicit flows hand a secret — code or token — to a URL controlled by the client app. If the authorisation server lets the client (or the attacker) influence that URL, or the client's callback handler leaks the secret to third parties, the attacker takes over the victim's session in the protected resource.

## Preconditions / where it applies
- An OAuth provider that accepts wildcard, prefix-matched, or attacker-influencable `redirect_uri`.
- A client app with a loose callback (open redirect, third-party JS, leaky `Referer`, postMessage handler).
- A victim who is authenticated to the provider and clicks the attacker URL — or a logged-in session that the attacker triggers via a hidden iframe / pop-up.

## Technique
1. **Map the flow.** Capture the `/authorize` request. Note `response_type` (code / token / id_token), `redirect_uri`, `scope`, `state`, PKCE (`code_challenge`).
2. **redirect_uri attacks.**
   - **Allowlist by `startsWith`** — register `https://app.example.com.attacker.tld`.
   - **Path append** — allowlist is `https://app.example.com/`; provider accepts `https://app.example.com/../../attacker`.
   - **Sub-path with open redirect** — provider only checks origin; client's `/callback?next=//attacker` redirects after consuming the code.
   - **Fragment trick** — implicit flow returns `#access_token=...` in URL fragment; chain through an open redirect that preserves the fragment.
3. **Missing or unbound `state`.** No `state` → CSRF on the callback (force-link attacker's account to victim's session). `state` bound to attacker's cookie → relogin attack.
4. **Referer leak.** Authorization code lands in the URL; the callback page loads third-party JS / images / analytics; the `Referer` header carries the code to those origins.
5. **postMessage leak.** A SPA does `window.opener.postMessage({code})` without checking `targetOrigin`. Attacker pops the auth window from `attacker.tld` and listens.
6. **PKCE downgrade.** Provider accepts requests without `code_verifier` even when the original `/authorize` included a `code_challenge`. Public clients are then trivially MITM'd.
7. **Refresh-token theft.** SPA stores refresh in `localStorage`; chain with an [[cross-site-scripting]] to exfil long-lived tokens. See [[client-side-storage-attacks]].

   ```http
   GET /authorize?response_type=code&client_id=abc
       &redirect_uri=https://app.example.com/callback?next=//attacker.tld
       &scope=email
       &state=...
   ```

## Detection and defence
- Exact-match `redirect_uri` registration. No wildcards, no path append, no scheme downgrade. Validate the full URI byte-for-byte.
- Require and verify `state` bound to the user session; require PKCE for all clients (public and confidential).
- Short-lived authorization codes (≤ 60s, single use). Refresh tokens rotated and bound to client + DPoP / mTLS where possible.
- Client callback page: no third-party scripts, no analytics, no open redirects, validate `event.origin` on postMessage.
- Detection: provider logs of consecutive `/authorize` and `/token` calls from very different IPs, `Referer` of the `/callback` page pointing off-origin.

## References
- [PortSwigger — OAuth 2.0 authentication vulnerabilities](https://portswigger.net/web-security/oauth) — labs.
- [OAuth Threat Model — RFC 6819](https://datatracker.ietf.org/doc/html/rfc6819) — canonical risks.
- [OAuth 2.0 Security Best Current Practice](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics) — modern defences.
