---
title: Reversing C++ MFC Binaries
slug: cpp-mfc-reverse
---

> **TL;DR:** MFC binaries leak structure through `CRuntimeClass`, message maps, and MFC42 ordinals — walk those to recover window classes, dialog handlers, and event wiring.

## What it is
Microsoft Foundation Classes wraps the Win32 API in a deep C++ hierarchy (`CObject` → `CCmdTarget` → `CWnd` → `CDialog`, etc.). MFC apps from the VC6 era statically embed or dynamically link `MFC42.DLL` / `MFC140.DLL` and route GUI events through a compact message-map table instead of a giant `switch` on `WM_*`. Recognising those patterns is the difference between staring at vtables and reading the program like source.

## Preconditions / where it applies
- Windows PE binaries linked against `MFC*.DLL` (ordinals visible in the import table)
- Statically-linked MFC where strings like `CWnd`, `CDialog`, `AFX_MSGMAP` survive
- Legacy enterprise apps, installers, and CTF reversing targets

## Technique
Detect MFC, then walk the message map for a chosen `CWnd` subclass.

```python
# IDAPython sketch — find AFX_MSGMAP entries off a CWnd vtable
import idaapi, idc

def walk_msgmap(map_ea):
    # struct AFX_MSGMAP_ENTRY { UINT nMessage; UINT nCode; UINT nID;
    #                           UINT nLastID; UINT_PTR nSig; AFX_PMSG pfn; }
    ENTRY = 6 * 4 if not idaapi.get_inf_structure().is_64bit() else 6 * 8
    while True:
        msg = idc.get_wide_dword(map_ea)
        if msg == 0:
            break
        pfn = idc.get_wide_dword(map_ea + ENTRY - 4)
        print(f"WM_{msg:04x} -> sub_{pfn:08x}")
        idc.set_name(pfn, f"AfxMsg_{msg:04X}_{pfn:X}", idc.SN_NOWARN)
        map_ea += ENTRY
```

Pair with ordinal resolution: load `mfc42.lib` FLIRT signatures, then re-import using `mfc42.dll` ordinal-to-name mappings so `Ordinal_1234` becomes `CWinApp::Run`.

## Detection and defence
- Stripped RTTI + `CRuntimeClass` names defeat naive class discovery — fall back to vtable signature scans against known `CWnd`/`CDialog` layouts.
- Packers that rebuild the IAT lose ordinal hints; rebuild with Scylla after dumping, then re-apply the MFC ordinal map.
- Detect Frida/Pin attachment via `IsDebuggerPresent`, `NtQueryInformationProcess`, or message-map tampering checks.

## References
- [Microsoft MFC message map internals](https://learn.microsoft.com/en-us/cpp/mfc/tn006-message-maps) — official doc on `AFX_MSGMAP` layout
- [Hex-Rays MFC reversing notes](https://hex-rays.com/blog/) — vendor write-ups on FLIRT and MFC ordinals

See also: [[ida-hexrays]], [[ghidra-decompiler]], [[rust-go-reverse]], [[csharp-python-reverse]].
