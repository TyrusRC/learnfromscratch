---
title: Domain fronting and CDN abuse
slug: domain-fronting-and-cdn-abuse
aliases: [domain-fronting, cdn-abuse]
---

{% raw %}

> **TL;DR:** Domain fronting hides your real C2 host behind a popular CDN: the TLS SNI shows `legit.cdn.com`, but the HTTP `Host` header inside the TLS tunnel routes to your malicious origin. Major CDNs (Cloudfront, Fastly, Google) have largely closed this; some smaller ones still allow it, and the *general* technique — exploit the gap between SNI and inner HTTP routing — keeps working in new forms (domain hiding, CDN-shared certs, fronting via Cloudflare Workers). Companion to [[dns-c2-and-icmp-c2]] and [[c2-protocol-design]].

## The mechanic

A standard HTTPS request to `evil.example.com`:
```
TLS SNI       → evil.example.com   ← what your network sees
TLS cert      → evil.example.com
HTTP Host:    → evil.example.com   ← what the server sees
```

Classic domain fronting:
```
TLS SNI       → ajax.googleapis.com   ← decoy, looks innocent on the wire
TLS cert      → *.googleapis.com
HTTP Host:    → evil-attacker.cloudfront.net   ← real routing target
```

If the CDN's edge ignores SNI for routing and trusts the `Host` header instead, your traffic reaches the attacker origin while the network sees only "user talking to Google".

## Why CDNs killed it

In 2018 Amazon and Google announced they'd require SNI ↔ Host alignment. Cloudfront returns `421 Misdirected Request` if they diverge. Cloudflare and Fastly enforced similar.

Today the *literal* trick (SNI of one customer, Host of another) generally doesn't work on the big three. The *family* of techniques is broader.

## Modern variants

### 1. Domain hiding (same CDN tenant)

You buy a clean-looking domain `update-news.example`, point it at Cloudfront, set up a Cloudfront distribution that proxies to your origin. SNI = your domain. To a low-tier proxy, this is just another customer of Cloudfront, indistinguishable from a real product website. Detection is content-based, not domain-based.

This isn't "fronting" but it's the same operational effect — high-reputation CDN IP, hard to block without overblocking real traffic.

### 2. Cloudflare Workers as C2 proxy

A Worker is JS running at Cloudflare's edge for *your* domain. You write one that proxies all `/api/*` requests to your origin (a Sliver/Mythic server). Implants call `https://your-clean-domain.workers.dev/api/...` and get a response.

The defender sees `*.workers.dev`. Some EDRs categorise this as low-reputation; many do not.

### 3. SNI-padded fronting on lesser CDNs

Some CDNs and reverse proxies still don't enforce SNI/Host alignment. Lab and document case-by-case; vendors close these as soon as researchers publish.

### 4. Encrypted ClientHello (ECH)

ECH (formerly ESNI) hides the SNI itself inside an encrypted envelope. When ECH is widespread, network-layer SNI inspection breaks entirely — defenders will need TLS interception or DNS-based controls instead. As of writing, ECH is supported by Cloudflare and increasingly by Firefox/Chrome.

## Operational setup (Cloudfront-style example)

```text
attacker.example.tld  ─DNS CNAME─→  d1abcdef.cloudfront.net
                                          ↓ origin
                                   c2.attacker.example  (Sliver/Mythic listener)
```

1. Buy a domain that looks plausible for your pretext.
2. Create a Cloudfront distribution with `c2.attacker.example` as origin.
3. Cloudfront issues a TLS cert for `attacker.example.tld`.
4. Implants beacon `https://attacker.example.tld/jquery-3.6.0.min.map` etc.
5. Cloudfront forwards to your origin, which returns base64-encoded tasks.

## Detection (so you know what to obfuscate)

- Beacon timing — periodic, low-variance HTTPS calls to one domain.
- URL shape — `*.workers.dev`, freshly-registered domains, low Alexa/Tranco rank.
- TLS JA3/JA4 fingerprints — many C2 clients have unusual TLS stacks.
- Body size patterns — small request/large response repeated.
- Reputation feeds and CT-log monitoring catch newly-issued certs for impersonation.

## OSEP/red-team relevance

OSEP cares about *bypassing network filters*. Domain fronting / CDN abuse is one of the two big patterns (the other is covert channels via DNS/ICMP — [[dns-c2-and-icmp-c2]]).

A defensible engagement chain:
- Stage 1 implant uses DNS C2 for foothold (slow but resilient).
- Once promoted, switch to HTTPS over a CDN-fronted domain for higher throughput.
- Loot exfil over the high-rep CDN, not DNS.

## Legal and ethical
Domain fronting on a CDN is in many cases against the CDN's terms of service. Even for pentests where the *target* permits the activity, the *CDN* may suspend your account. Confirm with the engagement letter and use only services where you have explicit authorisation.

## References
- [Fox-IT — Domain fronting strikes again](https://blog.fox-it.com/) (research index)
- [Cloudflare — End-to-end encrypted SNI](https://blog.cloudflare.com/encrypted-client-hello/)
- [Will Schroeder / cobbr — C2 infrastructure planning](https://posts.specterops.io/)
- [BishopFox Sliver — HTTPS transport](https://github.com/BishopFox/sliver/wiki/HTTPS)
- See also: [[c2-protocol-design]], [[infrastructure-design]], [[dns-c2-and-icmp-c2]], [[osep-roadmap]]

{% endraw %}
