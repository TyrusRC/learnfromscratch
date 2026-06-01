---
title: Many-time pad / keystream reuse
slug: many-time-pad
---

> **TL;DR:** When two ciphertexts share the same keystream, `C1 XOR C2 = P1 XOR P2` — drag English (or known-format) cribs along that XOR to recover both plaintexts without ever touching the key.

## What it is
A one-time pad is unconditionally secure only if the keystream is used once. Reusing it across multiple messages collapses the security: any pair of same-keystream ciphertexts XORs to the XOR of their plaintexts, which carries enormous statistical structure (English digrams, JSON braces, HTTP headers). This is the practical impact of nonce reuse in [[stream-ciphers-overview]] (CTR, ChaCha20), repeated IVs in AES-GCM (catastrophic — also leaks the authentication subkey H), and the historic VENONA break of reused Soviet pad pages.

## Preconditions / where it applies
- Two or more ciphertexts encrypted under the same `(key, nonce)` in CTR/GCM, the same IV in OFB, or the same RC4 key (see [[rc4]]).
- Plaintexts share language structure or partial known content (HTTP `GET /`, JSON `{"`, mail headers, file magic).
- More ciphertexts → easier: with N ciphertexts every column has N(N-1)/2 XOR samples.

## Technique
1. Align ciphertexts by offset 0 (or by known structural markers).
2. For each column position, XOR every pair of ciphertext bytes. Columns where the XOR consistently lands in printable ASCII (`0x20`-`0x7e`) suggest both plaintexts are text.
3. Crib drag: slide a guessed word `crib` (e.g. `" the "`) across the XOR of two ciphertexts. Where `C1 XOR C2 XOR crib` yields plausible English in the same window, the crib is in one of the messages.
4. Extend: once one plaintext byte is recovered, XOR with the ciphertext to extract a keystream byte; that keystream byte decrypts the same column in every other ciphertext.
5. Iterate until full plaintexts emerge. Tools: `cribdrag`, `xortool` (works against repeating-key XOR too).

```python
def crib_drag(c1, c2, crib):
    xor = bytes(a ^ b for a, b in zip(c1, c2))
    for i in range(len(xor) - len(crib) + 1):
        window = bytes(x ^ c for x, c in zip(xor[i:i+len(crib)], crib))
        if all(32 <= b < 127 for b in window):
            print(i, window)
```

```bash
xortool -c 20 -l 12 ciphertext.bin   # guess key length and most-common-byte
```

GCM-specific bonus: with two ciphertexts under the same nonce, recover `H = E_K(0^128)` by solving the polynomial equation in `H` from the two tag/ciphertext pairs — then forge new authenticated messages at will (Joux / forbidden attack).

## Detection and defence
- Always use a fresh, unique nonce per message under any stream/CTR/GCM construction. Random 96-bit nonces are safe up to 2^32 messages; deterministic counters are safer.
- For AES-GCM specifically, switch to AES-GCM-SIV or ChaCha20-Poly1305 when reuse risk exists.
- Detect operationally: telemetry alerts on duplicate (key-id, nonce) tuples; SIEM rules flagging two ciphertexts whose XOR has low entropy.
- Never compress before encrypting if attackers can mix chosen and secret data (CRIME-style side channel amplifies any reuse).

## References
- [CryptoPals Set 3 Challenge 19/20](https://cryptopals.com/sets/3/challenges/19) — many-time-pad cribbing exercise.
- [Joux — Forbidden attack on GCM](https://csrc.nist.gov/csrc/media/projects/block-cipher-techniques/documents/bcm/joux_comments.pdf) — nonce-reuse tag forgery.
- [xortool](https://github.com/hellman/xortool) — repeating-key XOR breaker.
