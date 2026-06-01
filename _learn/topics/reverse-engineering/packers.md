---
title: Packers and unpacking
slug: packers
---

> **TL;DR:** Packers wrap a binary in a stub that decompresses or decrypts the real code at runtime — UPX is trivial, VMProtect / Themida virtualise code into custom bytecode and demand serious effort.

## What it is
A packer transforms an executable so that its on-disk image differs from what the CPU eventually runs. The stub at the entry point reconstructs the original code in memory and jumps to the Original Entry Point (OEP). Unpacking is the process of getting from the packed image back to something close to the unpacked binary plus a fixed Import Address Table. Related: [[anti-static-analysis]], [[executable-files-pe-elf]].

## Preconditions / where it applies
- A binary whose section names look unusual (`.UPX0/1`, `.aspack`, `.vmp0`), or whose entropy per section is near 8.0, or whose imports are nearly empty.
- An analysis VM you don't mind detonating the binary in.

## Technique
Identify first:

```bash
die sample.exe                  # Detect It Easy
pe-sieve / pestudio             # entropy + section perms
upx -t sample.exe               # is it UPX?
```

**Tier 1 — trivial:**
- **UPX** — `upx -d sample.exe` restores. If the stub is corrupted to defeat the tool, manually patch the header and re-run.

**Tier 2 — generic packers (ASPack, MPRESS, PECompact, FSG):**
- Generic approach:
  1. Load in [[dynamic-debugging]] (x64dbg).
  2. Set breakpoint on `VirtualAlloc` / `VirtualProtect` to spot the unpacked region.
  3. Use ScyllaHide to mask debugger artefacts.
  4. Run until OEP — typically a `jmp` or `pushad`/`popad` boundary; ESP trick (HW BP on the saved ESP after pushad) lands on the OEP.
  5. Dump with Scylla, fix IAT, rebuild PE.

**Tier 3 — protectors (Themida, VMProtect, Enigma):**
- Code virtualisation: real instructions are compiled to a custom bytecode interpreted by a handler dispatch loop. Each protected function is a giant `while(1) switch(opcode)`.
- Defeat options:
  - Devirtualisation tools (VTIL, Themidie, vmpattack) — research grade, target-specific.
  - Symbolic execution + IL lifting to learn the handler semantics, then re-emit native code.
  - Tracing approach: record one execution per input, reconstruct logic from the trace.
- Realistic outcome: extract enough understanding to identify the algorithm, not produce a clean unpacked binary.

**Tier 4 — custom packers / loaders (malware):**
- Often combine reflective loading, API hashing, and TLS-stage decryption.
- Memory dumping while the process runs almost always yields the payload; use `pe-sieve`, `Volatility3 malfind`, or `procdump -ma` on the live process.

Manual unpacking checklist:
1. Dump the decoded section.
2. Locate OEP (look for compiler-typical prologue or `__security_init_cookie`).
3. Walk the IAT — many packers replace it with stubs; Scylla can rebuild from import names left in memory.
4. Rebuild PE headers, fix section sizes/permissions, set new entry point.

## Detection and defence
- AV/EDR commonly flag packed binaries even without a signature — high entropy + RWX section + small import table.
- For defenders: unpack in sandbox, hash the unpacked image, write detection on the actual payload, not the packer skin.
- For developers wanting protection: assume any client-side packer is defeatable; reserve sensitive logic for the server.

## References
- [Unpacking guide (x64dbg wiki)](https://github.com/x64dbg/x64dbg/wiki/Tutorial) — x64dbg-driven workflow
- [VMProtect analysis writeups](https://back.engineering/17/05/2021/) — academic + practitioner devirtualisation work
