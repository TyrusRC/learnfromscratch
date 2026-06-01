---
title: DNS rebinding
slug: dns-rebinding
---

> **TL;DR:** Attacker domain TTL=0 flips between attacker IP (load script) and victim internal IP (same-origin requests). Bypasses SOP at the IP layer.

## What it is
Same-origin policy is keyed on (scheme, host, port) — the **hostname**, not the resolved IP. An attacker who controls authoritative DNS for `evil.tld` can return their own IP first (to deliver JS), wait for the browser to time-out the cache, then return an internal/RFC1918 IP for the same hostname. The page's own scripts now talk to the internal target *as same-origin*, defeating SOP-based isolation that internal services rely on.

## Preconditions / where it applies
- Victim browses to attacker domain (phishing, malvertising)
- Target service reachable from victim's network (router admin, dev server, internal API, IoT, metadata endpoints)
- Target accepts requests with arbitrary `Host:` header (no virtual-host enforcement)
- DNS cache TTL ≤ a few seconds, or browser uses short pinning windows

## Technique
1. Stand up authoritative DNS (e.g. `whonow`, custom Python `dnslib`) that returns differing answers per-query: first query → attacker IP, subsequent → `192.168.1.1`/`169.254.169.254`/`127.0.0.1`.
2. Victim loads `http://rebind.evil.tld/` → resolves to attacker IP, gets attacker JS.
3. JS keeps an XHR loop running:
   ```js
   async function poke(){
     try { const r = await fetch('/admin/info'); return await r.text(); }
     catch(e){ setTimeout(poke, 1500); }
   }
   ```
4. After browser pin expires, the second DNS lookup returns the internal IP. The XHR now hits `192.168.1.1` but the browser thinks it is same-origin with `rebind.evil.tld`, so the response body is readable.
5. JS reads and exfiltrates router config / credentials / cloud metadata to attacker collector.
6. **Singularity-of-origin** (NCC Group) automates multi-target attacks, port scanning, and payload selection.
7. Variants: **multi-A record** (return both attacker and target IPs, attacker IP firewalled to force fallback), **WebRTC IP discovery** to learn victim's LAN range first.

## Detection and defence
- Services: enforce `Host:` header allowlist (only accept `Host: 192.168.1.1` or known hostname); reject unknown.
- Require authentication on every endpoint, even on localhost / LAN — no "trusted network".
- TLS everywhere internally; rebinding cannot match cert SAN.
- Browsers pin DNS for the page lifetime against private-IP rebinds (Chrome `--enable-features=PrivateNetworkAccessRespectPreflightResults`); enable PNA preflights.
- Block RFC1918 / link-local / loopback responses for public-suffix domains at the resolver (dnsmasq `--stop-dns-rebind`, Unbound `private-address`).
- Cloud metadata: require `Metadata: true` (Azure) or IMDSv2 token (AWS) — defeats simple rebind because the token request needs PUT/header that fetch from a foreign origin cannot provide without preflight.
- Related: [[ssrf]], [[ssrf-to-cloud]], [[cors-misconfig]].

## References
- [NCC Group — Singularity of Origin](https://github.com/nccgroup/singularity) — automated rebind framework
- [whonow](https://github.com/brannondorsey/whonow) — minimal rebinding DNS server
- [Chromium — Private Network Access](https://developer.chrome.com/blog/private-network-access-preflight) — browser mitigation
