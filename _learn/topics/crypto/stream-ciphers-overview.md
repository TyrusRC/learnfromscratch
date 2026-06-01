---
title: Stream ciphers — overview
slug: stream-ciphers-overview
---

> **TL;DR:** A stream cipher generates a pseudorandom keystream from (key, nonce) and XORs it with plaintext; any keystream byte reused across messages is catastrophic, and without an authentication tag the ciphertext is fully malleable.

## What it is
Stream ciphers fall into two camps: dedicated designs (RC4, ChaCha20, Salsa20, Grain, Trivium) and block-cipher modes that produce a keystream (CTR, OFB, CFB on top of AES). The cipher's job is to produce a keystream indistinguishable from random given the key; the rest is XOR. This makes them fast and bit-aligned but also unforgiving: every weakness compounds because the plaintext is a one-XOR-away view of the keystream. Pair with a MAC (Poly1305, HMAC, GMAC) for AEAD.

## Preconditions / where it applies
- Anywhere TLS, SSH, WireGuard, IPsec, QUIC, BLE, file/disk encryption, or DRM uses a stream construction — which today is nearly everywhere.
- Misuses to watch for: nonce reuse, predictable nonces, truncated tags, no authentication, leaked keystream bytes (debug logs).

## Technique
Failure modes carry over to every stream cipher:

1. **Keystream reuse / many-time pad**: see [[many-time-pad]]. Two ciphertexts under same `(key, nonce)` XOR to `P1 XOR P2`.
2. **Malleability**: flipping bit i of the ciphertext flips bit i of the plaintext — no integrity by default. Authenticate with Poly1305/HMAC/GMAC.
3. **Predictable nonce**: deterministic counters that the attacker can replay (e.g. resetting on reboot) cause silent reuse.
4. **Truncated keystream extraction**: when a server returns the first n bytes of plaintext as an error message, treat each error response as a keystream-recovery oracle.
5. **Bias-based recovery**: see [[rc4]] for keystream-distribution attacks specific to RC4. Modern designs (ChaCha20, AES-CTR) have no known biases at full rounds.
6. **Birthday bounds**: keep `(messages × max_block_count)` well below 2^32 for 128-bit block CTR; 96-bit-nonce ChaCha20 is comfortable up to 2^32 messages per key.

Choose-the-mode quick reference:

| Construction | Authenticated? | Notes |
|---|---|---|
| AES-CTR | No | Pair with HMAC; popular in disk encryption (XTS is its own beast). |
| AES-GCM | Yes (GHASH) | 96-bit nonce; nonce reuse is catastrophic for tags too. |
| ChaCha20 | No | Pair with Poly1305 → ChaCha20-Poly1305 AEAD. |
| AES-GCM-SIV / AES-OCB | Yes, nonce-misuse-resistant | Preferred for unreliable nonce sources. |
| RC4 | No | Deprecated; see [[rc4]]. |

```python
# AES-CTR keystream generation
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
ks_chunk = Cipher(algorithms.AES(key), modes.CTR(nonce)).encryptor().update(b"\x00"*64)
```

## Detection and defence
- Always use AEAD (AES-GCM, AES-GCM-SIV, ChaCha20-Poly1305). Never raw stream XOR + separate MAC unless you really know what you're doing.
- Random 96-bit nonces are fine up to 2^32 messages per key; otherwise use a counter with deployment-wide uniqueness or XChaCha20 (192-bit nonce).
- Log and alert on duplicate `(key-id, nonce)` use in your platform. KMS-issued data keys should never re-emit identical nonces.
- Constant-time keystream generation and tag comparison to avoid timing oracles.

## References
- [RFC 8439 — ChaCha20-Poly1305](https://datatracker.ietf.org/doc/html/rfc8439) — modern AEAD spec.
- [NIST SP 800-38D — GCM](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf) — GCM mode of operation.
- [Bernstein — ChaCha](https://cr.yp.to/chacha.html) — design rationale.
