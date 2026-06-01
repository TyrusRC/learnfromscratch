---
title: ETW bypass
slug: etw-bypass
---

> **TL;DR:** Patch `EtwEventWrite` / `NtTraceEvent` in your process so security ETW providers stop emitting events — defeats userland telemetry like .NET assembly load logging, but kernel-side ETW-TI still fires.

## What it is
Event Tracing for Windows is the kernel's general-purpose telemetry bus. Providers register, consumers subscribe. Defenders subscribe to providers like `Microsoft-Windows-DotNETRuntime` (assembly loads), `Microsoft-Windows-PowerShell` (script blocks), `Microsoft-Windows-Kernel-Process`. Userland bypasses patch the write-side functions in the process you control, so events for that process never reach the kernel buffer.

## Preconditions / where it applies
- Execution in the process whose telemetry you want to silence
- Write access to ntdll memory (VirtualProtect, normal user permission)
- Note: kernel ETW Threat Intelligence (ETW-TI) emits from the kernel and cannot be patched from userland

## Technique
**Userland .NET ETW.** Patch `EtwEventWrite` to return `0`:

```
ntdll!EtwEventWrite:
  C3                ret      ; was: 4C 8B DC 53 ...
```

```c
void* p = GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "EtwEventWrite");
DWORD old; VirtualProtect(p, 1, PAGE_EXECUTE_READWRITE, &old);
*(BYTE*)p = 0xC3; // RET
VirtualProtect(p, 1, old, &old);
```

Stops the in-process .NET runtime from logging assembly loads, JIT events, exceptions.

**Block at the trace level.** Find `EtwpEventRegister` callbacks or zero the `ProviderEnableInfo` field of the relevant `_ETW_REG_ENTRY` so the provider thinks no session is consuming it. More invasive, harder to detect.

**PowerShell script-block logging.** Reflectively reach `[Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider')`, grab the `etwProvider` field, replace its `enabled` flag with `false`. Once that's done, no more 4104 events from this runspace.

**.NET assembly load logging (ETW + AMSI).** Combine an AMSI patch with an `EtwEventWrite` patch before reflectively loading a managed assembly. Without both, Defender flags suspicious assemblies via .NET ETW even if AMSI is silenced.

**Hardware breakpoints variant.** Same idea as AMSI — set Dr-register on `EtwEventWrite`, VEH catches and skips the call. No `.text` write.

**Tamper the tracing session itself.** If you are already SYSTEM (or otherwise hold trace-session rights), you do not need to patch anything in your own process — instead surgically detach the noisy provider from the defender's session, e.g. `logman update trace <session-name> --p Microsoft-Windows-Kernel-Process 0x0 -ets` zeros the keyword mask for that provider, or `logman stop <session-name> -ets` tears the session down outright. This leaves the on-disk ETL chain looking healthy while events for your activity quietly stop arriving, and it does not touch `ntdll` so the ETW-TI write-virtual-memory tripwire never fires.

## Detection and defence
- ETW-TI (kernel) still emits write-virtual-memory and protect-virtual-memory events when you patch ntdll — high-fidelity signal
- Defender for Endpoint correlates abrupt drops in expected provider rates per-process
- Sealed/secure ETW (when enabled by policy) doesn't trust userland tampering for the events it cares about
- Hunt: write to first byte of `EtwEventWrite` in any process via ETW-TI; almost nothing legitimate does this
- Kernel-mode ELAM-loaded sensors observe the same syscalls regardless of userland patches

## References
- [Microsoft Docs — ETW providers](https://learn.microsoft.com/en-us/windows/win32/etw/event-tracing-portal) — official architecture
- [Outflank blog](https://www.outflank.nl/blog/) — research on ETW and AMSI disablement detection
- [WithSecure Labs](https://labs.withsecure.com/) — provider-level bypass notes
- [ired.team — ETW 101](https://www.ired.team/miscellaneous-reversing-forensics/windows-kernel-internals/etw-event-tracing-for-windows-101) — provider/session model plus the `logman update trace` keyword-mask trick attackers reuse
- [[amsi-bypass]] [[edr-hooks-and-unhooking]]
