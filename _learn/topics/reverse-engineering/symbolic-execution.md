---
title: Symbolic execution
slug: symbolic-execution
---

> **TL;DR:** Treat inputs as symbols, propagate constraints through the program, ask an SMT solver for a concrete input that reaches a target state — angr, Triton, Manticore.

## What it is
Symbolic execution explores program paths analytically. Instead of concrete values, variables hold symbolic expressions; branches add constraints to a path condition; at any point an SMT solver (Z3, Yices) can decide if a path is feasible and produce a model — i.e. an input that follows it. The classic killer use case: solving keygen/checker problems, finding crashing inputs, proving (un)reachability of code regions.

## Preconditions / where it applies
- A small, deterministic piece of code where the input space is too big for brute force but the path constraints are tractable.
- Library functions modelled or replaced with summaries — otherwise the engine "explodes" inside libc.

## Technique
Engines:
- **angr** (Python, VEX IR) — the most common. Lifts binaries to VEX then symbolises.
- **Triton** (C++ with Python bindings) — DBI-friendly, integrates with Pin/Frida.
- **Manticore** — strong for smart-contract analysis (EVM) and Linux x86-64.
- **KLEE** — operates on LLVM bitcode; great if you have source.
- **SymCC / SymQEMU** — compile or QEMU-translate with symbolic tracking, much faster than naive interpretation.

Classic angr crackme solve:

```python
import angr, claripy
proj = angr.Project('./crackme', auto_load_libs=False)
flag = claripy.BVS('flag', 8 * 32)
state = proj.factory.entry_state(stdin=flag)
sm = proj.factory.simgr(state)
sm.explore(find=0x401234, avoid=0x4012a0)   # "good" / "bad" addresses
if sm.found:
    print(sm.found[0].solver.eval(flag, cast_to=bytes))
```

Path explosion is the central problem:
- **Loops** with symbolic bounds blow up.
- **Library calls** drag in libc; replace `printf`, `strlen`, `strcmp` with **SimProcedures** / summaries.
- **State merging** combines equivalent states at join points to keep counts manageable.
- **Concolic** execution alternates concrete and symbolic, using a real input to guide which paths to explore (this is how `driller` augments fuzzers).

Useful patterns:
- **Solve a constraint check** — set up a `state` at the function entry, mark the argument symbolic, explore until the check, solve for `args[0]` such that the check returns success.
- **Prove unreachability** — explore to a target with `step_func` limiting depth; if no state reaches it within budget, you have evidence (not proof) the path is dead.
- **Fuzzing hybrid** — use angr to find inputs that flip branches the fuzzer hasn't reached, then feed them back to the fuzzer (the Driller approach).

When to skip symbex:
- Heavy crypto in the path (SMT can't invert SHA-256 in tractable time).
- Floating-point heavy code (limited Z3 FP support).
- Code with millions of branches — switch to fuzzing or manual analysis.

Combine with [[binary-instrumentation]] to record a concrete trace, then re-execute symbolically along just that path (concolic).

## Detection and defence
- Not a runtime tool on the target side.
- For defenders: code that is hard to symbolically execute (opaque predicates ([[anti-static-analysis]]), MBA expressions, hash-based checks, time-dependent state) raises analyst cost — essentially the same techniques that thwart [[static-analysis]] thwart symbex.

## References
- [angr docs](https://docs.angr.io/) — installation, simgr, SimProcedures
- [Triton documentation](https://triton-library.github.io/) — concolic + symbolic API
