---
title: Dangerous PHP sinks reference
slug: dangerous-php-sinks
---

> **TL;DR:** Reference list of PHP function families that turn tainted strings into RCE, LFI/RFI, command exec, SQLi or object instantiation. Grep these first when auditing — most PHP CVEs land in one of these buckets.

## What it is
A "sink" is a function whose output crosses a trust boundary — e.g. into the OS, the interpreter, the database, or the file system. PHP ships with a large dangerous-function surface, much of it inherited from PHP4 days. Grepping for these names + checking whether arguments are user-influenced is the fastest path to bugs.

## Preconditions / where it applies
- PHP source code (any version — many sinks predate PHP 5)
- Tainted variables — `$_GET`, `$_POST`, `$_COOKIE`, `$_REQUEST`, `$_SERVER` (headers), uploaded files, DB rows previously populated by users
- Framework helpers that wrap the same sinks (Laravel `Process::run`, Symfony `Process`, CodeIgniter `eval` helpers)

## Technique
Grep aggressively, then triage by sink class.

**Code execution** — instant RCE if any arg is tainted:
```
eval | assert | create_function | preg_replace .*/e (PHP < 7)
mb_ereg_replace .*/e | mb_eregi_replace .*/e
```

**OS command execution** — RCE via shell:
```
system | exec | shell_exec | passthru | popen | proc_open
backtick operator `...` | pcntl_exec
```

**File inclusion** — RCE via LFI/RFI, log poisoning, phar://:
```
include | include_once | require | require_once
```

**Deserialisation** — POP-chain RCE if a gadget exists (see [[php-deserialization-gadgets]]):
```
unserialize | Phar:: (auto-deserialises metadata on file-stat sinks)
file_exists / file_get_contents / fopen / md5_file / filemtime on phar:// URL
```

**SQL** — string-concat queries hit `mysqli_query | mysql_query | PDO->query | pg_query`. Parameterised `prepare/execute` is safe; concatenated `prepare` is not.

**Filesystem read/write** — arbitrary read/write:
```
fopen | file_get_contents | file_put_contents | readfile | move_uploaded_file
copy | rename | unlink | chmod | symlink
```

**Header / response splitting**: `header()` with `\r\n` in user input on PHP < 5.1.2; `setcookie()` similarly.

**Variable injection** — overwrites locals, often leads to auth bypass:
```php
extract($_GET);           // $_GET[is_admin]=1 wins
parse_str($qs);           // same primitive
import_request_variables  // legacy
```

**Mail / SMTP injection** — `mail($to, $subject, $body, $headers)` with tainted `$headers` allows CRLF injection of extra recipients and arbitrary `-X` sendmail flags via 5th arg.

**XXE** — `simplexml_load_string|DOMDocument::loadXML|libxml_disable_entity_loader(false)` enables external entities.

## Detection and defence
- WAFs see common payloads (`;id;`, `php://input`, `data://`) — log and alert on these strings hitting params
- `disable_functions` in `php.ini` for the worst sinks (`eval` cannot be disabled — needs Suhosin/Snuffleupagus)
- `allow_url_include=Off`, `allow_url_fopen=Off` kills RFI and `phar://`-over-HTTP
- Open_basedir restricts filesystem sinks
- Use prepared statements, `escapeshellarg` (not `escapeshellcmd`), `is_uploaded_file`, and allowlist file extensions

## References
- [PHP manual — disable_functions](https://www.php.net/manual/en/ini.core.php#ini.disable-functions) — official sink disabling list
- [HackTricks — PHP RCE function list](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/php-tricks-esp/php-useful-functions-disable_functions-open_basedir-bypass.html) — function-by-function notes
- [PayloadsAllTheThings — PHP injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/PHP%20Juggling) — payload corpus
- [OWASP Code Review Guide — PHP](https://owasp.org/www-project-code-review-guide/) — review checklist
