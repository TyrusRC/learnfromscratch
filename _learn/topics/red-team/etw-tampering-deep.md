---
title: ETW tampering - deep
slug: etw-tampering-deep
aliases: [etw-tampering, etw-patching-deep]
---

> **TL;DR:** Event Tracing for Windows (ETW) is the high-volume telemetry bus that modern EDRs depend on, especially the Microsoft-Windows-Threat-Intelligence (TI) provider that surfaces in-kernel security events to user-mode agents. Beyond the well-known one-byte `ntdll!EtwEventWrite` ret patch (covered in [[etw-bypass]]), serious operators learn the actual architecture: providers, sessions, controllers, and `NtTraceControl`. This note goes deep on enumeration, patch variants, session-level tampering, the TI provider's special role, and why event-filter forging beats blind suppression. Companions: [[amsi-memory-patching-deep]], [[edr-hooks-and-unhooking]], [[edr-bypass-at-exploitation-time]], [[syscall-direct-and-indirect]].

## Why it matters

EDR vendors discovered around 2017-2019 that hooking `ntdll` in every process is expensive, fragile, and trivially undone (see [[edr-hooks-and-unhooking]]). ETW - particularly the kernel-mode TI provider - lets them consume signals like remote thread creation, image load with suspicious characteristics, and memory protection changes without injecting into the target. If you can blind ETW, you blind a meaningful slice of the modern detection stack while leaving user-mode hooks looking healthy.

The catch: most public "ETW bypass" code only patches `EtwEventWrite` in the current process. Real engagements run into:

- Out-of-process sessions you cannot patch from your token.
- Providers that flush via `EtwWriteTransfer`, `EtwEventWriteFull`, `EtwEventWriteEx`, not just `EtwEventWrite`.
- Patch detectors that re-checksum `ntdll` exports.
- TI provider data the kernel emits regardless of user-mode patches.

If you do not understand the architecture, you will "bypass" ETW and still get caught.

## ETW architecture in one page

Four roles, all coordinated by the kernel ETW subsystem:

- **Provider** - code that calls `EtwRegister(GUID, ...)` and emits events via `EtwEventWrite` family. Lives in any process or in the kernel.
- **Session (logger)** - kernel-managed buffer that consumes events for one or more providers. Controlled via `StartTrace` / `EnableTraceEx2` / `NtTraceControl`.
- **Controller** - process that creates/configures sessions (e.g., `logman`, `xperf`, the EDR's own service).
- **Consumer** - process that reads events (real-time via `ProcessTrace` or from `.etl` files).

The TI provider GUID is `{F4E1897C-BB5D-5668-F1D8-040F4D8DD344}` (Microsoft-Windows-Threat-Intelligence). It is **PPL-restricted**: only Protected Process Light services with anti-malware signing can subscribe. That is why your code cannot just call `EnableTraceEx2` against it to silence the EDR - your token is not allowed.

### Provider GUID enumeration

```text
logman query providers
logman query providers Microsoft-Windows-Threat-Intelligence
wevtutil gp Microsoft-Windows-Threat-Intelligence
```

Programmatically, `EnumerateTraceGuidsEx(TraceGuidQueryList, ...)` returns every registered provider GUID. From there `TraceGuidQueryInfo` gives you the sessions consuming that provider, their session IDs, and their enable masks. This is how you find which session the EDR uses without guessing.

## Classes of ETW tampering

### Class 1 - in-process write-side patching (the noisy baseline)

The technique [[etw-bypass]] documents: locate `ntdll!EtwEventWrite`, flip the first byte to `0xC3` (ret) or copy `xor eax,eax; ret`. Works because `.NET`'s `Microsoft-Windows-DotNETRuntime`, PowerShell's `Microsoft-Windows-PowerShell`, and most user-mode providers in **your** process call this export.

Problems:

- Patches every consumer in your process simultaneously - obvious in detection telemetry that watches `.text` integrity.
- Does nothing about kernel-emitted events (TI provider, threat-intel).
- Patch-checksum detectors compare `ntdll!Etw*` first bytes to a known-good copy.

Variant: rather than `ret`, set `STATUS_INVALID_PARAMETER` return (`mov eax, 0xC000000D; ret`) so consumer-side error counters increment but the provider thinks the event went out. Lower telemetry footprint than zero returns.

### Class 2 - manifest / registration tampering

Instead of patching the export, call `EtwEventWriteNoRegistration` paths or manipulate the registration handle. Approaches seen in public PoCs:

- Walk `EtwpProcessHandleList` in the PEB-adjacent ETW state and zero the enable mask per registration. The provider stays "registered" but every `EtwEventEnabled` check returns false, so the provider short-circuits before writing.
- Hook `EtwEventEnabled` / `EtwEventEnabledEx` to always return zero. Quieter than smashing `EtwEventWrite` because consumers see no error - they just never emit.

This class survives some integrity checks that only look at the first few bytes of `EtwEventWrite`.

### Class 3 - out-of-process / session tampering

If the EDR runs a session in its own protected service, you cannot reach into its memory. But you might still be able to stop the session if your token has `SeSystemProfilePrivilege` or you are running as SYSTEM.

- `NtTraceControl(EtwpStopTrace, ...)` - stop a session by name or GUID.
- `EnableTraceEx2(handle, &ProviderGuid, EVENT_CONTROL_CODE_DISABLE_PROVIDER, ...)` - tell a session to stop consuming a specific provider.
- `ControlTraceW(sessionHandle, NULL, &props, EVENT_TRACE_CONTROL_STOP)` - same, higher-level.

In practice, EDR sessions are often started by a PPL service with `SeSystemProfilePrivilege` and ACL'd so non-PPL callers get `STATUS_ACCESS_DENIED` even from SYSTEM. The PPL boundary, not the privilege boundary, is what protects them. See [[macos-amfi-and-codesigning-deep]] for the analogous concept on macOS.

### Class 4 - event filter forging

The most surgical variant. Sessions support **event filters** (`EVENT_FILTER_DESCRIPTOR`) so you can drop events by event ID, by payload field value, or by stack-walk attribute. If you control the controller, you can re-enable the TI provider with a filter that excludes every event ID the EDR actually cares about (e.g., `KERNEL_THREATINT_OP_INJECT_THREAD = 23`), and the session keeps running.

From a detection perspective the session is alive, buffers are flowing, and no `EtwEventWrite` got patched. But the events the EDR depends on are simply gone. Operators have used this against poorly-designed agents.

### Class 5 - threat-intelligence provider blinding from kernel

If you already have a kernel read/write primitive (e.g., from [[hevd-pool-overflow-walkthrough]] or a [[fuzzing-windows-drivers]] find), you can:

- Locate `EtwThreatIntProvRegHandle` (the kernel global registration handle for the TI provider).
- Zero its enable mask field. The kernel keeps calling `EtwWrite` against it, but `EtwEventEnabled` returns false and nothing reaches user-mode consumers.

This is the highest-value tamper because no PPL service notices anything - their session is still healthy, they just stop receiving security events. EDRs increasingly checksum that structure on a timer.

## Defensive baseline (what blue teams do)

If you are on the other side, the assumptions hold:

- Run a **canary provider** that should always emit a heartbeat. Missing heartbeats are louder than missing real events.
- Monitor `ntdll!Etw*` first-byte integrity from a separate process - in-process verification can be patched too.
- Watch for `NtTraceControl` and `EnableTraceEx2` calls from non-PPL processes against your sessions (the kernel can ETW-emit this from a different provider you also subscribe to).
- Cross-validate kernel TI events against equivalent user-mode signals (Sysmon image loads, EDR usermode hooks) - large mismatch implies someone is blinding the kernel side.
- Use Microsoft-Windows-Kernel-Audit-API-Calls (the syscall-audit provider in 11/2022+) as a secondary source.

This is the same defense-in-depth thinking as [[detection-engineering-pyramid-of-pain]]: stop relying on a single telemetry channel.

## Workflow to study ETW tampering

1. Stand up Windows 11 with Defender. Enable verbose ETW logging via `wpr -start GeneralProfile`.
2. Enumerate every TI-subscribed session: `logman query -ets` and then `TraceGuidQueryInfo` programmatically. Note Defender's `DefenderApiLogger` and `EventLog-Security` consumers.
3. Reproduce the baseline `EtwEventWrite` patch from [[etw-bypass]] in a C# .NET tracee. Confirm `Microsoft-Windows-DotNETRuntime` goes silent in Event Viewer.
4. Repeat with `EtwEventEnabled` returning 0. Notice that the provider now silently no-ops and produces no error events.
5. Run `EnumerateTraceGuidsEx` to enumerate every provider in your process. You will be surprised how many libraries register (TLS, crypto, COM, WPP).
6. From an elevated context, try `ControlTraceW(... STOP)` on `EventLog-Security`. Observe `STATUS_ACCESS_DENIED` because of the session ACL.
7. Inside a kernel debugger, locate `nt!EtwThreatIntProvRegHandle` (symbol present in public PDB). Inspect its `EnableMask`. Toggle it; reproduce a known TI-emitting action (cross-process `WriteProcessMemory` + `CreateRemoteThread`) and see whether it still surfaces. This is the moment ETW tampering "clicks".
8. Read SilentMoonwalk, EDRSandblast, and SharpEtwHunter source for production-grade implementations.

## Comparison vs AMSI bypass

[[amsi-memory-patching-deep]] and ETW tampering get conflated because both are "patch one ntdll-adjacent export to go dark". The differences matter:

- AMSI is **per-process, per-buffer**, returns `AMSI_RESULT_CLEAN`, and only affects the script engines (PowerShell, JScript, VBScript, .NET assembly load scan). One process, narrow scope.
- ETW spans **kernel-emitted security events** that no AMSI bypass touches. ETW tampering blinds your remote-thread creation, your driver load, your handle-duplication primitive - none of which AMSI sees.

Operator priority on a modern Windows 11 host with Defender + a mid-tier EDR is usually: ETW TI blinding first (broad), then AMSI (script-engine-specific), then `ntdll` unhooking ([[edr-hooks-and-unhooking]]), then direct syscalls ([[syscall-direct-and-indirect]]) for the most sensitive primitives.

## Detection arms race notes

- `EtwEventWrite` first-byte checksum detection appeared in 2020-2021 vendor releases. Operators moved to `EtwEventEnabled` and to mask-zeroing.
- 2022-2023 saw vendors start checksumming `EtwThreatIntProvRegHandle` from PPL services on a 30-second timer.
- The publicly known robust counter is kernel-level: if you have arbitrary kernel write, you can pause the timer thread or hook the integrity check. That escalates the engagement into a kernel exploit ([[vbs-hvci-bypass-walkthrough]] is the relevant mitigation to defeat).

## Related

- [[etw-bypass]] - the introductory patch
- [[amsi-bypass]] / [[amsi-memory-patching-deep]] / [[amsi-providers-tampering]]
- [[edr-hooks-and-unhooking]] / [[edr-bypass-at-exploitation-time]]
- [[syscall-direct-and-indirect]]
- [[wldp-bypass]]
- [[process-injection-techniques]]
- [[hevd-pool-overflow-walkthrough]] / [[fuzzing-windows-drivers]]
- [[vbs-hvci-bypass-walkthrough]]
- [[detection-engineering-pyramid-of-pain]]
- [[atomic-red-team-emulation-deep]]

## References

- Microsoft Learn: Event Tracing for Windows architecture - https://learn.microsoft.com/en-us/windows/win32/etw/about-event-tracing
- Microsoft Learn: `EnableTraceEx2` and `EVENT_FILTER_DESCRIPTOR` - https://learn.microsoft.com/en-us/windows/win32/api/evntrace/nf-evntrace-enabletraceex2
- Palantir: Tampering with Windows Event Tracing - https://blog.palantir.com/tampering-with-windows-event-tracing-background-offense-and-defense-4be7ac62ac63
- Outflank: Silencing the EDR Silencers (TI provider deep dive) - https://outflank.nl/blog/2022/09/13/c-self-decrypting-binaries-using-the-windows-ci-policy/
- Wover / Adam Chester: ETW internals and threat intelligence provider - https://www.mdsec.co.uk/2020/03/hiding-your-net-etw/
- EDRSandblast source (ETW TI blinding implementation) - https://github.com/wavestone-cdt/EDRSandblast
