---
title: Reverse engineering
slug: reverse-engineering
aliases: [re, binary-reversing]
---

> Reverse engineering as a standalone discipline — distinct from
> exploit dev (covered in [[windows-internals]] /
> [[advanced-windows-exploitation]] / [[linux-internals]]). RE skill
> earns money in malware analysis, IR, mobile security, and any audit
> that lands on a closed-source binary.

## Prereqs

- C or assembly familiarity (you can read it; not write fluently).
- One scripting language for tool-building (Python or Lua).

## Stage 1 — foundations

- [[reverse-engineering-overview]]
- [[executable-files-pe-elf]] — PE, ELF, Mach-O layout.
- [[assembly-basics-x86-64]] · [[assembly-basics-arm]]
- [[string-and-import-recon]] — the first five minutes always.

## Stage 2 — static and dynamic

- [[static-analysis]] · [[dynamic-debugging]]
- [[ida-hexrays]] · [[ghidra-decompiler]] · [[binary-ninja]]
- [[algorithm-identification]] — recognise AES S-box, DES Feistel
  rounds, RSA mod-exp loops, CRC tables by their constants.

## Stage 3 — anti-analysis

Defeating the most common counter-measures real binaries throw at you.

- [[anti-static-analysis]]
- [[anti-debugging]]
- [[packers]] — UPX, ASPack, Themida, VMProtect tiers.

## Stage 4 — modern techniques

- [[symbolic-execution]] — angr, Triton, Manticore.
- [[binary-instrumentation]] — Intel Pin, DynamoRIO, Frida.
- Coverage-guided fuzzing on closed binaries.

## Stage 5 — per-language

- [[rust-go-reverse]] — monomorphisation, panic strings, calling
  convention quirks.
- [[csharp-python-reverse]] — dnSpy / ILSpy / uncompyle6 workflow.

## Where this earns money / impact

- Malware analysis and IR shops hire on RE skill.
- Mobile-security work (see [[mobile-security]]).
- Vulnerability research roles at vendors and at consultancies that
  publish n-day teardowns (Horizon3, watchTowr).
- Bug-bounty programs with binary-only desktop or IoT scope.

## References

- *Practical Binary Analysis* — Dennis Andriesse.
- *Practical Reverse Engineering* — Dang, Gazet, Bachaalany.
- [LiveOverflow](https://www.youtube.com/@LiveOverflow) RE playlists.
- [pwn.college](https://pwn.college/) RE modules.
- *Handbook for CTFers* (Nu1L Team, Springer) — extensive RE chapter
  informed this hub's RE topic structure.
