---
title: AES
slug: aes
---

> **TL;DR:** AES is a 128-bit block substitution-permutation network with 10/12/14 rounds for 128/192/256-bit keys; in CTFs you almost never break AES itself — you break mode usage, padding, IV reuse, or key handling around it.

## What it is
AES (Rijndael) operates on a 4x4 byte state. Each round applies SubBytes (S-box), ShiftRows, MixColumns, AddRoundKey; the final round drops MixColumns. The key schedule derives per-round subkeys from the master key via Rcon and the same S-box. As a primitive AES is considered secure against practical cryptanalysis; the realistic attack surface is everything wrapped around it.

## Preconditions / where it applies
- Any system using AES-ECB, AES-CBC, AES-CTR, AES-GCM, or AES-CCM with attacker-controlled input or oracles.
- Key reuse across messages without authenticated IV/nonce handling.
- Side channels (cache timing, power) in software/embedded targets where bitsliced or T-table implementations leak.

## Technique
Pick the mode-specific bug, not the cipher:

- ECB: same plaintext block → same ciphertext. See [[ecb-attacks]] (byte-at-a-time decryption when attacker prefix is concatenated to a secret).
- CBC: malleable. See [[cbc-bit-flipping]] (controlled plaintext mutation in block N by XORing C_{N-1}) and [[cbc-padding-oracle]] (full decryption with a padding-validity oracle).
- CTR/GCM: nonce reuse collapses to keystream reuse — see [[many-time-pad]]. GCM nonce reuse additionally lets an attacker forge authentication tags by recovering H.
- Key schedule weaknesses: related-key attacks on AES-256 are academic; in CTFs you usually get a leaked round key. Reverse the schedule with tools like `aeskeyschedule` to recover the master key.

```python
# AES-CTR keystream reuse: two ciphertexts under same (key, nonce)
ks_xor_pt1_pt2 = bytes(a ^ b for a, b in zip(c1, c2))  # = P1 ^ P2
```

```bash
# Recover AES key from an exposed round key
aeskeyschedule --key 5468617473206d79204b756e67204675 --round 1
```

## Detection and defence
- Use authenticated modes (AES-GCM, AES-GCM-SIV, ChaCha20-Poly1305) and never reuse a (key, nonce) pair.
- Enforce constant-time AES (AES-NI hardware path or bitsliced software) to kill cache-timing leaks.
- Validate tags before any decryption-side processing — never reveal a padding-vs-MAC error distinction.
- Rotate keys; treat each key as message-bounded under the mode's birthday limits (2^32 blocks for CTR/GCM at 128-bit blocks).

## References
- [NIST FIPS 197 — AES specification](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf) — official AES standard.
- [CryptoHack — AES challenges](https://cryptohack.org/challenges/aes/) — hands-on mode-misuse exercises.
- [PortSwigger — Padding oracle attacks](https://portswigger.net/web-security/encryption) — web-flavoured mode abuse.
