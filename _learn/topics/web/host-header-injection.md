---
title: Host Header Injection
slug: host-header-injection
---

> **TL;DR:** Apps that trust the `Host` (or `X-Forwarded-Host`) header to build links, cache keys, or routing decisions can be tricked into emitting attacker-controlled URLs, poisoning caches, or reaching unintended virtual hosts.

## What it is
The `Host` header tells the server which virtual host to serve, but frameworks frequently reflect it into password-reset URLs, absolute redirects, canonical tags, or backend routing rules. If the value is attacker-controlled and not validated against an allowlist, the resulting link or response gets redirected through an evil origin. Reverse proxies that forward `X-Forwarded-Host` blindly extend the same problem one hop deeper.

## Preconditions / where it applies
- Password-reset / email-verification flows that build links from request headers
- CDN or Varnish layers that key cache only on path, not on Host
- Reverse proxies forwarding `X-Forwarded-Host`, `Forwarded`, or `X-Original-Host` to a backend that trusts it
- Apps serving multiple tenants by Host without strict allowlisting (virtual-host confusion)

## Technique
```http
POST /password/reset HTTP/1.1
Host: attacker.example
X-Forwarded-Host: attacker.example
Content-Type: application/x-www-form-urlencoded

email=victim@target.tld
```

Dual-host smuggling (some stacks parse only the first, others the last):
```http
GET / HTTP/1.1
Host: target.tld
Host: attacker.example
```

Cache-poisoning probe via unkeyed header:
```bash
curl -s -H 'X-Forwarded-Host: evil.tld' https://target.tld/login | grep -i evil.tld
curl -s https://target.tld/login | grep -i evil.tld   # second request -- did the cache serve the poisoned copy?
```

## Detection and defence
- Compare reflected canonical / `Location` / reset-link domain against the request Host header in logs
- Allowlist Host server-side, reject unknown values with 421 Misdirected Request
- Include Host (and any trusted `X-Forwarded-*`) in cache keys; strip untrusted forwarded headers at the edge
- Build outbound links from a server-side constant base URL, never from request headers

## References
- [PortSwigger Web Security Academy — Host header attacks](https://portswigger.net/web-security/host-header) — lab-driven walkthroughs of poisoning, routing, and reset chains
- [OWASP — Testing for Host Header Injection](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/07-Input_Validation_Testing/17-Testing_for_Host_Header_Injection) — checklist for assessors

See also: [[cache-poisoning]], [[account-recovery-attacks]], [[vhost-enumeration]].
