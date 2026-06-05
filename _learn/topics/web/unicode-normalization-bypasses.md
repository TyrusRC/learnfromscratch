---
title: Unicode normalization bypasses
slug: unicode-normalization-bypasses
aliases: [unicode-attacks, nfkc-nfkd-bypass, homoglyph-attacks]
---

{% raw %}

> **TL;DR:** Unicode normalization (NFC/NFD/NFKC/NFKD) and case-folding rules differ between languages, libraries, and runtime layers. The classic Spotify Turkish "i" bug, account takeover via lowercase()-equivalence, mixed-script lookalikes, and the Trojan Source overlap attacks all share the same root: validate-now-then-canonicalise-later. Audit anywhere user input is compared, deduplicated, or used as a key.

## What it is
Unicode defines multiple "equivalent" representations of similar-looking text:
- **Normalization Form C (NFC)**: composed form, e.g., "é" as single codepoint U+00E9.
- **Normalization Form D (NFD)**: decomposed, e.g., "é" as U+0065 U+0301 (e + combining acute).
- **Normalization Form KC/KD**: compatibility decompositions — collapses visually-similar variants (e.g., "ﬃ" ligature → "ffi").
- **Case folding**: full case folding (`String.toLocaleLowerCase('tr')` lowercases "I" to "ı" in Turkish — different bytes than English lowercase "i").

When code compares strings without consistent normalization, attacker exploits the gap.

## Classic bug patterns

### 1. Account takeover via lowercase mismatch
- App stores email lowercased: `email.toLowerCase()`.
- User registers `Admin@SITE.com` → stored as `admin@site.com`.
- Attacker registers `Aᴅᴍɪɴ@site.com` (smallcaps Unicode chars) → `tolowercase` may not normalize → different bytes → bypass uniqueness check → "admin@site.com" looks the same to readers but differs in storage.

### 2. The Turkish "i" (Spotify CVE)
- Username system stores `bigbird` as username. Lookup uses `username.toLowerCase()` → matches.
- Attacker registers username with `İ` (U+0130, capital "I" with dot above, common in Turkish).
- `'BİGBIRD'.toLowerCase('tr-TR')` → `'bigbird'` (the dotted I lowercases to plain i).
- `'BİGBIRD'.toLowerCase('en')` → `'bi̇gbird'` (with combining dot).
- Two equally-valid lowercase results → bypass uniqueness.

### 3. Email normalisation gap
- Email policy: "+" tags allowed (`alice+ads@x.com` routes to `alice@x.com`).
- Code strips `+...@` to canonicalise.
- Attacker uses U+FF0B (full-width plus sign) → looks like `+` but code doesn't strip → unique email → multiple accounts on same mailbox → privilege escalation.

### 4. Homoglyph login
- Domain `apple.com` vs `аpple.com` (Cyrillic `а` U+0430).
- IDN homograph at the URL level + email username homograph for password reset.

### 5. Path traversal via overlong UTF-8
- Old IIS / web servers accepted overlong UTF-8: 3-byte encoding of "/" (`0xE0 0x80 0xAF`) bypassed normalisation that only checked single-byte `0x2F`.
- Mostly historical (CVE-2000-0884), but resurfaces in custom path validators.

### 6. NFKC collapse vs validation
- Validator rejects "javascript:" in user-supplied URLs.
- Attacker supplies `ｊａｖａｓｃｒｉｐｔ:` (full-width chars, U+FF4A...).
- Validator (string-compares "javascript") passes.
- Browser NFKC-normalises before parsing URL → fires `javascript:` → XSS.

### 7. RTL override / Trojan Source
- Unicode control char U+202E (right-to-left override) reverses display of subsequent chars.
- Code `if (admin) { harmless‮evil_action‭ }` displays reversed; reviewers miss it.
- See [Trojan Source paper](https://trojansource.codes/).
- Repo / IDE warnings now flag U+202E-class control chars.

### 8. Bidirectional algorithm attacks
- Mixing LTR and RTL scripts can hide content from visual review.
- `filename.exe` displayed but parsed as `filenam‮fdp.exe` — extension confusion.

### 9. Zero-width characters
- U+200B (zero-width space), U+200C (zero-width non-joiner), U+200D (zero-width joiner), U+FEFF (BOM).
- "admin​" lookups differ from "admin" — bypass denylists.
- Email "ad​min@x.com" registers as different from "admin@x.com" but visually identical.

### 10. Punycode / IDN
- `xn--mnich-kva.example.com` (München) ↔ `münich.example.com`.
- App stores in one form, displays in another, validates in third — confusion possible.

### 11. Path / filename canonicalisation
- Filesystems normalise: macOS HFS+ stores NFD, APFS as-is. Windows NTFS as-is. Linux generally as-is.
- App validates filename in NFC; OS stores NFD; lookup with NFC fails; access control bypass possible.

### 12. URL percent-encoding double-decode
- `%2e%2e%2f` (`../`) — one decode round.
- `%252e%252e%252f` — two-round encoding; some servers decode twice (Apache mod_rewrite, certain CDNs).
- Bypasses single-decode validators.

## Audit workflow

### Source review
```bash
# Find string equality / inclusion checks on user input
rg -n '\.toLowerCase|\.toUpperCase|\.normalize\(' src/
# Look for uniqueness checks
rg -n 'unique|where.*username.*=|where.*email.*=' src/
# Path/URL normalisation
rg -n 'path\.normalize|filepath\.Clean|realpath|os\.path\.abspath' src/
# Check for normalize form specified
rg -n '\.normalize\(["\x27]NF[CDK][CD]?["\x27]\)' src/
```

### Tests
For each comparison code path:
- Test with NFC vs NFD versions of input.
- Test with capital İ vs i.
- Test with full-width vs ASCII.
- Test with homoglyphs.
- Test with zero-width chars.
- Test with RTL override.

## Defence patterns

### Canonicalise at the boundary
- All user input passes through a normalize-and-validate step at intake.
- Single canonical form (NFKC + casefold) stored.
- Output rendered as canonical.

### Reject suspicious chars
- Block control chars (categories `Cc`, `Cf`) in identifiers.
- Block mixed-script identifiers (Unicode Standard Annex 39).
- Block zero-width characters in usernames/emails.

### Use Punycode for IDN
- Internal storage in Punycode; display in Unicode after verifying script.

### Verify after normalisation
- Apply normalization first, validate second.
- Never validate, then normalize, then use.

## Tooling
- Python: `unicodedata.normalize('NFKC', s)`.
- JS: `s.normalize('NFKC')`.
- Java: `Normalizer.normalize(s, Normalizer.Form.NFKC)`.
- Go: `golang.org/x/text/unicode/norm`.
- Rust: `unicode-normalization` crate.
- Static: `gosec` has rules; Semgrep has community rules for unsafe normalisation.

## References
- [Unicode Technical Report #36 — Security Considerations](https://www.unicode.org/reports/tr36/)
- [Unicode Technical Standard #39 — Security Mechanisms](https://www.unicode.org/reports/tr39/)
- [Trojan Source](https://trojansource.codes/)
- [Spotify CVE writeup — Turkish "i"](https://labs.spotify.com/2013/06/18/creative-usernames/)
- [PortSwigger — Unicode in URLs](https://portswigger.net/research)
- See also: [[canonicalization-attacks]], [[path-traversal]], [[host-header-injection]], [[crlf-injection]]

{% endraw %}
