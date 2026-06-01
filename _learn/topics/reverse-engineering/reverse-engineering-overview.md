---
title: Reverse engineering — overview
slug: reverse-engineering-overview
---

> **TL;DR:** Recover semantics from compiled artefacts by combining disassembly, decompilation, and runtime tracing into an iterative loop.

## What it is
Reverse engineering (RE) is the process of going from a built artefact — PE, ELF, Mach-O, .NET assembly, Python bytecode, firmware blob — back to a model of behaviour the analyst can reason about. RE rarely produces source; it produces enough understanding to find bugs, write a patch, build a detection, or write an unpacker.

## Preconditions / where it applies
- You have the binary (or memory dump, firmware image, sample from a sandbox).
- You have a goal narrow enough to scope work: find a vuln, defeat a check, extract a key, document a protocol.
- You know the target arch/format — guess wrong and tools will give garbage.

## Technique
The workflow alternates static and dynamic passes:

1. **Triage**: file type, arch, packer, entropy, imports, strings. See [[string-and-import-recon]].
2. **Static map**: load in [[ida-hexrays]] / [[ghidra-decompiler]] / [[binary-ninja]], find `main` (or `WinMain`, `DllMain`, exported APIs, JNI entries), recover types.
3. **Dynamic confirm**: run under [[dynamic-debugging]] (gdb, x64dbg, WinDbg, lldb) with breakpoints on hot functions; or trace with [[binary-instrumentation]].
4. **Defeat protections**: identify [[packers]] and [[anti-debugging]] / [[anti-static-analysis]] tricks; unpack, patch, or hook past them.
5. **Solve hard branches**: if a check is purely input-driven, [[symbolic-execution]] can solve for inputs.
6. **Document**: comment functions, rename variables, write a script that reproduces the finding.

```bash
# canonical triage
file sample.bin
strings -a -n 8 sample.bin | head -50
rabin2 -I sample.bin   # arch, bits, format, canary, PIE
```

For managed targets jump straight to the matching tool: [[csharp-python-reverse]] for IL/bytecode, [[rust-go-reverse]] for Rust/Go peculiarities.

## Detection and defence
- Defenders embed tamper checks, code signing, runtime attestation, anti-debug, packer + virtualisation obfuscation.
- Telemetry: integrity of loaded modules, debugger-present probes, syscalls indicative of memory patching.
- DRM and licensing layers raise cost, never eliminate RE — assume any client-side check is defeatable given time.

## References
- [Ghidra docs](https://ghidra-sre.org/) — disassembler/decompiler reference
- [HackTricks reversing index](https://book.hacktricks.wiki/en/reversing/reversing-tools-basic-methods/index.html) — quick-reference tools and tricks
