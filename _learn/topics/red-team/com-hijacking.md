---
title: COM hijacking
slug: com-hijacking
---

> **TL;DR:** Put a writable CLSID entry under HKCU that points at your DLL — Windows resolves HKCU before HKLM, so when a trusted host instantiates that COM object you get loaded into it.

## What it is
Component Object Model lookups follow a precedence: `HKCU\Software\Classes\CLSID` is checked before `HKLM\Software\Classes\CLSID`. A standard user can write under HKCU. If a high-integrity process (Explorer, MMC snap-in, a scheduled task host) `CoCreateInstance`s a CLSID that you've shadowed in HKCU, your DLL is loaded — same integrity level as the loader.

## Preconditions / where it applies
- Standard user, but session is the one that will trigger the call (logged-in user context)
- A CLSID that is actually invoked: many catalogued "missing" CLSIDs persist on disk in HKLM but never get called
- Useful for persistence (autoload via Explorer) and for elevation-by-trick (host runs at higher integrity, like a Task Scheduler COM handler)

## Technique
Recon first. Procmon for `RegOpenKey` on `HKCU\...\CLSID\{xxx}` with `NAME NOT FOUND` results during user logon and during the action you want to trigger — those are hijackable. The Cn33liz `COMRaider` / `acCOMplice` toolset and James Forshaw's OleViewDotNet enumerate registered CLSIDs and their hosting binary.

Once you've found a target CLSID:

```reg
[HKEY_CURRENT_USER\Software\Classes\CLSID\{TARGET-CLSID}]
@="HijackedHandler"

[HKEY_CURRENT_USER\Software\Classes\CLSID\{TARGET-CLSID}\InprocServer32]
@="C:\\Users\\user\\AppData\\Roaming\\evil.dll"
"ThreadingModel"="Apartment"
```

Pick a CLSID with the right triggering mechanism:
- Explorer-loaded shell extensions → fire on every logon (great persistence)
- Office add-ins → fire when Word/Excel opens
- Task Scheduler COM tasks → fire on schedule, often as SYSTEM if the task runs as SYSTEM and uses CLSID-based action

For elevation via UAC bypass, target a CLSID loaded by an autoElevate=true binary (mmc.exe with certain snap-ins, fodhelper.exe historically used file association rather than COM but the pattern overlaps). Several known UAC bypasses chain a COM elevation moniker (`Elevation:Administrator!new:`) with a missing-CLSID hijack.

Your DLL should `DllMain` quickly (don't block the host), spawn payload in a separate thread, then either return a valid COM interface or fail gracefully so the host doesn't crash.

## Detection and defence
- Sysmon Event ID 7 (Image Loaded) showing a non-system DLL loaded by explorer.exe / mmc.exe / svchost.exe from a user-writable path
- Sysmon Event ID 12/13 (registry) writes under `HKCU\Software\Classes\CLSID` create-or-write on `InprocServer32` are a strong signal — almost no legitimate software does this
- Autoruns and Sysinternals procmon catch this trivially; AppLocker / WDAC DLL rules block load if user paths aren't trusted
- Defenders should baseline shell extension CLSIDs and alert on new HKCU classes overriding HKLM

## References
- [ired.team — COM hijacking](https://www.ired.team/offensive-security/persistence/com-hijacking) — registry keys and triggers
- [Project Zero on COM](https://googleprojectzero.blogspot.com/) — research on COM internals and abuse
- [enigma0x3 blog](https://enigma0x3.net/) — UAC bypasses via COM elevation monikers
- [[persistence-techniques-windows]] [[dll-side-loading]]
