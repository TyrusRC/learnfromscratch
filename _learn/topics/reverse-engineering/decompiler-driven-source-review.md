---
title: Decompiler-driven source review
slug: decompiler-driven-source-review
aliases: [decompiler-source-review, ghidra-source-review]
---

{% raw %}

> **TL;DR:** When you have a binary but no source, a modern decompiler (Ghidra, IDA Hex-Rays, Binary Ninja) recovers pseudo-C that you audit *as if* it were source. The methodology is the same as source review — find sinks, trace sources, model trust boundaries — but the artefacts (struct definitions, function signatures) need rebuilding before the audit pays off. Companion to [[ida-hexrays]], [[ghidra-decompiler]], [[native-rce-from-source-review]].

## When to reach for this

- You have a binary and need to find pre-auth bugs (OSEE/OSEP-adjacent).
- You're triaging an n-day from a patch and need to know what the vulnerable function looks like.
- You're auditing a vendor SDK shipped only as a `.so`/`.dll`.
- The vendor source is not under license you can quote in a report — but you can still find the bug from binary.

## The recovery loop

1. **Symbol triage** — function names, imports, exports, RTTI, dwarf/pdb if present.
2. **Type recovery** — rebuild structs from access patterns and known APIs.
3. **Calling-convention sanity** — fastcall vs cdecl vs ms_abi; let the decompiler know.
4. **Auto-renamed → meaningful names** — `FUN_140001230` → `parse_packet`.
5. **Sink discovery** — `memcpy`, `strcpy`, `system`, `WinExec`, indirect-call tables.
6. **Source discovery** — entry points (exports, IRP dispatch, RPC server), input parsers.
7. **Trace** — pick a sink, walk backward to a source; pick a source, walk forward to sinks.
8. **Hypothesise → confirm dynamically** — set a breakpoint, send input, observe.

## Tool ergonomics

### Ghidra
```text
File → New Project → Import Files → analyse with all options
Symbol Tree → Imports → find `system`, `popen`, `memcpy`, `strcpy`
Right-click → Find References to → trace callers
P → set variable type ; L → label local
```

Ghidra scripting (Python/Java) — script repetitive renames and struct applications.

### IDA + Hex-Rays
```text
F5 — decompile
Y — set local type (paste C struct)
N — rename
X — cross-references
Alt+P — function signature
```

Type Libraries (TIL) for the platform turn ten lines of struct math into one named access.

### Binary Ninja
Type-Inference does most of the struct work automatically. The python API is cleaner than Ghidra's for auditing at scale.

## Common decompiler tells (so you know what to fix)

- **Off-by-one in unrolled loops** — Hex-Rays sometimes "unrolls" `do/while` into nested `if`s. Look at the assembly to confirm bounds.
- **Indirect calls to nowhere** — `(*v6)(a1, a2)` is a vtable / function-pointer call. Build the vtable struct, name the slots.
- **`v3 = *(int *)(a1 + 12)` everywhere** — type recovery missing. Define a struct, apply it; decompilation collapses to readable form.
- **Unsigned vs signed comparisons** — decompilers default to int; many integer-overflow bugs hide here.

## Audit pattern: parser → sink

Pick a function that handles a network/file packet. In Hex-Rays you'll see:
```c
__int64 parse_message(char *buf, unsigned int len) {
    unsigned int type = *(unsigned int *)buf;
    unsigned int sz   = *(unsigned int *)(buf + 4);
    char *payload     = buf + 8;
    if (sz > len - 8) return -1;            // bound check? confirm
    if (type == 1) {
        char dst[64];
        memcpy(dst, payload, sz);            // ← sz is attacker-controlled
        ...
    }
}
```

The bound check `sz > len - 8` looks like it bounds `sz` to remaining buffer, but `dst` is 64 bytes; classic. Either the check is wrong, or there's a missing `sz > 64` check.

The decompiler view *looked clean*; the bug is in what the developer didn't check. Source-review intuition applies.

## Audit pattern: unhandled error path

```c
HANDLE h = CreateFileA(path, ...);
DWORD r = ReadFile(h, &len, 4, &n, 0);
buf = malloc(len);                 // BUG: if ReadFile failed, len is uninitialised
ReadFile(h, buf, len, &n, 0);
```

Decompilers leave error paths visible; the developer's failure to check `r` shows up as no branch on `r`.

## Diffing patched binaries

See [[patched-binary-diffing-for-vulnid]]. Once you find a candidate vulnerable function from a diff, decompile both versions side-by-side; the bug is usually in the *removed* lines.

## Notes hygiene

For long audits, save a Ghidra project / IDA database with:
- Every renamed function carrying a one-line purpose comment.
- Every struct named and exported.
- A `notes.md` per binary listing audited functions, sinks discovered, hypotheses pending.

When you come back to it three weeks later, that hygiene is the difference between a 1-hour resume and a re-audit.

## When to give up on the decompiler

- Heavy obfuscation (control-flow flattening, opaque predicates) makes decompilation noisy. Switch to a symbolic-execution tool ([[symbolic-execution]]) or instrumented dynamic analysis ([[binary-instrumentation]]) instead.
- A managed runtime (.NET, JVM) hides the C-level model; use dnSpy / JD-GUI / Procyon, not Ghidra.

## References
- [Ghidra documentation](https://ghidra-sre.org/)
- [IDA Pro user manual](https://hex-rays.com/products/ida/support/) (subscription)
- [Binary Ninja API docs](https://docs.binary.ninja/dev/)
- [Practical Binary Analysis — Dennis Andriesse](https://practicalbinaryanalysis.com/)
- See also: [[ghidra-decompiler]], [[ida-hexrays]], [[binary-ninja]], [[patched-binary-diffing-for-vulnid]], [[native-rce-from-source-review]]

{% endraw %}
