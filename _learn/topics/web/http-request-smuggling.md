---
title: HTTP request smuggling
slug: http-request-smuggling
---

> **TL;DR:** Front-end and back-end disagree about where one request ends and the next begins; smuggled bytes become a second request that bypasses front-end controls and steals data from neighbour connections.

## What it is
HTTP/1.1 supports two ways to delimit a request body: `Content-Length` (CL) and `Transfer-Encoding: chunked` (TE). When a chain of proxies and an origin disagree about which to honour, the attacker can append part of a second request inside the first. The back-end then prefixes the smuggled bytes onto whichever request comes next on the keep-alive connection — usually another user's.

## Preconditions / where it applies
- Front-end proxy, CDN, or load balancer in front of an origin server, both speaking HTTP/1.1 to each other.
- Either back-end keep-alive is on (it nearly always is) or HTTP/2 → HTTP/1.1 downgrade at the front-end.
- A parser mismatch — patched stacks are still vulnerable when a feature flag or header-line normaliser regresses.

## Technique
1. **Classic variants.**
   - **CL.TE:** front-end uses CL, back-end uses TE. Send both headers; the back-end stops at `0\r\n\r\n` and treats trailing bytes as a fresh request.
   - **TE.CL:** front-end uses TE, back-end uses CL. Opposite asymmetry.
   - **TE.TE:** both honour TE but one accepts a malformed variant (`Transfer-Encoding : chunked`, `Transfer-encoding: xchunked`, etc.).
2. **Sample CL.TE smuggle.**

   ```http
   POST / HTTP/1.1
   Host: target
   Content-Length: 13
   Transfer-Encoding: chunked

   0

   SMUGGLED
   ```

   Front-end forwards everything (CL=13). Back-end stops at `0\r\n\r\n`, leaves `SMUGGLED` queued.
3. **HTTP/2 downgrade (H2.CL / H2.TE).** Front-end speaks H2 to the client, H1 to the back-end. H2 has no CL/TE but the front-end blindly serialises pseudo-headers into H1 — inject `:authority`, `transfer-encoding`, or `content-length` via H2 header smuggling. See [[http2-h2-downgrade-desync-v3]] and [[request-tunnelling-desync]].
4. **What to do with it.** Steal session cookies by prefixing a victim's request with a header that gets logged or reflected. Bypass front-end auth/path filters (smuggled request goes to `/admin`). Cache-poison by aligning the smuggled response with another user's request.
5. **Detection tooling.** Burp Repeater with the HTTP Request Smuggler extension; manual timing-based probes that look for delayed responses indicating queued bytes.

## Detection and defence
- Use HTTP/2 end-to-end and disable HTTP/1.1 downgrade where possible.
- Configure front-end to reject ambiguous requests: both CL and TE present, or any TE variant other than canonical `chunked`. Normalise headers before forwarding.
- Disable keep-alive between front-end and back-end (performance hit but kills the queue).
- Patch and test: PortSwigger's research keeps surfacing new variants — re-run smuggle tests after any proxy upgrade.
- Detection: 400/502 spikes from one IP, prefix-mismatch in access logs (one user's request shows a path another user submitted), Burp Collaborator hits from queued probes.

## References
- [PortSwigger — HTTP request smuggling](https://portswigger.net/web-security/request-smuggling) — foundational labs.
- [PortSwigger — HTTP/2 desync research (2021)](https://portswigger.net/research/http2) — H2-specific variants.
- [PortSwigger — Browser-Powered Desync Attacks](https://portswigger.net/research/browser-powered-desync-attacks) — client-side amplification.
