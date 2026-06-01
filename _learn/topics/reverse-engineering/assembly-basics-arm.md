---
title: ARM / AArch64 assembly basics
slug: assembly-basics-arm
---

> **TL;DR:** Load-store RISC ISA with fixed 32-bit (A64) or mixed 16/32-bit (Thumb) encoding, 31 general registers, and a calling convention you must know cold for mobile and embedded reverse.

## What it is
ARM dominates mobile (iOS, Android), embedded, and increasingly desktop/server (Apple Silicon, Graviton). AArch64 (ARMv8 64-bit) is the modern target; ARMv7 / Thumb-2 is still common in firmware. Pairs with [[assembly-basics-x86-64]] as the second ISA every reverser needs.

## Preconditions / where it applies
- Mobile apps (Android .so, iOS Mach-O), firmware (routers, IoT), Apple Silicon binaries.
- Disassembler with ARM mode: [[ghidra-decompiler]], [[ida-hexrays]], [[binary-ninja]], objdump, radare2.

## Technique
**Registers (AArch64):**
- `x0..x30` 64-bit GPRs; `w0..w30` are the low 32 bits.
- `x0..x7` argument + return registers.
- `x8` indirect result / syscall number (Linux).
- `x9..x15` caller-saved (temps).
- `x19..x28` callee-saved.
- `x29` frame pointer, `x30` link register (return address), `sp` stack pointer.
- `pc` not directly addressable; use `adr`/`adrp`.

**Calling convention (AAPCS64):** args in `x0..x7`, FP/vector args in `v0..v7`, return in `x0` (`x0`+`x1` for 128-bit). Stack 16-byte aligned.

**Canonical idioms:**

```asm
; function prologue
stp x29, x30, [sp, #-32]!   ; save FP+LR, allocate 32B
mov x29, sp
; ... body ...
ldp x29, x30, [sp], #32     ; restore, deallocate
ret                          ; branches to x30
```

```asm
; PC-relative addressing for globals
adrp x0, msg                 ; page address
add  x0, x0, :lo12:msg       ; + offset
bl   puts
```

**Load-store**: no memory operands on ALU ops. Everything goes through `ldr`/`str` (and pair variants `ldp`/`stp`). Addressing modes: pre-index `[x0, #8]!`, post-index `[x0], #8`, register offset `[x0, x1, lsl #3]`.

**Control flow**: `b`/`bl` (unconditional / link), `b.eq` etc (NZCV-conditional), `cbz`/`cbnz` (compare-and-branch zero), `tbz`/`tbnz` (test bit).

**ARMv7 + Thumb**: PC is `r15`, LR `r14`, SP `r13`. Thumb encodes 16-bit; switch between modes via the low bit of branch targets. IT blocks gate up to 4 conditional instructions.

**SIMD**: NEON registers `v0..v31` (128-bit), used heavily by memcpy/crypto.

**Syscalls (Linux AArch64)**: number in `x8`, args `x0..x5`, `svc #0`.

## Detection and defence
- Reversing-related: PAC (Pointer Authentication) on Apple Silicon / ARMv8.3 signs return addresses with `paciasp` / `autiasp`; you'll see those in every prologue.
- BTI (Branch Target Identification) restricts indirect branch targets.
- MTE (Memory Tagging Extension) catches UAF/overflow at runtime.

## References
- [ARM Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest) — authoritative ISA spec
- [AAPCS64](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst) — calling convention details
