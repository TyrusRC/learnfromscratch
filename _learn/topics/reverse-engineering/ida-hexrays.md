---
title: IDA + Hex-Rays
slug: ida-hexrays
---

> **TL;DR:** Industry-standard disassembler with the Hex-Rays decompiler — function-by-function decompile/rename/retype loop, FLIRT library recognition, IDAPython for scripting.

## What it is
IDA Pro (Hex-Rays) is the dominant commercial RE tool. The free version (IDA Free) covers many use cases; the decompiler add-ons (Hex-Rays for x86/x64/ARM/ARM64/MIPS/PPC/RISC-V) and the cloud edition (IDA Home/Pro) add scale. See also [[ghidra-decompiler]] and [[binary-ninja]].

## Preconditions / where it applies
- A licensed install (Free for non-commercial, Pro for cross-arch + remote debugging).
- A binary matching one of IDA's loaders (PE, ELF, Mach-O, dozens of embedded formats).

## Technique
Core loop:
1. Open binary → autoanalysis builds functions and CFG.
2. `Shift+F12` for strings; `Ctrl+S` for segments; navigate via Names window.
3. Decompile with `F5` (need Hex-Rays). Iterate: rename (`N`), retype (`Y`), add struct (`Ctrl+T`), set enum.
4. The decompiler output improves as types propagate. Stick at it.

Productivity keys:
- `G` go to address; `X` cross-references; `J` jump to xref under cursor.
- `H` toggle hex/decimal display; `K` make stack variable; `*` make array.
- `Alt+F8` to define a fixed-length string; `A` for an ASCII string.

**FLIRT** signatures recognise standard library functions in stripped binaries — `libc`, MSVC runtime, OpenSSL — and rename them. Custom signatures via `sigmake`.

**Lumina** is a cloud function-signature service; opt-in upload of metadata helps recognise common functions across binaries.

IDAPython 7.7+ uses Python 3:

```python
import idautils, ida_funcs, ida_name
for ea in idautils.Functions():
    name = ida_name.get_ea_name(ea)
    if name.startswith('sub_'):
        # find candidate names from string xrefs
        for s in idautils.FuncItems(ea):
            for x in idautils.DataRefsFrom(s):
                str_ = ida_bytes.get_strlit_contents(x, -1, ida_nalt.STRTYPE_C)
                if str_ and b'error' in str_:
                    ida_name.set_name(ea, f'maybe_err_{ea:x}')
```

**Hex-Rays Microcode** (the underlying IR) is exposed via APIs and plugin SDK; advanced plugins (HexRaysCodeXplorer, hrtng, lighthouse) operate at microcode level.

Debugging: IDA ships local + remote debuggers for Windows, Linux, macOS, Android, iOS — `dbgsrv` on the target. Pair with [[dynamic-debugging]] when static stalls.

## Detection and defence
- Not a runtime tool. The protections matter on the target side ([[anti-static-analysis]], [[packers]]).
- License compromise risk: never open untrusted binaries on a hot dev machine; use an analysis VM. IDA loaders have had parser CVEs in the past.

## References
- [Hex-Rays documentation](https://hex-rays.com/documentation/) — manual + decompiler reference
- [Practical IDAPython examples](https://github.com/idapython/src) — script samples
