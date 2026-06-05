---
title: WebSocket state-sync bugs
slug: websocket-state-sync-bugs
aliases: [websocket-state-bugs, ws-sync-vulns]
---

{% raw %}

> **TL;DR:** WebSocket security usually focuses on origin checking and message-level auth ([[websocket-attacks]]). The under-discussed bug family is *state-sync*: server and clients share authoritative state via messages, and bugs in the sync protocol let one client mutate another's state, see another's state, or desync to bypass server checks. Common in collaborative editors, multiplayer games, real-time dashboards, Phoenix LiveView / Hotwire / Blazor Server.

## What it is
Stateful WebSocket apps maintain a server-side model that mirrors what each client sees. Clients send "intent" messages (`move-cursor`, `update-cell`, `cast-spell`), the server validates against its model, applies the change, and broadcasts the diff. Bugs cluster around:
- Trust assumption that the message references state the *sender* is allowed to mutate.
- Broadcast that includes data the recipient shouldn't see.
- Desync between client view and server truth that lets a stale client trick the server.

## Bug patterns

### 1. Channel/room authorization gap
Connection-level auth is done (user is logged in), but channel join is not gated. User joins another team's channel by guessing/leaking the channel ID, then receives broadcasts.
- See: Phoenix `channel.join`, socket.io `room`, ActionCable `subscribed` callback.
- Fix: per-channel authorize on join AND on every message (defense in depth).

### 2. Cross-channel broadcast leaking
Server broadcasts `{type: 'price-update', value: ...}` to all clients on a tier-restricted feed. Free-tier client joined a premium channel via the gap above → leaks premium data. Or: broadcast includes per-user data (`{user_balances: {user_a: ..., user_b: ...}}`) instead of just the recipient's.
- Fix: broadcast per-user filtered messages; never include cross-user data in a multi-recipient frame.

### 3. Authoritative state on client
Multiplayer game accepts `{type: 'damage-other-player', amount: 9999}` from a client. Server applies because it trusts the message origin. Classic "trusted client" anti-pattern.
- Fix: server authoritative for all gameplay-relevant state; client sends intents (button presses), server resolves them.

### 4. Desync attack
Client and server diverge. Client view shows you have 100 gold; server records 50 (you spent 50). Client now requests "buy item for 80" — server should reject (you only have 50). Bug: server validates against a stale client-supplied "current balance" field instead of its own record.
- Fix: server-side validation always against server state, never against client-supplied snapshots.

### 5. Reconnection state reuse
Client reconnects after a temporary drop. Server resumes session by restoring last-known state for that user. Attacker steals session token / reconnects from another IP → resume to victim's state.
- Fix: re-auth on reconnect; require re-establishment of context, especially for sensitive flows.

### 6. CRDT / OT injection
Collaborative editors using CRDT or OT (operational transform) take user-submitted ops and merge into shared state. Malformed ops can:
- Corrupt the doc (DoS).
- Apply ops with attacker-chosen author/timestamp (impersonation).
- Cause divergence between clients.
Yjs, Automerge, ShareDB each have CVE history — pin recent versions; validate op structure server-side; reject ops referencing entities the user can't edit.

### 7. Race condition in handler
Two messages from the same client (or different clients) arrive concurrently. Handler reads state, mutates, writes — not atomic. TOCTOU window allows double-spend, double-promote, etc. Worse than HTTP because WS handlers are often `async` in the same connection scope.
- Fix: per-resource locking, optimistic concurrency with version stamps, or queue messages per-actor for serial processing.

### 8. Phoenix LiveView / Hotwire / Blazor Server-specific
- LiveView: assigns are server-side state per socket. `phx-value-*` parameters reach handlers — must be validated. `:transport_pid` exposure can hijack sockets if logged.
- Hotwire (Rails): TurboStreams broadcast HTML diffs. Same XSS risk as HTMX swaps; same auth-per-broadcast issue.
- Blazor Server: SignalR circuit holds component state. Reconnection without auth re-check restores circuit; concurrent invocations of `InvokeAsync` can race.

### 9. Heartbeat exhaustion / no rate limit
WS connections often skip rate limiting. Send 1M `ping` or 1M small messages → DoS the broadcast loop.
- Fix: per-connection rate limit + global broadcast queue depth.

### 10. Subprotocol negotiation downgrade
Server accepts multiple subprotocols (`Sec-WebSocket-Protocol`); attacker picks the one with weakest auth (e.g., legacy "v1" protocol that doesn't require JWT in every message).
- Fix: deprecate old protocols; force latest.

## Audit workflow
1. Map every message type. For each, what state does it read/write?
2. For each message type, who is authorised to send it? Where is that check?
3. For each broadcast, who receives it? Is per-user data filtered correctly?
4. Look for "snapshot" patterns where server validates against client-supplied state.
5. Look for race windows: two handlers reading + writing the same resource without locking.
6. Audit reconnection logic for auth replay.

## References
- [Pusher / Ably / Phoenix Channels security docs](https://hexdocs.pm/phoenix/channels.html)
- [Trail of Bits — Blazor Server analysis](https://blog.trailofbits.com/)
- [Yjs / Automerge issue trackers — CRDT CVE history]
- See also: [[websocket-attacks]], [[cross-site-scripting]], [[race-conditions]]

{% endraw %}
