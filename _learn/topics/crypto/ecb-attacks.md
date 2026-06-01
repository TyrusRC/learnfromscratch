---
title: ECB attacks
slug: ecb-attacks
---

> **TL;DR:** Identical plaintext blocks → identical ciphertext blocks. ECB byte-at-a-time prefix recovery is the classic.

## What it is
ECB encrypts each block independently: `C_i = E_k(P_i)`. The mode preserves equality of plaintext blocks in the ciphertext, which leaks structure and enables block-level cut-and-paste. Two practical exploits dominate: visual/dup-block detection and adaptive chosen-plaintext byte-at-a-time secret recovery when the server prepends or appends attacker-controlled data to a hidden secret before encrypting under ECB.

## Preconditions / where it applies
- A service encrypts (attacker_input || secret) or (secret || attacker_input) under ECB and returns the ciphertext
- Block size is known or can be measured (encrypt 1, 2, 3, ... bytes; watch ciphertext length jump by one block)
- Common in CTFs, legacy session cookies, and homemade JWE-like blobs. See [[block-cipher-modes]].

## Technique
Detect ECB first by feeding ≥ 2 × block_size bytes of a repeating character and looking for duplicate ciphertext blocks.

Byte-at-a-time decryption of an unknown suffix `S` appended to your input:

1. Determine block size: send `A`, `AA`, `AAA`, ... until ciphertext length jumps. The jump size is the block size `b`.
2. Pad with `b-1` known bytes so the first secret byte sits at the last position of a known block: input = `"A" * (b-1)`. The first ciphertext block encodes `"AAAAAAAAAAAAAAA" + S[0]`.
3. Build a dictionary by encrypting `"A" * (b-1) + c` for every byte `c` in 0..255. Match the dictionary block to the target block to recover `S[0]`.
4. Shift left: input = `"A" * (b-2)`. The target block is `"AAAAAAAAAAAAAA" + S[0] + S[1]`. Dictionary entries are `"AAAAAAAAAAAAAA" + S[0] + c`. Recover `S[1]`.
5. Repeat to recover all of `S`.

Concise Python sketch:

```python
def recover(oracle, block=16):
    secret = b""
    for i in range(block * MAX_BLOCKS):
        pad = b"A" * (block - 1 - (len(secret) % block))
        target = oracle(pad)[: ((len(secret) // block) + 1) * block]
        for c in range(256):
            guess = oracle(pad + secret + bytes([c]))[: len(target)]
            if guess == target:
                secret += bytes([c])
                break
        else:
            break
    return secret
```

If the server prepends a fixed unknown prefix before the attacker input, first measure the prefix length (find smallest `n` for which two identical input blocks appear) and pad your attacker input to block-align the secret.

Block cut-and-paste: ECB lets you splice ciphertext blocks from one message into another to forge structured payloads (classic example: rearranging blocks of an encrypted role cookie to elevate `user` to `admin`).

## Detection and defence
- Reject ECB outright; pick AES-GCM or ChaCha20-Poly1305
- WAF/IDS rules: alert on requests with long runs of identical bytes (`AAAA...`) hitting the same encrypted endpoint
- Tag cookies/blobs with a per-request random IV (CBC/GCM) so the same plaintext yields different ciphertext
- Server-side: code review for `Cipher.getInstance("AES")` (Java default is ECB), `AES.new(key, AES.MODE_ECB)` (PyCryptodome)

## References
- [HackTricks — Electronic codebook (ECB)](https://book.hacktricks.wiki/en/crypto-and-stego/electronic-code-book-ecb.html) — exploitation primer
- [Cryptopals — Set 2 challenges 12 and 14](https://cryptopals.com/sets/2) — byte-at-a-time ECB
- [NIST SP 800-38A](https://csrc.nist.gov/publications/detail/sp/800-38a/final) — formal definition and warning on ECB usage
