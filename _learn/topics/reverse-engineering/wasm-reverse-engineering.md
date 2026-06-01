---
title: WebAssembly Reverse Engineering
slug: wasm-reverse-engineering
---

> **TL;DR:** WebAssembly modules are typed, sectioned binaries; wabt converts them to readable text or pseudo-C, and Ghidra plus browser DevTools cover deeper analysis.

## What it is
A WebAssembly (`.wasm`) module is a binary container split into sections: type, import, function, table, memory, global, export, start, element, code, and data. Each function is a stack-based bytecode body with explicit value types (`i32`, `i64`, `f32`, `f64`, `v128`, ref types). Reverse engineering targets either textual translation (WAT) or higher-level decompilation back to C-like pseudocode.

## Preconditions / where it applies
- A `.wasm` module extracted from a browser, Node.js, or standalone runtime
- wabt 1.0.34+ for `wasm2wat`, `wasm-decompile`, `wasm-objdump`
- Ghidra 11+ with the community WASM loader extension installed
- Chromium-based DevTools for source-map-aware live debugging

## Technique
Convert, decompile, and statically inspect a module.

```bash
# Inventory sections and imports
wasm-objdump -x module.wasm | less

# Lift to WAT (s-expressions)
wasm2wat module.wasm -o module.wat

# Higher-level pseudo-C output
wasm-decompile module.wasm -o module.dcmp

# Strip and re-roundtrip to confirm semantics
wasm-strip module.wasm
wat2wasm module.wat -o roundtrip.wasm

# Ghidra: File > Import > module.wasm with the WASM loader extension,
# then run Auto-Analyze. Functions appear as func_0, func_1, ...
```

In Chrome DevTools open the Sources panel, find the `wasm://` script, set breakpoints on function indices, and use the scope view to inspect locals and the linear-memory hex dump.

## Detection and defence
- App-side: ship modules with integrity hashes (`Subresource-Integrity`-style) and validate before instantiation
- RE-side: keep DWARF or source maps out of production builds; strip custom `name` sections
- Detection: alert on unexpected `import` of `env.memory` or syscall-like host functions inside otherwise pure modules

## References
- [WebAssembly Core Specification](https://webassembly.github.io/spec/core/) — authoritative format reference
- [WABT toolkit](https://github.com/WebAssembly/wabt) — wasm2wat, wasm-decompile, wasm-objdump

See also: [[ghidra-decompiler]], [[executable-files-pe-elf]].
