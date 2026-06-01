---
title: Classical ciphers — overview
slug: classical-ciphers-overview
---

> **TL;DR:** Pre-computer ciphers split into substitution (Caesar, Vigenere, Playfair, mono-alphabetic) and transposition (rail fence, columnar) families; recognise the family from ciphertext shape, then apply the right break.

## What it is
Classical ciphers act on letters, not bits. Substitution ciphers map symbols to other symbols (mono- or poly-alphabetic). Transposition ciphers permute symbol order without changing the alphabet. Both leave statistical fingerprints — letter frequencies, index of coincidence, n-gram distributions — that modern analysis tears apart in milliseconds. They appear in CTFs as warm-ups, in puzzle hunts, and occasionally hidden inside binaries or steganography layers.

## Preconditions / where it applies
- Ciphertext is ASCII letters or digits, length usually 30+ characters (less makes statistics noisy).
- No headers/magic bytes — first run [[encoding-base-family]] decoders to peel encoding layers.
- Optional crib: a known word ("FLAG", "CTF", language hint).

## Technique
Triage by quick statistics, then branch:

1. **Index of coincidence (IC)**: English ~0.067, random ~0.038. IC near 0.067 → mono-alphabetic substitution or transposition. IC near 0.04 → poly-alphabetic ([[vigenere-cipher]], Beaufort).
2. **Letter histogram**: matches English-shifted → [[shift-ciphers]] (try all 25 Caesar offsets). Matches English but reordered → [[fixed-substitution-ciphers]] (use `quipqiup` or hill-climbing solver). Flat → poly-alphabetic or transposition.
3. **Transposition check**: histogram is exactly English but plaintext is unreadable → try rail-fence (2..10 rails), columnar transposition (try key lengths 2..12 sorted by anagram score).
4. **Bigram-aware**: digrams like `TH`, `HE`, `IN` map to a single Playfair pair → spot 5x5 grid hints (no `J`, pairs of letters).
5. **Linear/affine variants**: see [[linear-mapping-ciphers]] for `y = a·x + b mod 26`.

```python
from collections import Counter
def ic(s):
    s = [c for c in s.upper() if c.isalpha()]
    N = len(s); f = Counter(s)
    return sum(n*(n-1) for n in f.values()) / (N*(N-1))
```

Universal toolkits: [CyberChef](https://gchq.github.io/CyberChef/), [dCode](https://www.dcode.fr/), `cipher-identifier` libraries.

## Detection and defence
- Classical ciphers offer no real confidentiality — never use them for anything but puzzles and CTF flavour.
- For obfuscation use case (e.g. cookies, config), classical ciphers are trivially reversed offline; even simple frequency analysis on captured tokens breaks them.

## References
- [Practical Cryptography — Cipher list](http://practicalcryptography.com/ciphers/) — concise descriptions per cipher.
- [dCode](https://www.dcode.fr/cipher-identifier) — auto-identifier for unknown ciphertexts.
- [CryptoHack — Introduction](https://cryptohack.org/challenges/introduction/) — guided exposure to the classic families.
