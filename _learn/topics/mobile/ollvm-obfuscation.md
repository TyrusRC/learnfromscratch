---
title: OLLVM obfuscation
slug: ollvm-obfuscation
---

> **TL;DR:** Obfuscator-LLVM rewrites IR with control-flow flattening, bogus control flow, and instruction substitution. Defeat it with pattern-based deflattening, symbolic execution (Triton/angr), or scripted IDA/Ghidra passes.

## What it is
OLLVM is a fork of LLVM that adds three obfuscation passes runnable on any language LLVM compiles (C, C++, Rust, Swift, ObjC). It is the default protection for many Android JNI libraries and iOS binaries, and is bundled into commercial wrappers like Hikari, Armariris and Pluto. Output looks like a giant switch dispatcher dispatched by a "state variable" rather than a sequence of basic blocks.

## Preconditions / where it applies
- Native `.so` / Mach-O code; OLLVM does not touch DEX (Java side stays untouched, see [[dex-file-format]])
- Common in [[apk-unpacking]] loaders, banking apps, DRM, anti-cheat
- Three transformations stack: `-fla` (flatten), `-bcf` (bogus), `-sub` (substitute)

## Technique
**Recognising the passes**

- *Control-flow flattening (`-fla`)* — original basic blocks are turned into cases of a `while(1) switch(state)` dispatcher. Function CFG in IDA shows a hub-and-spokes graph: one dispatch block, many case blocks, one update block, all feeding back to the dispatch.
- *Bogus control flow (`-bcf`)* — opaque predicates (e.g. `x*(x+1) % 2 == 0`) gate fake branches that look reachable but never execute. Visible as branches comparing against constants that are statically true/false.
- *Instruction substitution (`-sub`)* — replaces `add`, `sub`, `xor`, `and`, `or` with longer equivalent sequences. e.g. `a - b` → `a + (~b + 1)`; `a ^ b` → `(a | b) - (a & b)`.

**Deflattening workflow**

1. Identify the dispatcher: the basic block whose successors are all "case" blocks.
2. Recover the state-variable mapping: for each case, what state value selected it and what value it writes back.
3. Reconstruct edges: case block → next case block by following the written state. Drop the dispatcher.

Tools:

- `D810` (IDA plugin) — automated OLLVM/Tigress deflattening using AST rewriting
- `Souper` / `mba-deobfuscator` — simplify MBA (mixed boolean-arithmetic) substitutions
- `Triton` — symbolic execution to concretise opaque predicates and emit a clean CFG
- `angr` — `Project.factory.simulation_manager` with `explore()` plus a custom merge to collapse flattened states
- `miasm` IR + expression simplifier — collapse `-sub` patterns to canonical ops

Sketch of an angr deflattener:

```python
import angr, claripy
p = angr.Project('libnative.so', auto_load_libs=False)
cfg = p.analyses.CFGFast(normalize=True)
func = cfg.functions.function(name='checkLicense')
# Symbolically execute through the dispatcher, hooking the state write to
# record (state_in, state_out) pairs, then rebuild the CFG.
```

For the bogus pass, evaluate the predicate symbolically with Z3; if it is tautological, replace the branch with its always-taken target. For the substitution pass, run an MBA simplifier or apply a pattern-rewrite table over the IR.

**When deflattening is too costly:** instrument with [[frida-hook]] (`Interceptor.attach` on the function entry and exit) to log inputs/outputs and treat the function as a black box. Combined with fuzzing this often recovers the algorithm without ever reading the IR.

## Detection and defence
- OLLVM is the defence; pair with string encryption and per-build seed rotation to break signature-based detectors
- Anti-tamper checksum of `.text` (see [[apk-anti-debug]]) to catch IDA/Ghidra-applied patches
- Custom MBA on top of `-sub` (Hikari) raises symbolic-execution cost exponentially
- Detect emulation/symbolic execution via timing checks and tight loops with side effects

## References
- [Obfuscator-LLVM project](https://github.com/obfuscator-llvm/obfuscator) — original passes
- [Quarkslab – Deobfuscation: recovering an OLLVM-protected program](https://blog.quarkslab.com/deobfuscation-recovering-an-ollvm-protected-program.html) — canonical deflattening writeup
- [D810 IDA plugin](https://gitlab.com/eshard/d810) — automated deobfuscator
