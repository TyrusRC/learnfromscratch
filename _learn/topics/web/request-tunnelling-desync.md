---
title: Request tunnelling via desync
slug: request-tunnelling-desync
---

> **TL;DR:** Tunnelled requests reach the back-end on a shared keep-alive connection but never traverse the front-end fully, leaking responses meant for other users across the same socket.

## What it is
A variant family of [[http-request-smuggling]] where the smuggled bytes do not become a fully-formed second request from the front-end's perspective but instead "tunnel" along the same back-end connection. The front-end thinks it forwarded one request; the back-end services that request, then services the smuggled remainder, then returns the response on the same TCP connection — which the front-end mis-attributes to the next inbound client.

## Preconditions / where it applies
- Shared connection pooling between front-end (CDN, ALB, nginx, HAProxy) and back-end origin. HTTP/1.1 keep-alive or HTTP/2 → HTTP/1.1 downgrade.
- Header normalisation or framing mismatch — TE/CL disagreement, `Content-Length: 0` plus a body, oversized chunk-size hex, or H2 pseudo-header smuggling into H1.
- Multi-tenant front-end (CDN) pools connections from many clients onto few back-end sockets — that's where the cross-user leak shows up.

## Technique
1. **Find the desync.** Same probes as classic smuggling: send CL+TE, ambiguous TE, or H2-to-H1 framing tricks. Watch for delayed-response and probe-collision behaviour with Burp's Smuggler extension.
2. **Tunnel a request that prefixes the next.** The smuggled request body contains a partial request line that, when combined with the next victim request, alters routing or headers:

   ```http
   POST / HTTP/1.1
   Host: target
   Content-Length: 200
   Transfer-Encoding: chunked

   0

   GET /private HTTP/1.1
   X-Ignore: 
   ```

   Front-end thinks one request of length 200. Back-end stops at the `0\r\n\r\n`, then parses `GET /private...` as a new request, but reads its headers from whatever the next victim request put on the wire — including their `Cookie`.
3. **Cross-user response steal.** Set up a slow-read on a smuggled request whose response will be served on the next take of the connection — collect the response intended for another user.
4. **Header injection.** Tunnel a header (`X-Forwarded-For: 127.0.0.1`) that bypasses front-end IP allowlists for the next victim's request.
5. **HTTP/2 specifics.** The "downgrade" surface in [[http2-h2-downgrade-desync-v3]] is the most fertile in current research — H2 lets the attacker inject CR/LF and header smuggling that the H1 back-end then re-parses.

## Detection and defence
- Disable front-end → back-end keep-alive, or set `Connection: close` on every forwarded request. Performance hit, but it kills the cross-user channel.
- Speak HTTP/2 (or HTTP/3) end-to-end and refuse downgrade. Validate H2 pseudo-headers; reject CR/LF and ASCII control in header values.
- Reject ambiguous H1 requests at the edge: both CL and TE, malformed TE, oversize chunks, header lines with leading whitespace.
- Patch and re-test: every PortSwigger desync paper since 2019 has surfaced new variants on stacks that thought they were fixed.
- Detection: 5xx clusters on a single back-end socket, response/request id mismatches in correlated logs, Burp Collaborator hits on tunnelled probes.

## References
- [PortSwigger — HTTP request smuggling, redux](https://portswigger.net/research/http2) — H2 desync variants.
- [PortSwigger — Browser-Powered Desync Attacks](https://portswigger.net/research/browser-powered-desync-attacks) — client-side amplification.
- [PortSwigger — Listen to the whispers (2024)](https://portswigger.net/research/listen-to-the-whispers-web-timing-attacks-that-actually-work) — timing-side desync detection.
