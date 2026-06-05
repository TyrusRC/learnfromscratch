---
title: Post-quantum crypto attack surface
slug: post-quantum-crypto-attack-surface
aliases: [pqc-attack-surface, pqc-attacks, kyber-dilithium-attacks]
---

> **TL;DR:** Post-quantum cryptography (PQC) is rolling out across TLS, SSH, secure messaging, and identity systems. The NIST-standardised algorithms — ML-KEM (Kyber), ML-DSA (Dilithium), SLH-DSA (SPHINCS+) — replace classical algorithms vulnerable to large quantum computers. Practical attacks today aren't on the math but on **implementation bugs**: side-channels in lattice reductions, key-recovery via fault injection, and **harvest-now-decrypt-later** captures of classical traffic for future quantum decryption. Companion to [[lattice-attacks-crypto-ctf]] and [[diffie-hellman]].

## Why PQC matters now

- **Quantum threat is asymmetric across the timeline**. Cryptographically-relevant quantum computers don't exist today, but attackers harvest classical-encrypted traffic today for later decryption.
- **Long-term secrets** (medical records, classified comms, root CAs with 20-year lives) face the harvest-now-decrypt-later (HNDL) class **today**.
- **Migration is happening** — TLS 1.3 hybrid key exchange (X25519MLKEM768), SSH PQC suites, Signal Protocol PQXDH all rolling.
- Cryptographic agility is now an engineering priority for many products.

## The standardised algorithms

- **ML-KEM (Module-Lattice Key Encapsulation Mechanism)** — formerly Kyber. Standardised FIPS 203. For key agreement.
- **ML-DSA (Module-Lattice Digital Signature Algorithm)** — formerly Dilithium. FIPS 204. For signatures.
- **SLH-DSA (Stateless Hash-Based Digital Signature Algorithm)** — formerly SPHINCS+. FIPS 205. Conservative hash-based signatures; large but well-understood.
- **HQC** — code-based KEM, alternative to ML-KEM.
- **FALCON** (FN-DSA, in progress) — lattice-based signatures, smaller than ML-DSA.

Each has parameter sets at three security levels.

## Why "attack surface" rather than "attacks on the math"

The lattice / hash / code-based hardness assumptions are well-studied. The likely attack vectors in deployed systems are:

### Implementation side-channels

Lattice cryptography involves polynomial multiplications, NTT (Number-Theoretic Transform), rejection sampling. Naive implementations leak through:
- **Timing** — branches in rejection sampling.
- **Cache** — table lookups in NTT.
- **Power** — Hamming weight of intermediate values.

Single-trace side-channel key-recovery has been demonstrated on multiple ML-KEM implementations. Constant-time implementations exist but production deployments may use older libraries.

### Fault injection

Hardware fault attacks against signing operations (ML-DSA, SLH-DSA):
- **Skip-instruction faults** during signature computation cause leaks.
- **Rejection sampling fault** — skip a "reject" branch and produce an invalid but accepted signature; key extracted.

ChipWhisperer / EMFI rigs (see [[bootloader-and-secure-boot-attacks]]) target this class.

### Hybrid mode downgrade

TLS 1.3 hybrid key exchange combines a classical (X25519) and PQC (ML-KEM-768) shared secret. If either is weak, the combination should still be secure. But:
- **Downgrade attack**: induce client to negotiate classical-only.
- **Library bug** — only the classical half of the hybrid is checked.
- **Protocol parser** treats one half as authoritative.

Audit hybrid-mode implementations for downgrade resistance.

### Harvest-now-decrypt-later (HNDL)

The most practical threat to deployed classical crypto. Attacker collects encrypted traffic today; stores it; decrypts when quantum computers mature.

Implications:
- **Encryption-at-rest** with long retention should migrate before adversary capability arrives.
- **Long-lived secret rotation** is mandatory; root CAs that signed 10-year certs need renewal before quantum.
- **PFS (perfect forward secrecy)** with classical Diffie-Hellman doesn't protect — the DH exchange itself can be broken.

### Long-lived keys / certificates

Root CAs, device-embedded keys (in IoT, vehicles, satellites) that can't be field-replaced are highest-risk. The signing keys behind these will be attackable as quantum matures; migration requires replacement at the hardware level.

### Cryptographic agility bugs

Migration introduces transition states. Bugs:
- **Algorithm-confusion** — verifier accepts a signature with the wrong algorithm.
- **Parameter-mismatch** — server expects ML-KEM-768; client sends ML-KEM-512.
- **Negotiation downgrade** — see hybrid-mode above.
- **Default behaviour** in libraries — using classical when PQC fails silently.

These look identical to historical TLS / SSH algorithm-confusion bugs ([[jwt-key-confusion]] is the analogous JWT class).

## Migration roadmap (practitioner view)

Per CISA / NIST / NSA guidance:

1. **Inventory** every protocol and product using classical asymmetric crypto.
2. **Identify HNDL exposure** — what could attackers extract that's still valuable 10–15 years out?
3. **Prioritise** by exposure and migration cost.
4. **Pilot** hybrid mode in low-risk environments.
5. **Roll out** hybrid as default, with feature flags.
6. **Phase out** classical for new deployments.
7. **Crypto-agile architecture** so future algorithm replacement is procedural.

## Specific deployment points

- **TLS 1.3** — hybrid X25519MLKEM768 added in 2024-2025. Cloudflare, Google, Apple have rolled out.
- **SSH** — OpenSSH 9.0+ supports `sntrup761x25519-sha512`. PQC SSH-key-exchange suites adopted by major sshd builds.
- **Signal Protocol** — PQXDH (post-quantum extended Diffie-Hellman) added 2023.
- **JWT** — PQC signature algorithms (ML-DSA-44/65/87) in draft.
- **Certificate Authorities** — Smallstep, AWS PCA, Google certificates moving toward PQC.
- **HSM / FIDO2 / TPM** — vendor support uneven; some only support classical.

## Audit shape for PQC implementations

Check:
- **Constant-time** library implementation (libcrypto, BoringSSL, libOQS).
- **Side-channel resistance** assessed by independent review.
- **Hybrid mode used** for TLS, not pure PQC (defence-in-depth during early years).
- **Algorithm-id verification** at each protocol layer.
- **Default-on PQC** for new deployments.
- **Forward-secrecy preserved** through migration.

## Workflow to study

1. Read NIST FIPS 203/204/205 specifications.
2. Compile and link **liboqs** (Open Quantum Safe) or **PQClean** against test programs.
3. Capture TLS 1.3 PQC handshake with Wireshark; identify the hybrid key share.
4. Run side-channel analysis on a reference implementation (lab only).
5. Investigate vendor advisories — Cloudflare, AWS, Microsoft publish ongoing PQC deployment writeups.

## Pitfalls / open issues

- **Performance** — PQC handshakes have larger keys / signatures (ML-KEM-768 ~1 KB ciphertext; ML-DSA-65 ~3.3 KB signature). TLS records grow.
- **Interoperability** between early-adopter implementations isn't always clean.
- **Quantum capability timeline uncertainty** — could be 10 years, could be 30. Migration urgency depends on data lifetime.
- **Side-channel landscape** for PQC is younger than for RSA / ECC; more bugs will surface.
- **NSA mandates** — CNSA 2.0 requires PQC in certain US-classified contexts on accelerated timeline.

## Related

- [[lattice-attacks-crypto-ctf]] — lattice math foundations.
- [[diffie-hellman]] / [[rsa]] — classical primitives.
- [[bootloader-and-secure-boot-attacks]] — affected ecosystem.
- [[pqc-migration-risk]] — organisational view.
- [[jwt-key-confusion]] — analogous protocol-confusion class.

## References
- [NIST PQC standardization](https://csrc.nist.gov/Projects/post-quantum-cryptography)
- [Open Quantum Safe (liboqs)](https://openquantumsafe.org/)
- [PQClean](https://github.com/PQClean/PQClean)
- [Cloudflare — PQC research](https://blog.cloudflare.com/tag/post-quantum/)
- [NSA CNSA 2.0](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/3148990/)
- See also: [[lattice-attacks-crypto-ctf]], [[diffie-hellman]], [[rsa]], [[pqc-migration-risk]]
