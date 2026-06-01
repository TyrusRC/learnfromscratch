---
title: Static analysis
slug: static-analysis
---

> **TL;DR:** Read code or IR without executing — cheap, safe, scriptable. Fails on heavily obfuscated, encrypted, or self-modifying targets; pair with [[dynamic-debugging]].

## What it is
Static analysis examines the binary on disk: headers, sections, disassembly, decompilation, control-flow and dataflow graphs. It is the default first pass because it does not run hostile code and scales to many samples via scripting.

## Preconditions / where it applies
- A binary file (PE/ELF/Mach-O, IL, bytecode) and a parser that understands it.
- Not packed beyond recovery; if so, unpack first ([[packers]]).

## Technique
Four altitudes, pick the right one:

1. **Format triage** — `file`, `rabin2 -I`, `pestudio`, `readelf -a`. Confirm arch, format, hardening flags, suspicious sections.
2. **Surface recon** — strings, imports, exports, resources. See [[string-and-import-recon]]. Yara-match against known malware families.
3. **Disassembly** — linear sweep (objdump) vs recursive descent (IDA, Ghidra, Binary Ninja). Recursive descent handles indirect branches better; linear sweep is faster on clean code.
4. **Decompilation** — IR-driven C-like output. Iterate types and names; the output improves with every annotation.

Static analysis scripts often answer specific questions cheaply:

```bash
# every callsite of strcpy in a directory of binaries
for f in *.bin; do
  objdump -d -M intel "$f" 2>/dev/null \
    | grep -B1 'call.*strcpy@plt' \
    | awk -v f="$f" 'NR%2==1{print f":"$1}'
done
```

```python
# Ghidra headless: list every function calling system()
fm = currentProgram.getFunctionManager()
target = getSymbol('system', None)
if target:
    for ref in getReferencesTo(target.getAddress()):
        fn = getFunctionContaining(ref.getFromAddress())
        if fn: print(fn.getName())
```

**Common static tasks:**
- Identify dangerous sinks (`memcpy`, `strcpy`, `gets`, `system`, `popen`, `exec*`, deserialisation entry points).
- Map data flow from a network/file input to a sink (taint analysis).
- Recover types from heuristics (constructor patterns, vtables, RTTI).
- Identify crypto by constants — see [[algorithm-identification]].
- Diff binaries (BinDiff, Diaphora) to find patched-in changes (patch diffing).

**Where static fails:**
- Packed/encrypted code only reified at runtime.
- JIT (V8, .NET ReadyToRun, WebAssembly modules generated at runtime).
- Heavy obfuscation: control-flow flattening, MBA, virtualisation ([[anti-static-analysis]]).
- Indirect calls without type info — decompiler shows `(*fn)()` with no callee.

For those cases, pivot to runtime tooling: [[dynamic-debugging]], [[binary-instrumentation]], or [[symbolic-execution]] to solve specific reachability questions.

## Detection and defence
- N/A on the analyst side — but defenders care about analysts reading code, so deploy [[anti-static-analysis]] tricks: strings encryption, API hashing, packed sections.
- For supply-chain defence, scan vendor binaries statically before deployment (CodeQL on source, BinAbsInspector / Joern on binaries).

## References
- [HackTricks reversing tools](https://book.hacktricks.wiki/en/reversing/reversing-tools-basic-methods/index.html) — overview of the static toolchain
- [angr documentation](https://docs.angr.io/) — static + symbolic Python framework
