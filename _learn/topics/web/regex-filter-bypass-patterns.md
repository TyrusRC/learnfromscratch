---
title: Regex filter bypass patterns
slug: regex-filter-bypass-patterns
aliases: [regex bypass, ReDoS, regex evasion, filter bypass regex]
---

> **TL;DR:** Application-layer regex filters are among the most brittle security controls — bypass them with null bytes, newline injection, Unicode normalisation, double encoding, case tricks, and multiline flag abuse. Catastrophic backtracking (ReDoS) turns the filter itself into a DoS vector.

## What it is
Web apps frequently use regex to validate input, enforce allowlists/denylists, or strip dangerous patterns (e.g., `<script>`, `../`, `UNION SELECT`). These filters break whenever the regex engine's behaviour diverges from the developer's mental model — edge cases in anchoring, Unicode, encoding, and backtracking are the attack surface.

## Preconditions / where it applies
- Any server-side or client-side input filter implemented via regex
- WAF rules written in PCRE / RE2 / POSIX regex
- OSWE-relevant: PHP `preg_match`, Python `re.match` vs `re.search`, Java `Pattern`, Node.js `/regex/` on user input

## Technique

### 1 — ReDoS (catastrophic backtracking)
Regex with nested quantifiers cause exponential backtracking in NFA engines (PCRE, Python `re`, Java `Pattern`, JavaScript). Classic patterns:

```
(a+)+$        ← payload: "aaaaaaaaaaaaaaaaX"
(a|aa)+$      ← payload: "aaaaaaaaaaaaaaaaX"
([a-zA-Z]+)*$ ← payload: long string ending with non-alpha
```

```bash
# quick test with Python
python3 -c "import re,time; s=time.time(); re.match(r'(a+)+\$','a'*28+'!'); print(time.time()-s)"
```

Impact: thread/process hang → application DoS. In Node.js (single-threaded), one request freezes the event loop.

### 2 — Null byte injection (`%00`)
Languages with C-string semantics (older PHP, Perl) truncate at `\x00`. The regex validates before the null byte, but the downstream sink processes past it:

```
malicious.php%00.jpg    # regex sees .jpg, PHP fopen sees .php
```

PHP < 5.3.4 `include()` and `file_get_contents()` are classic victims. See [[lfi-to-rce-chains]].

### 3 — Newline injection / `$` anchor bypass
`$` matches end-of-string **or before a trailing `\n`** in most engines by default:

```python
import re
re.match(r'^[a-z]+$', "valid\n<script>alert(1)</script>")  # matches!
```

Fix requires `\A...\z` anchors (Ruby/Python) or stripping newlines before matching. PHP `preg_match('/^pattern$/', $input)` is vulnerable — use `\A...\z` or the `D` modifier.

### 4 — Case sensitivity bypass
Regex without `/i` flag misses mixed-case:

```
# filter blocks: /union\s+select/
UnIoN SeLeCt 1,2,3--
```

WAF bypass: `<ScRiPt>`, `<iMg SrC=x oNeRrOr=alert(1)>`.

### 5 — Unicode normalisation bypass
Input passes through a normalisation layer *after* the regex check. Fullwidth characters (`＜` = `<`, `＞` = `>`) pass the ASCII regex, then normalise to their ASCII equivalents downstream:

```
＜script＞alert(1)＜/script＞    # fullwidth < and >
```

Also exploitable: homoglyphs (`а` Cyrillic vs `a` Latin), combining characters, NFKC/NFKD normalisation. See [[character-restriction-bypass]].

### 6 — Double URL encoding
Filter decodes once, but the app decodes a second time:

```
%252e%252e%252f  →  %2e%2e%2f  →  ../
%253c%2573%2563%2572%2569%2570%2574%253e  →  <script>
```

Relevant when WAF sits in front of an app that also URL-decodes. See [[path-traversal]].

### 7 — Character class escapes
Regex `\d` in Python 3 / Java / .NET matches Unicode digits (e.g., `٣` Arabic-Indic 3), not just `[0-9]`. Developers assume ASCII. Similarly, `\s` matches exotic whitespace like ` `, ` `, ` ` — line/paragraph separators that can break parsing.

### 8 — Multiline flag abuse (`/m`)
With `/m`, `^` and `$` match at every line boundary, not just start/end of string:

```php
// Intended: block anything containing "admin"
preg_match('/^(?!.*admin)/m', "user\nadmin")  // matches "user" line → bypass
```

### 9 — `re.match` vs `re.search` (Python)
`re.match` checks only at start of string. A denylist using `re.match(r'bad_pattern', input)` is bypassed by prepending benign content:

```python
re.match(r'javascript:', 'safe\njavascript:alert(1)')  # None — bypass
```

## Detection and defence
- Use a well-tested allowlist of known-good characters rather than a denylist regex
- Anchor with `\A...\z` (not `^...$`) to match full string
- Always set explicit flags (`/i`, `/s`); avoid `/m` for security regexes
- Limit input length before regex evaluation (mitigates ReDoS)
- Use RE2 / Rust `regex` (linear-time guarantee, no backtracking) for security-critical paths
- Normalise and decode input **before** applying the regex, not after
- Static analysis: `eslint-plugin-security` detects unsafe regexes in JS; `semgrep` has ReDoS rules

See also [[character-restriction-bypass]], [[xss]], [[sql-injection]], [[waf-bypass]].

## References
- [OWASP — ReDoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS) — backtracking theory + examples
- [HackTricks — Regex bypass](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/regular-expression-denial-of-service-redos.html) — bypass catalogue
- [PortSwigger — WAF bypass cheatsheet](https://portswigger.net/web-security/essential-skills/obfuscating-attacks-using-encodings) — encoding evasion
