---
title: AMSI memory patching - deep
slug: amsi-memory-patching-deep
aliases: [amsi-patch-deep, amsi-bypass-memory]
---

> **TL;DR:** AMSI (Antimalware Scan Interface) is a Windows COM surface that lets scripting hosts (PowerShell, WSH, JScript, VBA, Excel 4) and the .NET CLR submit content to registered AV/EDR providers via `amsi.dll`. The classic Matt Graeber patch overwrites the first bytes of `AmsiScanBuffer` with a stub that returns `S_OK` and `AMSI_RESULT_CLEAN`, or returns the failure constant `0x80070057`/`0xC0000023` to force "not scanned." Modern Defender flags that exact byte sequence, so practitioners rotate prologues, use hardware breakpoints to avoid in-place writes, patch alternate functions (`AmsiScanString`, `amsi!CAmsiAntimalware::Scan`, `Utils::amsiInitFailed` for .NET), unhook ntdll first, and consider HVCI/CFG constraints. See [[amsi-bypass]], [[amsi-providers-tampering]], [[etw-bypass]], [[edr-bypass-at-exploitation-time]], [[syscall-direct-and-indirect]], and [[edr-hooks-and-unhooking]] for the surrounding ecosystem.

## Why it matters

AMSI is the choke point for in-memory script execution on modern Windows. If you land a PowerShell beacon, a VBA dropper, a .NET assembly via reflection, or a JScript loader, AMSI is what hands the deobfuscated payload to Defender (or a third-party provider) before it runs. Bypassing AMSI in-process is often a prerequisite to running tooling like Rubeus, SharpHound, or any [[c2-frameworks]] stager that touches managed code.

The "one-liner" patch is a tripwire now. Defender both inspects `amsi.dll` integrity at runtime and signatures known patch gadgets. Operators who want reliability across patched hosts need to understand the surface deeply, not just paste a gist.

## AMSI architecture refresher

### Clients

- `powershell.exe` / `pwsh.exe` — calls AMSI before invoking the AST evaluator on script blocks.
- `wscript.exe` / `cscript.exe` — JScript, VBScript via the WSH engine.
- Office (`winword`, `excel`, `outlook`) — VBA and Excel 4 macros, XLM.
- .NET CLR — `clr.dll` calls AMSI on `Assembly.Load(byte[])` since .NET 4.8 on Windows 10 1809+.
- WMI, MSHTA (`mshta.exe`), legacy WSH hosts.
- Edge/IE for downloaded scripts in older configurations.

### Provider model

`amsi.dll` is a COM dispatcher. Providers are COM servers registered under `HKLM\SOFTWARE\Microsoft\AMSI\Providers\{CLSID}` and the corresponding `HKLM\SOFTWARE\Classes\CLSID\{CLSID}\InprocServer32` pointing at the provider DLL. Defender ships `MpOav.dll`. Third-party AVs (Sophos, Kaspersky, CrowdStrike where applicable) drop their own provider DLLs.

Tampering with the provider registration (delete, point at a stub DLL, swap CLSID) is its own technique covered in [[amsi-providers-tampering]]. Memory patching is for when you cannot or do not want to touch registry.

### Calls of interest

- `AmsiScanBuffer(HAMSICONTEXT, PVOID, ULONG, LPCWSTR, HAMSISESSION, AMSI_RESULT*)` — primary scan API.
- `AmsiScanString` — thin wrapper around `AmsiScanBuffer`.
- `AmsiOpenSession` / `AmsiCloseSession` — context handles.
- `AmsiInitialize` — process-level bootstrap.
- Internally, `amsi!CAmsiAntimalware::Scan` is the dispatch into the provider COM call.

## Classic patches and their tells

### Matt Graeber 0xC0000023 patch

Overwrites the first bytes of `AmsiScanBuffer` with code that loads a failure NTSTATUS (`STATUS_BUFFER_TOO_SMALL` / `0xC0000023`) into `eax` and returns. Defender now signatures the canonical `B8 57 00 07 80 C3` (or similar `mov eax, 0x80070057; ret`) immediately at the function prologue. Static scans of writable executable regions catch this on inject.

### .NET amsiInitFailed flag

`System.Management.Automation.AmsiUtils.amsiInitFailed = true` — toggling a static bool via reflection. This skips AMSI in the PowerShell process specifically and is itself signatured at the AST level. Obfuscating the strings (`"amsiInitFailed"` and `"AmsiUtils"` split, base64'd, formatted) is the usual move, but the AST signature on the property write is hard to fully evade.

### AmsiScanString redirect

Patching the wrapper instead of `AmsiScanBuffer` works if the host calls `AmsiScanString`, but most modern callers go straight to `AmsiScanBuffer`. Useful in older script hosts.

## Beyond the prologue patch

### Hardware breakpoint hooks

Instead of writing executable memory (which leaves a static artifact and trips memory-integrity checks), set a Dr0-Dr3 hardware breakpoint on `AmsiScanBuffer` via `SetThreadContext` with `ContextFlags = CONTEXT_DEBUG_REGISTERS`. Install a vectored exception handler (`AddVectoredExceptionHandler`) that, on `EXCEPTION_SINGLE_STEP` at the AMSI entry, rewrites `RAX`/return registers to clean and skips to the function epilogue by adjusting `Rip`.

Advantages: no bytes change in `amsi.dll`. PAGE_EXECUTE_READ stays intact. HVCI does not block it (no W^X violation). Tooling like `HWBP-AMSI`, `DeathSleep`, and `Hells-Gate`-adjacent libraries demonstrate the pattern.

Caveats: HW breakpoints are thread-local. You must hook every thread that might invoke AMSI, including new ones via thread-creation callbacks or a TLS-based reinstall. Defender's behavioral telemetry can observe `SetThreadContext` against own-process threads with DR registers populated, though detection in practice lags.

### Unhook ntdll then patch

EDRs often hook `amsi.dll` indirectly by hooking the NT calls AMSI relies on, or by hooking `AmsiScanBuffer` themselves with a JMP into their analysis DLL. Step one: read a clean copy of `ntdll.dll` (and sometimes `amsi.dll`) from disk or `\KnownDlls`, diff against the in-memory copy, restore the original `.text`. Step two: apply your AMSI patch to the now-clean function. See [[edr-hooks-and-unhooking]].

This sequence matters because patching on top of an EDR's existing hook may either be reverted by the EDR's integrity poller, or trigger the EDR's "someone is rewriting our trampoline" detection.

### Patch the provider call path

Instead of `AmsiScanBuffer`'s prologue, patch the JMP/CALL that dispatches into `MpOav.dll` (or the provider's `IAntimalwareProvider::Scan` vtable entry). Walk the COM vtable for the `IAntimalware` interface obtained via `AmsiInitialize` and overwrite the relevant slot. Higher engineering cost, far less signatured because the bytes you change are not in `amsi.dll`'s prologue.

### COM interface stubbing

Override `g_Amsi` / `g_AmsiAntimalware` globals in `amsi.dll` with pointers to your own COM object whose `Scan` returns clean. Requires resolving non-exported symbols; PDB-driven offsets break across patch Tuesdays. Worth it for long-lived implants that ship per-build offset tables.

## Anti-detection on the patch itself

### Avoid known byte gadgets

`B8 57 00 07 80 C3` — signatured. `B8 23 00 00 C0 C3` — signatured. Common workarounds:

- Use longer logically-equivalent sequences (`xor eax, eax; mov ax, 0x4c7; bswap eax; ret`-style obfuscation).
- Patch in the middle of the function rather than at the prologue (locate a conditional that decides clean vs detected and flip it).
- Patch the comparison constant the caller uses to interpret `AMSI_RESULT` rather than the scan function (caller-side patch is rarer to signature).

### Defender's own patch detection

`MpOav.dll` and `MsMpEng.exe` periodically validate the integrity of `amsi.dll`'s `.text` section by recomputing hashes against a known-good baseline. Hardware breakpoints sidestep this entirely. Byte patches need either to occur after the integrity check window or to also patch the integrity-check routine, which is what makes the HW-BP approach more durable.

### VBS/HVCI considerations

Under Virtualization-Based Security with HVCI, kernel-mode code integrity is enforced. User-mode `.text` is not directly HVCI-protected, but EDRs often place CFG (Control Flow Guard) guards around indirect calls. Your patched function pointer must satisfy CFG bitmap checks or call `SetProcessValidCallTargets`. See [[vbs-hvci-bypass-walkthrough]] for the kernel side; AMSI patching itself is user-mode and not blocked by HVCI, but the techniques used to deliver the patch (process injection from another process) can run into PPL/CFG hurdles. Companion: [[edr-bypass-at-exploitation-time]].

### Patching from another process

If your loader cannot run AMSI patching from within the target (some sandboxed initial-access scenarios), you can `VirtualProtectEx` + `WriteProcessMemory` into the target. This adds risk: cross-process writes into `amsi.dll`'s `.text` are a very high-signal telemetry event for most EDRs. Prefer in-process patching delivered by a stager that has already executed in the target, or use [[process-injection-techniques]] variants that avoid `WriteProcessMemory` (APC injection, thread-context hijack, mapped-section injection).

### Persistence of the patch

A single patch is per-process. PowerShell-style implants that spawn child PowerShells need to reapply, or to drop the `amsiInitFailed` reflection bypass inside every new runspace's first script block. For long-running C2 implants, install a vectored exception handler that survives the lifetime of the process and reinstalls HW breakpoints on `DLL_THREAD_ATTACH` via a small thread-creation callback.

## Defensive baseline

- Treat AMSI bypass attempts as high-fidelity signals; PowerShell ScriptBlock logging (`EID 4104`) often records the deobfuscated bypass even when AMSI itself is skipped because the AST evaluator logs before/independently.
- Sysmon `EventID 7` (Image Load) for `amsi.dll` into unusual processes; correlate with subsequent `RWX` allocations.
- Defender ASR rule "Block execution of potentially obfuscated scripts" raises the cost of the in-AST `amsiInitFailed` patch.
- ETW `Microsoft-Antimalware-Scan-Interface` provider exposes scan-skip telemetry if you collect it (see [[etw-bypass]] for the symmetric attacker move).
- Hunt: PowerShell processes with `amsi.dll` mapped but zero ETW AMSI events over a session.

## Workflow to study (lab, not against production AV)

1. Spin up a Windows 11 VM with Defender enabled and real-time protection on, plus ScriptBlock logging.
2. Run the canonical Graeber one-liner in PowerShell. Observe Defender blocks it.
3. Read `amsi.dll` symbols (`AmsiScanBuffer`, `AmsiScanString`, `AmsiOpenSession`) via `dumpbin /exports` or x64dbg.
4. Manually patch in WinDbg: `eb amsi!AmsiScanBuffer <bytes>`. Run a known-malicious-looking string (`AmsiUtils.amsiInitFailed` is conveniently itself flagged). Watch the result.
5. Implement the hardware-breakpoint variant in a small C# or C++ POC. Confirm `amsi.dll` `.text` checksum is unchanged.
6. Try the .NET pathway: write a managed loader that calls `Assembly.Load(byte[])` on a Defender-flagged binary; patch AMSI first.
7. Read `MpOav.dll` strings to understand what the provider returns and how `AMSI_RESULT_DETECTED` (`32768`) flows back.
8. Try patching only the comparison rather than the scan function — instructive about caller-side bypasses.

Do this on isolated VMs. Do not test on hosts where you do not own the EDR.

## Related

- [[amsi-bypass]]
- [[amsi-providers-tampering]]
- [[etw-bypass]]
- [[wldp-bypass]]
- [[edr-bypass-at-exploitation-time]]
- [[edr-hooks-and-unhooking]]
- [[syscall-direct-and-indirect]]
- [[process-injection-techniques]]
- [[vbs-hvci-bypass-walkthrough]]
- [[applocker-bypass-techniques]]
- [[c2-frameworks]]

## References

- https://learn.microsoft.com/en-us/windows/win32/amsi/antimalware-scan-interface-portal
- https://learn.microsoft.com/en-us/windows/win32/api/amsi/nf-amsi-amsiscanbuffer
- https://www.microsoft.com/en-us/security/blog/2018/06/14/hunting-down-dofoil-with-windows-defender-atp/
- https://github.com/S3cur3Th1sSh1t/Amsi-Bypass-Powershell
- https://web.archive.org/web/2024/https://www.contextis.com/en/blog/amsi-bypass
- https://posts.specterops.io/host-based-threat-modeling-amsi-from-the-defenders-perspective-4f2b5d3e7c8a
