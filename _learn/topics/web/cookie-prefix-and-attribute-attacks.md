---
title: Cookie prefix and attribute attacks
slug: cookie-prefix-and-attribute-attacks
aliases: [cookie-jar-attacks, cookie-attribute-misconfig]
---

{% raw %}

> **TL;DR:** Cookies are governed by a chaotic set of attributes — `Domain`, `Path`, `Secure`, `HttpOnly`, `SameSite`, `__Secure-`/`__Host-` prefixes — and most apps misuse them. Attacks include cookie tossing (set cookies from a subdomain that override the parent), prefix-bypass via parser quirks, `SameSite=None` without `Secure`, `Lax` defaults exposing top-level navigation, and DoS via cookie jar overflow. The `__Host-` prefix is the strongest binding the browser offers — most apps don't use it.

## Background — the attributes

| Attribute | What it does | Bypass surface |
|-----------|--------------|----------------|
| `Domain=example.com` | Cookie valid for example.com + subdomains | Any subdomain can set/read it |
| (no Domain) | Cookie valid only for exact host | Most-restrictive; safest |
| `Path=/foo` | Cookie sent only for /foo* | Path traversal in browser? No — but server may not know context |
| `Secure` | HTTPS only | Doesn't prevent reading on HTTPS site that's vulnerable to XSS |
| `HttpOnly` | Not exposed to `document.cookie` | Doesn't stop CSRF or read via dev tools |
| `SameSite=Strict` | Cookie never sent on cross-site requests | Strong; breaks SSO |
| `SameSite=Lax` (browser default) | Sent on top-level navigation GETs | Cross-site POST blocked but top-level GET not |
| `SameSite=None` | Sent on all cross-site requests | Must pair with `Secure` |
| `__Secure-Name` prefix | Browser rejects if not `Secure` | Hardening — opt in |
| `__Host-Name` prefix | Browser rejects unless `Secure`, no `Domain`, `Path=/` | Strongest; opt in |
| `Partitioned` (CHIPS) | Per-top-level-site cookie jar | New (2024+); for cross-site iframes |

## Attacks

### 1. Cookie tossing (subdomain → parent override)
Vulnerability: site sets `session=victim` on `Domain=example.com`. Attacker controls `evil.example.com` (e.g., a subdomain takeover, user-content subdomain) and sets `session=attacker; Path=/; Domain=example.com`.
Browser sends both cookies. Spec says order is implementation-defined; many servers pick the *longest path* or *most specific* first, but `Path=/` is the broadest. RFC 6265 doesn't define order — the server gets ambiguous state.
- Test: have a controlled subdomain set a `session` cookie for the parent. Check if it overrides on main app.
- Fix: `__Host-` prefix forbids `Domain` → cookie is host-only, can't be set from subdomain.

### 2. `__Secure-` / `__Host-` prefix bypass
Older browsers / parsers had bugs where `__Secure-` only applied if explicitly checked. Modern browsers enforce; bypass via:
- Server reading the prefix from request and treating it as untrusted? No — browser-side validation only.
- Race condition during prefix policy update? Rare.
- Look for non-browser HTTP clients (Postman, curl scripts) that don't enforce prefix — internal API access from those bypasses prefix.

### 3. `SameSite=None` without `Secure`
Spec requires `Secure` if `SameSite=None`. Browsers reject the cookie if missing. Older non-compliant servers set both incorrectly → cookie ignored → user logged out / functional bug. Not a vuln per se, but indicator of misconfig.

### 4. Default `SameSite=Lax` exposes top-level GET
Browser default is `Lax`. Cookie still sent on top-level navigations from third-party sites — `<a href="https://victim/transfer?amount=100">`. State-changing GET endpoints are CSRF-vulnerable.
- Fix: state-changing actions are POST only; or set `SameSite=Strict` for the session cookie.

### 5. Cookie jar exhaustion / DoS
Browser limits: ~180 cookies per origin (varies), 4KB per cookie. Attacker who can set many cookies from a subdomain can:
- Force browser to drop oldest cookies → log victim out.
- Make request headers too large → server returns 400/413 → DoS.
- Fix: set sensitive cookies with explicit name, monitor Set-Cookie volume from subdomain origins.

### 6. Parser quirks across servers
Different servers parse `Cookie:` header differently:
- Nginx, Apache, IIS, Node, Java each have edge-case behaviour on quoted values, trailing semicolons, repeated names.
- Request smuggling-adjacent: when frontend and backend disagree on cookie boundaries, you can sometimes inject a fake cookie via reflected input.
- See: [parser differentials](https://portswigger.net/research/cookies-the-extra-saucy-edition).

### 7. Cookie attribute injection
If server reflects a user-controlled string into a `Set-Cookie` header without escaping `;` or `\r\n`, attacker injects attributes:
- `value` → `value; Domain=.evil.com; Path=/`
- `value` → `value\r\nSet-Cookie: malicious=1; ...`
- [[crlf-injection]] is the parent class.

### 8. Cookie path scope confusion
`Path=/` is sent everywhere; `Path=/api` only for /api/*. Sites set login cookie with `Path=/` and CSRF token with `Path=/api` — server-side handlers receive different cookies depending on request path. Vulnerable when one path's session cookie is intended to be separate but Path overlaps.

### 9. Subdomain takeover → parent cookie
Common in cloud-hosted apps. Old subdomain points at deprovisioned S3/Heroku → attacker claims it → sets cookies for parent. Pair with [[subdomain-takeover]], [[dangling-dns-takeover]].

### 10. Partitioned cookies (CHIPS) edge cases
New `Partitioned` attribute creates per-top-level-site cookie jars. Some apps assume traditional cookie behaviour and break with Partitioned. Authentication flows in iframes may lose state.

## Hardening checklist
- Session cookie: `Set-Cookie: session=...; HttpOnly; Secure; SameSite=Lax; Path=/; __Host-session=...` (the host-prefix variant).
- Never set `Domain=example.com` on a sensitive cookie unless you control every subdomain.
- Cross-origin SSO needs `SameSite=None; Secure` — only on the specific token cookie, not session.
- CSRF token cookie: `SameSite=Strict` is fine.
- Audit every `Set-Cookie` in source for attributes.
- Monitor `Set-Cookie` volume from subdomain origins to detect tossing attempts.

## Source review patterns
```bash
rg -n 'Set-Cookie|setHeader\(\s*[\x27"]Set-Cookie|cookie\(' .
rg -n 'sameSite|samesite|SameSite' .
rg -n 'domain:|Domain=|cookie_domain' .
rg -n 'secure:\s*false|httpOnly:\s*false' .
```

## References
- [RFC 6265bis — current cookie spec draft](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis)
- [PortSwigger — Cookies The Extra Saucy Edition](https://portswigger.net/research/cookies-the-extra-saucy-edition)
- [MDN — Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie)
- [Chrome — Cookies and Partitioned](https://developer.chrome.com/docs/privacy-sandbox/chips/)
- See also: [[csrf]], [[subdomain-takeover]], [[crlf-injection]], [[session-fixation]]

{% endraw %}
