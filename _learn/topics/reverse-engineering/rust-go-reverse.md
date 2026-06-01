---
title: Reversing Rust and Go
slug: rust-go-reverse
---

> **TL;DR:** Rust monomorphises generics into a flood of similarly-named symbols and embeds panic messages as strings; Go has its own ABI, runtime, and goroutine scheduler — both demand workflow tweaks vs C/C++.

## What it is
Rust and Go produce native binaries that look superficially like C but bring runtime structures that confuse generic tooling. Knowing the patterns saves enormous time. Complements [[csharp-python-reverse]] for managed runtimes and [[reverse-engineering-overview]] for the generic workflow.

## Preconditions / where it applies
- Native binary written in Rust or Go (commonly statically linked, large, and stripped).
- Disassembler with the right plugins ([[ghidra-decompiler]] GolangAnalyzer, IDA `golang_loader_assist`, [[binary-ninja]] Go workflow plugins).

## Technique

### Rust
Triage signs:
- `__rust_alloc`, `core::panicking::panic_fmt`, `rust_begin_unwind` imports.
- Long mangled symbols (`_ZN4core3fmt9Formatter3pad17h<hash>E`).
- Panic strings with file paths like `src/main.rs:42:18`.

Workflow:
1. Run `rustfilt` (or `c++filt --hint=rust`) to demangle.
2. Look at panic strings — they include source file + line numbers in debug or non-stripped release builds and provide a map back to source structure.
3. Generic functions are **monomorphised**: `Vec<u8>::push` and `Vec<String>::push` are two distinct compiled functions. Expect duplication.
4. Trait dispatch becomes vtable lookups in `.rodata`; tag the vtables.
5. `Result`/`Option` show up as small structs returned by value (`{tag, data}`); ABI returns in `rax`/`rdx`.

Common runtime fingerprints:
- `__rustc_debug_gdb_scripts_section__` section in non-stripped builds.
- Use of `jemalloc`/`mimalloc` allocators changes heap layout.
- LLVM features (autovectorisation, MIR optimisation) leave many small functions.

### Go
Triage signs:
- `runtime.morestack_noctxt`, `runtime.goexit`, `go.buildid`, `go.itab.*`, dense `gopclntab` section.
- File paths like `_cgo_export.c`, package paths `github.com/...`.
- All-in-one static binary, several MB even for "hello world".

Key runtime structures:
- **`pclntab`** (`runtime.pclntab` / `gopclntab`) — function names + file/line tables. Recover symbols even from stripped binaries; tools (`redress`, `golang_loader_assist`, GolangAnalyzer) parse it and restore names.
- **`moduledata`** points to `pclntab`, types, itabs.
- **`itab`** — interface dispatch tables.
- **String** = `(ptr, len)` pair.
- **Slice** = `(ptr, len, cap)`.

Calling convention:
- Pre-Go 1.17: all args on the stack.
- Go 1.17+: register-based ABI (`AX, BX, CX, DI, SI, R8, R9, R10, R11` for ints on amd64). Decompiler output looks much cleaner.

Workflow:
1. Identify Go version (look for `go1.NN.M` string).
2. Run `redress` or the GolangAnalyzer Ghidra plugin to restore function names + types.
3. `main.main` is the user entry point (not `runtime.main`).
4. Goroutines complicate dynamic tracing; `delve` (`dlv`) is the language-aware debugger and beats raw gdb here.

```bash
strings -n 8 sample | grep -E '^go1\.[0-9]+\.[0-9]+'
redress -p sample > funcs.txt
```

## Detection and defence
- Rust: strip aggressively (`strip -s`, `panic = "abort"`, `lto = true`, `codegen-units = 1`) to remove panic file/line strings.
- Go: `-ldflags="-s -w"` strips DWARF + symbol table but `pclntab` remains by design. `-trimpath` removes absolute build paths.
- Neither hides logic from a determined analyst — they merely raise cost.

## References
- [Reversing Go binaries (Mandiant)](https://www.mandiant.com/resources/blog/reversing-golang-binaries) — gopclntab walkthrough
- [Rust binary triage (CheckPoint)](https://research.checkpoint.com/2022/) — demangling and panic-string recovery
