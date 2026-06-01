---
title: Tokens and privileges
slug: tokens-and-privileges
---

> **TL;DR:** Every Windows thread acts under an access token (user SID + group SIDs + privileges + integrity level). Privileges like SeDebugPrivilege, SeImpersonatePrivilege, SeBackupPrivilege, SeRestorePrivilege, SeTcbPrivilege are direct escalation primitives — knowing which one is enabled tells you what attack is available.

## What it is
A Windows access token is the kernel structure that answers "who is this thread and what can it do?". The LSA builds it at logon from the SAM/AD account, group memberships, and rights policies. Two flavours exist:

- Primary token — attached to a process; defines the default security context for new threads.
- Impersonation token — attached to a thread to "wear" another principal's identity for the duration of a call.

A token also carries an Integrity Level (Low/Medium/High/System) and a Mandatory Label, which gate write access to lower-IL objects, and a list of named privileges in three states: Removed, Disabled, Enabled. Many privileges are Disabled by default but trivially enabled with `AdjustTokenPrivileges` if granted.

## Preconditions / where it applies
- Local Windows host with shell or code execution under any account
- Use `whoami /priv` and `whoami /groups` as first-stop enumeration; a single `Enabled` or even `Disabled` high-value privilege often is the entire escalation path
- Service accounts (IIS app pool, MSSQL, scheduled tasks) almost always hold one of the dangerous privileges by policy

## Technique
The privileges that matter, and what they buy you:

- **SeImpersonatePrivilege** — required by [[token-impersonation]] Potato chain. Default on LocalService/NetworkService and most service accounts.
- **SeAssignPrimaryTokenPrivilege** — pair with impersonation to `CreateProcessAsUser`. Often granted alongside SeImpersonate.
- **SeDebugPrivilege** — open any process (including LSASS) for `PROCESS_VM_READ`/`PROCESS_ALL_ACCESS`. Direct path to [[credential-dumping]]. Default for local admins.
- **SeBackupPrivilege / SeRestorePrivilege** — read/write any file ignoring DACLs via `FILE_FLAG_BACKUP_SEMANTICS`. Dump SAM/SYSTEM hives, drop binaries in protected dirs.
- **SeTakeOwnershipPrivilege** — set yourself as owner of any object, then rewrite its DACL.
- **SeLoadDriverPrivilege** — load a signed kernel driver; chain with a known vulnerable driver (loldrivers.io) to get kernel exec — this is the canonical BYOVD entry point.
- **SeTcbPrivilege** — "act as part of the OS"; rare, lets you forge tokens with `LsaLogonUser`.
- **SeManageVolumePrivilege** — recently weaponised for arbitrary file write via FsControl junctions.

Enable a disabled-but-granted privilege:

```c
HANDLE t;
TOKEN_PRIVILEGES tp = {1};
LookupPrivilegeValueW(NULL, L"SeDebugPrivilege", &tp.Privileges[0].Luid);
tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &t);
AdjustTokenPrivileges(t, FALSE, &tp, 0, NULL, NULL);
```

Integrity levels gate UAC ([[user-account-control]]): a Medium-IL admin token cannot write to HKLM by default — that is why a UAC bypass is needed to elevate to High-IL inside the same session.

## Detection and defence
- Audit privilege use: enable "Audit Sensitive Privilege Use" (event 4673/4674) — noisy but catches abnormal SeDebug usage
- Remove SeImpersonate from non-essential service accounts; never grant SeDebug to interactive users
- Use Just Enough Administration / Protected Users; remove `BUILTIN\Administrators` from sensitive privilege assignments
- WDAC / driver block list to neutralise SeLoadDriver + BYOVD
- Sysmon event 1 with command lines invoking `whoami /priv` + immediate elevation tooling is a strong sequence

## References
- [HackTricks — abusing tokens](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/privilege-escalation-abusing-tokens.html) — practical privilege-by-privilege catalogue
- [Microsoft — Access tokens](https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens) — official structure reference
- [Microsoft — Privilege constants](https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants) — every Se* name and meaning
