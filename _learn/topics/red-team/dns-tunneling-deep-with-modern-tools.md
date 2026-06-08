---
title: DNS tunnelling deep with modern tools
slug: dns-tunneling-deep-with-modern-tools
aliases: ["dns-tunneling-modern","dns-c2-tradecraft-modern"]
date: 2026-06-08
---
{% raw %}

DNS tunnelling refuses to die because the protocol refuses to be properly inspected. Every enterprise still allows recursive resolution somewhere, and every cloud egress still leaks TXT lookups. The trick in 2026 is not whether you can tunnel — you can — but whether your tunnel survives a halfway competent SOC for more than a shift. This note covers the modern toolset, the physics of the channel, and the telemetry that catches lazy operators.

## The tool landscape

Five families matter today.

- **iodine**: the classic. NULL/TXT upstream, base32/base64/base128 encodings, raw UDP fallback if port 53 is open end to end. Throughput is the best of the bunch (hundreds of kbps on a clean path) because it treats DNS as a transport, not a covert channel. Loud by design.
- **dnscat2**: Ron Bowes' tool, still the reference for "covert" DNS C2. Encrypted by default, supports direct mode (you point it at the attacker NS) and authoritative mode (resolver chain). Sessions multiplexed over a single domain.
- **Sliver DNS implant**: production tradecraft. Uses parent domain delegation, per-message canaries, jittered polling, and chunked responses. See [[sliver-c2-deep]] for the implant internals. The DNS handler in Sliver is intentionally slow and chatty in short bursts to mimic recursive churn.
- **C3 (FSecure / MWR lineage)**: relay channel framework. DNS is just one channel among many; the value is chaining DNS-into-SMB-into-named-pipe so the operator never touches the implant directly. Pair with [[mythic-framework-deep]] style C2 brains.
- **Custom DoH tunnels**: typically Go or Rust, hitting Cloudflare/Google/Quad9 DoH endpoints. You give up DNS entirely and ride HTTPS, but the wire format stays DNS so server-side parsing is reusable. See also [[domain-fronting-and-cdn-abuse]].

## Bandwidth realism

Stop expecting SSH-grade throughput. Real numbers on enterprise resolvers:

- iodine, NULL records, low-latency path: 30 to 80 kbps
- dnscat2 over recursive resolvers: 3 to 8 kbps
- Sliver DNS implant with default jitter: 1 to 4 kbps
- DoH custom tunnel: 50 to 200 kbps but it is not DNS anymore

The ceiling is governed by three things: maximum label length (63 bytes), maximum FQDN length (253 bytes), and the response record size. TXT gives you ~255 bytes per string, multiple strings per record, ~4 KB with EDNS0. CNAME gives you one domain name per response. A records give you 4 bytes each but you can stack ~30 in a response. Most defenders fixate on TXT; CNAME chains are quieter and underused.

## Wire shapes

What defenders actually see:

```
; iodine — high entropy left labels, NULL/TXT, query rate ~50/s
abf3kq2.h7n4p9.tun.attacker.tld NULL

; dnscat2 — hex-ish labels, regular cadence, TXT responses
4a2f.1c.b3e9.c2.attacker.tld TXT "9e1c..."

; sliver dns — short labels, message-id prefix, low rate, jittered
a1.m7.k.c2.attacker.tld A 10.x.x.x
```

CNAME tunnels look like long delegation chains where the right-hand side keeps changing. A-record tunnels look like a host that suddenly resolves a domain 200 times in 10 seconds and gets 30 answers each time. None of these patterns survive a SIEM rule that looks for them, which is the point of the next section.

## EDNS0, DoH, DoT

EDNS0 OPT records let you push the response budget to ~4 KB, which roughly triples dnscat2 throughput. Most resolvers honour it. Use it.

DoH (RFC 8484) and DoT (RFC 7858) move the conversation off port 53. Operationally:

- DoH hides the queries from passive DNS sensors entirely. It does not hide the SNI of the DoH endpoint, so picking `cloudflare-dns.com` is fine until the SOC blocks public resolvers.
- DoT is easier to fingerprint (port 853, distinctive TLS handshake) and is often outright blocked.
- Some EDRs now MITM the workstation resolver stub; your DoH client should pin certificates or fail closed.

For network filter bypass framing, this slots directly into [[osep-network-filter-bypass-techniques]] and the broader picture in [[modern-tunnelling-chains-chisel-ligolo-gost]].

## Jitter and pacing

Static polling is what kills implants. Sliver's default DNS poll is a uniform distribution between two bounds with an optional skew. Better: poisson-distributed inter-query gaps with a human-hours mask. Drop traffic entirely outside 08:00 to 19:00 local for the victim. Yes, this caps you at a few KB per hour. That is the cost of staying resident.

## Detection — what catches you

The detections that work, in order of how cheap they are to deploy:

- **NXDOMAIN spike per host**: tunnels that encode upstream data as labels generate misses when chunking races the cache. A workstation hitting 500 NXDOMAIN on one parent domain in 5 minutes is not browsing.
- **Label Shannon entropy**: base32-encoded payloads have entropy in the 4.5 to 5.0 bits/char range. Real subdomains sit around 3.0 to 4.0. A rolling per-domain entropy histogram catches iodine and dnscat2 trivially.
- **Query rate per host per parent domain**: 60+ queries/minute to one second-level domain that is not a CDN is a tunnel until proven otherwise.
- **Unique-label cardinality**: tunnels burn through label space; a host querying 10k unique labels under one domain in an hour is unambiguous.
- **TXT/NULL/CNAME volume by host**: most workstations issue ~0 TXT lookups outside SPF/DMARC and ~0 NULL ever.
- **DoH endpoint blocklists plus DNS-over-port-53 enforcement**: forces tunnels back onto inspectable channels.

A mature SOC stacks these into a per-host score rather than firing on any one. Operators counter by reducing rate, lowering label entropy with dictionary encoding, and parking inside legitimate CDN zones.

## When to use DNS at all

DNS is for staging, beaconing, and credential exfil — not for shells and not for files. Use [[dns-c2-and-icmp-c2]] for the channel selection logic, switch to HTTPS, SMB, or named pipes for interactive work via [[pivoting-and-tunneling]], and accept that DNS is the channel you keep in your back pocket for the day the proxy dies.

{% endraw %}
