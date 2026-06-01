---
title: Shift ciphers (Caesar / ROT-n)
slug: shift-ciphers
---

> **TL;DR:** Single-key shift; 26 possible rotations make brute force one line of code.

## What it is
A shift cipher maps each letter to the letter `k` positions later in the alphabet, modulo the alphabet size: `E(x) = x + k mod 26`. Special case `k = 3` is the Caesar cipher; `k = 13` is ROT13 (self-inverse). ROT47 extends the idea to printable ASCII (`!` through `~`, 94 characters). All shift ciphers are the trivial subset of the [[linear-mapping-ciphers]] family with `a = 1` and a single-symbol key.

## Preconditions / where it applies
- Beginner CTF prompts, obfuscated spoiler text in forums (ROT13), trivial log scrambling
- Sanity check before trying anything more complex when the ciphertext is the same length as the plaintext and shares the alphabet
- Useful as a building block layer in multi-stage CTF puzzles (e.g. base64 of ROT13 of base64)

## Technique

Brute-force all 26 shifts; rank by English-likeness:

```python
def shift(s, k):
    out = []
    for c in s:
        if "a" <= c <= "z":
            out.append(chr((ord(c)-97+k) % 26 + 97))
        elif "A" <= c <= "Z":
            out.append(chr((ord(c)-65+k) % 26 + 65))
        else:
            out.append(c)
    return "".join(out)

for k in range(26):
    print(k, shift(ciphertext, k))
```

Pick the candidate with the lowest chi-squared distance from English letter frequencies, or the highest sum of log-quadgram probabilities. For ROT47:

```python
def rot47(s):
    return "".join(chr(33 + (ord(c) - 33 + 47) % 94) if 33 <= ord(c) <= 126 else c for c in s)
```

Identification cues:

- Length-preserving cipher, same alphabet as plaintext, frequency distribution shifted by a constant offset
- Distance between letter `E` of suspected plaintext and the most-frequent ciphertext letter often reveals `k`
- Single Unix command: `tr 'A-Za-z' 'N-ZA-Mn-za-m'` is ROT13

Known-plaintext: one matched letter gives `k` directly. Probable-word attack: if you know a common word appears, search every offset for that word to lock in `k`.

Variants: the keyed Caesar (a substitution preceded by a shift) collapses to a substitution cipher overall; solve via the [[fixed-substitution-ciphers]] workflow. The Vigenère cipher repeats shifts on a key cycle and is solved by period detection — see [[vigenere-cipher]].

## Detection and defence
- Trivially recognisable; do not use for confidentiality, only for obfuscation/spoiler-tagging
- If you find shift-cipher output in production traffic, it almost certainly indicates an opaque "obfuscation" layer hiding a real protocol — investigate the wrapped payload, not the shift
- The "defence" is to recognise that shift ciphers provide zero security; the keyspace is 26 (or 94 for ROT47), exhaustively searchable in microseconds

## References
- [Practical Cryptography — Caesar cipher](https://practicalcryptography.com/ciphers/caesar-cipher/) — formulas and break
- [HackTricks — Cryptographic algorithms](https://book.hacktricks.wiki/en/crypto-and-stego/cryptographic-algorithms/index.html) — recognition cues
- [dCode — Caesar / ROT solver](https://www.dcode.fr/caesar-cipher) — online brute-force tool
- [Singh — The Code Book](https://simonsingh.net/books/the-code-book/) — historical context
