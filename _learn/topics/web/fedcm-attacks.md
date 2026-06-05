---
title: FedCM (Federated Credential Management) attacks
slug: fedcm-attacks
aliases: [fedcm, federated-credential-management-attacks]
---

> **TL;DR:** FedCM is a browser API (Chromium-led, W3C draft) intended to replace third-party-cookie-based federated login (Google Sign-In, etc.) before third-party cookies are deprecated. The browser mediates identity-provider (IdP) and relying-party (RP) communication via a "well-known" endpoint and accounts list. Attack surface: IdP impersonation, RP misconfiguration, account-list leakage, well-known endpoint hijack. Companion to [[oauth-modern-attacks]] and [[webauthn-api-hijacking-downgrade]].

## Why FedCM matters

- **Replacing third-party cookies** for federated login.
- **Browser-mediated** — different trust model than OAuth implicit / authorization-code flows.
- **Privacy-improved by design** — IdP doesn't see RP-visit signal until consent.
- **New attack surface** — fresh spec, fresh bugs.

## FedCM flow

1. RP page calls `navigator.credentials.get({identity: {providers: [{configURL: "https://idp.example/fedcm.json", clientId: "..."}]}})`.
2. Browser fetches `configURL` (the IdP's FedCM well-known).
3. Browser fetches accounts list from IdP (using browser-managed identity).
4. Browser displays UI "Sign in to RP with these accounts".
5. User selects account.
6. Browser fetches ID token from IdP for that account + this RP.
7. Browser returns token to RP via promise.

The browser is a mediator; the user sees a consistent UI rather than IdP-styled popup.

## Well-known endpoints

The IdP must expose:
- `https://idp.example/.well-known/web-identity` — declares which configURLs are valid.
- `configURL` (e.g., `https://idp.example/fedcm.json`) — points to accounts, client metadata, token endpoints.
- Accounts endpoint — returns user list.
- Token endpoint — issues ID tokens.

## Class 1 — IdP impersonation via DNS / config

Like OAuth, the IdP host is identified by URL. If an attacker can serve content at the IdP URL (subdomain takeover, DNS hijack, CDN config bypass):
- Browser fetches attacker-controlled config.
- Attacker's accounts list shown to user.
- User selects; attacker mints fake token.
- RP accepts as long as audience / issuer match.

The RP's verification of the token signature against the IdP's published keys is the gate. If JWKS are also under attacker control, full impersonation.

## Class 2 — RP misconfiguration

RP must:
- Verify ID token signature.
- Verify audience (`aud` claim) matches expected client ID.
- Verify issuer (`iss` claim) matches expected IdP.

If RP misses any check (typical OAuth-equivalent mistakes), attacker presents an arbitrary token.

Many integrations are pre-1.0 and prone to mistakes.

## Class 3 — Accounts list leakage / enumeration

The accounts list endpoint returns user data when called by the browser. If the endpoint can be called from a malicious RP page in attacker context:
- Enumerate users.
- Cross-tenant access.

Browser mediation should restrict, but implementation bugs in browsers and IdPs exist.

## Class 4 — Configuration confusion

The `.well-known/web-identity` lists allowed `configURL`s. If wildcards or path-traversal accepted:
- Attacker configURL accepted that points to attacker-controlled metadata.

## Class 5 — Mixed-content with legacy OAuth

During the transition, FedCM may fall back to popup-based OAuth. Attacker forces the fallback path:
- Use OAuth-class bugs ([[oauth-modern-attacks]]) including `redirect_uri` manipulation.

## Class 6 — Privacy-channel abuse

FedCM is privacy-oriented but exposes a side-channel:
- Whether the user has an account at IdP X is revealed (browser shows account picker or doesn't).
- Cross-site tracking via timing of the picker UI.

## Class 7 — Token endpoint cross-RP abuse

Token endpoint returns token for "RP X requesting from origin Y". If origin checking is loose:
- Attacker RP origin sends request for victim RP's client ID.
- Browser may pass through depending on FedCM implementation maturity.

## Class 8 — Privileged FedCM in extensions / WebView

Browser extensions and WebViews may have different FedCM semantics. Misconfiguration:
- Extension-installed RP gets broader FedCM access.
- Embedded WebView treats parent app origin as RP.

## Real-world status

- Chrome rolling FedCM out in stages from 2023.
- Google Sign-In transitioning to use FedCM.
- Mozilla / Apple have raised concerns about privacy / standards alignment.
- Production usage is early; bug-bounty findings are emerging at integration sites.

## Defensive baseline

For RPs (relying parties):
- Verify token signature, issuer, audience.
- Pin IdP's well-known URL (don't accept user-supplied IdP).
- Combine FedCM with traditional session-binding (cookie + recent-auth proof).
- Monitor for new IdP redirects.

For IdPs:
- HTTPS-only, HSTS, narrow CORS.
- Verify well-known and config endpoints aren't behind cache or CDN that could be poisoned.
- Restrict accounts endpoint to authenticated browser sessions only.
- Use short-lived ID tokens.
- Audit DNS / subdomain control.

For users / browsers:
- Use updated browsers — bug fixes ship.
- Be cautious of unfamiliar IdP UI.

## Workflow to study

1. Read the FedCM spec.
2. Build a small RP using `navigator.credentials.get` with an IdP.
3. Examine the request flow with browser dev tools.
4. Test edge cases: invalid signature, wrong audience, etc.
5. Read Chrome's FedCM implementation source for bug-class shape.

## Related

- [[oauth-modern-attacks]]
- [[oauth-token-theft]]
- [[oauth-authorization-code-injection]]
- [[webauthn-api-hijacking-downgrade]]
- [[passkey-mobile-ble-phish]]
- [[cred-management-api-attacks]]
- [[sso-attacks]]

## References
- [W3C FedCM draft](https://fedidcg.github.io/FedCM/)
- [Chrome FedCM docs](https://developer.chrome.com/docs/privacy-sandbox/fedcm/)
- [Web Authentication and federated identity discussion](https://github.com/w3c-fedid)
- See also: [[oauth-modern-attacks]], [[webauthn-api-hijacking-downgrade]], [[sso-attacks]], [[cred-management-api-attacks]]
