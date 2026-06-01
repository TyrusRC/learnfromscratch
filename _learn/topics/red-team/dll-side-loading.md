---
title: DLL side-loading
slug: dll-side-loading
---

> **TL;DR:** Drop a malicious DLL next to a signed Microsoft / vendor EXE that resolves dependencies by name from its own directory — when launched, the signed binary loads and executes your code.

## What it is
The Windows DLL search order checks the executable's own directory early. Many signed binaries `LoadLibrary("something.dll")` without a full path, expecting the system copy. If you drop a same-named DLL next to the EXE in a writable location, that copy wins. Side-loading is the cleanest variant of "DLL hijacking" because you don't depend on PATH ordering — the EXE's own directory always wins under SafeDllSearchMode.

## Preconditions / where it applies
- A signed binary with a known unresolved or relatively-resolved import
- Write access to a directory where you can also drop the binary (user-writable folder, AppData, temp)
- Often combined with phishing payloads (ship a ZIP that contains both legit EXE + your DLL)

## Technique
Find a vulnerable binary. Public catalogues: HijackLibs project, LOLBAS DLL list, Wietze Beukema's research. Common targets historically: OneDriveStandaloneUpdater, vmnat.exe, GoogleUpdate.exe, signed installers that drop temp DLLs.

Build a proxy DLL that forwards all real exports to the legit DLL so the host process keeps working. Tools: SharpDllProxy, Spartacus, DLLirant.

```
# Spartacus — find side-loadable DLLs by procmon log
Spartacus.exe --mode proxy --pml procmon.pml --solution C:\out
# It generates a Visual Studio project with #pragma comment(linker, "/export:...=forward...")
```

A lightweight alternative to a full DEF file is the linker pragma — `#pragma comment(linker, "/export:exportedFunction1=legit1.exportedFunction1")` per export — which emits forwarders straight from the C source, so the proxy's import table looks identical to the original and you do not have to maintain a separate `.def`. Rename the original DLL (e.g. `legit1.dll` → `legit1_orig.dll`) and forward to that, so DllMain runs your payload while every legitimate call is satisfied transparently and the host process never notices a missing export.

Minimal proxy `DllMain`:

```c
BOOL APIENTRY DllMain(HMODULE h, DWORD reason, LPVOID lp) {
    if (reason == DLL_PROCESS_ATTACH) {
        CreateThread(NULL, 0, payload, NULL, 0, NULL);
    }
    return TRUE;
}
```

Package: signed EXE + your DLL + any extra resource files it expects, dropped into a writable folder. Execute via shortcut, scheduled task, or autostart.

Bonus: many vendor installers extract a temp folder, drop a DLL, and load it. If you can race the extraction (or pre-place the file via persistence in `%TEMP%`), you side-load at install time on a fresh box.

## Detection and defence
- Image Load events showing a signed binary loading a DLL from a user-writable path
- Code-integrity / WDAC policies block unsigned DLLs from loading into signed processes
- Microsoft's ASR rules (block Office child processes, block executable content from email) cover common chains
- Hash-allowlist tools (AppLocker DLL rules, WDAC) defeat side-loading entirely when DLL enforcement is on
- Hunt: parent EXE path under `C:\Program Files\...` but loaded DLL path under `C:\Users\...\AppData\...`

## References
- [HijackLibs project](https://hijacklibs.net/) — catalogue of side-loadable DLLs
- [LOLBAS](https://lolbas-project.github.io/) — signed binaries usable for living-off-the-land
- [Spartacus tool](https://github.com/Accenture/Spartacus) — automated proxy DLL generation
- [Wietze Beukema research](https://wietze.github.io/) — DLL hijacking research and methodology
- [ired.team — DLL proxying for persistence](https://www.ired.team/offensive-security/persistence/dll-proxying-for-persistence) — linker-pragma forwarder pattern reused for long-lived side-load persistence
- [[com-hijacking]] [[living-off-the-land]] [[parent-pid-spoofing]]
