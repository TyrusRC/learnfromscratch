---
title: Ghidra decompiler
slug: ghidra-decompiler
---

> **TL;DR:** Free NSA-released RE suite with a strong decompiler, headless analysis mode, and Java/Python scripting — the standard open alternative to [[ida-hexrays]].

## What it is
Ghidra is a full reverse-engineering platform: loaders for PE/ELF/Mach-O and many embedded formats, disassemblers for dozens of architectures, a decompiler producing C-like output, and a project model that supports multiple analysts sharing a database. Its decompiler quality is competitive with Hex-Rays for x86/ARM/MIPS; some niches (Go runtime, heavily optimised C++) still favour commercial tools.

## Preconditions / where it applies
- JDK 17+ installed (or use the bundled launcher).
- Binary you can drop into a project; Ghidra handles raw blobs once you tell it the language spec.

## Technique
Project flow:
1. New Project → import binary → analyse (defaults are fine for first pass).
2. Symbol Tree → Functions: jump to `main`, `entry`, exports.
3. Decompiler view (right) + listing (centre): rename (`L`), retype (`Ctrl+L`), comment (`;`).
4. Define structures (Data Type Manager) and apply them to variables — decompiler output transforms.
5. Save often; the database persists analysis.

Headless mode for pipelines:

```bash
analyzeHeadless /tmp/proj MyProj \
  -import sample.bin \
  -postScript MyScript.java \
  -deleteProject
```

Scripting (Python via Jython or PyGhidra for CPython 3):

```python
# enumerate calls to LoadLibraryA
fm = currentProgram.getFunctionManager()
sym = currentProgram.getSymbolTable().getSymbols('LoadLibraryA').next()
for ref in getReferencesTo(sym.getAddress()):
    print(hex(ref.getFromAddress().getOffset()), getFunctionContaining(ref.getFromAddress()))
```

**Strengths:**
- **Versionable** project database (collaborative via Ghidra Server).
- **Sleigh** — a DSL to describe new ISAs; reverse esoteric/embedded chips by writing a Sleigh spec.
- **PCode** — Ghidra's IR; powerful for taint and dataflow scripts.
- **Function ID** signatures recover library calls in stripped binaries.

**Weaknesses to know:**
- Default analysis can be slow on large binaries; disable rarely-useful analyzers (`Decompiler Parameter ID` is expensive).
- Go and Rust binary support is improving but lags Hex-Rays for now ([[rust-go-reverse]]).
- The UI is dense; learn keybinds (`G` go to, `L` rename, `H` data type chooser).

Pair with [[dynamic-debugging]] for runtime confirmation — Ghidra ships a debugger UI integrating gdb/lldb/WinDbg too.

## Detection and defence
- Not a runtime tool; nothing on target.
- For analysts: keep Ghidra updated for parser CVEs (the loaders parse untrusted binaries).

## References
- [Ghidra GitHub](https://github.com/NationalSecurityAgency/ghidra) — releases, source, scripts
- [Ghidra cheat sheet](https://ghidra-sre.org/CheatSheet.html) — quick keybind reference
