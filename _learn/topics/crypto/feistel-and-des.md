---
title: Feistel networks and DES
slug: feistel-and-des
---

> **TL;DR:** A Feistel round splits the block into (L, R) and computes (L', R') = (R, L XOR F(R, K)) so any F — even non-invertible — gives an invertible cipher; DES is the canonical 16-round Feistel with a 56-bit key, now broken by brute force.

## What it is
The Feistel structure builds invertible block ciphers from arbitrary round functions F. Encryption and decryption use the same hardware, with reversed round-key order. DES (Data Encryption Standard) implements this with a 64-bit block, 56 effective key bits, 16 rounds, and a key schedule based on permuted choice tables. Successors include 3DES (chained DES, EDE), Blowfish, Twofish, GOST, MISTY, and Camellia. AES is _not_ Feistel — it's an SPN. In modern CTFs DES appears as a legacy challenge (brute-force the 56-bit key, exploit 3DES meet-in-the-middle, recover a partial subkey).

## Preconditions / where it applies
- Target uses DES or 3DES (legacy banking, mainframe, old smartcards, MS-CHAPv2).
- Key length <= 56 bits (or 80 effective bits for 2-key 3DES under meet-in-the-middle).
- Block size 64 bits: Sweet32 birthday attacks against long-lived sessions encrypting > 2^32 blocks.
- A leaked round key — reversing the DES key schedule recovers the master.

## Technique
- **Brute force DES**: distributed effort or specialised hardware. Software finishes a 56-bit search on a modern GPU farm in days; hashcat mode 14000 handles known plaintext/ciphertext pairs.

```bash
hashcat -m 14000 -a 3 hash.txt -1 charsets/DES_full.hcchr '?1?1?1?1?1?1?1?1'
```

- **Meet-in-the-middle on 2-key 3DES**: store `Enc_K1(P)` for all K1; iterate K2 and match `Dec_K2(C)`. Effective work 2^57 + memory 2^56.
- **Sweet32 (CVE-2016-2183)**: 64-bit block birthday collisions; ~785 GB of CBC traffic under the same key recovers plaintext blocks. Affects 3DES in TLS and OpenVPN.
- **Reverse the key schedule**: DES key schedule applies PC-1 then rotates and applies PC-2 per round. Inverting PC-2 from one round key gives 48 bits of the 56-bit master; bruteforce the remaining 8.
- **Differential / linear cryptanalysis** on reduced-round DES is academic; CTFs sometimes ship a 4-6 round variant where these break the cipher trivially.

```python
# Round structure
def feistel_round(L, R, K, F):
    return R, L ^ F(R, K)
```

## Detection and defence
- Disable DES/3DES in TLS (`!3DES:!DES` cipher suites), SSH, IPSec, Kerberos (`des-cbc-md5`).
- Migrate MS-CHAPv2/PPTP-style protocols to EAP-TLS/EAP-TTLS.
- Rotate sessions before 2^32 64-bit blocks under any 64-bit-block cipher (Sweet32 mitigation).
- Pick AES or ChaCha20-Poly1305 for new designs; treat DES strictly as a teaching artefact.

## References
- [NIST FIPS 46-3 — DES](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.46-3.pdf) — original specification (withdrawn 2005).
- [Sweet32 — Bhargavan & Leurent](https://sweet32.info/) — birthday attack on 64-bit ciphers.
- [Schneier on Feistel networks](https://www.schneier.com/academic/archives/1996/01/the_blowfish_encrypti.html) — Blowfish design and Feistel rationale.
