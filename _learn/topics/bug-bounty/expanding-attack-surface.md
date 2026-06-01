---
title: Expanding the attack surface
slug: expanding-attack-surface
---

> **TL;DR:** After surface recon (hosts, ports, paths), expand by discovering hidden parameters, undocumented routes, legacy endpoints, and information disclosed in error responses. This is where dupes get rarer and severity gets higher.

## What it is
Surface-level recon gives you a list of URLs. Expanding the attack surface means looking *inside* each URL — what parameters the handler accepts that the UI never sends, what alternative routes the framework exposes, what older API versions still respond, and what the server tells you about itself when it crashes. Each is a fresh input that may bypass the controls the visible UI is paired with.

## Preconditions / where it applies
- You've completed content discovery and have a working endpoint or set of them ([[content-discovery]])
- You can replay requests freely (no MFA-locked single-use tokens)
- The target tech stack is identified ([[tech-stack-fingerprinting]]) — guides which discovery vectors apply

## Technique
1. Hidden parameter mining. Frameworks read parameters the UI doesn't send. `param-miner` (Burp), `arjun`, and `x8` brute thousands of common names against a known endpoint, watching for response-size, status, or reflected-input diffs:

```
arjun -u https://target.tld/api/profile -m GET --stable
x8 -u https://target.tld/api/profile -w params.txt
```

Hits like `?debug=1`, `?admin=true`, `?include=users`, `?_method=PUT` unlock new functionality.
2. Undocumented routes by verb tampering and content-type switching:
   - `GET /api/orders` works → try `POST`, `PUT`, `DELETE`, `OPTIONS`
   - JSON endpoint → send same payload as `application/xml` (XXE), `application/x-www-form-urlencoded`, `multipart/form-data`
   - Some frameworks honour `X-HTTP-Method-Override: PUT` on POST requests
3. Legacy API versions. If `/api/v3/users` exists, probe `/api/v2/`, `/api/v1/`, `/internal/users`, `/api/internal/users`. Older versions often skip auth checks added later.
4. Error-message info disclosure. Force errors and read what leaks:
   - Send malformed JSON → stack trace exposes framework + version
   - Invalid type on a numeric field → SQL error reveals DB engine
   - Oversized upload → reveals tmp directory path
   - Invalid Host header → reveals backend server / IP
5. Spider for JS-only endpoints. The HTML site shows /login; the JS bundle calls /api/internal/v2/admin/* (see [[js-endpoint-extraction]], [[js-recon]]).
6. Cross-protocol exposure. The same backend may be served over WebSockets, gRPC, or GraphQL on a different path. Look for `/socket.io`, `/graphql`, `/grpc`, `/ws`.

## Detection and defence
- WAF should normalise / reject unexpected HTTP verbs and content types per route, not allow everything by default
- Production error responses should be generic (`500 Internal Server Error` with no body) — stack traces belong in logs, not responses
- Deprecated API versions should be hard-disabled, not just removed from docs
- Parameter-mining traffic looks distinctive: 50+ requests/second to the same URL with rotating single-parameter payloads — alert on it

## References
- [PortSwigger — Hidden parameter mining](https://portswigger.net/research/hunting-for-hidden-parameters) — paramminer methodology
- [HackTricks — Web Pentesting Methodology](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — checklist of expansion vectors
- [OWASP WSTG — Information gathering](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/01-Information_Gathering/) — error-message disclosure references
