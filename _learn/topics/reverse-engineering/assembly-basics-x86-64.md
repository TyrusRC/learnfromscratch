---
title: x86 / x86-64 assembly basics
slug: assembly-basics-x86-64
---

> **TL;DR:** Variable-length CISC, two calling conventions you must memorise (System V vs Microsoft x64), and a handful of compiler idioms covering 90% of what decompilers emit.

## What it is
x86-64 is the desktop/server default. Reading it fluently is non-negotiable for binary RE on Windows, Linux, and pre-Apple-Silicon macOS. Pairs with [[assembly-basics-arm]] for the mobile side.

## Preconditions / where it applies
- Any PE/ELF/Mach-O binary on Intel/AMD CPUs.
- A disassembler with x86-64 support (every mainstream one).

## Technique
**Registers (64-bit):** `rax rbx rcx rdx rsi rdi rbp rsp r8..r15`. Low halves: `eax` (32), `ax` (16), `al`/`ah` (8). XMM/YMM/ZMM for SIMD.

**Calling conventions:**

| | System V (Linux, macOS) | Microsoft x64 (Windows) |
|---|---|---|
| Int args | `rdi rsi rdx rcx r8 r9` | `rcx rdx r8 r9` |
| FP args | `xmm0..xmm7` | `xmm0..xmm3` |
| Return | `rax` (`rax`+`rdx` 128-bit) | `rax` |
| Shadow space | none | 32 bytes on stack |
| Callee-saved | `rbx rbp r12..r15` | `rbx rbp rdi rsi r12..r15 xmm6..xmm15` |
| Stack align | 16B before `call` | 16B before `call` |

**Canonical prologue/epilogue:**

```asm
push rbp
mov  rbp, rsp
sub  rsp, 0x20
; ...
leave              ; mov rsp, rbp; pop rbp
ret
```

**Compiler idioms to recognise instantly:**

- `xor reg, reg` — zero a register (shorter than `mov reg, 0`).
- `test rax, rax / jz label` — null check.
- `lea rax, [rbx + rcx*4]` — multiply-add as address computation (NOT a load).
- `cdq / idiv` — signed divide; `xor edx, edx / div` — unsigned.
- `mov eax, eax` — zero-extend (writes to 32-bit clear top 32).
- `movsxd rax, eax` — sign-extend 32→64.
- `rep stosb / movsb` — memset / memcpy unrolled.
- `endbr64` — first instruction of indirect-call targets (CET-IBT).

**Syscalls (Linux x86-64):** number in `rax`, args `rdi rsi rdx r10 r8 r9`, `syscall`. Note `r10` not `rcx` because `syscall` clobbers `rcx`/`r11`.

**Windows API:** import via IAT; first arg in `rcx`. `__fastcall` is the default for x64.

**Stack layout looking up from `rbp`:**
- `[rbp+8]` saved return address.
- `[rbp+16]` first stack arg (after regs spill).
- Locals at `[rbp-N]` / `[rsp+M]`.

**Flags**: ZF (zero), SF (sign), CF (carry), OF (overflow), PF (parity), DF (direction — clear before string ops).

## Detection and defence
- CET (Control-flow Enforcement Technology) — shadow stack + IBT. Misuse triggers `#CP`.
- Stack canaries (`__stack_chk_fail`) — RE will see a load from `%fs:0x28` / `%gs:0x14`.
- PIE + ASLR mean absolute addresses become RIP-relative `[rip+disp32]`.

## References
- [Intel SDM Volume 2](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) — instruction reference
- [System V ABI x86-64](https://gitlab.com/x86-psABIs/x86-64-ABI) — Linux/macOS calling convention spec
