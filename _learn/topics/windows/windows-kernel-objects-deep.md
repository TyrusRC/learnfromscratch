---
title: Windows kernel objects — deep
slug: windows-kernel-objects-deep
aliases: [windows-objects-deep, kernel-objects-windows]
---

> **TL;DR:** Windows kernel objects are the unit of currency for both offense and defense on Windows. Processes, threads, tokens, sections, files, mutants, jobs, drivers, and devices all live in the Object Manager namespace and are reached via handles. Understanding `_OBJECT_HEADER`, the handle table in `_EPROCESS`, security descriptors, and how the pool allocates these structures unlocks both UAF exploitation and EDR telemetry interpretation. Read alongside [[windows-kernel-architecture]], [[kernel-objects-and-irps]], [[windows-processes-and-threads]], and [[hevd-uaf-walkthrough]].

## Why it matters

Almost every meaningful Windows operation crosses a kernel object boundary. Opening a file produces a `File` handle backed by a `_FILE_OBJECT`. Spawning a process creates `_EPROCESS` plus `_ETHREAD`, each referenced by handles in the parent. Cross-process injection requires duplicating a `Process` handle with `PROCESS_VM_WRITE`. EDR vendors hook `PsSetCreateProcessNotifyRoutineEx`, `ObRegisterCallbacks`, and minifilters precisely because the object model is the universal choke point.

From an exploit-dev angle, kernel object lifetimes and pool placement drive nearly every modern Windows LPE chain: handle table corruption, type confusion on object headers, pipe attribute spraying, and `_TOKEN.Privileges` overwrites all rely on knowing exactly how these structures are laid out and allocated. See [[hevd-uaf-walkthrough]] for a hands-on UAF and [[windows-driver-ioctl-audit]] for the attack surface that reaches these primitives.

## Classes of objects

### The Object Manager namespace

`\` is the root. Notable subtrees:

- `\Device\` — device objects exposed by drivers; `\Device\HarddiskVolume1`, `\Device\Afd`.
- `\GLOBAL??\` — DOS-name symbolic links (`C:` -> `\Device\HarddiskVolume3`).
- `\BaseNamedObjects\` and `\Sessions\<n>\BaseNamedObjects\` — user-mode named mutants, events, sections.
- `\KnownDlls\` — pre-mapped section objects for trusted DLLs; abused historically by KnownDlls hijacking.
- `\ObjectTypes\` — one entry per object type (Process, Thread, Token, File, Section, ...).
- `\Driver\` and `\FileSystem\` — `_DRIVER_OBJECT` instances.

Explore live with WinObj from Sysinternals or programmatically via `NtQueryDirectoryObject`.

### Core object types

| Type | Backing struct | Typical handle rights |
|------|----------------|-----------------------|
| Process | `_EPROCESS` | PROCESS_VM_READ/WRITE, PROCESS_CREATE_THREAD, PROCESS_DUP_HANDLE |
| Thread | `_ETHREAD` | THREAD_SET_CONTEXT, THREAD_SUSPEND_RESUME |
| Token | `_TOKEN` | TOKEN_DUPLICATE, TOKEN_IMPERSONATE, TOKEN_ADJUST_PRIVILEGES |
| File | `_FILE_OBJECT` | FILE_READ_DATA, FILE_WRITE_DATA, SYNCHRONIZE |
| Section | `_SECTION_OBJECT` | SECTION_MAP_READ/WRITE/EXECUTE |
| Mutant/Event/Semaphore | dispatcher headers | SYNCHRONIZE, MUTANT_QUERY_STATE |
| Job | `_EJOB` | JOB_OBJECT_ASSIGN_PROCESS |
| Driver/Device | `_DRIVER_OBJECT`, `_DEVICE_OBJECT` | n/a — accessed via IRPs, see [[kernel-objects-and-irps]] |
| Pipe | `_FILE_OBJECT` + NPFS | named-pipe ACL bits |

### Object header and security descriptor

Every kernel object is preceded by an `_OBJECT_HEADER`. Key fields:

- `PointerCount` and `HandleCount` — reference counting; UAFs typically corrupt or race these.
- `TypeIndex` — XOR-cookied index into `nt!ObTypeIndexTable`. Type confusion bugs flip this.
- `InfoMask` — bitmap describing which optional headers precede the object (`_OBJECT_HEADER_NAME_INFO`, `_OBJECT_HEADER_HANDLE_INFO`, `_OBJECT_HEADER_QUOTA_INFO`, `_OBJECT_HEADER_PROCESS_INFO`, `_OBJECT_HEADER_CREATOR_INFO`).
- `SecurityDescriptor` — pointer (with low bits stolen) to the SD that governs `ObCheckObjectAccess`.

The SD itself is a self-relative blob with owner SID, group SID, DACL, SACL. Object ACLs are the real gatekeeper for cross-process access, more than just being SYSTEM.

### Handle table

`_EPROCESS.ObjectTable` -> `_HANDLE_TABLE` -> three-level tree of `_HANDLE_TABLE_ENTRY` (8 bytes on x64). Each entry packs:

- Pointer to `_OBJECT_HEADER` (high bits).
- Granted access mask (low bits).
- Inheritance and protect-from-close flags.

`!handle` in WinDbg walks this. Cross-process `DuplicateHandle` and `NtDuplicateObject` are how injection-light tradecraft (handle stealing, parent PID spoofing via `UpdateProcThreadAttribute(PROC_THREAD_ATTRIBUTE_PARENT_PROCESS)`) happens.

### `_EPROCESS`, `_ETHREAD`, `_TOKEN` internals

`_EPROCESS` highlights:

- `Pcb` — `_KPROCESS` scheduler block, holds `DirectoryTableBase` (CR3).
- `ActiveProcessLinks` — doubly-linked list; classic DKOM rootkit unlinks here.
- `Token` — `_EX_FAST_REF` to `_TOKEN`; the canonical token-stealing target.
- `Protection` — PsProtectedSignerWinTcb, PPL bits that EDRs rely on.
- `MitigationFlags` / `MitigationFlags2` — CFG, ACG, dynamic code, child-process policy.

`_TOKEN` highlights:

- `Privileges.Present` / `Enabled` / `EnabledByDefault` — 64-bit bitmaps. SeDebugPrivilege etc.
- `IntegrityLevel`, `TokenType`, `ImpersonationLevel`.
- `UserAndGroups` SID array.

Token-swap LPEs replace the calling `_EPROCESS.Token` with the System (PID 4) token reference, then bump the ref count. See [[hevd-stack-overflow-walkthrough]] for the canonical shellcode pattern, [[kernel-exploits-linux]] for the Linux analogue.

### Handle inheritance

`bInheritHandles = TRUE` in `CreateProcess` plus `SECURITY_ATTRIBUTES.bInheritHandle` on each handle causes the child to receive duplicates. Misuse leaks privileged handles into low-integrity children. `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` explicitly whitelists handles and is the safer pattern.

### Pool allocation for objects

Pre-Win10: NonPagedPool / PagedPool. Win10 1809+: segregated pools via `ExAllocatePool2` with `POOL_FLAG_*`. Objects live in tagged pool blocks — `Proc`, `Thre`, `Toke`, `File`, `Sect`. Pool spraying primitives (named pipe attributes `NpFs`, `WNF` subscriptions, registry value `Vad ` allocations) groom adjacent slots so a freed object can be reclaimed with attacker-controlled data — the bread and butter of [[hevd-uaf-walkthrough]].

LFH-style randomization, pool zeroing on free (KASLR-ish), and the Kernel Heap Backed Pool (KHBP) on recent builds change spray reliability significantly. Track `nt!ExInitializePoolDescriptor` changes per release.

## Recent CVE patterns

- **CLFS (Common Log File System)** — repeated UAF / type-confusion bugs in `_CLFS_CONTAINER_CONTEXT` (CVE-2022-37969, CVE-2023-23376, CVE-2023-28252, CVE-2024-49138). Attackers craft `.blf` files to corrupt object headers.
- **AFD.sys** — CVE-2023-21768 IO completion port + socket object UAF used for SYSTEM.
- **Win32k / DxgKrnl** — long history of GDI and dxgkrnl object confusion (CVE-2021-1732, CVE-2024-30088).
- **NTFS / FastFat** — file-object lifetime bugs reachable from mounted VHD.
- **PPL bypasses** — abusing legitimate signed objects (`PROCEXP152.SYS`, vulnerable drivers from loldrivers.io) to read or write `_EPROCESS.Protection`.

## Defensive baseline

### What EDR sees

- `PsSetCreateProcessNotifyRoutineEx` — every `_EPROCESS` create/exit, parent PID, command line, integrity, image file object.
- `PsSetCreateThreadNotifyRoutine` — `_ETHREAD` create, useful for remote-thread injection detection.
- `PsSetLoadImageNotifyRoutine` — Section -> mapped image association.
- `ObRegisterCallbacks` (PreOperation/PostOperation on Process and Thread) — can strip rights like `PROCESS_VM_WRITE` from non-trusted callers; used by LSASS protections.
- `CmRegisterCallbackEx` — registry object operations.
- Minifilters (`FltRegisterFilter`) — File object IRP_MJ_CREATE etc.
- ETW providers: Microsoft-Windows-Kernel-Process, Kernel-Object, Kernel-Audit-API-Calls, Threat-Intelligence (TI-ETW, requires PPL anti-malware).

### Detections to baseline

- Suspicious `\BaseNamedObjects\` names — known C2 mutex strings (Cobalt Strike default `MSSE-<n>-server`, Mimikatz `LegacyXX`), or per-machine GUID mutexes from ransomware families.
- Handle inheritance crossing integrity levels — Medium-IL parent leaking a SYSTEM token handle to a Low-IL child.
- `OpenProcess(PROCESS_VM_READ, lsass.exe)` from non-MsMpEng processes — classic credential dump precursor.
- `NtCreateSection` with `SEC_IMAGE` from a writable path, then mapping into a remote process — module stomping.
- Driver loads creating `_DRIVER_OBJECT` for known vulnerable drivers (cross-ref [loldrivers.io](https://www.loldrivers.io/)).
- Token manipulation: `NtDuplicateToken` followed by `NtSetInformationProcess(ProcessAccessToken)` from non-svchost.

Wire these into [[siem-detection-use-case-catalog]] and [[edr-rules-as-code-from-attack-patterns]]; map to ATT&CK T1055, T1134, T1068.

## Workflow to study

1. Boot a Windows 11 VM with kernel debugging enabled and attach WinDbg over network/COM. See [[kernel-debugging-with-windbg]].
2. `!process 0 0` to enumerate `_EPROCESS`. Pick one, `!process <addr> 7` for full detail including handles.
3. `dt nt!_OBJECT_HEADER <obj-1>` to inspect the header before the object body.
4. `!object \BaseNamedObjects` and walk an interesting mutant — observe `_OBJECT_HEADER_NAME_INFO`.
5. `!handle 0 f <pid>` to dump all handles of a process; correlate handle index to object address.
6. Run WinObj as admin and screenshot `\KnownDlls`, `\Driver`, `\Device`.
7. Write a small driver that calls `ObReferenceObjectByHandle` on a user-supplied handle, then introduce a deliberate refcount bug; reproduce a UAF under Driver Verifier with Special Pool. Pair with [[hevd-uaf-walkthrough]].
8. From user mode, write a tool that enumerates handles via `NtQuerySystemInformation(SystemHandleInformation)` and prints owner process + type + name — this is what attacker handle-stealing tools and what defender triage scripts both look like.
9. Capture an ETW trace with Microsoft-Windows-Kernel-Object and analyze in Windows Performance Analyzer; identify which handle operations are noisy.
10. Audit one shipping driver from a vendor (publicly available) for `ObOpenObjectByPointer` or `ZwOpenProcess` calls with attacker-influenced parameters — see [[windows-driver-ioctl-audit]].

## Related

- [[windows-kernel-architecture]]
- [[kernel-objects-and-irps]]
- [[windows-processes-and-threads]]
- [[windows-api-and-syscalls]]
- [[windows-driver-ioctl-audit]]
- [[hevd-uaf-walkthrough]]
- [[hevd-stack-overflow-walkthrough]]
- [[kernel-debugging-with-windbg]]
- [[kernel-exploits-linux]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[siem-detection-use-case-catalog]]
- [[detection-engineering-pyramid-of-pain]]

## References

- https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/windows-kernel-mode-object-manager
- https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-obregistercallbacks
- https://learn.microsoft.com/en-us/sysinternals/downloads/winobj
- https://www.crowdstrike.com/blog/the-anatomy-of-windows-kernel-exploit/
- https://googleprojectzero.blogspot.com/2021/01/in-wild-series-windows-exploits.html
- https://www.loldrivers.io/
