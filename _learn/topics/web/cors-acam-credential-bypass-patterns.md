---
title: CORS ACAM credential bypass patterns
slug: cors-acam-credential-bypass-patterns
aliases: [cors-credentialed-bypass, cors-misconfig-advanced]
---

{% raw %}

> **TL;DR:** Classic CORS misconfig ([[cors-misconfig]]) covers `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` (browser blocks that combo, but old SDKs / non-browser clients don't). This note covers the more subtle patterns: regex-based origin reflection bypass, null-origin abuse, wildcard subdomain trust where one subdomain is attacker-controllable, `Vary: Origin` cache pollution, and pre-flight cache poisoning. The ACAM ("Access-Control-Allow-Method/Headers") side is often under-checked.

## What it is
CORS is enforced *by the browser* on JS-initiated cross-origin requests. The server's `Access-Control-Allow-*` headers tell the browser whether to deliver the response to JS. Misconfig categories:

1. **`ACAO` (Origin) too permissive** — most reports focus here.
2. **`ACAC` (Credentials) + reflected origin** — credentialed cross-origin read.
3. **`ACAM` (Methods) + `ACAH` (Headers) too permissive** — allows arbitrary preflighted requests.
4. **Pre-flight cache poisoning** — stale `ACAH` lets attacker re-use headers.

## Patterns

### 1. Origin reflection with weak regex
Server reads `Origin: https://victim.com.attacker.com` and reflects with `ACAO`. If regex is `^https://(.*\.)?victim\.com$` it correctly rejects, but `^https://.*victim\.com.*$` or substring match allows.
- Audit: every reflection point, see if there's an allowlist with strict anchors.
- Common shortcuts that fail: `endsWith('victim.com')` matches `attackervictim.com`.

### 2. `null` origin acceptance
Some sandboxed contexts send `Origin: null`:
- Sandboxed iframe (`<iframe sandbox>` without `allow-same-origin`).
- Local file (`file://`).
- Redirected request through certain protocols.
- Server allowing `null` → attacker creates an iframe sandbox at any origin, makes credentialed request.
- Fix: never allowlist `null`.

### 3. Wildcard subdomain + takeable subdomain
- Allowlist: `^https://.*\.victim\.com$`.
- `legacy.victim.com` points to a deprovisioned Heroku → attacker claims it.
- Now attacker hosts JS on `https://legacy.victim.com` that makes credentialed cross-origin requests to `app.victim.com`.
- Combine: [[subdomain-takeover]], [[dangling-dns-takeover]].

### 4. Allowed scheme confusion
- Allowlist: `victim.com` without scheme check.
- Attacker hosts `http://victim.com` (no TLS) — under proxy or mitm context.
- Or `wss://victim.com` for WebSocket-origin trust.

### 5. `Vary: Origin` cache pollution
- Server sends `ACAO: https://app.victim.com` for one user.
- If `Vary: Origin` missing, CDN caches the response.
- Next user (different origin) gets the cached headers — ACAO mismatches, browser rejects, but the actual response body is delivered to the cache, which means anyone with the cache key can read it.
- Fix: always `Vary: Origin` on any reflected response.

### 6. Preflight `ACAH` too permissive
- Server responds to OPTIONS with `Access-Control-Allow-Headers: *` or includes every request header.
- Attacker can attach arbitrary headers (`Authorization`, `Cookie`-equivalent via headers, custom tokens) that bypass server-side filtering.
- Fix: list only allowed headers.

### 7. Preflight cache poisoning
- Browser caches preflight result per `Access-Control-Max-Age`. Default Chrome is 2hr.
- If server has a brief misconfig (deploys an allowlist change badly), browsers retain the permissive preflight for hours.
- Attacker times the request during the misconfig window; preflight cached; even after fix, attacker still has access for the cache duration.
- Fix: short `Max-Age` (under 600s); careful staged deploys.

### 8. `ACAC: true` reflected by mistake
Server reflects origin and credentials. Browser will accept credentialed cross-origin response. Auth cookie sent. Attacker reads response.
- Mistake pattern: `app.use((req,res,next)=>{ res.header('ACAO', req.headers.origin); res.header('ACAC', 'true'); next() })` — naive Express middleware.

### 9. Non-browser HTTP clients ignore CORS
- Postman, curl, mobile apps, server-to-server — none enforce CORS.
- If your server returns `ACAO: *` + sensitive data assuming browser blocks, but a separate path (mobile API) returns the same data with auth → not a CORS bug, but an authn bug.
- CORS is a browser feature; never rely on it as authentication.

### 10. PostMessage as CORS bypass
- iframe with `target.postMessage(data, '*')` sends data to any origin.
- Not technically a CORS bypass, but achieves same goal: cross-origin data flow.
- See [[postmessage-bugs]].

## Testing methodology

### Black-box
1. Find every API endpoint that returns sensitive data or accepts credentials.
2. For each: send with `Origin: https://attacker.com`, observe `ACAO` echo.
3. Test `Origin: null`, `Origin: https://victim.com.attacker.com`, `Origin: https://attackervictim.com`.
4. Look for `Vary: Origin` header.
5. Send OPTIONS preflight with `Access-Control-Request-Headers: X-Custom`; see what `ACAH` returns.
6. Test allowed subdomain expansion: known takeover candidates.

### Source review
1. Find all CORS middleware: `cors` npm package, `flask-cors`, `django-cors-headers`, `aspnet-cors`, manual `Access-Control-*` setting.
2. For each: read the origin allowlist logic. Look for regex, substring match, fallback to wildcard.
3. Check `ACAC` settings.
4. Check that `Vary: Origin` is set.

## Hardening checklist
- Strict origin allowlist with exact match, no regex.
- `Access-Control-Allow-Credentials: true` only on endpoints that truly need it.
- `Vary: Origin` on any response with reflected origin.
- Audit every `*.yourdomain.com` for takeover risk (you wildcard-trust them).
- Preflight `Max-Age` ≤ 600s during config change windows; longer otherwise but rotate audits.
- No CORS = no cross-origin JS read; reserve CORS for the specific endpoints that need it.

## References
- [Fetch spec — CORS](https://fetch.spec.whatwg.org/#http-cors-protocol)
- [PortSwigger — CORS](https://portswigger.net/web-security/cors)
- [James Kettle — Practical CORS exploitation](https://portswigger.net/research/exploiting-cors-misconfigurations-for-bitcoins-and-bounties)
- [HackerOne reports on CORS misconfig](https://hackerone.com/hacktivity?searchInput=cors)
- See also: [[cors-misconfig]], [[subdomain-takeover]], [[postmessage-bugs]], [[same-origin-policy-bypasses]]

{% endraw %}
