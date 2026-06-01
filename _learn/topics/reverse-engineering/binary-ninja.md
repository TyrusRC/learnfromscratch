---
title: Binary Ninja
slug: binary-ninja
---

> **TL;DR:** Scriptable, IL-first disassembler/decompiler with a clean Python API — the sweet spot for automated analysis pipelines and custom architectures.

## What it is
Binary Ninja (Vector 35) is a commercial RE platform organised around a stack of intermediate languages (LLIL → MLIL → HLIL → Pseudo-C). The graphical UI is matched by a first-class headless Python API, making it the easiest of the big three for writing analysis scripts and custom architecture plugins. See also [[ida-hexrays]] and [[ghidra-decompiler]].

## Preconditions / where it applies
- Commercial / Personal / Free editions; headless requires Commercial.
- Supports PE, ELF, Mach-O, raw blobs; first-party arch plugins for x86, x86-64, ARMv7, AArch64, MIPS, PowerPC, RISC-V, more via plugins.

## Technique
Workflow basics:
1. Open binary; auto-analysis builds CFGs and lifts to LLIL/MLIL/HLIL.
2. Switch IL view (`F5` cycles) to find the right altitude — LLIL for instruction-level fidelity, MLIL for SSA reasoning, HLIL/Pseudo-C for readability.
3. Use `n` to rename, `y` to retype, `;` to comment.
4. Script in Python for everything repetitive.

Canonical headless script:

```python
import binaryninja as bn

with bn.load("/tmp/sample") as bv:
    bv.update_analysis_and_wait()
    for f in bv.functions:
        for bb in f.medium_level_il:
            for insn in bb:
                if insn.operation == bn.MediumLevelILOperation.MLIL_CALL:
                    print(f"{hex(insn.address)} -> {insn.dest}")
```

**Why IL-first matters:**
- MLIL is SSA-friendly — built-in `ssa_form` gives use-def chains for free.
- Type propagation works across IL levels; retyping a variable updates HLIL.
- Architectures are plugins implementing `Architecture` + lifter to LLIL — you get the whole IL stack for free once you lift.

Useful built-ins:
- **Linear sweep + recursive descent** combined analysis catches more functions in stripped binaries.
- **Tags** for marking findings without comments.
- **Dataflow** queries: `function.get_constants_referenced_by(insn)`.
- **DWARF / PDB import** for symbols.
- **Type Libraries** for common APIs (Win32, libc, OpenSSL).

Sidekick (AI assistant), Sidekick Cloud, and the BNIL signature system speed library identification — comparable to IDA F.L.I.R.T.

## Detection and defence
- Not a runtime tool; nothing to detect. Concerns are around licence enforcement and update channels.
- For reverse-engineering protected targets, combine static work in Binary Ninja with [[dynamic-debugging]] / [[binary-instrumentation]] to defeat [[anti-static-analysis]] and [[packers]].

## References
- [Binary Ninja user docs](https://docs.binary.ninja/) — UI + workflow
- [Binary Ninja Python API](https://api.binary.ninja/) — API reference for scripting
