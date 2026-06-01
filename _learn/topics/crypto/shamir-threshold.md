---
title: Shamir secret sharing
slug: shamir-threshold
---

> **TL;DR:** Encode a secret S as the constant term of a random degree-(k-1) polynomial over a finite field, hand out n points on it as shares; any k shares reconstruct S via Lagrange interpolation, any k-1 reveal nothing.

## What it is
Shamir's (k, n)-threshold scheme is information-theoretically secure: with fewer than k shares the secret is uniformly distributed over the field. Operations happen in a prime field GF(p) or GF(2^m). It is the dominant primitive in HSM key escrow, cryptocurrency cold storage, and certificate-authority root key custody. CTFs use it to gate flags behind sharing puzzles, sometimes with subtle bugs that make k-1 shares enough.

## Preconditions / where it applies
- The dealer chooses a prime p > S and p > n; defines `f(x) = S + a_1·x + ... + a_{k-1}·x^{k-1} mod p`.
- Each share is `(x_i, f(x_i))` with `x_i != 0`, distinct across participants.
- Reconstruction uses any k shares to recover f(0) = S.
- Attack surface: weak coefficients (low entropy), reused polynomials across secrets, missing index integrity (substitution), small p (brute force), missing verifiable property.

## Technique
**Reconstruction (Lagrange interpolation at x = 0)**:

```python
def lagrange_at_zero(shares, p):
    s = 0
    for j, (xj, yj) in enumerate(shares):
        num, den = 1, 1
        for m, (xm, _) in enumerate(shares):
            if m == j: continue
            num = (num * -xm) % p
            den = (den * (xj - xm)) % p
        s = (s + yj * num * pow(den, -1, p)) % p
    return s
```

**CTF-flavoured weaknesses**:

- **Small field**: if `p < 2^64`, with k-1 shares you can brute-force the missing share value (`p` candidates) and detect the right one by structure (printable flag, magic bytes).
- **Reused polynomial across two secrets**: dealer reused `f(x)` to share two different "secrets" by changing `a_0`. With both share sets, subtract pairwise → recover the polynomial difference, hence both secrets.
- **No verification**: a malicious participant submits a forged share `(x_i, y_i')`. Lagrange happily interpolates a wrong S. Defence: Feldman or Pedersen verifiable secret sharing (publish commitments `g^{a_j}`).
- **Berlekamp-Welch decoding**: with `n` shares and up to `e` wrong ones, recover the right polynomial if `n >= k + 2e` — useful when you suspect some shares are corrupted.

```bash
# ssss-split / ssss-combine — classic CLI
ssss-split -t 3 -n 5 -s 256
ssss-combine -t 3
```

Real-world deployments: AWS KMS custom key store, HashiCorp Vault auto-unseal recovery keys, Bitcoin multisig wallets (similar idea, different primitives).

## Detection and defence
- Use a well-reviewed library (`pyshamir`, libsodium-friendly forks); never roll your own field arithmetic.
- Verifiable secret sharing (Feldman/Pedersen) prevents share substitution and dealer cheating.
- Generate coefficients with CSPRNG; never reuse polynomials.
- For long-lived secrets, refresh shares periodically (proactive secret sharing) so old leaked shares expire.
- Audit reconstruction code for constant-time field inversion to avoid timing leaks of share values.

## References
- [Shamir 1979 — How to share a secret](https://dl.acm.org/doi/10.1145/359168.359176) — the original paper.
- [Feldman VSS](https://www.cs.umd.edu/~gasarch/TOPICS/secretsharing/feldmanVSS.pdf) — verifiable variant.
- [ssss](https://point-at-infinity.org/ssss/) — reference CLI implementation.
