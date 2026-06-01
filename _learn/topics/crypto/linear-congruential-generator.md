---
title: LCG (Linear Congruential Generator)
slug: linear-congruential-generator
---

> **TL;DR:** `x_{n+1} = a·x_n + c mod m` is fully linear, so a handful of consecutive outputs plus basic modular algebra recovers the parameters and lets you predict (or rewind) the stream — never use an LCG for anything security-adjacent.

## What it is
A linear congruential generator is a stateful PRNG with three parameters (multiplier `a`, increment `c`, modulus `m`) and seed `x_0`. Each call returns `x_{n+1} = a·x_n + c mod m`. It is fast and ubiquitous in legacy languages and games (Java `Random`, glibc `rand`, MS Visual C `rand`, many CTF challenges). Because every step is affine over Z/mZ, knowledge of a few consecutive states gives a linear system the attacker can solve in closed form.

## Preconditions / where it applies
- Target reveals raw or partial PRNG outputs: tokens, session IDs, "random" coupon codes, game RNG.
- Output is consecutive (or attacker knows the gap between samples).
- `m` is known or guessable (often a power of two, or a published constant).
- Even if the program returns only the top bits per output (truncated LCG), Stern's lattice attack still recovers the state.

## Technique
**Case 1 — `m` known, full outputs, `a` and `c` unknown.** Two equations from three samples:

```
x2 - x1 = a(x1 - x0) mod m
x3 - x2 = a(x2 - x1) mod m
=>  a = (x2 - x1) * (x1 - x0)^{-1} mod m
    c = x1 - a*x0 mod m
```

```python
from sympy import mod_inverse
a = ((x2 - x1) * mod_inverse(x1 - x0, m)) % m
c = (x1 - a*x0) % m
```

**Case 2 — `m` unknown.** Build candidate moduli from differences: `t_n = x_{n+1} - x_n`; then `T_n = t_{n+1}·t_{n-1} - t_n^2` is a multiple of `m`. GCD several `T_n` to recover `m`, then fall back to Case 1.

**Case 3 — truncated LCG (only top k bits per output).** Use lattice reduction (LLL) on the system relating consecutive truncated outputs. Sage's `LLL()` solves typical 32-bit-truncated 64-bit LCGs in seconds.

**Java `Random` specifics**: 48-bit state, `nextInt(n)` reveals top 32 bits → recover state from two consecutive `nextInt` outputs by brute-forcing the 16 missing low bits.

```python
# Java Random state recovery from two consecutive nextInt() outputs
MASK = (1<<48) - 1
A, C = 0x5DEECE66D, 0xB
for low in range(1<<16):
    seed = ((out1 << 16) | low) & MASK
    seed = (seed * A + C) & MASK
    if (seed >> 16) == out2:
        print(hex(seed)); break
```

## Detection and defence
- Never use LCG output for secrets. Use a CSPRNG: `/dev/urandom`, `getrandom(2)`, `secrets` (Python), `crypto.randomBytes` (Node), `RandomNumberGenerator` (Java `SecureRandom`).
- Audit code for `rand()`, `Math.random()`, `java.util.Random`, `mt_rand()` (PHP) being used in security paths — replace with the corresponding secure call.
- Even hashed LCG output is unsafe — the hash hides outputs but doesn't change predictability once the state is recovered.

## References
- [L'Ecuyer & Simard — TestU01](https://simul.iro.umontreal.ca/testu01/tu01.html) — empirical PRNG quality tests.
- [CryptoHack — RNG](https://cryptohack.org/challenges/rng/) — guided LCG breakage challenges.
- [Reversing Java's Random — Frans Rosen](https://franklinta.com/2014/08/31/predicting-the-next-math-random-in-java/) — Java `Random` state recovery write-up.
