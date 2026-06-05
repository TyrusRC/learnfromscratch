---
title: Cryptography side-channels — survey
slug: cryptography-side-channels-survey
aliases: [crypto-side-channels, timing-attacks-survey]
---

> **TL;DR:** Cryptographic algorithms have well-understood theoretical security; their implementations leak through side channels — timing, cache, microarchitecture, power, EM, fault, and even branch-prediction state. A few classes recur: variable-time comparison (HMAC, MAC), branch on secret (RSA / DSA exponent), cache-aware table lookups (AES T-tables), Bleichenbacher / Manger PKCS1 oracles, Lucky 13 in TLS, ECDSA nonce side channels (Minerva, TPM-FAIL), pre-PQC and PQC implementation issues. Companion to [[side-channel-power-em]] and [[spectre-meltdown-deep]].

## Why crypto side-channels recur

- **Algorithm-level security** proven; **implementation-level security** complex.
- **Constant-time discipline** is hard; one assumption violated = leak.
- **New hardware** introduces new microarchitectural channels.
- **PQC migration** introduces fresh implementations susceptible to fresh bugs.

## Class 1 — Timing side-channels

### Variable-time comparison

```c
if (memcmp(received_mac, expected_mac, 32) == 0) accept;
```

`memcmp` returns at first difference. Attacker measures times to learn byte-by-byte.

Defence: `CRYPTO_memcmp` constant-time variants. Modern libraries fixed.

### Branch on secret

```python
def exponentiation(x, e, n):
    result = 1
    while e:
        if e & 1:
            result = (result * x) % n
        x = (x * x) % n
        e >>= 1
    return result
```

Branch taken depends on `e` bit. Timing leaks `e` (the private key).

Defence: Montgomery ladder, square-and-multiply-always.

### Lucky 13 (TLS, 2013)

MAC-then-pad-then-encrypt TLS construction; padding-check timing reveals plaintext byte-by-byte.

Defence: switch to AEAD (AES-GCM, ChaCha20-Poly1305); TLS 1.3 mandates.

## Class 2 — Cache side-channels

### AES T-tables

Reference AES uses 256-entry T-tables. Cache-line resolution lets attacker observe which entries victim accessed.

Defence: bitsliced AES, AES-NI hardware, table-less implementations.

### Prime+Probe / Flush+Reload

General cache side-channel primitives. Apply to AES, RSA, ECDSA, OS kernel data.

### Cross-VM / cross-tenant

Public cloud co-tenancy enables cache side-channel attacks across VM boundaries. Demonstrated for AES, RSA in academic settings.

Defence: AES-NI (hardware-supported AES), constant-time ECDSA, dedicated-tenant hosts for sensitive workloads.

## Class 3 — Microarchitectural

See [[spectre-meltdown-deep]]. Branch predictor, load buffers, ports.

Crypto-specific manifestations:
- **PortSmash** — port-contention side-channel against OpenSSL ECDSA.
- **L1TF / Foreshadow** — could recover SGX-sealed crypto.
- Various Spectre-class against constant-time-claimed implementations.

## Class 4 — Padding oracle

### Bleichenbacher (1998)

RSA PKCS1 v1.5 padding-oracle attack on TLS handshake. Server returns distinguishable response for valid-vs-invalid padding. Adaptive querying recovers session key.

Affected SSL 3.0 / TLS 1.0 broadly; mitigations cat-and-mouse for decades.

### Manger

OAEP-side equivalent.

### Modern variants

- **ROBOT (2017)** — Bleichenbacher resurrected against modern TLS implementations.
- **CCS Injection**.

Defence: RSA-OAEP for new; TLS 1.3 uses ECDHE-only.

## Class 5 — ECDSA nonce side channels

ECDSA signature uses a per-signature nonce `k`. If `k` leaks:
- Lattice attack recovers private key from a few signatures with partial-`k` knowledge.

Bugs:
- **Minerva** (2020) — variable-time scalar multiplication in some libraries leaks `k` bits.
- **TPM-FAIL** (2019) — TPM ECDSA implementations leaked `k`.
- **Sony PS3 (2010)** — fixed `k` per signature (egregious).
- **Bitcoin wallet bugs** — RNG failure → nonce reuse → key recovery.

Defence: Deterministic nonces (RFC 6979) eliminate randomness issues. Or use Ed25519 / Curve25519 deterministic-by-design.

## Class 6 — Random-number generator

If RNG seeded weakly or predictably, generated keys are recoverable.

- **Debian OpenSSL 2008** — patched-out PRNG entropy. All keys generated for ~2 years were predictable.
- **Various embedded** — RNG hardware not present or used incorrectly.

Defence: hardware RNG; OS-provided high-quality entropy (Linux `getrandom(2)`).

## Class 7 — Fault injection

Crypto-state corruption via fault yields key recovery in some algorithms. See [[fault-injection-laser-emfi]].

Specific:
- **DFA on AES** — Differential Fault Analysis recovers key with ~30 fault traces.
- **RSA-CRT** fault recovery.

Defence: redundant computation, signature verification post-sign.

## Class 8 — Branch predictor / training

Spectre v2 used to attack constant-time crypto:
- Train branch predictor to mispredict in victim.
- Observe transient execution.

Newer mitigations (eIBRS, IBPB on context switch) reduce but don't eliminate.

## Class 9 — PQC implementation

Newer issue (2024+):
- **ML-KEM / Kyber side channels** — early implementations had timing / cache issues.
- **ML-DSA / Dilithium fault attacks** — rejection-sampling fault recovers key.
- See [[post-quantum-crypto-attack-surface]].

## Class 10 — Curve parameter attacks

- **Curve25519** with implementation bug — some implementations not constant-time at clamp step.
- **NIST P-curves** with bad implementations — small-subgroup attacks.

## Modern defences

### Library best practices

- **libsodium** — opinionated, constant-time, hard-to-misuse API.
- **mbedTLS** — embedded-focused.
- **BoringSSL / OpenSSL** — modern versions hardened.
- **AWS-LC**, **rustls**, **Wycheproof** — testing.

### Hardware acceleration

- **AES-NI**, **SHA-NI** instructions — constant-time at CPU level.
- **HSM / TPM** — isolated execution but historically had own side channels.

### Constant-time linting

- **`ctgrind`**, **`tlsfuzzer`** — automated side-channel detection.
- **TIMECOP** — academic tool.

### Format-side defences

- **AEAD only** in TLS 1.3.
- **Deterministic nonces** (RFC 6979).
- **No PKCS1 v1.5 padding** for RSA.

## Workflow to study

1. Read libsodium documentation; understand constant-time guarantees.
2. Read original Bleichenbacher paper + ROBOT.
3. Read Lucky 13, BEAST, CRIME, BREACH chain.
4. Read Minerva / TPM-FAIL writeups.
5. Apply Wycheproof / TLS-fuzzer to a test target.

## Workflow to defend

1. Use modern libraries — libsodium, ring (Rust), BoringSSL.
2. Avoid implementing crypto yourself.
3. Audit dependencies for known-bad crypto patterns.
4. Test with TLS-fuzzer / similar against your TLS endpoints.

## Related

- [[side-channel-power-em]] — adjacent.
- [[spectre-meltdown-deep]] — adjacent.
- [[hardware-glitching-deep]] — adjacent.
- [[fault-injection-laser-emfi]] — adjacent.
- [[rsa]], [[rsa-coppersmith]], [[rsa-wiener]] — algorithm context.
- [[post-quantum-crypto-attack-surface]] — adjacent.
- [[tls-1-3-attacks-and-misuse]] — adjacent.
- [[hardware-security-module-attacks]] — adjacent.

## References
- [Cryptographic Hardware and Embedded Systems (CHES)](https://ches.iacr.org/)
- [Real World Crypto](https://rwc.iacr.org/)
- [Bleichenbacher original paper (1998)](https://link.springer.com/chapter/10.1007/BFb0055716)
- [Lucky 13 paper](https://www.isg.rhul.ac.uk/tls/Lucky13.html)
- [Minerva](https://minerva.crocs.fi.muni.cz/)
- [libsodium documentation](https://doc.libsodium.org/)
- See also: [[side-channel-power-em]], [[spectre-meltdown-deep]], [[post-quantum-crypto-attack-surface]], [[tls-1-3-attacks-and-misuse]]
