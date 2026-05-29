---
title: Windows internals & user-mode exploit dev
slug: windows-internals
aliases: [windows-exploit-dev]
---

> Build the Windows mental model first, then layer exploit primitives on
> top. The model survives mitigations; the primitives change every year.

## Prereqs

- C and x86 / x64 assembly basics (Intel syntax).
- A Windows 10/11 VM with WinDbg + symbols configured.
- One scripting language for tooling.

## Stage 1 — Windows internals fundamentals

- [[pe-format]] — sections, IAT, EAT, relocations.
- [[windows-processes-and-threads]] —
  TEB, PEB, handles.
- [[tokens-and-privileges]] — primary vs impersonation, SIDs,
  integrity levels.
- [[user-account-control]] — UAC bypass theory.
- [[windows-api-and-syscalls]] — `Nt*` vs `Zw*` vs Win32.
- *Recommended reading:* *Windows Internals* (Russinovich, Solomon,
  Ionescu) — first 6 chapters.

## Stage 2 — user-mode exploit dev

- [[stack-buffer-overflow]] — vanilla overflow, EIP control.
- [[seh-overwrite]] — exception handler abuse.
- [[egghunters]] · [[bad-character-handling]].
- [[rop-chains]] — gadgets, stack pivots.
- Mitigations and their bypasses:
  [[dep-bypass]] · [[aslr-bypass]] ·
  [[safeseh-bypass]].
- [[format-string-bugs]] (less common on Windows, still useful).
- [[heap-exploitation-windows]] — LFH, segment heap (Win10+).
- Tools: [[windbg]], [[x64dbg]], [[ida]] / [[ghidra]],
  [[mona-py]].

## Stage 3 — moving toward modern targets

- 64-bit calling conventions and ROP under
  [[control-flow-guard]] / [[xfg]].
- [[cet-shadow-stack]] implications for chain construction.
- Use-after-free and type confusion fundamentals (browser-class bugs).
- Transition to [[advanced-windows-exploitation]] for kernel and driver
  work.

## References

- [Corelan Team tutorials](https://www.corelan.be/index.php/articles/) —
  the canonical user-mode exploit-dev series.
- [Connor McGarr's posts](https://connormcgarr.github.io/) — modern
  Windows internals and exploit dev.
- [Open Security Training Windows
  Internals](https://opensecuritytraining.info/Welcome.html).
