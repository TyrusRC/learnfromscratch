---
title: HTTP pipelining and keep-alive abuse
slug: http-pipelining-keepalive-abuse
aliases: [keep-alive-attacks, http-pipelining-bugs, connection-reuse-abuse]
---

{% raw %}

> **TL;DR:** HTTP/1.1 pipelining (rare today) and connection keep-alive (universal) let multiple requests share one TCP/TLS connection. Bugs: request-response misalignment when upstream errors mid-response, frontend/backend disagreement on connection lifetime, response splitting via connection-reuse-aware payloads, state bleed between sequential requests on the same connection (proxy-side or origin-side), and HTTP/2/3 frame interleaving abuse. Related to but distinct from [[http-request-smuggling]].

## What it is
HTTP keep-alive: after a response, the TCP connection stays open for the next request (`Connection: keep-alive` in 1.0; default in 1.1). HTTP/2 multiplexes streams on one connection. HTTP/3 over QUIC further.

For connection-reuse vulnerabilities, the shared identity is the connection, not the request. Server state — proxy state — can bleed across requests on the same connection if mishandled.

## Bug patterns

### 1. Connection-pool tenant bleed (proxy-side)
- Reverse proxy (HAProxy, nginx) pools backend connections.
- Connection from `req1` to backend used for `req2` from a different user.
- If backend caches authentication on connection (rare but real for some protocols), bleed.
- More common in DB connection pools than HTTP, but HTTP proxy with custom auth (mTLS) can exhibit.

### 2. Response splitting / desync via keep-alive
- Backend sends response with wrong `Content-Length` (off by N bytes).
- Next response on same connection starts N bytes into the data.
- Pipelined client receives garbled responses for request 2+.
- Same root cause as [[http-request-smuggling]] but observed on the response side.

### 3. Pipelining response misalignment
- Older HTTP/1.1 spec allowed client to send `req1, req2, req3` before any response.
- Server responds in order. If server processes async out-of-order and returns wrong response → client receives wrong content.
- Most modern proxies/servers don't pipeline; but if enabled, misalignment is a real bug.

### 4. Connection drop mid-response
- Backend writes headers then crashes.
- Proxy hands the half-written response to client OR retries on a new connection.
- Retry leaks: client-cached partial response + retry → user sees prior user's content if cache hits.

### 5. HTTP/2 stream interleaving
- HTTP/2 multiplexes streams on one connection. Streams have IDs.
- HTTP/2 spec doesn't strictly bind streams to authentication; auth is per-request (per-stream header).
- Bug: server caches "user" on connection on first stream → uses same on subsequent stream → wrong user.
- Variant of [[http2-h2-downgrade-desync-v3]].

### 6. CONNECT method state
- `CONNECT proxy.example.com:443` opens a tunnel through HTTP/2 connection.
- After CONNECT, the same connection carries arbitrary TCP. Some HTTP/2 servers don't properly transition state → header injection back to HTTP context.

### 7. WebSocket upgrade
- HTTP request becomes WebSocket via Upgrade. Same connection, different protocol.
- Server may inadvertently process post-upgrade frames as HTTP if upgrade-state machine has bug.

### 8. Keep-alive timeout race
- Server keeps connection N seconds. Client sends new request at N - 0.001s; server closes between read and respond.
- Race window: client resubmits on new connection; if request is non-idempotent (POST), duplicated.

### 9. Connection reuse across redirects
- Client receives 302 → reuses connection for the new URL.
- If new URL is on different security context (e.g., open redirect to attacker), some clients reuse the cookies/headers.
- Rare server-side bug; more client-side.

### 10. Proxy-server connection hijack
- TLS-terminating proxy holds backend connection. Bad cert validation in proxy → MitM proxies tamper with kept-alive flows.

### 11. Request smuggling persistence
- A smuggled request via [[http-request-smuggling]] persists in the next request's slot on the kept-alive connection.
- Effect: subsequent requests from OTHER users on the same proxy-backend connection get the smuggled response.
- "Persistent" smuggling has been observed against major sites.

### 12. Response queue poisoning
- Browser pipelines requests over HTTP/1.1 keep-alive (rare in modern browsers but happens).
- Response queue mismatch → wrong response for wrong tab.
- Modern browsers fall back to one-request-per-connection to avoid this.

### 13. Slowloris connection exhaustion
- Many keep-alive connections from one attacker; never close.
- Server connection table fills; DoS.
- Mitigation: `keepalive_timeout` short; per-IP connection cap.

## Testing methodology

### Black-box
- Burp Suite Repeater "Send connections in single connection" option.
- HTTP Request Smuggler extension.
- Custom scripts with persistent TCP socket + multiple requests.

### Detection
- Send 10 sequential requests on one connection; tag each with a unique cookie/header.
- For each response, verify it matches the right request.
- Misalignment → response splitting bug.

### Test scenario: response splitting
```http
GET /a HTTP/1.1
Host: x
Connection: keep-alive

GET /b HTTP/1.1
Host: x
Connection: keep-alive

GET /c HTTP/1.1
Host: x
Connection: close
```
Inspect responses order + content. If `/b` response contains `/a` data → desync.

## Source-side audit
```bash
# Custom connection / keep-alive handling
rg -n 'keep-?alive|setKeepAlive|KeepAliveTimeout' src/
# Connection-cached state
rg -n 'this\.connection\.\w+\s*=' src/
rg -n 'conn\.data|connection\.state' src/
# HTTP/2 stream state
rg -n 'http2\.Http2Stream|nghttp2' src/
# Manual buffer/framing
rg -n 'Content-Length|Transfer-Encoding' src/
```

## Defence

### Server config
- `keepalive_timeout` 60s typical for nginx; reduce to 15s if attack risk.
- Per-IP connection cap.
- HTTP/2 stream limit per connection (default 100 in nginx).
- Strict Content-Length / Transfer-Encoding enforcement; reject ambiguous.

### Application
- Authenticate per-request (header check), never per-connection.
- No connection-scoped mutable state.
- Logs include connection ID for debugging cross-request bleed.

### Defence in depth
- HTTP/2 end-to-end (frontend + backend), avoid H2/H1 boundary.
- Use HTTP/3 where supported (QUIC's framing is less ambiguous).

## References
- [RFC 9112 — HTTP/1.1 Semantics & Pipelining](https://datatracker.ietf.org/doc/html/rfc9112)
- [RFC 9113 — HTTP/2](https://datatracker.ietf.org/doc/html/rfc9113)
- [PortSwigger — HTTP/2 desync research](https://portswigger.net/research/http2)
- [Trail of Bits — Connection reuse audit notes](https://blog.trailofbits.com/)
- See also: [[http-request-smuggling]], [[http2-h2-downgrade-desync-v3]], [[request-tunnelling-desync]], [[websocket-attacks]]

{% endraw %}
