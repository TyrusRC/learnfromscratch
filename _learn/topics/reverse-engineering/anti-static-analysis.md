---
title: Anti-static-analysis tricks
slug: anti-static-analysis
---

> **TL;DR:** Obfuscate the on-disk image — pack, flatten control flow, insert junk bytes, encrypt strings — so disassembly + decompilation look like noise until you run the code.

## What it is
Static analysis tools rely on a clean linear sweep or recursive descent disassembly, identifiable functions, and readable constants. Anti-static tricks break those assumptions so the analyst is forced into [[dynamic-debugging]] or scripting, raising cost. Pair with [[anti-debugging]] for full coverage.

## Preconditions / where it applies
- Native binaries shipped to untrusted endpoints (malware, DRM, games, anti-cheat).
- IL-level languages can be obfuscated similarly via name mangling, control-flow flattening tools.

## Technique
Common families:

- **Packing** — code section is compressed/encrypted; an unpacker stub at entry rebuilds it in memory. See [[packers]].
- **String encryption** — strings XORed or AES-decrypted on first use; static `strings` shows garbage.
- **API hashing** — instead of importing by name, code walks the export table and matches a precomputed hash. The IAT looks empty.
- **Control-flow flattening** — every basic block dispatched through a switch on a state variable; decompiler output is a giant `while(1) switch(state)`.
- **Opaque predicates** — branches whose outcome is constant but cannot be proven without solving (e.g., `(x*x - x) % 2 == 0`).
- **Junk bytes / anti-disassembly** — invalid instructions or misaligned jumps that desync linear disassemblers. IDA's autoanalysis gets confused; recursive descent still wins.
- **Stack strings** — build a string byte-by-byte on the stack so it never appears in .rodata.
- **Self-modifying code** — instructions rewritten at runtime.
- **Mixed Boolean-Arithmetic (MBA)** — replace `a^b` with an equivalent polynomial of `a`, `b`, and constants.
- **Virtualisation** — compile real logic to a custom bytecode interpreted by a handler dispatch loop (VMProtect, Themida).

Defeat:

```python
# Stack string recovery (IDA / Ghidra script pattern)
# 1. Find mov [rbp-XX], imm8 sequences
# 2. Concatenate the immediates ordered by offset
# 3. Comment on the basic block
```

- Unpacking — run to OEP, dump, fix IAT (Scylla, x64dbg dump).
- Flattening — write a deobfuscator script that statically simulates the dispatcher (Triton, miasm).
- Opaque predicates — symbolic execution proves them constant.
- API hashing — precompute the hash for each `kernel32`/`ntdll` export and rename calls in the disassembly.

## Detection and defence
- These are defensive controls; "detection" here is the analyst recognising the family quickly.
- Layered defence: pack the binary, then virtualise the unpacked code, then add anti-debug — raises cost.
- Don't ship secrets in the binary; treat any client-side check as eventually broken.

## References
- [HackTricks obfuscation](https://book.hacktricks.wiki/en/reversing/cheat-engine.html) — practical defeat notes
- [Tigress documentation](https://tigress.wtf/) — academic source-to-source obfuscator showing the families
