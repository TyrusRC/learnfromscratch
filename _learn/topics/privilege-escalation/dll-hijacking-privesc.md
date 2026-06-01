---
title: DLL hijacking for privesc
slug: dll-hijacking-privesc
---

> **TL;DR:** A privileged process loads a DLL by name without a fully-qualified path; drop a malicious DLL earlier in the search order (writable directory on `%PATH%`, app dir, side-by-side manifest) and it executes in the high-priv context on next launch.

## What it is
Windows resolves DLL imports following a documented search order. If a process loads `foo.dll` without specifying a full path and the DLL is not in the Known DLLs list, Windows walks: application directory, system directories, current directory, then `%PATH%`. When a SYSTEM-run or admin-launched binary references a missing or non-Known DLL and any earlier search-order directory is attacker-writable, you get code execution in the privileged process.

## Preconditions / where it applies
- A process that runs at higher integrity (SYSTEM service, scheduled task as admin, auto-elevated MS binary).
- One of: writable application directory, a writable directory earlier on `%PATH%` than the legit DLL, a missing dependency the loader keeps searching for, or an app SxS manifest that pulls an attacker-controlled assembly.
- DLL not protected by KnownDLLs (`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs`).
- Common on third-party services installed under `C:\Program Files\<vendor>\` with weak ACLs, or vendor MSI installers that drop binaries into writable directories.

## Technique
1. Find candidate targets. With Process Monitor, run a filter:

```
Process Name = <target.exe>
Result    = NAME NOT FOUND
Path     ends with .dll
```

Each NAME NOT FOUND on a `.dll` lookup is a hijack candidate. The lower in the search list it appears, the more directories you can plant in. `winPEAS` and PowerSploit's `Find-PathDLLHijack` automate the writable-`%PATH%` and writable-app-dir cases.

2. Generate a payload DLL that exports the same symbols, or just runs in `DllMain`:

```bash
msfvenom -p windows/x64/exec CMD='cmd.exe /c net user pwn P@ss1 /add && net localgroup administrators pwn /add' -f dll -o legit.dll
```

For proxy-style hijacks where the host expects real exports, use a forwarder (`#pragma comment(linker, "/export:OriginalFn=real.OriginalFn")`) or tools like Spartacus / Koppeling to auto-clone exports.

3. Plant the DLL in the first writable directory in the search order — typically the service's install directory if its ACL is loose, or a writable `%PATH%` entry such as `C:\Python27\` left from a prior install.

4. Trigger: restart the service (`sc start <svc>`), wait for a scheduled task, or reboot. The DLL loads with the service's token.

Side-by-side (SxS) variant: drop an `app.exe.manifest` next to the binary that references an attacker-controlled assembly under `C:\Users\<u>\AppData\Local\Microsoft\WindowsApps\` — the SxS loader is even more permissive than the standard search order.

## Detection and defence
- Sysmon Event ID 7 (Image Loaded) showing a high-priv process loading a DLL from a user-writable path (`C:\Users\`, `C:\ProgramData\`, app dirs with weak ACLs) is the classic IOC. Correlate with EID 11 (FileCreate) of `.dll` in those paths.
- Defence: call `SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32)` and use `LoadLibraryEx` with `LOAD_LIBRARY_SEARCH_*` flags; ship DLLs in `System32` or use fully-qualified paths.
- Harden ACLs on `Program Files\<vendor>` install directories — remove `Users:(M)` and `Authenticated Users:(W)`.
- Enable `SafeDllSearchMode` (default on modern Windows) and add critical DLLs to `KnownDLLs`. WDAC in DLL-enforcement mode blocks unsigned DLL loads entirely.
- Related: [[weak-service-permissions]], [[unquoted-service-paths]], [[always-install-elevated]].

## References
- [Microsoft — Dynamic-Link Library Search Order](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order) — Canonical search-order documentation.
- [HackTricks — DLL Hijacking](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/dll-hijacking/index.html) — Enumeration, planting, and proxy DLL techniques.
- [ired.team — DLL hijacking](https://www.ired.team/offensive-security/persistence/dll-search-order-hijacking) — Practical examples with Process Monitor and payload generation.
- [Spartacus](https://github.com/Accenture/Spartacus) — Procmon-driven DLL hijack discovery and proxy DLL generation.
