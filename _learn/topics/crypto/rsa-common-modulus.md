---
title: RSA common modulus
slug: rsa-common-modulus
---

> **TL;DR:** Same n encrypted to two coprime exponents → recover m via Bézout coefficients.

## What it is
If the same message `m` is encrypted under the same RSA modulus `n` to two different public exponents `e1` and `e2` with `gcd(e1, e2) = 1`, anyone can recover `m` from `(c1, c2)` without the private key. The attack abuses the multiplicative structure of textbook RSA plus Bézout's identity: there exist integers `u, v` such that `u·e1 + v·e2 = 1`, and therefore `c1^u · c2^v ≡ m^{u·e1+v·e2} ≡ m (mod n)`.

## Preconditions / where it applies
- Two ciphertexts of the same plaintext under the same `n`
- Two distinct, coprime public exponents `e1, e2`
- No randomised padding (textbook / PKCS#1 v1.5 encryption is vulnerable; OAEP defeats this)
- Common in CTFs and legacy multi-recipient designs where a shared modulus was a misguided "optimisation". See [[rsa]].

## Technique
The full recipe in five lines:

1. Verify `gcd(e1, e2) = 1`.
2. Run extended Euclidean to obtain `u, v` with `u·e1 + v·e2 = 1`. One of `u, v` is negative.
3. For the negative coefficient, replace `c^{-k}` by `(c^{-1} mod n)^k`. Compute the inverse with `pow(c, -1, n)`.
4. Compute `m = c1^u · c2^v mod n`.
5. Convert the integer back to bytes.

```python
from math import gcd

def egcd(a, b):
    if b == 0: return a, 1, 0
    g, x, y = egcd(b, a % b)
    return g, y, x - (a // b) * y

def common_modulus(c1, c2, e1, e2, n):
    assert gcd(e1, e2) == 1
    _, u, v = egcd(e1, e2)
    if u < 0:
        c1 = pow(c1, -1, n); u = -u
    if v < 0:
        c2 = pow(c2, -1, n); v = -v
    return pow(c1, u, n) * pow(c2, v, n) % n
```

Variants and pitfalls:

- **Shared modulus across users.** Some designs gave every user the same `n` and a unique `(e_i, d_i)`. Any user can derive any other user's private key: with `d` and `e` known, factor `n` (Miller's algorithm) and then compute any `d_i = e_i^{-1} mod φ(n)`. Never share `n`.
- **Same plaintext, different padding.** Probabilistic padding (OAEP) randomises each encryption, so the two ciphertexts encrypt **different** integers and the algebra fails. The attack only bites textbook RSA or deterministic PKCS#1 v1.5 of the same `m`.
- **Related, not identical, messages.** If `c1 = (a·m + b)^{e1}` and `c2 = (a·m + b)^{e2} mod n` are linearly related, Franklin–Reiter generalises the attack via polynomial GCD.

Related techniques: [[rsa-low-exponent]] (Håstad on different moduli), [[rsa-wiener]] (small `d`), [[rsa-coppersmith]] (small root recovery).

## Detection and defence
- Never share an RSA modulus across users or services; generate a fresh keypair per identity
- Always use randomised padding (RSA-OAEP) for encryption and RSA-PSS for signatures
- Code review for static `n` constants reused across configuration profiles
- If you discover a shared-modulus deployment in the wild, treat it as a full compromise of all parties on that modulus

## References
- [Boneh — Twenty Years of Attacks on the RSA Cryptosystem](https://crypto.stanford.edu/~dabo/papers/RSA-survey.pdf) — covers common-modulus and Franklin–Reiter
- [HackTricks — RSA common modulus](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — exploitation summary
- [CTF Wiki — Common Modulus Attack](https://ctf-wiki.org/crypto/asymmetric/rsa/rsa_common_mod_attack/) — worked example
- [Stanford CS255 — RSA pitfalls](https://crypto.stanford.edu/~dabo/courses/cs255_winter12/) — lecture notes
