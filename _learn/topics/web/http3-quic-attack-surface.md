---
title: HTTP/3 and QUIC attack surface
slug: http3-quic-attack-surface
aliases: [http3-attacks, quic-attacks]
---

{% raw %}

> **TL;DR:** HTTP/3 runs HTTP semantics over QUIC, which runs over UDP. Attack surface differs from HTTP/2: (1) connection migration via connection IDs — token theft scenarios change, (2) 0-RTT replay, (3) different request-smuggling primitives because frames vs streams differ, (4) amplification via initial-packet UDP, (5) load-balancer / WAF gaps because many vendors still don't fully parse QUIC, (6) new fingerprinting primitives. Companion to [[http-smuggling-modern-variants]] and [[http2-h2-downgrade-desync-v3]].

## What changed from HTTP/2

| Layer | HTTP/2 | HTTP/3 |
|---|---|---|
| Transport | TCP + TLS | UDP + QUIC (TLS 1.3 built-in) |
| Connection re-establish | new TCP handshake | Connection ID migration, no rehandshake |
| Frame loss | TCP head-of-line blocking across streams | per-stream loss isolation |
| 0-RTT | TLS session resumption | QUIC 0-RTT (replayable) |
| Header compression | HPACK | QPACK (different state model) |
| Frame layer | HTTP/2 frames over TCP | HTTP/3 frames over QUIC streams |

## Attack class 1 — Connection ID and migration

QUIC connections aren't tied to a 5-tuple (src IP/port → dst IP/port). They use *Connection IDs* — opaque blobs in each packet. A client can switch networks (Wi-Fi → cellular) and the same connection survives.

Bug shapes:
- Server logs by source IP — attacker migrates, evades IP-based throttling / blocking.
- Load balancer sticky-routing breaks when Connection ID and src IP disagree.
- Token-bound-to-IP schemes (legacy session-IP binding) trivially defeated by migration.

## Attack class 2 — 0-RTT replay

QUIC's 0-RTT lets clients send application data on the *first* packet using a key from a previous session. That data has no replay protection by spec — replays are possible.

Bug shapes:
- Non-idempotent endpoints (POST that creates state) reachable in 0-RTT → replay creates duplicate state.
- Authorization checks that depend on counter values can be replayed.

Defence: server-side reject 0-RTT for state-changing endpoints. Most modern servers (nginx-quic, h2o, cloudflare quiche) allow opt-in.

## Attack class 3 — HTTP/3 smuggling

HTTP/3 frames a single request as a sequence of frames on one stream. Smuggling primitives that worked at HTTP/1.1 (CL vs TE) don't apply directly. New ones:

- **Header-list compression confusion** — QPACK uses dynamic table; attacker manipulates table state to inject extra headers a downstream parser sees differently.
- **Stream multiplexing parsing gaps** — middlebox decodes streams independently, server reassembles; sequence differences create smuggle.
- **Pseudo-header injection** — `:authority`, `:method`, `:path` — different normalisation across stack tiers.

Bug research is younger than HTTP/2 smuggling; James Kettle / PortSwigger have published initial findings.

## Attack class 4 — UDP amplification

The initial QUIC packet is large (≥ 1200 bytes) and the server replies with up to 3x the client's data (Anti-Amplification limit). Misconfigured servers exceed the limit → reflection amplifier.

Modern servers respect the 3x rule and reject malformed Initial packets. Test with `--check-amplification` flags in QUIC scanners.

## Attack class 5 — load balancer / WAF visibility gaps

Many enterprise WAFs and load-balancers still:
- Don't parse HTTP/3 at all (passthrough).
- Parse HTTP/3 but skip stream/frame validation that they do for HTTP/2.
- Apply rate-limits per src-IP, defeated by Connection ID migration.

The attacker who knows the WAF terminates HTTP/3 differently from origin can craft requests that one side sees one way, the other sees another.

## Attack class 6 — fingerprinting

QUIC includes a transport-parameters Initial packet whose layout varies by implementation. JA4 (Wireshark)'s QUIC fingerprint can identify Chrome vs Firefox vs Go vs curl — useful both for blocking (defender) and detecting evasion (attacker).

## Tooling

```bash
# Send HTTP/3 requests
curl --http3 https://example.com/
# nghttp3 / quiche / chrome with --enable-quic
chromium --enable-quic --quic-version=h3 https://example.com

# Capture + decrypt (with SSLKEYLOGFILE)
SSLKEYLOGFILE=keys.log curl --http3 ...
# Wireshark loads keys.log and decrypts QUIC payload
```

## Server inventory

```bash
# Detect HTTP/3 support
curl -sIv --http3 https://example.com 2>&1 | grep -i alt-svc
# Alt-Svc: h3=":443"
```

## Defence

- Pin behaviour: server config decides 0-RTT replay-protection vs replay-allowed per endpoint.
- WAF / LB chain validates QUIC: same vendor end-to-end is safer than mixed-vendor.
- Rate-limit by Connection ID + token + IP, not IP alone.
- Logging includes Connection ID for correlation post-migration.

## OSCP/OSEP relevance

Low — bug-bounty and research relevance high.

## References
- [RFC 9000 — QUIC transport](https://datatracker.ietf.org/doc/html/rfc9000)
- [RFC 9114 — HTTP/3](https://datatracker.ietf.org/doc/html/rfc9114)
- [Cloudflare — HTTP/3 deep dive series](https://blog.cloudflare.com/http3-the-past-present-and-future/)
- [PortSwigger Research — HTTP/3 + protocol-level work](https://portswigger.net/research)
- See also: [[http-smuggling-modern-variants]], [[http2-h2-downgrade-desync-v3]], [[tls-1-3-attacks-and-misuse]]

{% endraw %}
