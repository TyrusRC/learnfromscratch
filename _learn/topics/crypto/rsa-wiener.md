---
title: RSA Wiener attack
slug: rsa-wiener
---

> **TL;DR:** When d is small relative to n, continued fractions of e/n recover d.

## What it is
Wiener (1990) showed that if the private exponent `d` is smaller than roughly `n^{1/4} / 3`, then the continued-fraction expansion of `e/n` contains a convergent `k/d` that matches the true `(k, d)` pair. Once `d` is known you can decrypt anything and (optionally) factor `n`. Boneh and Durfee (1999) extended the bound to `d < n^{0.292}` using lattice reduction, so any deployment using a small `d` to speed up decryption is fatally weak.

## Preconditions / where it applies
- RSA where `d` was chosen small (common embedded "optimisation" because CRT-style fast decryption isn't available)
- `d < n^{1/4}` for the original Wiener bound; `d < n^{0.292}` for Boneh–Durfee
- `q < p < 2q` (typical balanced primes)
- Public `(n, e)` known — that's it; no chosen messages required
- See [[rsa]], [[rsa-coppersmith]], [[public-key-basics]]

## Technique
The math: `e·d ≡ 1 (mod φ(n))`, so `e·d = k·φ(n) + 1` for some small integer `k`. Approximating `φ(n) ≈ n` (since `φ(n) = n - p - q + 1` and `p + q ≪ n`):

```
e/n ≈ k/d
```

The convergents of the continued fraction of `e/n` enumerate the best rational approximations to `e/n` in lowest terms. One of them is `k/d`. Test each convergent for the RSA equation; the right one factors `n`.

```python
from sympy import continued_fraction_iterator, Rational, isqrt

def convergents(x):
    a = []
    for ai in continued_fraction_iterator(x):
        a.append(ai)
        h = [0, 1]; k = [1, 0]
        for q in a:
            h = [h[1], q*h[1] + h[0]]
            k = [k[1], q*k[1] + k[0]]
        yield h[1], k[1]

def wiener(e, n):
    for k, d in convergents(Rational(e, n)):
        if k == 0: continue
        phi = (e*d - 1) // k
        # solve x^2 - (n - phi + 1) x + n = 0; integer roots → p, q
        s = n - phi + 1
        disc = s*s - 4*n
        if disc < 0: continue
        sq = isqrt(disc)
        if sq*sq != disc: continue
        p = (s + sq) // 2
        q = (s - sq) // 2
        if p*q == n:
            return d, p, q
    return None
```

Boneh–Durfee extension uses Coppersmith-style lattice reduction (Howgrave-Graham + LLL) on the bivariate polynomial `f(x, y) = x·(A + y) + 1`, where `A = (n + 1)/2` and the root encodes `(k, (p + q)/2)`. Implementations in Sage typically run in a few seconds for 1024-bit `n` when `d` is in the vulnerable range.

When to suspect Wiener: tiny decryption time on a constrained device, deliberately small `d` in the source, or CTF setups where `e` is anomalously close to `n` (because `e·d ≈ k·n` forces large `e` when `d` is small).

## Detection and defence
- Generate `e` first (e.g. 65537) and derive `d`; never choose a small `d` for speed
- For fast decryption, use CRT-RSA (precompute `dp = d mod (p-1)`, `dq = d mod (q-1)`) — that gives ~4× speedup without shrinking `d`
- Audit any RSA library that exposes a `small_d=True` knob; remove it
- Key generation should enforce `d > n^{0.5}` as a hard floor

## References
- [Wiener — Cryptanalysis of short RSA secret exponents (1990)](https://www.cits.rub.de/imperia/md/content/may/krypto2ss08/wiener.pdf) — original paper
- [Boneh, Durfee — Cryptanalysis of RSA with private key d less than n^{0.292} (1999)](https://crypto.stanford.edu/~dabo/papers/lowRSAexp.ps) — lattice extension
- [Boneh — Twenty Years of Attacks on RSA](https://crypto.stanford.edu/~dabo/papers/RSA-survey.pdf) — survey including Wiener
- [CTF Wiki — Wiener's attack](https://ctf-wiki.org/crypto/asymmetric/rsa/rsa_d_attack/) — worked example
