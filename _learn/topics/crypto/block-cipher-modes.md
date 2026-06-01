---
title: Block cipher modes (ECB / CBC / CTR / GCM)
slug: block-cipher-modes
---

> **TL;DR:** Modes glue a block cipher to arbitrary-length data. Mode choice changes everything about attack surface.

## What it is
A block cipher like [[aes]] only transforms a fixed-size block (16 bytes). A mode of operation describes how plaintext is split, padded, chained, or XORed with counters to encrypt arbitrary lengths and (optionally) authenticate. The choice determines whether identical plaintext leaks, whether ciphertext is malleable, and whether tampering is detected.

## Preconditions / where it applies
- Any place a symmetric cipher is used: TLS records, JWE, cookies, session tokens, file/disk encryption, message queues
- Audit hits when keys are reused, IVs/nonces are static or predictable, or no MAC is attached
- Particularly relevant against home-grown cookie/state crypto on web apps

## Technique
Pick the mode that matches the bug:

- **ECB** — `C_i = E_k(P_i)`. Deterministic per block, no IV. Equal blocks → equal ciphertext. Visual giveaway: encrypting a bitmap shows the silhouette. Enables byte-at-a-time recovery, see [[ecb-attacks]].
- **CBC** — `C_i = E_k(P_i XOR C_{i-1})`, `C_0 = IV`. Decryption: `P_i = D_k(C_i) XOR C_{i-1}`. Flipping a bit in `C_{i-1}` flips the same bit in `P_i` (and scrambles block `i-1`) — basis of [[cbc-bit-flipping]] and the [[cbc-padding-oracle]]. Predictable IVs broke TLS 1.0 (BEAST).
- **CTR** — `C_i = P_i XOR E_k(nonce || counter)`. Stream cipher built from a block cipher. Nonce reuse with the same key destroys confidentiality and forgery resistance — XOR two ciphertexts and you get plaintext XOR plaintext (see [[many-time-pad]]).
- **GCM** — CTR plus a GHASH MAC over AAD and ciphertext, producing an authentication tag. Nonce reuse is catastrophic: attackers recover the GHASH authentication key `H` and can forge arbitrary messages. Tag truncation below 96 bits weakens forgery resistance.

Quick visual ECB detector:

```python
def looks_like_ecb(ct, block=16):
    blocks = [ct[i:i+block] for i in range(0, len(ct), block)]
    return len(blocks) != len(set(blocks))
```

Operational rules of thumb:

- Never ship raw ECB.
- CBC needs a random unpredictable IV per message **and** a separate MAC (encrypt-then-MAC), otherwise expect padding-oracle / bit-flip bugs.
- CTR/GCM need a unique nonce per `(key, message)`. With 96-bit random nonces, rekey before ~2^32 messages.
- Prefer AEAD (GCM, ChaCha20-Poly1305, AES-GCM-SIV) over unauthenticated modes.

## Detection and defence
- Code review for `ECB`, `NoPadding`, hardcoded IVs (`new byte[16]`), or IVs derived from message counters/timestamps
- Log nonce values server-side; alert on duplicates per key
- Enforce AEAD via library wrappers (libsodium `crypto_secretbox`, Tink, AWS Encryption SDK) so callers cannot pick a bad mode
- For storage, prefer misuse-resistant modes (AES-GCM-SIV) when nonce uniqueness is hard to guarantee

## References
- [NIST SP 800-38A](https://csrc.nist.gov/publications/detail/sp/800-38a/final) — formal definitions of ECB/CBC/CTR
- [NIST SP 800-38D](https://csrc.nist.gov/publications/detail/sp/800-38d/final) — GCM specification
- [Joux — Authentication failures in NIST version of GCM](https://csrc.nist.gov/csrc/media/projects/block-cipher-techniques/documents/bcm/comments/800-38-series-drafts/gcm/joux_comments.pdf) — nonce reuse forgery
- [HackTricks — Cipher block chaining](https://book.hacktricks.wiki/en/crypto-and-stego/cipher-block-chaining-cbc-mac-priv.html) — practical attack notes
