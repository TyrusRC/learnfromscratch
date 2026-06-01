---
title: Anti-debugging tricks
slug: anti-debugging
---

> **TL;DR:** Software probes the environment (PEB flags, ptrace, timing, exceptions) to detect debuggers; defeat by patching the probe or returning a fake result.

## What it is
Anti-debugging is any runtime check designed to behave differently when an analyst is attached. The check itself is usually small; the value comes from making the analyst find every instance. Knowing the families lets you pattern-match and neutralise them quickly. See [[anti-static-analysis]] for the static-side counterpart.

## Preconditions / where it applies
- Native binaries (PE, ELF, Mach-O) — managed runtimes usually rely on environment checks instead.
- An attached debugger (gdb, x64dbg, WinDbg, lldb) or instrumentation framework — see [[dynamic-debugging]] and [[binary-instrumentation]].

## Technique
Windows families:

- **API probes** — `IsDebuggerPresent`, `CheckRemoteDebuggerPresent`, `NtQueryInformationProcess(ProcessDebugPort/Flags/ObjectHandle)`.
- **PEB fields** — `BeingDebugged` byte, `NtGlobalFlag` (`0x70` under debugger), heap flags (`ForceFlags`, `Flags`).
- **TLS callbacks** — execute checks before `main`, before breakpoints land.
- **Hardware breakpoints** — read `Dr0..Dr7` via `GetThreadContext`; non-zero means HW BPs.
- **Exception abuse** — `INT 3` (0xCC), `INT 2D`, `ICEBP` (0xF1), `RDTSC` deltas, `SEH` chains to detect single-step.
- **Self-debug** — process calls `DebugActiveProcess` on itself so no other debugger can attach.

Linux families:

- `ptrace(PTRACE_TRACEME)` returns -1 if already traced.
- Read `/proc/self/status` for `TracerPid != 0`.
- Check `/proc/self/maps` for `gdb`, `frida`, ld_preload artefacts.
- Compare `getppid()` to expected shell.

Defeat:

```text
# x64dbg: ScyllaHide plugin auto-patches PEB + API hooks
# gdb: set follow-fork-mode child; catch syscall ptrace; return 0
```

Generic playbook:
1. Find the check with a breakpoint on the suspect API.
2. Patch the conditional jump (`JZ`→`JNZ` or `NOP` the call).
3. Or hook the function to always return the benign value.
4. Re-run; repeat for the next check.

For PEB-level probes set `BeingDebugged=0` and `NtGlobalFlag=0` once at attach; for `RDTSC` timing, hook to return monotonically small deltas.

## Detection and defence
- Add many small, distributed checks rather than one big one — raises analyst cost linearly.
- Combine with code virtualisation (see [[packers]]) so each check is hidden inside a VM handler.
- Server-side attestation beats any client check: if the secret is on the server, RE of the client cannot recover it.

## References
- [Anti-Debug Tricks (Check Point)](https://anti-debug.checkpoint.com/) — exhaustive Windows catalogue with code
- [HackTricks anti-debug](https://book.hacktricks.wiki/en/reversing/common-api-used-in-malware.html) — quick API list
