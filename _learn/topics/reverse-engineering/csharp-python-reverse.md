---
title: Reversing C# and Python
slug: csharp-python-reverse
---

> **TL;DR:** Managed/interpreted languages ship metadata-rich bytecode — dnSpy/ILSpy round-trip .NET to near-source; uncompyle6 / pycdc handle Python depending on the marshal version.

## What it is
Compiled .NET assemblies (`.exe`, `.dll`) carry IL plus full type metadata, so decompilation produces near-original C#. Python `.pyc` is CPython bytecode plus a header — the decompilation challenge is mostly tracking which opcode set was used. Both are dramatically faster to reverse than native code; pair with [[rust-go-reverse]] for compiled-managed-runtime hybrids.

## Preconditions / where it applies
- A managed binary (PE header with CLR data directory) or a `.pyc`/embedded Python.
- For .NET, no heavy obfuscation; for Python, the matching CPython version.

## Technique

### .NET
Triage:

```bash
file app.exe                 # PE32 executable (console) Intel 80386 Mono/.Net assembly
ilspycmd app.exe > app.cs    # one-shot decompile
```

Tools:
- **dnSpy / dnSpyEx** — decompile, edit IL, debug live .NET processes.
- **ILSpy** — same engine, no debugger.
- **dotPeek** — JetBrains decompiler.
- **de4dot** — deobfuscates ConfuserEx, Eazfuscator, SmartAssembly families.

Workflow:
1. Open in dnSpy; entry point usually `Main` in the module's `<Module>` class.
2. If names look mangled (`a.b.c.d()` everywhere) run de4dot first.
3. Search strings (Ctrl+Shift+K) and types (Ctrl+T).
4. Use Edit Method / Edit IL Instructions to patch licence checks live.

**Watch for:**
- **Reflection-loaded assemblies** — `Assembly.Load(byte[])` hides a second DLL in a resource. Dump bytes, recurse.
- **Native interop** — `[DllImport]` calls drop into native code; switch tools.
- **AOT / NativeAOT / Mono-AOT** — produces real native binaries; no IL to decompile.

### Python
`.pyc` layout: 16-byte header (magic, bit field, timestamp, source size) then a marshalled code object.

```bash
file mod.pyc        # python 3.10 byte-compiled
xxd mod.pyc | head -1
```

Tools by version:
- **uncompyle6** — Python 2.7–3.8.
- **decompyle3** — 3.7+.
- **pycdc** — community decompiler, broader 3.x coverage including 3.11/3.12.
- **uncompyle6 won't touch 3.9+** — use pycdc or step through bytecode with `dis`.

PyInstaller / Nuitka:
- PyInstaller bundles a Python interpreter plus zipped `.pyc`. Extract with `pyinstxtractor.py`, then decompile the resulting `.pyc` files. The encryption key (if `--key` was used) is in the bootloader.
- Nuitka compiles Python to C — treat as native [[reverse-engineering-overview]].

For obfuscated bytecode (custom opcode remap), patch `dis.opmap` and `opcode.opname` in a custom CPython build, then re-emit standard bytecode.

## Detection and defence
- .NET: obfuscate with control-flow flattening (ConfuserEx), strong-name + AOT compile, ship as Single-File AOT.
- Python: ship as a native binary via Nuitka or Cython; treat `.pyc` as plaintext for any threat model.

## References
- [dnSpyEx repo](https://github.com/dnSpyEx/dnSpy) — actively maintained fork
- [pycdc repo](https://github.com/zrax/pycdc) — modern Python bytecode decompiler
