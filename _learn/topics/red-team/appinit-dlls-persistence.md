---
title: AppInit_DLLs Persistence
slug: appinit-dlls-persistence
---

> **TL;DR:** Drop a DLL path into `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows\AppInit_DLLs` and flip `LoadAppInit_DLLs=1` — every process that loads `user32.dll` will side-load your code, but only on legacy systems with Secure Boot disabled.

## What it is
A legacy Windows user-mode persistence mechanism: any DLL listed in `AppInit_DLLs` is mapped by `user32.dll` into every process that links against it. The sibling `AppCertDlls` key (`HKLM\System\CurrentControlSet\Control\Session Manager\AppCertDlls`) achieves a similar effect via `kernel32.dll` for processes that call `CreateProcess`-family APIs. Both are ATT&CK T1546.010 / T1546.009.

## Preconditions / where it applies
- Local admin / `SeRestorePrivilege` to write the HKLM key
- Windows 7 / Server 2008 R2 era — disabled by default when **Secure Boot** is on (Win 8+) and ignored entirely when Code Integrity (`HVCI`) is enforced
- Target DLL must match the bitness of the loading process (provide both 32/64-bit, the WoW64 key is `HKLM\Software\Wow6432Node\...`)

## Technique
Write the absolute DLL path (or short 8.3 name; spaces have historically broken parsing) and enable the loader switch. Reboot or wait for a user32-linked process to spawn.

```powershell
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows" `
  /v AppInit_DLLs /t REG_SZ /d "C:\ProgramData\evil.dll" /f
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows" `
  /v LoadAppInit_DLLs /t REG_DWORD /d 1 /f
# Optional: require the DLL to be Authenticode-signed (Win8+ knob)
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows" `
  /v RequireSignedAppInit_DLLs /t REG_DWORD /d 0 /f
```

OPSEC: AppInit injection is noisy — your DLL gets pulled into dozens of unrelated processes and any one crashing it draws attention. Prefer scoped persistence ([[com-hijacking]], image file execution options, scheduled tasks) on modern endpoints; reserve AppInit for legacy footholds.

## Detection and defence
- Sysmon EID 13 (RegistryEvent Set) on `AppInit_DLLs` / `LoadAppInit_DLLs` / `AppCertDlls` keys — Microsoft baseline rule
- Audit policy: Object Access → Registry, event 4657 on the same keys
- Hard mitigation: keep Secure Boot enabled (forces `LoadAppInit_DLLs=0`); enforce `RequireSignedAppInit_DLLs=1` on systems that must keep it on

## References
- [MITRE ATT&CK T1546.010](https://attack.mitre.org/techniques/T1546/010/) — AppInit DLLs sub-technique
- [cocomelonc — AppInit_DLLs persistence walkthrough](https://cocomelonc.github.io/tutorial/2022/05/16/malware-pers-5.html) — working C++ proof of concept
- [Elastic — Registry Persistence via AppInit DLL](https://www.elastic.co/guide/en/security/8.19/registry-persistence-via-appinit-dll.html) — detection rule reference
