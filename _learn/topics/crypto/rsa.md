---
title: RSA
slug: rsa
---

> **TL;DR:** RSA: pick primes p, q; n = pq; phi = (p-1)(q-1); choose e coprime to phi; d = e^{-1} mod phi; encrypt c = m^e mod n, decrypt m = c^d mod n — safe only with full-entropy primes, randomised padding, and e = 65537.

## What it is
RSA is the most-implemented public-key scheme. Security rests on the hardness of factoring n. Encryption and signing both reduce to modular exponentiation. In raw textbook form RSA is malleable and deterministic; real deployments must wrap it in OAEP for encryption or PSS for signatures. Every CTF challenge tagged "RSA" is broken not by factoring n but by exploiting some parameter choice — small e, shared moduli, small d, partial primes, weak padding.

## Preconditions / where it applies
- You have n, e, c — sometimes more (multiple ciphertexts, two related public keys, leaked d bits).
- n is small enough to factor (≤ ~256-512 bits for laptop trial division/Pollard; up to ~768 bits for state-level NFS).
- One of the canonical weaknesses applies — see catalog below.

## Technique
Triage in this order; each branch lives in its own note:

1. **Small n** → factor with `sympy.factorint`, `yafu`, `cado-nfs`. Then `d = e^{-1} mod (p-1)(q-1)`.
2. **Fermat factoring**: works when |p - q| is small. Try `a = ceil(sqrt(n))`; iterate `a += 1` until `a^2 - n` is a square. Common on poorly-seeded key generation.
3. **Pollard p-1**: succeeds when p-1 is B-smooth. Compute `gcd(a^{B!} - 1, n)` for small B.
4. **Williams p+1** and **ECM**: smoothness on p+1 / on a random elliptic curve respectively.
5. **Shared factor across keys** → `gcd(n1, n2)` recovers a prime instantly. Devastating for IoT/SSH host keys with weak entropy.
6. **Small e + partial knowledge** → [[rsa-coppersmith]], [[rsa-low-exponent]].
7. **Small d** (d < n^{1/4}/3) → [[rsa-wiener]].
8. **Same m, multiple keys** → Hastad broadcast, see [[rsa-low-exponent]].
9. **Same n, multiple (e_i, c_i)** → [[rsa-common-modulus]].

```python
# Once you have p, q
from Crypto.Util.number import inverse, long_to_bytes
phi = (p-1)*(q-1)
d = inverse(e, phi)
m = pow(c, d, n)
print(long_to_bytes(m))
```

```bash
RsaCtfTool -n 0x... -e 65537 --uncipher 0x...
```

CRT-RSA speed-up: precompute `dp = d mod (p-1)`, `dq = d mod (q-1)`, `qinv = q^{-1} mod p`. Implementation pitfall: a single bit flip during CRT signing reveals p via gcd (Bellcore fault attack). PKCS#1 v1.5 padding leaks via Bleichenbacher oracles ([ROBOT](https://robotattack.org/) refresh).

## Detection and defence
- Generate primes with a CSPRNG, validated for entropy at install time; reject duplicates server-side.
- Use OAEP (RSAES-OAEP) for encryption, PSS for signatures. Never RSA-PKCS1-v1.5 in new designs.
- e = 65537, key size ≥ 2048 (3072 for long-lived secrets, 4096 if perf allows). Plan migration to ML-KEM/hybrid for post-quantum.
- Constant-time CRT with countermeasures against fault injection (verify s^e ≡ m before releasing s).
- Detect padding-oracle behaviour: identical error response and timing for all decryption failures.

## References
- [PKCS#1 v2.2 — RFC 8017](https://datatracker.ietf.org/doc/html/rfc8017) — RSA encryption and signing standard.
- [RsaCtfTool](https://github.com/RsaCtfTool/RsaCtfTool) — attack catalogue automation.
- [Boneh — Twenty years of attacks on RSA](https://crypto.stanford.edu/~dabo/papers/RSA-survey.pdf) — survey of weaknesses.
