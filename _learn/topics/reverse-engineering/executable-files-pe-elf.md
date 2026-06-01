---
title: Executable file formats
slug: executable-files-pe-elf
---

> **TL;DR:** PE (Windows), ELF (Linux/Android/BSD), Mach-O (macOS/iOS). Same idea — headers describe sections, imports, and entry — but the layout dictates how every tool parses the binary.

## What it is
Executable file formats package compiled code, data, relocations, imports/exports, and metadata that the OS loader needs to map the program into memory. Knowing the structure lets you find entry points, dump packed sections, fix IATs after unpacking, and write your own parsers.

## Preconditions / where it applies
- Any RE task that begins with `file sample` and proceeds to a structural triage.
- Tools: `readpe`/`pestudio` (PE), `readelf`/`pyelftools` (ELF), `otool`/`lipo`/`jtool2` (Mach-O), or the universal `rabin2`.

## Technique

### PE (Portable Executable, Windows)
Layout: `MZ` DOS stub → `PE\0\0` signature → `IMAGE_FILE_HEADER` → `IMAGE_OPTIONAL_HEADER` → section table → sections.

Key directories (in `OptionalHeader.DataDirectory`):
- `EXPORT` — DLL exported functions.
- `IMPORT` — IAT: which DLL+function names the loader resolves.
- `RESOURCE` — icons, manifests, embedded files.
- `EXCEPTION` — `.pdata` unwind info (x64 must have this).
- `TLS` — TLS callbacks; run before `main`, common for anti-debug.
- `DEBUG` — CodeView / RSDS pointing at the PDB.
- `IAT` — separate IAT direct pointer.
- `DELAY_IMPORT` — late-bound imports.
- `LOAD_CONFIG` — CFG, CET, GuardCF table.

```bash
pe-tree sample.exe        # GUI tree of every header
rabin2 -I sample.exe      # quick summary
```

Common section names: `.text` (code), `.rdata` (read-only), `.data` (RW), `.rsrc` (resources), `.reloc` (relocations). Unusual names (`.UPX0`, `.aspack`) signal packers — see [[packers]].

### ELF (Executable and Linkable Format)
Layout: ELF header → program headers (segments, what loader uses) → sections (what linkers/RE tools use) → string + symbol tables.

Two views:
- **Program headers** (`PT_LOAD`, `PT_DYNAMIC`, `PT_INTERP`, `PT_GNU_RELRO`) drive loading.
- **Section headers** (`.text`, `.rodata`, `.data`, `.bss`, `.dynsym`, `.dynstr`, `.plt`, `.got`) drive analysis.

Dynamic linking: `.dynamic` lists `NEEDED` libs, `RPATH`, `INIT`/`FINI` arrays. PLT/GOT implements lazy resolution — attackers target GOT for hijacks.

```bash
readelf -a sample
objdump -d -M intel sample | less
```

Hardening flags visible in the headers: `PIE` (ET_DYN), `RELRO` (`PT_GNU_RELRO`), `NX` (`PT_GNU_STACK` non-exec), stack canaries (`__stack_chk_fail` import).

### Mach-O
Layout: header (`MH_MAGIC_64`) → load commands → segments → sections.

Load commands of interest: `LC_SEGMENT_64`, `LC_DYLD_INFO_ONLY` (rebase/bind/lazy bind opcodes — the import mechanism), `LC_CODE_SIGNATURE`, `LC_ENCRYPTION_INFO_64` (FairPlay on iOS apps).

Fat (universal) binaries wrap multiple arches; `lipo -thin arm64 a.out -output a.arm64` extracts one.

### Cross-cutting
- Entry point: `IMAGE_OPTIONAL_HEADER.AddressOfEntryPoint` (PE), `e_entry` (ELF), `LC_MAIN` (Mach-O).
- TLS callbacks (PE) and `.init_array` (ELF) run before main — favourite anti-debug stash.
- Resources/embedded blobs (PE `.rsrc`, ELF custom sections, Mach-O `__TEXT,__const`) often hide stage-2 payloads.

## Detection and defence
- Signing (Authenticode, Mach-O codesign, Linux IMA) detects post-build tampering.
- Section permission audits (RWX sections in a benign app are suspicious).
- Entropy per section flags packed/encrypted data — see [[string-and-import-recon]].

## References
- [PE format reference (Microsoft)](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format) — official spec
- [ELF specification](https://refspecs.linuxfoundation.org/elf/gabi4+/contents.html) — generic ABI
