---
title: Web cache deception
slug: cache-deception
---

> **TL;DR:** Tricking the cache into storing a sensitive personalised response under a public-looking path.

## What it is
A confused-deputy between an origin that dynamically routes paths and a CDN that decides cacheability by suffix. The attacker convinces the victim's browser (or a crawler) to fetch a sensitive URL with an appended `*.css`/`*.js`/`*.png` segment. The origin still returns the personalised page; the cache sees a "static" extension and stores it. Any subsequent attacker request to the same path retrieves the victim's response.

## Preconditions / where it applies
- A CDN/reverse cache in front of the origin (Cloudflare, Akamai, Fastly, Varnish, nginx with default extension caching)
- Origin that ignores or rewrites trailing path segments (PHP `PATH_INFO`, Rails route globbing, IIS `?` handling, Express trailing slashes)
- A way to get the victim to issue the malicious URL while authenticated (link, image-src, [[cross-site-scripting]], [[open-redirect]])

## Technique
1. Identify a personalised endpoint, e.g. `/account` returning the victim's profile JSON/HTML.
2. Find the cache rule. Often "cache by extension" — `.css`, `.js`, `.gif`, `.ico`, `.svg`, `.woff`.
3. Probe the origin's path handling. Try variants:
   ```
   /account/foo.css
   /account/foo.js
   /account;name=foo.css
   /account%2ffoo.css
   /account%00foo.css
   /account?x=.css
   /account/.css
   ```
   If `/account/foo.css` returns the victim's personalised HTML (HTTP 200, account body), the origin ignored the suffix.
4. Confirm caching: send the same URL twice unauthenticated; second response shows the cached private body and a cache HIT header (`CF-Cache-Status: HIT`, `X-Cache: HIT`, `Age:` non-zero).
5. Lure the victim — `<img src="https://target/account/foo.png">` in a third-party page is enough; the browser sends cookies, origin renders private content, cache stores under public key.
6. Visit the URL from any client to read the cached PII / auth tokens / CSRF token.
7. Omer Gil's "delimiter" variants extend this to non-extension delimiters (`/`, `;`, `\`, encoded slashes) where origin and cache disagree on path normalisation.

## Detection and defence
- Cache key on full normalised path **as the origin sees it** — share a parser between proxy and origin where possible.
- Never cache responses with `Set-Cookie`, `Authorization` request header, or `Cache-Control: private` — enforce at CDN.
- Strip or canonicalise unexpected suffixes at the edge before routing.
- Add `Cache-Control: no-store` to anything personalised; verify with `curl -sI` after deploy.
- Hunt logs for high HIT ratios on URLs with extensions that mismatch their content-type (e.g. `text/html` served as `*.css`).
- Related: [[cache-poisoning]], [[http-request-smuggling]], [[canonicalization-attacks]].

## Technique — variant: cache key normalisation
Some CDNs lower-case the cache key. `/Account/foo.css` and `/account/foo.css` map to the same key but route to different controllers — a deception variant without needing an extension.

## References
- [Omer Gil — Web Cache Deception Attack](https://omergil.blogspot.com/2017/02/web-cache-deception-attack.html) — original write-up
- [PortSwigger — web cache deception](https://portswigger.net/web-security/web-cache-deception) — academy lab and theory
- [Akamai — WCD revisited](https://www.akamai.com/blog/security/web-cache-deception-attack-revisited) — delimiter variants at scale
