---
title: LFSR (Linear Feedback Shift Register)
slug: lfsr
---

> **TL;DR:** Linear keystream; Berlekamp–Massey recovers the recurrence from 2·degree output bits.

## What it is
An LFSR is an `n`-bit register that shifts each clock tick and feeds in a new bit computed as a fixed XOR of selected taps: `s_{t+n} = c_{n-1}·s_{t+n-1} XOR … XOR c_0·s_t`. Choosing taps that form a primitive polynomial over GF(2) yields the maximum period `2^n - 1`. LFSRs are cheap, fast, and were heavily used in legacy stream ciphers (A5/1 in GSM, E0 in Bluetooth, content scrambling system) and PRNG cores. They are linear, which is also exactly why they are broken.

## Preconditions / where it applies
- Embedded firmware, RFID/transit cards, satellite/voice scramblers, retro game DRM
- CTF stream-cipher challenges where the keystream is generated as XOR of LFSR outputs
- Any place a "fast random-looking bit source" is hand-rolled
- Foundational background for [[stream-ciphers-overview]] and contrast with [[rc4]]

## Technique
Linearity means: given `2n` consecutive output bits, Berlekamp–Massey recovers the shortest LFSR that produced them — the connection polynomial and the initial state — in `O(n^2)` time. Tooling: `sage` (`berlekamp_massey`), pwntools-style scripts, or 60-line pure Python.

```python
def berlekamp_massey(seq):
    n = len(seq); C = [1] + [0]*n; B = [1] + [0]*n
    L, m, b = 0, 1, 1
    for i in range(n):
        d = seq[i]
        for j in range(1, L+1):
            d ^= C[j] & seq[i-j]
        if d == 1:
            T = C[:]
            for j in range(n - m + 1):
                C[j+m] ^= B[j]
            if 2*L <= i:
                L, B, m = i+1-L, T, 1
            else:
                m += 1
        else:
            m += 1
    return L, C[:L+1]
```

With `(L, poly)` in hand you can roll the LFSR forward to generate any future keystream byte, then XOR it with intercepted ciphertext.

Combining-function attacks (correlation attacks):

- **Geffe generator** uses three LFSRs `R1, R2, R3` with output `(R1 AND R2) XOR (NOT R1 AND R3) = R2` 75% of the time. Run Berlekamp–Massey-style correlation on each LFSR independently, breaking total complexity from `2^{n1+n2+n3}` to `2^{n1} + 2^{n2} + 2^{n3}`.
- **A5/1** uses three irregularly-clocked LFSRs (lengths 19, 22, 23) combined by majority. Practical breaks exist using time–memory–data trade-offs (Biryukov–Shamir–Wagner, Karsten Nohl's rainbow tables).

If only ciphertext + partial known plaintext is available, recover the matching keystream bits by XOR, then feed into Berlekamp–Massey.

## Detection and defence
- Do not use a bare LFSR as a stream cipher; if you must, combine multiple LFSRs through a strongly non-linear filter and never expose ≥ `2n` keystream bits per key
- Prefer modern ChaCha20 or AES-CTR for keystream needs
- For tamper-resistant hardware that still wants LFSR-style speed, use NLFSR or stream ciphers like Trivium/Grain (eSTREAM portfolio)
- Don't seed PRNGs with low-entropy data (boot time, MAC) — see also [[linear-congruential-generator]]

## References
- [Massey — Shift-register synthesis and BCH decoding (1969)](https://ieeexplore.ieee.org/document/1054260) — original BM algorithm
- [Practical Cryptography — Berlekamp–Massey](https://en.wikipedia.org/wiki/Berlekamp%E2%80%93Massey_algorithm) — algorithm reference
- [Biryukov, Shamir, Wagner — Real Time Cryptanalysis of A5/1](https://www.iacr.org/archive/fse2000/18780001/18780001.pdf) — practical LFSR-combiner break
- [HackTricks — Stream cipher patterns](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — recognition primer
