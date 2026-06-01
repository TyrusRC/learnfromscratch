---
title: Fixed substitution ciphers
slug: fixed-substitution-ciphers
---

> **TL;DR:** Monoalphabetic substitution; broken by frequency analysis of the ciphertext alphabet.

## What it is
A fixed substitution cipher maps each plaintext symbol to a single fixed ciphertext symbol using a permutation of the alphabet. Variants include the simple keyed substitution, Atbash (`A↔Z`), Affine (a linear permutation, see [[linear-mapping-ciphers]]), and Pigpen / dancing men glyph alphabets. The mapping is fixed across the whole message, so the statistics of the plaintext leak through unchanged — only the labels are renamed.

## Preconditions / where it applies
- CTF puzzles with long enough ciphertext (~50+ characters of natural language) for frequency analysis to converge
- Legacy logs / steganography puzzles that hide the substitution behind a glyph alphabet
- Quick sanity check before assuming something stronger is in use
- Contrast with [[shift-ciphers]] (one of 26 permutations) and [[vigenere-cipher]] (polyalphabetic)

## Technique
The keyspace is `26!` ≈ `4 × 10^26` — far too large to brute-force, but the structure of natural language collapses it instantly.

1. **Frequency match.** Count letters in the ciphertext. The most frequent ciphertext letter likely maps to `E`, then `T`, `A`, `O`, `I`, `N`, `S`, `H`, `R`. Single-letter words map to `A` or `I`. Two-letter words to `of, to, in, it, is, be, as, at, so, we`.
2. **Bigram / trigram match.** The most common English bigrams are `TH, HE, IN, ER, AN, RE, ON`. Trigrams: `THE, AND, ING, ENT, ION`. Look for repeated three-letter words preceded by spaces — almost always `THE`.
3. **Pattern words.** Words like `XXYYX` (consonant pattern) match a small dictionary set. The `quipqiup` solver and `cipher_solver` libraries automate via simulated annealing over quadgram log-likelihood.
4. **Refine.** Apply tentative mapping, look for partial English words, lock in confident substitutions, iterate.

Simulated-annealing fitness skeleton (quadgrams):

```python
def score(text, quadgram_logprob):
    s = 0
    for i in range(len(text) - 3):
        s += quadgram_logprob.get(text[i:i+4], FLOOR)
    return s
# propose: swap two letters in current key; accept if score improves
# or with probability exp(delta/T); cool T over iterations.
```

Atbash is a one-shot involution (`chr(0x5A - (ord(c)-0x41))`); always try it first when you see all-caps gibberish. Pigpen and similar glyph alphabets only swap the encoding layer — solve the underlying substitution after transcribing.

For affine ciphers `y = a·x + b mod 26`, brute-force `(a, b)` over the 12 valid `a` values (those coprime with 26) × 26 shifts = 312 keys.

## Detection and defence
- Length-preserving ciphertext that contains the same character set as the plaintext, with skewed distribution, is the giveaway
- "Defence" is to not use this for confidentiality — substitution ciphers offer none against any attacker with statistical tooling; treat them as obfuscation only
- For puzzles, longer ciphertexts make analysis trivial; very short ciphertexts may have multiple plausible decryptions

## References
- [Practical Cryptography — Substitution cipher](https://practicalcryptography.com/cryptanalysis/stochastic-searching/cryptanalysis-simple-substitution-cipher/) — quadgram-based solver
- [Singh — The Code Book](https://simonsingh.net/books/the-code-book/) — historical context and worked breaks
- [HackTricks — Cryptographic algorithms](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — recognition patterns
- [quipqiup](https://quipqiup.com/) — online substitution-cipher solver
