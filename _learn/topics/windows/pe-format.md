---
title: PE format
slug: pe-format
---

> **TL;DR:** Portable Executable is the Windows container for EXE/DLL/SYS/OBJ files — a DOS stub, a PE header, an optional header, section table, and sections. Understanding the data directories (IAT, EAT, reloc, TLS) is the entry point for reflective loading, hooking, packing, and shellcode analysis.

## What it is
PE is the on-disk and in-memory format produced by the MS link.exe linker (derived from COFF). Loaders use it both to map the file into a process and to perform import resolution and base-relocation fix-ups. Almost every offensive technique on Windows that involves "load this thing without touching disk" is in some way a manual implementation of what `LdrLoadDll` would do — so PE literacy is a prerequisite for [[windows-api-and-syscalls]] tradecraft, EDR hook hunting, and binary patching.

## Preconditions / where it applies
- Any time you parse, modify, or hand-craft Windows binaries (loaders, shellcode runners, malware analysis)
- Reflective DLL injection, manual mapping, module stomping
- Indirect-syscall and import-hashing tradecraft that walks the PEB loader list ([[windows-processes-and-threads]])
- IAT/EAT hooking by EDRs — knowing the layout tells you what to bypass

## Technique
Walk the structure top to bottom:

1. `IMAGE_DOS_HEADER` at offset 0 — `e_magic == "MZ"`, `e_lfanew` is the offset to the NT headers.
2. `IMAGE_NT_HEADERS` — `Signature == "PE\0\0"`, then `FileHeader` (machine, section count, characteristics) and `OptionalHeader` (entry point RVA, image base, subsystem, data directories).
3. `DataDirectory[16]` — RVA/size pairs. The interesting ones:
   - `IMAGE_DIRECTORY_ENTRY_EXPORT` — Export Address Table; how `GetProcAddress` resolves names.
   - `IMAGE_DIRECTORY_ENTRY_IMPORT` — Import descriptors; an array of `IMAGE_IMPORT_DESCRIPTOR` each pointing at an INT (names) and IAT (resolved pointers).
   - `IMAGE_DIRECTORY_ENTRY_BASERELOC` — base relocations; needed when the image cannot load at its preferred base.
   - `IMAGE_DIRECTORY_ENTRY_TLS` — TLS callbacks fire before `AddressOfEntryPoint` and are a classic execution-stealth primitive.
   - `IMAGE_DIRECTORY_ENTRY_EXCEPTION` — function tables used for SEH/x64 unwind.
4. Section table — `IMAGE_SECTION_HEADER` array, one per section. `.text` (RX), `.data` (RW), `.rdata` (R), `.rsrc` (R), `.reloc` (R). `VirtualAddress` is the in-memory RVA, `PointerToRawData` is the file offset.

Manual map pseudo-flow:

```
buf = ReadFile(dll)
base = VirtualAlloc(preferredBase, SizeOfImage, MEM_COMMIT|RESERVE, PAGE_READWRITE)
copy headers + sections at their RVAs
walk BASERELOC, patch all absolute addresses by (base - ImageBase)
walk IMPORT, LoadLibrary each, GetProcAddress each thunk → write IAT
apply per-section page protections (VirtualProtect)
invoke TLS callbacks, then DllMain(DLL_PROCESS_ATTACH)
```

Quick triage with `dumpbin /headers`, `pe-bear`, `CFF Explorer`, or `radare2 -A`.

## Detection and defence
- EDRs hash known-good `.text` of ntdll/kernel32 and detect tampering — module stomping that overwrites sections shows up here
- Loaded modules absent from the PEB `InLoadOrderModuleList` (manual map) are flagged by tools like Moneta / Pe-Sieve
- TLS callbacks executing before entry-point are a known evasion — modern AV inspects them
- Unbacked RX memory regions (no `MappedFile` backing) are the cleanest manual-map IoC
- Hardening: enforce code-signing, Arbitrary Code Guard, CIG (Code Integrity Guard), and "block unsigned DLLs" mitigation policies per process

## References
- [Microsoft — PE Format spec](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format) — authoritative field-by-field reference
- [HackTricks — PE binaries](https://book.hacktricks.wiki/en/reversing/common-api-used-in-malware.html) — offensive-lens summary
- [Corkami PE poster](https://github.com/corkami/pics/blob/master/binary/pe101/pe101.pdf) — one-page visual map of the format
