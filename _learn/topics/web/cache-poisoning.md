---
title: Web cache poisoning
slug: cache-poisoning
---

> **TL;DR:** Mix an unkeyed input that the origin reflects into a cacheable response, then let the CDN serve your payload to every subsequent visitor.

## What it is
A cache stores a response keyed on a subset of the request (typically host + path + query). Any request element outside that key — a custom header, a vary mismatch, a fat GET body — is "unkeyed". If the origin reflects an unkeyed input into the response and the response is cacheable, an attacker can poison the cache entry so that legitimate users receive the attacker's content.

## Preconditions / where it applies
- A reverse proxy / CDN in front of the app (Akamai, Cloudflare, Varnish, Fastly, CloudFront, AEM Dispatcher).
- An origin behaviour that reflects a header/parameter into the response body, the Location header, a `Link` header, or an `X-` header that the browser will act on.
- The response is cacheable (200, no `Cache-Control: private/no-store`, or a hit-for-pass that returns to cache on a later cycle).

## Technique
Identify the cache by `X-Cache`, `Age`, `CF-Cache-Status`, `Via`, or Varnish hit-count headers. Send a candidate unkeyed input and look for reflection. Param Miner (Burp) automates the discovery — it fuzzes 200+ headers against a known cache buster.

```http
GET /en/?cb=1 HTTP/1.1
Host: target.com
X-Forwarded-Host: evil.com
X-Forwarded-Scheme: http
```

If the origin emits `<link rel="canonical" href="http://evil.com/en/">` or a redirect to `evil.com`, the response is cached and replayed. Other primitives:

- **Unkeyed query / fat GET** — `GET /?utm_source=x` where the parser accepts a duplicate parameter the cache ignores.
- **Cache key normalisation** — `;`, `..%2f`, trailing-slash, case-folding differences between CDN and origin let one URL poison another.
- **Cache deception cousin** — when a static-looking extension (`.css`, `.js`) is cached on top of a dynamic endpoint, e.g. `/account.css` resolves to `/account` at the origin.
- **DoS variant** — set a header that breaks rendering (`X-Forwarded-Scheme: nothttps` causing a redirect loop) so the cached entry is a denial-of-service page.

Once the unkeyed input is confirmed, append a cache-busting query while developing the payload, then drop the buster for the real poisoning request and race the cache TTL refresh.

## Detection and defence
- Define an explicit cache key that includes every header the origin reads (`Vary: X-Forwarded-Host, X-Forwarded-Scheme`) — or strip those headers at the edge.
- Origin should never emit attacker-controlled values into `Location`, `Link`, `Set-Cookie`, or `<link>` tags on cacheable paths.
- Monitor for spikes in `Vary` cardinality and for 5xx ratios immediately after a cache flush.
- Blue team: log the full request including headers on edge nodes; poisoning attempts show as one outlier followed by many identical hits.

See also [[cache-deception]], [[http-request-smuggling]], [[http-parameter-pollution]].

## References
- [PortSwigger – Web Cache Poisoning](https://portswigger.net/web-security/web-cache-poisoning) — primer + labs
- [Kettle – Practical Web Cache Poisoning](https://portswigger.net/research/practical-web-cache-poisoning) — original 2018 paper
- [Kettle – Cache Poisoning at Scale](https://portswigger.net/research/web-cache-entanglement) — 2020 follow-up with key-normalisation tricks
