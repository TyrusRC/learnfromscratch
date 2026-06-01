---
title: Base encoding family
slug: encoding-base-family
---

> **TL;DR:** Base16/32/58/64/85/91 are reversible byte-to-text encodings — not cryptography; they exist to ferry binary through text channels, and you peel them before doing any real crypto analysis.

## What it is
Base-N encodings map N-bit groups of input to printable characters from a chosen alphabet. They expand input length predictably and trade compactness for printability. Recognising one is the first reflex when staring at a suspicious blob: shape, alphabet, and length-mod hints identify the family. Padding (`=`) is a strong signal for the RFC 4648 family. See [[encoding-other]] for the URL/HTML/quoted-printable cousins.

## Preconditions / where it applies
- Input is printable ASCII with no obvious cipher structure.
- Length and alphabet hint at a specific base.
- Multi-layer challenges: base64 over base32 over base85 is common stego/CTF flavour.

## Technique
Quick recognition table:

| Alphabet hint | Likely base | Length mod |
|---|---|---|
| `0-9 a-f` (case-insensitive) | base16 | even |
| `A-Z 2-7`, `=` pad | base32 (RFC 4648) | mod 8 = 0 |
| `A-Z a-z 0-9 + /`, `=` pad | base64 | mod 4 = 0 |
| `A-Z a-z 0-9 - _` | base64url | mod 4 = 0 or no pad |
| `0-9 A-Z a-z` minus `0 O I l` | base58 (Bitcoin/IPFS) | variable |
| `! "-/ 0-9 : ;-? @-Z [-` _ a-z {-}` ` | base85 / Ascii85 | mod 5 |
| 91 printable, `"` or `'` excluded | base91 | variable |

Workflow:

1. Strip whitespace/newlines, count unique characters, check padding.
2. Decode with the matching family. If output is still text, recurse.
3. Magic-byte sniff the decode (`PK` → zip, `\x1f\x8b` → gzip, `\x89PNG` → PNG).

```bash
echo -n "SGVsbG8=" | base64 -d
echo "JBSWY3DPEBLW64TMMQ======" | base32 -d
python3 -c "import base64,sys; sys.stdout.buffer.write(base64.b85decode(sys.argv[1]))" 'cmZ}Hb98ce'
```

```bash
# Recursive peeler
while read -r line; do
  for f in base64 base32 base16; do
    out=$(printf %s "$line" | $f -d 2>/dev/null) && echo "$f: $out"
  done
done < blob.txt
```

[CyberChef "Magic"](https://gchq.github.io/CyberChef/) auto-detects most layers.

## Detection and defence
- Encodings are not security: do not treat base64 cookies/parameters as confidential.
- Log decoded payloads in WAFs/IDS so signature engines can match suffix-encoded malware (`powershell -enc <base64>`).
- For Bitcoin address validation reject characters outside the base58 alphabet to catch typos.

## References
- [RFC 4648 — Base16/32/64](https://datatracker.ietf.org/doc/html/rfc4648) — canonical spec.
- [CyberChef](https://gchq.github.io/CyberChef/) — interactive encoder/decoder.
- [Wikipedia — Binary-to-text encoding](https://en.wikipedia.org/wiki/Binary-to-text_encoding) — family overview.
