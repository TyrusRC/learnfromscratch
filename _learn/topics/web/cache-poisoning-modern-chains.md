---
title: Cache poisoning — modern chains
slug: cache-poisoning-modern-chains
aliases: [cache-poisoning-modern, cache-poisoning-2025]
---

{% raw %}

> **TL;DR:** Modern cache-poisoning bugs ride keyed/unkeyed input mismatches between an application and its CDN/cache tier. Classic vectors (X-Forwarded-Host, Host header) closed in many CDNs; current research targets fat-keying gaps (X-HTTP-Method-Override, Accept-Language fallbacks), normalisation differences (path %-decoding, header case-folding), parameter cloaking (multiple values, semicolon-separated), and cache-key smuggling via HTTP/2/HTTP/3 frame parsing. Companion to [[cache-poisoning]] (the foundation) and [[http-smuggling-modern-variants]].

## Refresher — the key

A cache stores: `(method, URL, key-headers) → response`. Anything *not* in the key is "unkeyed". Poison the unkeyed input → next request with the same key gets the poisoned response.

Most CDN cache keys default to (method, URL). `Host`, `Cookie` may be included; other headers usually not.

## Modern vector 1 — header case folding

Some caches lowercase header names; some don't. An attacker sends:
```
X-Forwarded-Host: attacker.tld
x-forwarded-host: original.tld
```

The cache sees one header (deduplicated); the origin's framework sees the other. If the origin reflects `X-Forwarded-Host` into the response (canonical URL, redirect Location), the cache stores a response with attacker-controlled content keyed under `original.tld`.

Test:
```http
GET / HTTP/1.1
Host: example.com
X-Forwarded-Host: evil
x-forwarded-host: example.com
```

PortSwigger's "cache key normalisation" lab series covers this.

## Modern vector 2 — Accept-Language / Accept-Encoding fallback

`Accept-Language: en-US,en;q=0.9,EVIL` → CDN keys on full string; origin parses to `en` and ignores the rest; reflects into a `lang` cookie or a `<html lang="...">` attribute.

Send once with `Accept-Language: en-US,en;q=0.9,"><script>...` — origin renders with that string; CDN caches under the noisy header.

The attacker then crafts a follow-up that *retrieves* the cached version. Modern caches use Vary to segment per Accept-Language — but Vary on a wide value space (every language string) doesn't actually segment, just floods the cache.

## Modern vector 3 — X-HTTP-Method-Override

`X-HTTP-Method-Override: PURGE` overrides the method on the origin while the cache keys on the visible `GET`. If the origin's framework respects it without auth, the attacker uses GET to send a PURGE → cache invalidates entries for unprivileged victim.

Variant: send `X-HTTP-Method-Override: POST` to an endpoint that mutates; cache the *response* under a GET key. Next victim sees the mutated response.

## Modern vector 4 — parameter cloaking

Same param twice: `?lang=en&lang=evil`. Languages vary:
- PHP — takes the last value.
- Node Express — array of both.
- Python Flask — first by default.

Cache keys on the URL as-is. If origin uses one rule and cache another, you get a stored response that doesn't match the visible URL semantics.

Variant: semicolon-separated values: `?a=1;b=2` — some frameworks split on `;` and produce extra params.

## Modern vector 5 — HTTP method confusion

A cache that treats HEAD and GET as equivalent (returns cached body for HEAD) is fine until the origin returns different responses for the same URL based on method. Send GET, then HEAD; check whether the cache served the GET body for HEAD. Reverse for some attack chains.

## Modern vector 6 — fat GET request body

`GET /` with a request body. Some origins parse it; caches don't include it in the key.

```
GET / HTTP/1.1
Host: example.com
Content-Length: 14

x=<script>...
```

Origin reflects `x`; cache stores keyed on URL only.

## Modern vector 7 — cache-key smuggling via HTTP/2 frame ordering

HTTP/2's header HPACK has dynamic table. Subsequent requests on the same connection reuse the table. If the cache parses one set of headers and the origin parses another (due to dynamic-table state), the response is stored under a different key.

James Kettle / PortSwigger has detailed research on this.

## Modern vector 8 — DNS rebinding for cache origin

Cache resolves origin via DNS at startup; some respect TTL, some don't. If you control DNS for an origin (deployment misconfig), you can swap origin IPs and the cache continues serving from the old (now-attacker-controlled) origin.

## CDN-specific quirks

| CDN | Notable behaviour |
|---|---|
| Cloudflare | normalises path; respects Vary; some headers cache-keyed via Cache Rules |
| Fastly | VCL-configurable; many bugs come from per-customer VCL |
| Akamai | extensive policy; CP code-level surface; X-Akamai-* headers |
| Cloudfront | path-based; behaviours per cache policy; OAC for origin auth |
| Varnish | open-source; widely customisable; bugs often in custom VCL |

## Detection / response

For each origin:
- Identify the cache tier (Server / Via headers).
- Test which headers are unkeyed (curl with different headers, same URL, get the same cached response).
- For each unkeyed header, test reflection on origin.

For defenders:
- Add Cache-Control: private for endpoints with personalised content.
- Don't reflect untrusted headers into responses.
- Use `Vary` carefully; wide Vary = effectively unkeyed *and* wastes cache.
- Set strict cache-key allowlists at the CDN.

## Tools

- **Burp Suite — Param Miner extension** — finds unkeyed inputs that affect responses.
- **Web Cache Vulnerability Scanner (Hackmanit)**.
- **cachetomic / cachepoisonexp** — open-source.
- Manual: send identical requests with different headers; diff responses.

## Reporting

For a finding:
- Header / param that's unkeyed.
- Effect on response (reflection / redirect / 5xx).
- Repro steps.
- Impact: XSS chain, redirect to phishing, account-takeover.

## References
- [PortSwigger — Web cache poisoning research](https://portswigger.net/research/web-cache-poisoning)
- [Hackmanit — Web Cache Vulnerability Scanner](https://github.com/Hackmanit/Web-Cache-Vulnerability-Scanner)
- [Cloudflare — Cache key configuration docs](https://developers.cloudflare.com/cache/how-to/cache-keys/)
- [HTTPbis WG — cache RFC 9111](https://datatracker.ietf.org/doc/html/rfc9111)
- See also: [[cache-poisoning]], [[cache-deception]], [[http-smuggling-modern-variants]], [[host-header-injection]]

{% endraw %}
