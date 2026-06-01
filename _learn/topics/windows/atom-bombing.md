---
title: Atom Bombing
slug: atom-bombing
---

> **TL;DR:** Smuggle shellcode into a victim process via the global atom table, then schedule an APC that forces the target thread to materialise and execute the payload — no `WriteProcessMemory`, no `VirtualAllocEx`.

## What it is
Atom Bombing is a code injection primitive published by enSilo (2016) that abuses Windows **global atom tables** as a side-channel for cross-process writes. The injector stores shellcode bytes as atom strings with `GlobalAddAtom`, then calls `NtQueueApcThread` on a thread inside the target process to coerce it into invoking `GlobalGetAtomName`, which writes the bytes into the victim's address space. A ROP chain then makes the region executable and jumps to it.

## Preconditions / where it applies
- Local process able to `OpenProcess` / `OpenThread` on the victim (same integrity level or sufficient rights)
- Target process must have at least one alertable thread for APC delivery
- Works on Windows 7 through 10 (pre-CFG enforced binaries); modern Windows + CFG limits the ROP step

## Technique
The flow is: (1) `GlobalAddAtom` writes the shellcode + ROP gadgets into the kernel-managed atom table; (2) `NtQueueApcThread` queues an APC pointing at `GlobalGetAtomName` in the target; (3) when the thread alerts, the atom is copied into target memory; (4) a second APC pivots the stack into the ROP chain to mark the region RX and execute it. No traditional injection API is touched.

```c
ATOM a = GlobalAddAtomA(shellcode);          // payload smuggled into atom table
HANDLE hT = OpenThread(THREAD_SET_CONTEXT, FALSE, tid);
NtQueueApcThread(hT, GlobalGetAtomNameA,
                 (PVOID)a, targetBuffer, (PVOID)len);
// follow-up APC chains ZwAllocateVirtualMemory / memcpy / jmp shellcode
```

OPSEC: bypasses many user-mode injection hooks because no `WriteProcessMemory`/`VirtualAllocEx` is used. Defeated by CFG/ACG, by EDRs hooking `NtQueueApcThread`, and by Windows 10 1809+ atom-table hardening.

## Related: [[process-injection-techniques]], [[apc-injection]]

## Detection and defence
- Sysmon Event ID 8 (CreateRemoteThread) is silent here — pivot to ETW Threat Intelligence APC events
- Alert on unusual `NtQueueApcThread` callers, especially with kernel32!GlobalGetAtomName as the routine
- Enforce Control Flow Guard and Arbitrary Code Guard on sensitive processes (browsers, lsass)
- EDRs that hook `NtQueueApcThread` / inspect APC routine targets catch the staging step

## References
- [enSilo — AtomBombing original write-up](https://blog.ensilo.com/atombombing-brand-new-code-injection-for-windows) — Tal Liberman's original disclosure
- [FortiGuard Labs — AtomBombing analysis](https://www.fortinet.com/blog/threat-research/atombombing-brand-new-code-injection-technique-for-windows) — vendor breakdown with ROP detail
