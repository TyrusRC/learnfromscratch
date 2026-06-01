---
title: Race conditions (web)
slug: race-conditions
---

> **TL;DR:** Fire many concurrent requests that share a single in-flight check, forcing duplicate side-effects — extra refunds, second redemptions, bypassed limits.

## What it is
The classic time-of-check / time-of-use race in a web context. A handler reads state ("does this coupon still have uses left?"), performs an action ("apply discount and decrement counter"), and writes the new state — but a second request between the read and the write sees the same stale state. PortSwigger's "single-packet attack" exploits TCP/HTTP-2 framing to deliver many requests with effectively zero skew between them.

## Preconditions / where it applies
- A workflow step that reads, decides, and writes without a per-row lock or atomic operation.
- An endpoint reachable by the attacker with the auth state required to trigger the step.
- Typical sinks: coupon / gift-card redemption, withdrawal / transfer, MFA backup-code consumption, account confirmation, friend invites, "first-N-only" promotions, voting.

## Technique
1. **Identify the candidate.** A request whose response says "you've already done this" on the second try, where the second-try check is the only thing stopping abuse.
2. **Single-packet attack.** Use Burp Repeater's "Send group in parallel (single-packet attack)" or Turbo Intruder's `engine=Engine.BURP2` / `concurrentConnections=1` with HTTP/2 frames. Send 20-50 copies of the same request batched into one TLS record so they all hit the back-end inside the same scheduler tick.

   ```python
   # Turbo Intruder sketch
   def queueRequests(target, wordlists):
       engine = RequestEngine(endpoint=target.endpoint, concurrentConnections=1,
                              engine=Engine.BURP2)
       for _ in range(30):
           engine.queue(target.req)
   ```

3. **Look for the side effect.** Balance went up twice, coupon used 5×, two sessions both got the "first" reward. Diff DB state if you have logs.
4. **Stateful races across steps.** "Limit-overrun" patterns — registration that allows one account per email but checks email after creating a partial row. Fire 20 registers with the same email; some succeed.
5. **Connection warming.** For HTTP/1.1 stacks, pre-send a long header then withhold the last byte across N connections, release simultaneously (last-byte sync). For HTTP/2, use the single-packet technique.
6. **Combine with [[idor]] / [[application-logic-flaws]].** The race is often the missing link that turns a small inconsistency into a real-money bug.

## Detection and defence
- Make the critical section atomic at the database: `UPDATE coupons SET uses=uses-1 WHERE id=? AND uses>0` and check `rowcount`; or `SELECT ... FOR UPDATE` inside a transaction with proper isolation.
- For distributed state, use a per-resource lock (Redis `SET NX PX`, distributed mutex) keyed to the object id.
- Application-level idempotency keys for state-changing endpoints; reject duplicates by key.
- Detection: count of successful sensitive actions per user per second; anomalous `rowcount=0` after the action; flame-graphs showing collisions on a row.

## References
- [PortSwigger — Smashing the state machine](https://portswigger.net/research/smashing-the-state-machine) — single-packet attack paper.
- [PortSwigger — Race conditions](https://portswigger.net/web-security/race-conditions) — labs.
- [Turbo Intruder](https://github.com/PortSwigger/turbo-intruder) — single-packet attack tooling.
