---
title: Rate limit bypass
slug: rate-limit-bypass
---

> **TL;DR:** Rate limits are usually keyed on something forgeable (IP, header, account). Spoof the key, vary the path or casing, or race the counter before it commits, and the limit disappears.

## What it is
Rate limiting protects login, OTP, password reset, payment, and search endpoints. It is almost always implemented as a counter keyed on `client_ip || user_id || token || header`. If any input to that key is attacker-controlled, the counter can be split into many buckets. Race conditions in the counter itself allow brief bursts above the configured ceiling.

## Preconditions / where it applies
- A rate-limited endpoint with a visible block behaviour (429 / 403 / soft error)
- Some understanding of the upstream — gateway vs application-tier limiting changes which bypasses work
- For race-condition bypass: low-latency network to the target

## Technique
**Spoof the key.**

```http
POST /api/login HTTP/1.1
X-Forwarded-For: 1.2.3.4
X-Real-IP: 1.2.3.4
X-Originating-IP: 1.2.3.4
X-Client-IP: 1.2.3.4
True-Client-IP: 1.2.3.4
Forwarded: for=1.2.3.4
```

Rotate the spoofed IP per request. Works whenever the gateway honours the header without an allowlist of upstream proxies.

**Path mutation.**
Limits keyed on exact path: try casing (`/API/Login`), trailing slash (`/login/`), encoded characters (`/lo%67in`), parameter noise (`/login?x=1`), or alternate version prefixes (`/v1/login` vs `/v2/login`).

**Account/identifier rotation.**
Limit per `username` is bypassed by trying each password against many usernames instead (credential stuffing). Limit per token rotates tokens via a registration loop.

**HTTP/2 request smuggling and pipelining.**
Send N requests in one TCP frame ("last-byte sync" technique). Many limiters increment on response, not request, and lose the race against concurrently arriving requests. `turbo-intruder` ships gates that do this.

```python
engine = RequestEngine(endpoint=URL, concurrentConnections=1, engine=Engine.BURP2)
for _ in range(30):
    engine.queue(req, gate='race1')
engine.openGate('race1')
```

**Auth-state confusion.**
Some apps rate-limit only unauthenticated requests; sending a (possibly invalid) bearer token flips the request into an authenticated bucket with looser limits.

## Detection and defence
- Key limits on the verified TLS-terminating IP, not on `X-Forwarded-For`; if behind a CDN, validate the trusted-proxy chain
- Apply limits at the application layer with atomic increments (Redis `INCR`+`EXPIRE` with `Lua`, or sliding-window counters)
- Normalise paths and query strings before keying
- Add a global ceiling per endpoint independent of per-user limits to catch distributed attacks
- For high-value flows (login, payment), require CAPTCHA or step-up after N failures within a window

## References
- [HackTricks: rate-limit bypass](https://book.hacktricks.wiki/en/pentesting-web/rate-limit-bypass.html) — header and path tricks
- [PortSwigger: race conditions](https://portswigger.net/web-security/race-conditions) — single-packet attack technique
- [OWASP API #4 Unrestricted Resource Consumption (2023)](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/) — class definition
