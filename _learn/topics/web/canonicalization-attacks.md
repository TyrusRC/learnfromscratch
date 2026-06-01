---
title: Canonicalization attacks
slug: canonicalization-attacks
---

> **TL;DR:** Path / encoding / unicode normalisation differences let attacker reach a resource the access control thought it excluded.

## What it is
Two components in a request pipeline (proxy → app server → file system, or filter → router → renderer) each decode and normalise the path differently. The filter sees a "safe" string; the resolver sees a different one. The gap is the bug. Same class covers URL decoding rounds, unicode NFC/NFKC folding, Windows short names, double-slash, dotless filenames, and case folding.

## Preconditions / where it applies
- Reverse proxy / WAF that path-matches before the backend
- Static-file routing or path-based ACLs (`/admin/*` blocked)
- File-system code that calls a single normalisation step (`Path.GetFullPath`, `realpath`)
- Languages/frameworks with default unicode normalisation differences (Java `File`, Go `filepath.Clean`, .NET)

## Technique
Try every layer separately. Encode the dangerous character at level 1, level 2, level 3 — see which mix bypasses the filter.

```
/admin/users         → blocked by WAF
/admin%2fusers       → blocked  (single decode at WAF, matches)
/admin%252fusers     → bypass   (WAF sees %2f, backend decodes twice → /admin/users)
/Admin/users         → bypass if WAF is case-sensitive but backend isn't
/admin/./users       → bypass if WAF doesn't collapse dot-segments
/admin//users        → bypass if WAF treats // as different
/admin/users%00.jpg  → null-byte truncation (older runtimes)
```

Unicode tricks: turkish dotless ı (U+0131) → uppercases to `I` in Turkish locale, so `admın` may match `admin` post-folding. Fullwidth `／` (U+FF0F) → some normalisers fold to `/`. Combining marks `é` vs `é` NFC vs NFD give different byte sequences but compare equal under NFKC.

Windows short names: `C:\PROGRA~1` ≡ `C:\Program Files`. Path filters that blocklist `Program Files` miss the 8.3 alias.

Closely related: [[path-traversal]], [[lfi-rfi]], [[waf-bypass]].

## Detection and defence
- Log raw request line *and* normalised path — diff anomalies
- Decode-then-normalise *once*, reject if input contained `%2f`, `%5c`, `\`, `..`, null, or non-ASCII path bytes
- Match ACLs on the canonical post-normalisation form only
- Reject mixed-script identifiers (IDN homograph) for authentication-relevant paths
- WAF and backend must agree on normalisation rules — test with a fuzzer that knows both

## References
- [PortSwigger — Bypassing access controls](https://portswigger.net/web-security/access-control) — path normalisation cases
- [OWASP — Canonicalization, locale and unicode](https://owasp.org/www-community/vulnerabilities/Canonicalization,_locale_and_Unicode) — taxonomy
- [Orange Tsai — Breaking parser logic](https://blog.orange.tw/2018/01/) — proxy/backend differential exploitation
