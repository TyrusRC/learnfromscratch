---
title: CBC bit-flipping
slug: cbc-bit-flipping
---

> **TL;DR:** In CBC, plaintext block N decrypts as D(C_N) XOR C_{N-1}, so XORing chosen bits into C_{N-1} flips the same bits in P_N — at the cost of fully scrambling block N-1.

## What it is
CBC chains ciphertext blocks: P_N = D_k(C_N) XOR C_{N-1}. The previous ciphertext block acts directly as an XOR mask on the next plaintext. An attacker who can deliver modified ciphertext to a decryption endpoint can therefore deterministically alter known plaintext bytes in any block — provided they're willing to corrupt the preceding block into random garbage.

## Preconditions / where it applies
- The target uses CBC for confidentiality without an authentication tag (no HMAC, no AEAD).
- The attacker controls or can replay the ciphertext sent for decryption (cookie, session token, URL-encoded blob).
- The attacker knows (or can guess) the plaintext of the block they want to flip — e.g. `role=user&admin=0`.
- Server reveals the manipulated plaintext through behaviour, not necessarily content (auth bypass, role escalation, account ID change).

## Technique
Target: flip `admin=0` to `admin=1` in a session cookie whose plaintext layout is known.

1. Capture ciphertext `IV || C1 || C2 || ...` where C2 contains `admin=0`.
2. Identify the byte position of `0` inside P2. Compute the XOR delta: `delta = ord('0') XOR ord('1') = 0x01`.
3. Modify the corresponding byte of C1: `C1'[i] = C1[i] XOR 0x01`.
4. Send `IV || C1' || C2 || ...`. After decryption, P2 has `admin=1`; P1 is now random noise.

```python
ct = bytearray(base64.b64decode(cookie))
# block size 16; flip byte 'admin=0' -> 'admin=1' in block index 2 (offset 22)
prev_block_byte = 16 + (22 - 16) - 16  # adjust per layout
ct[6] ^= ord('0') ^ ord('1')           # patch byte in C1 that affects P2[6]
print(base64.b64encode(ct).decode())
```

If P1 carries meaningful structure too (e.g. JSON), the corrupted block usually crashes the parser — chain with [[cbc-padding-oracle]] to repair P1 byte-by-byte when needed.

## Detection and defence
- Servers see decryption succeeding but downstream JSON/parser errors spike for the corrupted block; correlate with privilege change.
- Switch to AEAD: AES-GCM, AES-GCM-SIV, ChaCha20-Poly1305. Tag failure rejects the whole message before decryption results are exposed.
- If stuck with CBC, apply encrypt-then-MAC (HMAC-SHA-256 over `IV || ciphertext`) and verify in constant time before decryption.
- Bind session cookies to server-side state (random ID → server lookup) instead of putting authorisation fields inside encrypted blobs.

## References
- [CryptoPals Set 2 Challenge 16](https://cryptopals.com/sets/2/challenges/16) — canonical CBC bit-flip exercise.
- [PortSwigger — Using application functionality to exploit insecure deserialization](https://portswigger.net/web-security/deserialization) — adjacent attack pattern on encrypted blobs.
- [book.hacktricks.wiki — CBC](https://book.hacktricks.wiki/en/crypto-and-stego/cipher-block-chaining-cbc-mac-priv.html) — recipe and tooling.
