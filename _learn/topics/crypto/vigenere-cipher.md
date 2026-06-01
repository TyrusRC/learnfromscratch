---
title: Vigenère cipher
slug: vigenere-cipher
---

> **TL;DR:** Polyalphabetic shift with repeating key; broken by Kasiski exam or index-of-coincidence period detection.

## What it is
The Vigenère cipher applies a repeating-key Caesar shift: `C_i = (P_i + K_{i mod L}) mod 26`. Each plaintext letter is shifted by the corresponding key letter; the key cycles through every `L` positions. Built up from `L` interleaved [[shift-ciphers]], so once the period `L` is known, the cipher decomposes into `L` independent Caesars solvable by frequency analysis. Stronger only than a single Caesar — and only against analysts who don't know the period trick.

## Preconditions / where it applies
- CTF puzzles, historical ciphertexts, simple file-obfuscation routines
- XOR with a repeating key against bytes (the modern "Vigenère" used in basic malware obfuscation and CTF binaries) — same cryptanalysis
- Long enough ciphertext (a few hundred letters minimum) for statistics to converge

## Technique

**Step 1 — find the key length `L`.**

- **Kasiski examination.** Find repeated substrings (≥ 3 letters) and record the distances between occurrences. The key length divides most of these distances; the GCD of distances is a strong candidate.
- **Index of coincidence (IoC).** For each candidate `L = 1..30`, split the ciphertext into `L` cosets and compute the average IoC: `IC = Σ n_i(n_i-1) / N(N-1)`. English IoC is ~0.067; random is ~0.038. The smallest `L` whose IoC jumps to ~0.067 is the key length.

```python
from collections import Counter
def ioc(s):
    c = Counter(s); n = len(s)
    if n < 2: return 0
    return sum(v*(v-1) for v in c.values()) / (n*(n-1))

text = "".join(ch for ch in cipher.upper() if ch.isalpha())
for L in range(1, 31):
    cosets = ["".join(text[i::L]) for i in range(L)]
    print(L, sum(ioc(c) for c in cosets) / L)
```

**Step 2 — recover each key letter.** For each of the `L` cosets, find the shift `k_i` whose distribution best matches English (chi-squared against expected frequencies, or correlation with the expected vector). The key is `K = chr(k_0+65) chr(k_1+65) ...`.

**Step 3 — decrypt.** `P_i = (C_i - K_{i mod L}) mod 26`.

Repeating-key XOR (byte version):

```python
def xor_break(ct):
    L = best_keylen_by_ioc(ct)
    key = bytes(single_byte_xor_break(ct[i::L]) for i in range(L))
    return bytes(b ^ key[i % L] for i, b in enumerate(ct)), key
```

The `xortool` utility automates this end-to-end on arbitrary binary files; pwntools includes `xor_key` helpers.

Variants:

- **Autokey cipher.** Key continues with plaintext after the initial seed; defeats simple period detection but is broken by trigram statistical attack.
- **Beaufort cipher.** Same family with reciprocal arithmetic: `C = K - P mod 26`.
- **Running-key cipher.** Key is a long natural-language text; broken by aligning two probable plaintexts across the same key stretch (see [[many-time-pad]]).

## Detection and defence
- Length-preserving cipher whose IoC is well above random but below English, then exhibits English-like IoC when sliced at the right stride — the classic Vigenère fingerprint
- Do not use Vigenère for confidentiality; any text length over a few hundred letters is recoverable in seconds
- For obfuscation against casual reverse-engineers, even a true OTP would not help if the key is shipped in the binary — use proper symmetric authenticated encryption instead

## References
- [Practical Cryptography — Vigenère cipher cryptanalysis](https://practicalcryptography.com/cryptanalysis/stochastic-searching/cryptanalysis-vigenere-cipher/) — IoC + chi-squared
- [Friedman — The Index of Coincidence (1922)](https://en.wikipedia.org/wiki/Index_of_coincidence) — original technique
- [HackTricks — Cryptographic algorithms](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — recognition cues
- [hellman/xortool](https://github.com/hellman/xortool) — automated repeating-XOR key recovery
