---
title: Discrete logarithms
slug: discrete-logarithms
---

> **TL;DR:** Given generator g, target h, and modulus p find x such that g^x ≡ h (mod p); generic groups are hard, but smooth group order or small x makes it tractable via Pohlig-Hellman, BSGS, or Pollard's rho.

## What it is
The discrete logarithm problem (DLP) underpins [[diffie-hellman]], DSA, ECDSA, and ElGamal. Its hardness depends on the group: in a generic cyclic group of order n, the best known algorithm is O(sqrt(n)). Subexponential algorithms (index calculus, number field sieve) apply only to prime-field multiplicative groups, not to safely-chosen elliptic curves. CTFs almost always present a deliberately weak instance.

## Preconditions / where it applies
- Multiplicative group `(Z/pZ)*` with smooth p-1 (every prime factor of p-1 is small).
- Small x range — brute force or BSGS finishes in seconds.
- Singular curves or curves of order matching p (smart attack) for ECDLP.
- Repeated DH handshakes leaking enough public values to combine via Pohlig-Hellman.

## Technique
1. **Baby-step giant-step (BSGS)** — meet-in-the-middle, O(sqrt(n)) time and memory:

```python
def bsgs(g, h, p, n):
    m = int(n**0.5) + 1
    table = {pow(g, j, p): j for j in range(m)}
    factor = pow(g, -m % (p-1), p)
    y = h
    for i in range(m):
        if y in table:
            return i*m + table[y]
        y = (y * factor) % p
```

2. **Pohlig-Hellman** — factor n = p1^e1 · p2^e2 · …; solve DLP in each prime-power subgroup with BSGS, then CRT. Works only when n is smooth. In `sage`: `discrete_log(h, g)` calls this automatically.

3. **Pollard's rho / lambda** — same complexity as BSGS but O(1) memory. Standard for ECDLP.

4. **Index calculus** — subexponential for `Z/pZ`*; not applicable to ECDLP. If `p` is small (say < 1024 bits in modern terms), this finishes.

5. **Curve-specific weaknesses**: anomalous curves (`#E(Fp) = p`) succumb to the smart attack (lift to p-adics, log via formal group). MOV reduces supersingular ECDLP to finite-field DLP via pairings.

```python
# Sage
from sage.all import GF, discrete_log
F = GF(p)
x = discrete_log(F(h), F(g))
```

## Detection and defence
- Use safe primes (`p = 2q+1`, q prime) or RFC 7919 named groups for finite-field DH.
- Use modern elliptic curves: Curve25519, P-256/P-384, secp256k1. Avoid custom curves.
- Validate received public keys: reject identity, small-order points, points off curve (invalid-curve attacks).
- Choose ephemeral keys per session to prevent long-term key compromise extending across handshakes.

## References
- [Pohlig-Hellman — Wikipedia](https://en.wikipedia.org/wiki/Pohlig%E2%80%93Hellman_algorithm) — algorithm summary.
- [SageMath discrete_log](https://doc.sagemath.org/html/en/reference/groups/sage/groups/generic.html#sage.groups.generic.discrete_log) — built-in solver.
- [CryptoHack — Diffie-Hellman](https://cryptohack.org/challenges/diffie-hellman/) — smooth-prime exercises.
