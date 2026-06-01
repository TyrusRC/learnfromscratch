---
title: Token impersonation
slug: token-impersonation
---

> **TL;DR:** If you sit in a service account context that holds SeImpersonatePrivilege (IIS, MSSQL, scheduled tasks), trick a SYSTEM-owned process into authenticating to a socket you control, capture its token via `ImpersonateNamedPipeClient` or `RpcImpersonateClient`, and spawn a process as SYSTEM with `CreateProcessWithTokenW`.

## What it is
Windows lets a server thread "wear" the security context of a client that has connected to it. The privilege that gates this is SeImpersonatePrivilege, and it is granted by default to LocalService, NetworkService, and any account assigned the "Impersonate a client after authentication" right — which is almost every service account. The Potato family of exploits abuses this by coercing a SYSTEM service to authenticate to an attacker-controlled endpoint, then impersonating that connection. See [[tokens-and-privileges]] for the underlying token model.

## Preconditions / where it applies
- Code execution as a service account holding SeImpersonatePrivilege (check with `whoami /priv`)
- A SYSTEM service willing to call back to a local endpoint — Spooler (PrintSpoofer), RPC/DCOM (RoguePotato, JuicyPotatoNG, GodPotato), WebClient/WebDAV (PetitPotam-style on a local pipe), CertSrv, etc.
- Local network reachability between the attacker process and the coerced caller (named pipe or loopback TCP)

## Technique
PrintSpoofer (simple, requires Spooler enabled — still useful on workstations):

```cmd
PrintSpoofer.exe -i -c "cmd /c whoami"
:: → nt authority\system
```

It calls `RpcRemoteFindFirstPrinterChangeNotificationEx` against the local Spooler RPC endpoint with a UNC-style path that forces Spooler (SYSTEM) to connect back to an attacker-named pipe; on connect the attacker calls `ImpersonateNamedPipeClient` and `CreateProcessAsUser`.

GodPotato (works post-Spooler-disabled, uses RPC SS COM):

```cmd
GodPotato -cmd "cmd /c whoami"
```

Generic flow regardless of variant:

1. Acquire SeImpersonatePrivilege (default in IIS app pool, MSSQL service, etc.).
2. Stand up a server endpoint (named pipe `\\.\pipe\<rand>` or TCP loopback).
3. Trigger a SYSTEM-owned service to authenticate to that endpoint via RPC/DCOM/Spooler coercion.
4. On the incoming connection call `ImpersonateNamedPipeClient` → `OpenThreadToken` → `DuplicateTokenEx(TokenPrimary)` → `CreateProcessWithTokenW`.

The historical timeline matters: RottenPotato/JuicyPotato (DCOM loopback marshalling) → patched 2019 → RoguePotato (OXID resolver redirect) → PrintSpoofer/SeBatchLogonRight bypasses → JuicyPotatoNG, GodPotato, EfsPotato, DCOMPotato. Microsoft hardens specific RPC interfaces each round; a new variant pops within months.

## Detection and defence
- Remove SeImpersonatePrivilege from non-essential service accounts; never grant it to interactive users
- Disable Print Spooler on servers that do not print
- Sysmon event 1 with parent IIS/SQL spawning `cmd.exe`/`powershell.exe` running as SYSTEM is a strong signal
- EDRs watch named-pipe-impersonation API sequences and DCOM OXID anomalies
- Application Whitelisting (WDAC) blocks attacker binaries in the IIS app-pool directories
- Run services as virtual accounts (NT SERVICE\<svc>) or gMSAs and audit `Impersonate a client after authentication` user-right assignments

## References
- [HackTricks — RoguePotato/PrintSpoofer](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/roguepotato-and-printspoofer.html) — variants and usage
- [itm4n — PrintSpoofer writeup](https://itm4n.github.io/printspoofer-abusing-impersonate-privileges/) — original technique post
- [GodPotato — BeichenDream/GodPotato](https://github.com/BeichenDream/GodPotato) — current-gen variant
