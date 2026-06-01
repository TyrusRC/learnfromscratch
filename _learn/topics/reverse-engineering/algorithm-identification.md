---
title: Algorithm identification
slug: algorithm-identification
---

> **TL;DR:** Spot AES S-boxes, DES P-boxes, SHA constants, CRC tables, RSA modular exponentiation by their magic numbers and loop shape before reading any code.

## What it is
Most cryptographic and integrity-check algorithms carry distinctive constants or structural fingerprints. Identifying them up front saves hours of stepping through math you already understand and points immediately at key material and IV handling.

## Preconditions / where it applies
- You suspect a crypto, hashing, compression, or checksum routine.
- You can read .rodata / data sections (or dump memory at runtime if it's decrypted on load).
- A disassembler with cross-references, plus a constants database (FindCrypt, signsrch, YARA crypto rules).

## Technique
Pattern-match constants first, then confirm by control flow.

```bash
# pull printable + binary constants
rabin2 -z sample.bin
# YARA against the crypto rule set
yara crypto_signatures.yar sample.bin
```

Common fingerprints:

- **AES** — Rijndael S-box starts `63 7c 77 7b f2 6b 6f c5`; round constants `01 02 04 08 10 20 40 80 1b 36`.
- **DES** — initial permutation tables, S-box arrays of 64 nibbles each.
- **SHA-1** — H0..H4 = `67452301 efcdab89 98badcfe 10325476 c3d2e1f0`; K = `5a827999 6ed9eba1 8f1bbcdc ca62c1d6`.
- **SHA-256** — round constants begin `428a2f98 71374491 b5c0fbcf e9b5dba5`.
- **MD5** — T-table starts `d76aa478 e8c7b756 242070db c1bdceee`.
- **CRC32** — 256-entry table, top values `00000000 77073096 ee0e612c`.
- **RC4** — 256-byte key-scheduling array initialised 0..255, swap loop.
- **RSA** — large bignum operations, exponent `010001` (65537) in a buffer.
- **Base64** — alphabet `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`.

Plugins automate this: IDA's `findcrypt`, Ghidra's `FindCryptScript.java`, or the cross-platform `signsrch`.

Confirm by shape: AES has 10/12/14 rounds of `SubBytes → ShiftRows → MixColumns → AddRoundKey`; RSA modular exponentiation is a square-and-multiply loop on a bignum struct.

Beware **custom or modified** algorithms — attackers replace the S-box, change the round count, or XOR a constant on top. Diff the constants you find against the reference; mismatches are red flags.

## Detection and defence
- Encrypting/transforming the constant table at rest defeats trivial signature scans (used by many packers).
- Whitebox crypto bakes the key into the S-boxes — defeats key extraction by reading registers.
- Linker-time stripping of unused crypto removes false positives in detection rules.

## References
- [HackTricks identify crypto](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — constants and structural cues
- [FindCrypt2 reference](https://github.com/d3v1l401/FindCrypt-Ghidra) — Ghidra port with signature DB
