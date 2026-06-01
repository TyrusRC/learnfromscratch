---
title: Single Sign-On (SSO) attacks
slug: sso-attacks
---

> **TL;DR:** SAML + OAuth + OIDC trust-chain failures: confused-deputy, audience mismatch, account-linking races.

## What it is
SSO offloads authentication to an IdP. The bug class is the *trust chain* — IdP, broker, SP, and account-linking logic all have to agree on identity. When any two disagree, an attacker who controls one identity at the IdP can claim another at the SP, or vice-versa. SSO bugs typically yield account takeover with no password.

## Preconditions / where it applies
- App accepts SSO via SAML / OAuth / OIDC, possibly multiple providers
- Account-linking logic that matches federated identity to local user by email, sub, or claim
- IdP and SP not strictly bound (audience, issuer, redirect URI loose)

## Technique
1. **Email-claim trust without verification** — attacker registers IdP with `email_verified=false` or controls an IdP that lets them set any email; SP links to local user by email. Classic Google Workspace + custom-domain bug. Sign up `victim@corp.com` at attacker IdP, log in to SP as victim.
2. **OIDC `aud` mismatch** — token issued for client A accepted by client B; cross-app pivot. See [[jwt]].
3. **OAuth `redirect_uri` open allowlist** — `redirect_uri=https://attacker.tld` accepted, code leaks. See [[oauth-flows]].
4. **OAuth `state` not bound to session** — login CSRF: attacker initiates auth, victim completes; attacker is now logged into victim's app session.
5. **SAML XSW / NameID swap** — replay or wrap a signed assertion; see [[saml-attacks]].
6. **Provider confusion** — SP supports both "Login with Google" and "Login with Microsoft"; both expose `sub` claims that overlap (numeric ids). If linking uses only `sub`, attacker logs in as Microsoft user with a Google `sub` that collides.
7. **Account-linking race** — register victim's email at SP; victim signs up via IdP and is auto-linked to attacker's pre-existing account, granting attacker their session.
8. **Pre-account hijack** — attacker creates pending account `victim@corp.com`; victim later does SSO; SP merges accounts, attacker retains session cookie set at hijack time.
9. **`logout_uri` open redirect / token leak via Referer**.
10. **PKCE downgrade** — server accepts code flow without PKCE for "legacy" clients; intercept code via [[mv3-extension-bypass]] or malicious app.
11. **Cross-IdP recovery** — disabling one IdP via takeover lets attacker bind their own as primary.

## Detection and defence
- Always require `email_verified=true` (OIDC) or equivalent IdP assurance before linking to a local account; otherwise force out-of-band verification.
- Strict `redirect_uri` exact-match allowlist; sign the `state`; bind PKCE per session.
- Validate `iss`, `aud`, `azp`, `nonce`, `at_hash`, `exp`, `iat` on every token.
- Tie SSO identity to a tuple `(issuer, sub)` not `email` alone; never trust email as a primary key across providers.
- Disable account-merge by email; require manual confirmation.
- Audit IdP allowlist; disable unused providers.
- Related: [[saml-attacks]], [[oauth-flows]], [[oauth-token-theft]], [[jwt]], [[webauthn-api-hijacking-downgrade]].

## References
- [Detectify — pre-account hijack](https://blog.detectify.com/industry-insights/account-pre-hijacking/) — Microsoft research overview
- [PortSwigger — OAuth](https://portswigger.net/web-security/oauth) — flow attacks
- [Cloud Native Computing — SSO security model](https://datatracker.ietf.org/doc/html/rfc6819) — OAuth threat model RFC
