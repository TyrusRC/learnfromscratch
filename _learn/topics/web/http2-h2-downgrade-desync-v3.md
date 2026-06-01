---
title: HTTP/2 downgrade desync (v3)
slug: http2-h2-downgrade-desync-v3
---

> **TL;DR:** Front-ends translate HTTP/2 frames to HTTP/1.1 for the back-end; if the translation honours attacker-controlled header values, a single H2 request becomes two H1 requests on the back-end and poisons the next victim's response.

## What it is
HTTP/2 separates framing (HEADERS, DATA) from body length, so request smuggling primitives that abused `Content-Length` vs `Transfer-Encoding` in pure HTTP/1.1 mostly died. But many production stacks (CDNs, WAFs, load balancers) speak H2 to the client and H1 to the origin. The translator concatenates pseudo-headers into a textual H1 request — if it permits CRLF, illegal characters, or trusts client-supplied `:authority` / `:path` containing newlines, the attacker injects an entire second H1 request into the upstream TCP stream. PortSwigger's 2022-2023 research (HTTP/2: The Sequel is Always Worse) and the 2024 "Smuggling v3 / CL.0" research extend this with H2.CL, H2.TE, and "0.CL" client-side desync.

## Preconditions / where it applies
- Edge speaks H2/H3 to clients but H1.1 to back-end (Cloudflare, Akamai, AWS ALB → most origins).
- Either the front-end allows CRLF in H2 header values, or the back-end accepts ambiguous H1 bodies, or the front-end pools connections to the back-end.
- Targets: shared upstream connections; one poisoned request affects the next user on the same TCP socket.

## Technique
Send a single H2 request whose plain-text header values contain `\r\n` and a smuggled prefix:

```
:method  POST
:path    /
:authority example.com
foo:     bar\r\n\r\nGET /admin HTTP/1.1\r\nHost: example.com\r\nX:
content-length: 0
```

After H1 translation the back-end sees POST `/` immediately followed by GET `/admin` on the same socket; the smuggled GET steals the next user's session cookie or pollutes their response.

Other v3 primitives:

- **H2.CL** — H2 spec requires servers to ignore `content-length`, but some back-ends do not; front-end trusts the frame length, back-end the header → classic CL.TE.
- **H2.TE** — back-end accepts `transfer-encoding: chunked` from an H1 conversion even though H2 disallowed it.
- **CL.0 / 0.CL** — front-end thinks the body is empty (no `content-length`), back-end thinks it has a body, or vice versa. James Kettle's 2024 follow-up details "browser-powered" client-side desync against unmodified H1 servers.
- **Response queue desync** — poison the connection so the next response served on the pooled socket is the attacker's stolen one.

Tooling: HTTP Request Smuggler v3 (Burp extension) automates probing; `h2csmuggler` and `smuggler.py` for CLI. Differential probes use a known-safe endpoint and a 1-second wait to detect timing splits.

## Detection and defence
- Disable HTTP/2 → HTTP/1.1 downgrades; use end-to-end H2 to the origin where possible.
- Front-end MUST reject H2 header names/values containing CRLF, NUL, or otherwise invalid chars (RFC 9113 §8.2.1).
- Disable upstream connection pooling between distinct clients, or pin each upstream connection to a single front-end client session.
- Web server settings: nginx `http2_chunk_size` and `proxy_http_version 1.1` paired with `proxy_request_buffering on`; HAProxy `option http-no-delay` and v2.7+ for fixes.
- Detection: alert on responses with `Connection: close` followed by mismatched status codes, and on `400 Bad Request` bursts on shared upstreams.

See also [[http-request-smuggling]], [[request-tunnelling-desync]], [[cache-poisoning]].

## References
- [PortSwigger – HTTP/2: The Sequel is Always Worse](https://portswigger.net/research/http2) — 2021 reset of the desync field
- [PortSwigger – Smuggling the Unsmugglable](https://portswigger.net/research/smuggling-the-unsmugglable-web-application-request-queue) — v3 / CL.0 research
- [RFC 9113 – HTTP/2](https://www.rfc-editor.org/rfc/rfc9113) — normative framing rules
