---
title: RSA Coppersmith
slug: rsa-coppersmith
---

> **TL;DR:** Coppersmith's method uses LLL lattice reduction to find small integer roots of a polynomial mod N — turning partial knowledge (top bits of p, low bits of m, related messages) into a full RSA break.

## What it is
Coppersmith proved that for a monic polynomial f(x) of degree d mod N, all integer roots x with |x| < N^(1/d) can be found in polynomial time via lattice reduction. The Howgrave-Graham reformulation makes it constructive: build a lattice whose short vectors correspond to polynomials with the same small roots over the integers, run LLL, factor the recovered polynomial classically. The result powers most "partial-information" attacks on RSA.

## Preconditions / where it applies
- You know roughly half of p (the high bits) for a 1024-bit modulus, or 70% of a 2048-bit p — factor N.
- Public exponent e is small (3, 5, 7, 17) and you know all but a small portion of the plaintext or have multiple related ciphertexts ([[rsa-low-exponent]], Hastad broadcast).
- You see two ciphertexts of related plaintexts (m and m + a) under the same key (Franklin-Reiter).
- Bleichenbacher-style padding leaks combined with low e (small unknown padding).

## Technique
**Stereotyped messages (Coppersmith short-pad)**: known prefix `P`, unknown suffix `x` of length `k < N^(1/e)/e` bytes. Set f(x) = (P·B + x)^e - c mod N where B = 2^(8·suffix_len). Find root x.

```python
# Sage
N, e, c = ..., 3, ...
P = b"flag{" + b"\x00"*16
B = 1 << (8*16)
PR.<x> = PolynomialRing(Zmod(N))
f = (Integer.from_bytes(P, 'big') + x)^e - c
f = f.monic()
m_suffix = f.small_roots(X=B, beta=1.0)[0]
```

**Factoring with high-bits-of-p known**: let `p_high` be the known top half of p; the unknown low part `x0` satisfies `(p_high + x0) | N` with |x0| < N^(1/4). Use:

```python
PR.<x> = PolynomialRing(Zmod(N))
f = p_high + x
x0 = f.small_roots(X=2^512, beta=0.5)[0]
p = p_high + x0; q = N // p
```

**Franklin-Reiter related messages**: c1 = m^e, c2 = (m+a)^e mod N with small e. The polynomials f1(x) = x^e - c1 and f2(x) = (x+a)^e - c2 share root m; their GCD over Z/NZ is the linear factor `x - m`.

**Hastad broadcast**: same m sent to e recipients with small e and coprime moduli → CRT recovers m^e over Z, take e-th root. Practical when e ≤ small (3, 5).

Tooling: Sage's `small_roots`, [defund/coppersmith](https://github.com/defund/coppersmith), [RsaCtfTool](https://github.com/RsaCtfTool/RsaCtfTool) which wraps multiple variants.

## Detection and defence
- Use e = 65537 with OAEP padding (or RSA-PSS for signatures). Random padding kills stereotyped-message attacks.
- Generate p, q with full entropy and a fresh CSPRNG; never log, hash, or partially expose primes.
- Don't sign/encrypt structurally related messages without randomised padding.
- Where lattice attacks matter (post-quantum era considerations), migrate to ECC or PQ KEMs (ML-KEM/Kyber).

## References
- [Coppersmith — Small solutions to polynomial equations and low exponent RSA](https://link.springer.com/chapter/10.1007/3-540-68697-5_13) — original paper.
- [Howgrave-Graham — Finding small roots of univariate modular equations revisited](https://link.springer.com/chapter/10.1007/BFb0024458) — practical reformulation.
- [defund/coppersmith](https://github.com/defund/coppersmith) — Sage helpers for multivariate cases.
