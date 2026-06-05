---
title: BGP hijack attacks
slug: bgp-hijack-attacks
aliases: [bgp-hijack, bgp-attacks, prefix-hijack]
---

> **TL;DR:** Border Gateway Protocol (BGP) governs how Internet routes propagate between Autonomous Systems (ASes). Without strong authentication, an AS can announce prefixes it doesn't own — and the global routing table will accept. Attackers / nation-states use BGP hijacks to intercept traffic (MITM), redirect to attacker infrastructure, or DoS. Defences: RPKI Route Origin Validation, BGPsec (rare in deployment), AS path filtering, peer-specific filtering. Companion to [[dnssec-misconfig-attacks]] and [[tor-hidden-service-attacks]].

## Why BGP matters at this level

- BGP is **the** global routing protocol; every route between ASes goes through it.
- Originally designed with **mutual trust** assumption.
- Misconfiguration alone has taken down major chunks of internet (Pakistan vs YouTube 2008, Rogers 2022).
- Active attackers have repeatedly used BGP for intelligence collection and to facilitate phishing.
- Defences are deploying but globally incomplete.

## How BGP hijack works

Each AS announces "prefixes" (IP ranges) it owns. Neighbours accept and propagate. A hijack:
- Attacker AS announces a prefix it doesn't own.
- Neighbours, lacking verification, propagate.
- Some portion of global routing table now sends that prefix's traffic to attacker.

Several variants:

### Origin hijack

AS X announces prefix P, claiming to be the origin. Neighbours route to X for P.

### More-specific hijack

Legitimate owner announces /24. Attacker announces /25 (more specific). BGP best-route prefers more-specific. Traffic for that /25 routes to attacker.

### Path manipulation

Attacker announces P with an AS path that makes it appear legitimate (e.g., listing the real owner's AS at the end). Confuses ROV checks.

### Sub-prefix hijack with re-origination

Attacker announces a more-specific then re-routes to legitimate owner. Achieves transparent interception (MITM).

## Recent incidents

- **Pakistan → YouTube 2008** — accidental; ISP announced YouTube prefix to block locally; leaked globally.
- **Rostelecom 2017** — international financial routes briefly through Russia.
- **Verizon → Cloudflare 2019** — accidental; Cloudflare and friends down for hours.
- **AS9009 / multiple campaigns** — credential phishing routes during transient hijacks.
- **Crypto exchange theft via hijack** — multiple incidents 2018–2020 where BGP hijack of DNS-resolver IPs enabled fake exchange page.
- **Russia / RIPE NCC actions 2022+** — periodic geopolitical BGP issues.

## Class 1 — Intentional traffic interception

- **State actors** redirect target ISP's prefix to their AS for SIGINT.
- **Criminal** hijacks of payment processor or crypto-wallet servers to MITM.

## Class 2 — DoS via hijack

- Attacker hijacks victim's prefix to a sinkhole. Victim's services unreachable.
- 2022 Rogers (Canada) outage cascaded from internal BGP misconfig propagating broadly.

## Class 3 — Phishing facilitation via hijack

- Hijack DNS resolver IP for ~hours.
- Serve poisoned responses.
- Combined phishing.

## Class 4 — Crypto wallet phishing

Documented incidents (MyEtherWallet 2018):
- BGP hijack of AWS Route53 IPs.
- DNS-over-resolver-fed AWS Route53 returns attacker IP for `myetherwallet.com`.
- Phished credentials.

Attack window was hours; financial loss was real.

## Class 5 — Internal-BGP leak

A multi-homed enterprise that misconfigures iBGP / eBGP filters can leak internal routes externally — exposing internal IP ranges that should never be globally routed.

## Defence — RPKI Route Origin Validation

Resource Public Key Infrastructure:
- Prefix owners create cryptographically signed "Route Origin Authorisations" (ROAs) declaring "AS X is allowed to originate prefix P".
- BGP peers fetch ROAs from a validator.
- Routes contradicting ROAs are dropped or de-preferenced.

Deployment is increasing — major IXPs and Tier-1 carriers (Cloudflare, NTT, Hurricane Electric, others) drop ROV-invalid routes.

Adoption status (mid-2025): >50% of IPv4 prefixes have ROAs; >80% of major peer ASes filter invalids. Still gaps.

## Defence — BGPsec

Path-validation extension to BGP. Cryptographic signature on each AS-path hop. Theoretically defeats path manipulation.

Deployment is minimal — performance / operational concerns. Maybe wider deployment by 2030.

## Defence — Operational filters

- **Prefix-list filters** per peer ("only accept these prefixes from this peer").
- **AS-path filters** ("don't accept paths through known-bad ASes").
- **Max-prefix limits** (drop session if peer sends too many).
- **TTL Security (GTSM)** — only accept from immediate neighbours.

These are configurable manually; rigour varies by ISP.

## Detection

- **BGPmon**, **RIPE RIS**, **RouteViews** — public route monitoring.
- **BGP Hijack Detection** services (Cloudflare, RoughDNS, others).
- **Sudden change** in originating AS for owned prefix.
- **More-specific announcement** of owned prefix from unknown AS.

If you own a prefix, set up monitoring. Alert on any deviation.

## Defensive baseline for organisations

- **Create ROAs** for owned prefixes.
- **Validate routes** at your border — drop ROV-invalid.
- **Monitor** for hijack of your prefixes via BGPmon / Cloudflare Radar.
- **Customer-side traffic analytics** to detect unusual path behaviour.
- **Diversify carriers** — single carrier means single point of routing failure.

## Workflow to study

1. Set up a small BGP lab using FRR / GoBGP on two VMs.
2. Establish a session, announce prefixes.
3. Practice route-filter configuration.
4. Read public hijack post-mortems.
5. Sign up for RIPE NCC's RIS API; query historical route changes.

## Related

- [[dnssec-misconfig-attacks]] — adjacent class.
- [[tor-hidden-service-attacks]] — adjacent class.
- [[dangling-dns-takeover]] — DNS-side adjacent.
- [[subdomain-takeover]] — adjacent.
- [[domain-fronting-and-cdn-abuse]] — CDN-side adjacent.

## References
- [Cloudflare — "Is BGP safe yet?"](https://isbgpsafeyet.com/)
- [NIST RPKI deployment monitor](https://rpki-monitor.antd.nist.gov/)
- [RIPE NCC — BGP / RIS docs](https://www.ripe.net/analyse/internet-measurements/routing-information-service-ris)
- [MANRS — Mutually Agreed Norms for Routing Security](https://www.manrs.org/)
- [Job Snijders — BGP talks (NTT / Fastly)](https://www.youtube.com/@JobSnijders)
- See also: [[dnssec-misconfig-attacks]], [[tor-hidden-service-attacks]], [[dangling-dns-takeover]], [[subdomain-takeover]]
