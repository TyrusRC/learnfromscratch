---
title: Linear mapping ciphers
slug: linear-mapping-ciphers
---

> **TL;DR:** Affine cipher and friends — y = ax + b mod n; small keyspace makes brute force trivial.

## What it is
Linear mapping ciphers encrypt a symbol by an affine transformation modulo the alphabet size: `E(x) = a·x + b mod n` with `gcd(a, n) = 1` so the map is a bijection. The Caesar cipher is the special case `a = 1`. The Hill cipher generalises to vectors: `E(x⃗) = A·x⃗ + b⃗ mod n` with `A` an invertible matrix over `Z_n`. All of these share the fatal property of being linear, which collapses the cryptanalysis to a small linear system.

## Preconditions / where it applies
- CTF challenges, intro crypto exercises
- Legacy/embedded "scrambling" of identifiers (loyalty card codes, voucher serials) where someone wanted obfuscation, not security
- Foundation for understanding why modern ciphers need non-linearity (S-boxes)
- See also [[shift-ciphers]] and [[fixed-substitution-ciphers]]

## Technique

**Affine cipher (n = 26).** Valid `a` values are coprime with 26: `{1,3,5,7,9,11,15,17,19,21,23,25}` — 12 in total. Combined with 26 shifts: 312 keys. Brute-force and rank candidates by English quadgram score.

```python
from math import gcd
def affine_decrypt(ct, a, b, n=26):
    a_inv = pow(a, -1, n)
    return "".join(chr((a_inv * ((ord(c)-65) - b)) % n + 65) for c in ct)

candidates = []
for a in range(1, 26):
    if gcd(a, 26) != 1: continue
    for b in range(26):
        candidates.append((score(affine_decrypt(ct, a, b)), a, b))
candidates.sort(reverse=True)
```

**Known-plaintext break (1 query).** Two plaintext/ciphertext pairs solve `a, b`:

```
c1 = a·p1 + b   (mod n)
c2 = a·p2 + b   (mod n)
a = (c1 - c2) · (p1 - p2)^{-1}   mod n
b = c1 - a·p1                     mod n
```

`(p1 - p2)` must be invertible mod `n`. With three pairs you can always solve.

**Hill cipher.** Encrypt blocks of `k` symbols as a vector multiplied by a `k×k` matrix `A`. Known-plaintext: stack `k` plaintext vectors as columns of `P`, the matching ciphertext vectors as columns of `C`, then `A = C · P^{-1} mod n`. Requires `P` invertible over `Z_n` (rare but checkable). Ciphertext-only attacks rely on frequency analysis of block-bigrams plus hill-climbing.

**Bigram (Hill on 2-vectors).** Solve a 2×2 system from any two known plaintext-ciphertext digram pairs; algebra is identical.

Linear ciphers fail because the key is recovered from a constant-size linear system once you know any vectors. Adding modular reduction does not change this — the map is invertible exactly when the leading coefficient/matrix is.

## Detection and defence
- Length-preserving cipher where shifting plaintext by a constant produces a constant shift in ciphertext (modulo `a`) is a giveaway
- Do not use linear maps for confidentiality; they are obfuscation at best
- For learning purposes, follow with a study of non-linear S-boxes (see [[aes]]) to understand why modern designs include a non-linear layer

## References
- [Practical Cryptography — Affine cipher](https://practicalcryptography.com/ciphers/affine-cipher/) — formulae and cryptanalysis
- [Practical Cryptography — Hill cipher](https://practicalcryptography.com/ciphers/hill-cipher/) — matrix-based linear cipher
- [HackTricks — Cryptographic algorithms](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — recognition cues
- [Singh — The Code Book](https://simonsingh.net/books/the-code-book/) — historical linear ciphers
