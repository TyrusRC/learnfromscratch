---
title: Public-key cryptography basics
slug: public-key-basics
---

> **TL;DR:** Trapdoor functions — easy forward, hard reverse without the secret. Foundation for RSA, DH, ECC.

## What it is
Public-key (asymmetric) cryptography uses a key pair: a public key anyone can use to encrypt or verify, and a private key only the holder can use to decrypt or sign. Security rests on trapdoor functions — operations that are easy in one direction and hard in the other unless you know a secret. The three classical hardness assumptions are integer factorisation (RSA), the discrete logarithm in finite fields (DH/DSA, see [[discrete-logarithms]]), and the discrete logarithm on elliptic curves (ECDSA, Ed25519, X25519).

## Preconditions / where it applies
- Authenticating identities at scale: TLS certificates, SSH host keys, code signing, JWT signatures, OIDC
- Key agreement to bootstrap symmetric session keys: [[diffie-hellman]], ECDH, RSA-KEM, post-quantum KEMs (ML-KEM/Kyber)
- Digital signatures: RSA-PSS, ECDSA, Ed25519, ML-DSA/Dilithium
- Audit hits when raw textbook schemes are used without proper padding/encoding, or keys are too small for the era

## Technique
Three pillars to understand:

- **Encryption / KEM.** Public key encrypts a small payload (usually a symmetric key) that only the private key can recover. Classical RSA-OAEP encrypts up to `~k - 2·h - 2` bytes; modern designs use KEM/DEM split (e.g. RSA-KEM, ECDH-KEM, ML-KEM) plus a symmetric AEAD. See [[rsa]].
- **Signatures.** Private key signs a hash; public key verifies. RSA-PSS adds randomised salt for security proofs; ECDSA uses a per-message nonce `k` that must be unique and unpredictable (nonce reuse leaks the private key, famously broken Sony PS3). Ed25519 derives `k` deterministically from the key + message.
- **Key agreement.** Two parties run DH/ECDH to derive a shared secret, then KDF it into session keys. Authenticated DH (signed DH or X3DH/Signal) prevents MITM.

Sizing guidance (NIST SP 800-57, current as of 2026):

| Symmetric | RSA / DH (finite-field) | EC | Use case |
|-----------|-------------------------|----|----------|
| 112-bit | 2048 | 224 | Legacy minimum |
| 128-bit | 3072 | 256 | Default modern |
| 192-bit | 7680 | 384 | High assurance |
| 256-bit | 15360 | 521 | Long-term archive |

Common bug patterns:

- Using textbook RSA (no padding) — see [[rsa-low-exponent]], homomorphic mauling
- ECDSA with predictable / repeated `k` — recover the private key from two signatures
- Missing curve / subgroup checks on received points — invalid-curve attacks
- Mixing signing and encryption keys — protocol confusion, key separation failure
- Trusting `alg=none` or HMAC-vs-RSA confusion in JWT verifiers

Tooling:

```bash
openssl pkey -in priv.pem -text -noout            # inspect a key
openssl req -x509 -newkey ed25519 -days 365 ...   # generate self-signed
openssl pkeyutl -sign -inkey priv.pem -in file    # raw sign / verify
```

For post-quantum migration, NIST FIPS 203/204/205 standardised ML-KEM (Kyber), ML-DSA (Dilithium), and SLH-DSA (SPHINCS+); hybrid TLS draft `X25519+ML-KEM-768` is the deployment path in 2025-2026.

## Detection and defence
- Inventory key sizes; reject sub-2048-bit RSA / sub-256-bit ECC
- Enforce padding choices: RSA-OAEP for encryption, RSA-PSS or Ed25519 for signatures; never raw / PKCS#1 v1.5 for new designs
- Pin trust roots for high-value endpoints (HPKP is deprecated; use CT monitoring + key pinning at the app)
- Begin PQ hybrid rollout for long-lived secrets ("harvest now, decrypt later")

## References
- [NIST SP 800-57 Part 1 Rev. 5](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final) — key management recommendations
- [Boneh and Shoup — A Graduate Course in Applied Cryptography](https://toc.cryptobook.us/) — comprehensive textbook
- [Real World Crypto by Boneh and Shoup](https://crypto.stanford.edu/~dabo/cryptobook/) — practical schemes
- [HackTricks — Asymmetric cryptography](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — common pitfalls
