---
title: CBC padding oracle
slug: cbc-padding-oracle
---

> **TL;DR:** Server distinguishes valid from invalid PKCS#7 padding; that one bit decrypts entire ciphertexts.

## What it is
A padding oracle is any service that, while decrypting CBC ciphertext, behaves differently when PKCS#7 padding is malformed versus when it is well-formed. The leak can be an HTTP 500 vs 200, a different error string, or even a timing delta. With that single bit per query, an attacker can decrypt arbitrary CBC ciphertext block-by-block and — by running the algorithm against a chosen plaintext — also encrypt arbitrary data without knowing the key. Originally published by Vaudenay (2002); famous productisations include POODLE and the ASP.NET viewstate oracle.

## Preconditions / where it applies
- CBC mode (see [[block-cipher-modes]]) with PKCS#7 padding
- Attacker can submit chosen ciphertexts and observe a side channel revealing "padding valid" vs "padding invalid"
- Common targets: session cookies, viewstate, encrypted URL parameters, JWE with `A128CBC-HS256` when the MAC is checked after padding

## Technique
Recall CBC decryption: `P_i = D_k(C_i) XOR C_{i-1}`. Let `I_i = D_k(C_i)` (the intermediate). If we control `C_{i-1}`, we control `P_i = I_i XOR C_{i-1}` and we know `C_{i-1}`.

To decrypt block `C_i`, submit ciphertext `C' || C_i` where `C'` is a 16-byte block we mutate. The server decrypts as `P' = I_i XOR C'`.

1. Set the last byte of `C'` to a guess `g` from 0..255. The plaintext last byte becomes `I_i[15] XOR g`. The padding check passes when that byte equals `0x01` (or by chance the trailing run is valid).
2. The valid guess `g` gives `I_i[15] = g XOR 0x01`.
3. Move to byte 14: set `C'[15] = I_i[15] XOR 0x02` so the last plaintext byte is `0x02`, then brute-force `C'[14]` until padding `0x02 0x02` is accepted. That gives `I_i[14]`.
4. Repeat to recover all 16 bytes of `I_i`, then `P_i = I_i XOR C_{i-1}` (the real previous block).
5. Chain across all blocks of the message; ~128 × n_blocks requests per message in the worst case, ~16 on average per byte.

Encryption oracle: pick a target plaintext, recover `I_i` of any block, then choose `C_{i-1} = I_i XOR P_target` to force decryption to a chosen plaintext. Iterate from the last block backwards to forge arbitrary ciphertext.

Practical tooling:

```bash
padbuster https://target/app/session=BASE64CT BASE64CT 16 -encoding 0 -cookies "..."
```

`hashcat`-style mass decoding is also available via `python-paddingoracle` and Burp's "Padding Oracle" extension. For length-extension-style block stitching see also [[cbc-bit-flipping]].

## Detection and defence
- Server logs show a flood of decrypt errors on the same endpoint with mutated ciphertexts; rate-limit and alert
- Use authenticated encryption (AES-GCM, ChaCha20-Poly1305) so any ciphertext mutation fails MAC before padding is even looked at
- If you must use CBC, encrypt-then-MAC and verify the MAC in constant time **before** decrypting; return a single generic error
- WAF rules can match base64 ciphertexts with high entropy of mutation on a single parameter

## References
- [Vaudenay — Security flaws induced by CBC padding](https://www.iacr.org/archive/eurocrypt2002/23320530/cbc02_e02d.pdf) — original paper
- [PortSwigger — Cracking CBC encryption (padding oracle)](https://portswigger.net/web-security/essential-skills) — practical lab walkthrough
- [HackTricks — Padding oracle](https://book.hacktricks.wiki/en/crypto-and-stego/padding-oracle-priv.html) — exploitation notes
- [GitHub — AonCyberLabs/PadBuster](https://github.com/AonCyberLabs/PadBuster) — canonical exploitation tool
