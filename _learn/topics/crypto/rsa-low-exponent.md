---
title: RSA low public exponent
slug: rsa-low-exponent
---

> **TL;DR:** If m^e < n, decryption is just integer e-th root; the Håstad broadcast attack generalises across e recipients.

## What it is
RSA encryption is `c = m^e mod n`. When the public exponent `e` is small (3, 5, 17) and the message is small or unpadded, the modular reduction never fires — `m^e` itself fits below `n`, so recovering `m` is just an integer `e`-th root, computable directly with Newton's method or `gmpy2.iroot`. Håstad's broadcast attack generalises: if the same plaintext is encrypted with the same small `e` to `e` different recipients (different moduli), CRT plus an integer root recovers `m`.

## Preconditions / where it applies
- Textbook RSA or PKCS#1 v1.5 encryption without OAEP
- Small `e`, especially `e = 3`, still common in legacy embedded code
- Either a small message (`m^e < n`) or `e` different ciphertexts of the same `m` under coprime moduli
- Variants: stereotyped messages (use [[rsa-coppersmith]]) and related-message attacks (Franklin–Reiter)
- See [[rsa]] for the core algorithm

## Technique

**Plain low-`e` root.** If `m < n^{1/e}`:

```python
from gmpy2 import iroot
m, exact = iroot(c, e)   # integer e-th root
assert exact, "padded — m^e overflowed n"
print(int(m).to_bytes((int(m).bit_length()+7)//8, "big"))
```

If `m^e ≥ n` but only slightly, brute-force a small `k` and try `iroot(c + k*n, e)` for `k = 0..K`.

**Håstad broadcast (e = 3).** Same `m` sent to three users with moduli `n1, n2, n3` and `e = 3`:

```python
from sympy.ntheory.modular import crt
from gmpy2 import iroot
M, _ = crt([n1, n2, n3], [c1, c2, c3])
m, exact = iroot(M, 3)
assert exact
```

Why it works: by CRT, `M ≡ m^3 mod (n1·n2·n3)`. Since `m < min(n_i)`, `m^3 < n1·n2·n3`, so `M = m^3` as integers and the integer cube root recovers `m`.

**Padded but stereotyped.** If each recipient gets `m_i = a_i·m + b_i` with known `a_i, b_i` (e.g. unique per-recipient prefix), Håstad with linear padding still works via Coppersmith's method on polynomial `(a_i·x + b_i)^e - c_i mod n_i`.

**Related messages (Franklin–Reiter).** Two encryptions of `m` and `f(m)` for known low-degree polynomial `f` under the same `(n, e)` allow polynomial-GCD recovery in `Z_n[x]`. Common with chosen-IV mistakes.

**Bleichenbacher's signature forgery.** A separate but related low-`e` attack on RSA-PKCS#1 v1.5 signature verifiers that don't fully check the padding: forge a valid-looking padded hash whose cube root is a small integer. Affected many TLS/x509 verifiers in 2006 and again in 2016.

## Detection and defence
- Use RSA-OAEP for encryption; OAEP padding randomises `m` to fill the full modulus, making `m^e` always wrap mod `n`
- Use RSA-PSS or Ed25519 for signatures; for legacy PKCS#1 v1.5 verifiers, fully parse the DigestInfo and reject trailing garbage
- Prefer `e = 65537` over `e = 3`; it is fast enough and gives more headroom against root-style attacks (though OAEP makes `e` choice less critical)
- Never broadcast the same plaintext to multiple recipients — derive a per-recipient symmetric key via hybrid encryption (KEM/DEM)

## References
- [Håstad — Solving simultaneous modular equations of low degree (1988)](https://www.csc.kth.se/~johanh/relmod_sicomp.ps) — broadcast attack
- [Boneh — Twenty Years of Attacks on RSA](https://crypto.stanford.edu/~dabo/papers/RSA-survey.pdf) — surveys low-`e` family
- [Bleichenbacher 2006 — PKCS#1 v1.5 signature forgery](https://www.ietf.org/mail-archive/web/openpgp/current/msg00999.html) — low-e signature bug
- [CTF Wiki — Low public exponent](https://ctf-wiki.org/crypto/asymmetric/rsa/rsa_e_attack/) — worked examples
