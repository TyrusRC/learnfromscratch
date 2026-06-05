---
title: Lattice attacks for crypto CTF
slug: lattice-attacks-crypto-ctf
aliases: [lattice-attacks, lll-attacks, coppersmith]
---

{% raw %}

> **TL;DR:** Lattice-based attacks recover secrets from partial information using LLL / BKZ to find short vectors in lattices encoding the relationship between known and unknown values. Classic targets in CTF: (1) RSA with known partial bits (Coppersmith), (2) ECDSA / DSA with biased nonces, (3) approximate-GCD problems, (4) hidden number problem (HNP), (5) NTRU-shaped problems, (6) implicit factoring (Coron-May). Companion to [[rsa-fault-attacks]] and crypto/ existing notes.

## What a lattice is, in 60 seconds

A lattice is the set of all integer linear combinations of basis vectors. Given a "bad" basis (long vectors, far from orthogonal), LLL finds a "good" basis (short, more orthogonal). Many crypto problems can be encoded so that the secret is the shortest vector.

Library reflex:
- **SageMath** — has LLL/BKZ built in.
- **fpylll** — Python bindings to fplll (faster than Sage's).
- **PARI/GP** — alternative.
- **sympy** — symbolic; not lattice-specific but useful in setup.

## Pattern 1 — Coppersmith on RSA

Coppersmith's theorem: if you know enough bits of a small root of a polynomial mod N, you can recover it.

Common CTF scenarios:
- Known **high or low bits of p** (factor of N) → factor N.
- Known **high bits of m** (plaintext) with small e (typically e=3) → recover m.
- **Stereotyped message** (only K low bits unknown) and small e → solve.

Sage one-liner:
```python
from sage.all import *
N = ...
high_bits_of_p = ...
ks = 2**500
P.<x> = PolynomialRing(Zmod(N))
f = high_bits_of_p + x
root = f.small_roots(X=ks, beta=0.5)[0]
p = int(high_bits_of_p + root)
q = N // p
```

## Pattern 2 — DSA / ECDSA nonce bias (Hidden Number Problem)

ECDSA needs a random nonce `k` per signature. If `k` is biased (short, sequential, predictable), several signatures form a HNP that lattice attacks solve.

Setup: given multiple signatures `(r_i, s_i)` and their messages `m_i`, build a lattice whose shortest vector contains the private key.

CTF-specific: the challenge typically says "k is < 2^200" (truncated). With ~10-20 such signatures, LLL recovers the key.

Reference: `crypto-attacks/attacks/ecdsa/lattice_attack.sage`.

## Pattern 3 — LSB-only known plaintext RSA

Knowing only the low bits of `m` is harder than high bits. Use Coppersmith univariate; same code shape with `beta=0.5` and the polynomial reshaped.

## Pattern 4 — Common modulus / shared primes

Two RSA keys share a prime → `gcd(N_1, N_2)` reveals it.

Not strictly a lattice attack but pairs with lattice work when you have a corpus of keys:
```python
from math import gcd
for i in range(len(keys)):
    for j in range(i+1, len(keys)):
        g = gcd(keys[i].n, keys[j].n)
        if g > 1: print("shared prime!", g)
```

The Heninger-Halderman paper showed ~0.5% of TLS RSA keys had shared primes.

## Pattern 5 — Multiple modulus with known low bits of p

If multiple Ns are known and you suspect they share low bits of p (firmware-generated keys with low-entropy PRNG), lattice attacks (implicit factoring) can recover.

## Pattern 6 — NTRU-style

Some challenges hand you a lattice problem directly: "find a short vector in this basis". LLL with parameters tuned for the dimension; if LLL fails, BKZ with block size up to ~40.

```python
B = Matrix(ZZ, [...])
L = B.LLL()
print(L[0])      # often the secret
```

## Pattern 7 — RSA-CRT signatures with fault

Combined with [[rsa-fault-attacks]]. Bellcore-style fault on one component → `p = gcd(s - s', N)` recovers a factor.

## Pattern 8 — partial private key disclosure

Sometimes a CTF leaks high bits of d (private exponent). Boneh-Durfee attack uses lattice methods to recover d when `d < N^0.292`.

## Tools

- [crypto-attacks](https://github.com/jvdsn/crypto-attacks) — collection of SageMath scripts for many of the above.
- [defund/coppersmith](https://github.com/defund/coppersmith) — Coppersmith multivariate.
- [Inria flatter](https://github.com/keeganryan/flatter) — fast lattice reduction.
- [sage-cells](https://sagecell.sagemath.org/) — try snippets without local install.

## Workflow for a lattice CTF

1. **Read the challenge.** What's known, what's unknown.
2. **Compute information-theoretic feasibility.** If the unknown is 256 bits with no constraints, you can't recover.
3. **Identify the structure.** Polynomial relation? Linear equation with bounded error? Modular equation with small unknowns?
4. **Encode as a lattice.** Use known templates.
5. **Run LLL / BKZ.** Increase block size if first attempt fails.
6. **Verify.** The recovered short vector should yield a valid decryption.

## Common gotchas

- Bounds in Coppersmith are theoretical maximums; practical bounds are smaller.
- LLL produces *a* short vector; the secret may be the 2nd, 3rd; check several.
- `epsilon` in Coppersmith trades runtime for tightness; tune.
- Multivariate Coppersmith via Coron-May / Herrmann-May requires more setup.

## OSCP/OSEP/OSWE relevance

None — CTF-only.

## References
- [Coppersmith — "Finding Small Roots of Bivariate Integer Equations"](https://link.springer.com/) (search)
- [Boneh-Durfee 1999 — small private key attack](https://crypto.stanford.edu/~dabo/abstracts/SSSecret.html)
- [Joachim von zur Gathen — Modern Computer Algebra](https://mca.book.org/)
- [SageMath documentation](https://doc.sagemath.org/)
- [crypto-attacks repository](https://github.com/jvdsn/crypto-attacks)
- See also: [[applied-crypto]], [[rsa-attacks]] (if exists in your crypto/ tree)

{% endraw %}
