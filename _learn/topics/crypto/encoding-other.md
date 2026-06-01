---
title: Other encodings
slug: encoding-other
---

> **TL;DR:** URL, HTML entity, Punycode, quoted-printable, Morse, Brainfuck — recognise the alphabet, recover the plaintext.

## What it is
Encodings are not encryption — they map data into a constrained alphabet for transport or display. They show up constantly in CTFs and bug bounty work: WAF bypass via URL/Unicode double-encoding, phishing domains using Punycode homoglyphs, exfil disguised as Morse or whitespace, and CTF puzzle layers wrapped in esolang transforms. Recognising the alphabet is half the job; the rest is feeding it to the right decoder.

## Preconditions / where it applies
- Web payloads: URL `%xx`, HTML entities `&#xNN;`/`&name;`, JS `\uXXXX`, CSS `\NN`
- Email transport: quoted-printable (`=NN`), `=?UTF-8?B?...?=` MIME words
- Domain spoofing: Punycode `xn--` IDN labels
- CTF fluff: Morse, Brainfuck, Ook!, Whitespace, Malbolge, Piet, Cistercian numerals, baudot, NATO phonetic, leet
- For Base16/32/45/58/62/64/85 see [[encoding-base-family]]

## Technique

Identification cheats:

- `%` followed by two hex digits → URL/percent encoding (`urllib.parse.unquote`)
- `&#NN;` or `&#xHH;` or `&name;` → HTML entities (`html.unescape`)
- `=` at end of every short line, mixed-case alphanum + `=NN` → quoted-printable (`quopri.decodestring`)
- Hostname starting `xn--` → Punycode (`idna.decode`, `.encode("idna")`)
- `.- -... -.-.` with spaces/slashes → Morse
- `+`, `-`, `<`, `>`, `[`, `]`, `.`, `,` only → Brainfuck
- Only spaces, tabs, newlines → Whitespace language
- `Ook.`, `Ook!`, `Ook?` triples → Ook!
- Five-bit groups of letters → baudot/ITA-2

Quick polyglot decoder skeleton:

```python
import urllib.parse, html, quopri, codecs, idna, base64
def peel(s):
    candidates = []
    try: candidates.append(("url", urllib.parse.unquote(s)))
    except: pass
    try: candidates.append(("html", html.unescape(s)))
    except: pass
    try: candidates.append(("qp", quopri.decodestring(s).decode()))
    except: pass
    try: candidates.append(("rot13", codecs.decode(s, "rot13")))
    except: pass
    return candidates
```

Web attack uses:

- **WAF bypass via double URL encoding.** `%2527` → `%27` → `'`. Some WAFs decode once, the app server decodes twice.
- **Unicode normalization confusion.** `ＡＤＭＩＮ` (fullwidth) NFKC-normalises to `ADMIN`; bypasses denylists. Punycode lookalike domains (`xn--pple-43d.com`) for phishing.
- **HTML entity smuggling.** `&#x27;` survives a denylist that filters literal quotes but is decoded by the browser. Combine with [[encoding-base-family]] for layered obfuscation.
- **Quoted-printable smuggling.** `=2E` survives some email filters, becomes `.` for URL recovery on the client.

CTF layered puzzles: try `rot13 → base64 → reverse → hex → ascii`. CyberChef's "Magic" operation automates many transitions; for offline use, `xortool` and `featherduster` help identify.

## Detection and defence
- Canonicalise input (NFKC for Unicode, single-pass URL decode) **before** any allow/deny decisions
- Reject or flag IDN labels mixing scripts (Latin + Cyrillic in one label) — browsers already warn
- Mail gateways should decode quoted-printable and MIME words before content scanning
- Log raw + decoded forms separately so analysts can audit decoding mismatches

## References
- [RFC 3986 §2.1](https://www.rfc-editor.org/rfc/rfc3986#section-2.1) — percent-encoding
- [RFC 3492](https://www.rfc-editor.org/rfc/rfc3492) — Punycode
- [HackTricks — Stego and encoding tricks](https://book.hacktricks.wiki/en/crypto-and-stego/stego-tricks.html) — recognition patterns
- [GCHQ CyberChef](https://gchq.github.io/CyberChef/) — interactive multi-encoding decoder
