---
title: Diffie–Hellman
slug: diffie-hellman
---

> **TL;DR:** Key agreement over discrete log. Weak parameter / small subgroup attacks recover the shared secret.

## What it is
Diffie–Hellman (DH) lets two parties agree on a shared secret over a public channel. Alice picks `a`, sends `A = g^a mod p`. Bob picks `b`, sends `B = g^b mod p`. Both compute `s = g^{ab} mod p`. Security rests on the hardness of the [[discrete-logarithms]] problem in the chosen group. Elliptic-curve DH (ECDH, X25519) is the modern variant using point multiplication instead of modular exponentiation.

## Preconditions / where it applies
- Wherever a key is negotiated: TLS, SSH, IPsec/IKE, Signal, WireGuard, JWE ECDH-ES
- Audit targets: custom protocols using `pow(g, x, p)` with home-rolled primes; legacy SSL exporting 512-bit DH (Logjam); IoT firmwares with hardcoded small `p`

## Technique
Attacks fall into a few families:

- **Small subgroup / invalid curve.** If `p` is chosen carelessly, `g` may have small order or the group order `p-1` has many small factors. Send `A' = g_smallorder` so the victim computes the shared secret in a tiny subgroup; brute-force the result and recover `b mod q` for small `q`. Combine with Pohlig–Hellman across factors of `p-1` to lift the full private key.
- **Logjam / weak primes.** A 512-bit safe prime can be pre-broken with the number field sieve in days. Once the precomputation is done, online discrete logs in that group take minutes. Forces downgraded DHE_EXPORT ciphersuites.
- **Triangle / no-authentication MITM.** Plain DH provides no identity binding. An active attacker terminates one DH with each side and proxies traffic. TLS, SSH, IPsec all bind the DH transcript with a signature or PSK to prevent this.
- **Static-static ECDH key reuse.** Same private key across sessions, no random ephemeral — enables invalid-curve attacks (Jager et al.) and key-compromise impersonation. X25519 mitigates by clamping and twist-secure curves.
- **Bad randomness.** PRNG flaws in `a` collapse to known shared secret; see [[linear-congruential-generator]].

Sage snippet for Pohlig–Hellman over a smooth-order group:

```python
# p chosen so p-1 = q1*q2*...*qn with small qi
# given A = g^a mod p, recover a mod each qi then CRT
from sympy.ntheory.residue_ntheory import discrete_log
factors = [q1, q2, q3]   # small prime factors of p-1
residues = []
for q in factors:
    h = pow(A, (p-1)//q, p)
    gq = pow(g, (p-1)//q, p)
    residues.append(discrete_log(p, h, gq))
```

Practical primer: always use a named safe group (RFC 7919 ffdhe2048+, or X25519/X448) and ephemeral keys.

## Detection and defence
- Inventory all crypto libraries to ensure DH key sizes ≥ 2048 bits (finite-field) or use X25519/X448 (curves)
- Verify peer public keys belong to the correct subgroup; reject `A = 0, 1, p-1` and points off the curve
- Bind the DH exchange to authentication (TLS Finished, SSH host key signature, IPsec PSK/cert)
- Detect downgrade with TLS-level monitoring; alert on `DHE_EXPORT` or 1024-bit groups

## References
- [Logjam — Adrian et al. (2015)](https://weakdh.org/imperfect-forward-secrecy-ccs15.pdf) — weak DH parameters in TLS
- [Jager et al. — Practical Invalid Curve Attacks on TLS-ECDH](https://www.nds.rub.de/research/publications/ESORICS2015/) — small subgroup on ECDH
- [RFC 7919](https://www.rfc-editor.org/rfc/rfc7919) — Named FFDHE groups
- [HackTricks — Diffie–Hellman](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — common pitfalls
