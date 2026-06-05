---
title: pwn.college methodology
slug: pwn-college-walkthrough-methodology
aliases: [pwn-college-method, ase-walkthrough]
---

> **TL;DR:** pwn.college is the Arizona State University offensive-security curriculum (Yan Shoshitaishvili et al.) — a free, structured progression from "hello world" binary exploitation through advanced kernel pwn. Methodology: work through dojos sequentially, do every challenge, when stuck consult prior dojos' material, and don't move on without solving with understanding. Companion to [[htb-machine-walkthrough-methodology]] and [[c-and-asm-primer]].

## Why pwn.college

- **Free + structured** — the best pipeline from beginner to advanced binary exploitation publicly available.
- **University-grade curriculum** — taught at ASU.
- **Sequential dojos** — earn belts, build on prior work.
- **Active discord community** for help when stuck.
- **CTF-adjacent skills** — many top CTF players passed through.

## Structure

Dojos (as of 2025):
- **Computing 101** — Linux basics, command line, programming.
- **Program Security** — basic exploitation concepts.
- **Software Exploitation** — buffer overflows, shellcode, format strings.
- **Reverse Engineering** — static + dynamic.
- **System Security** — kernel, exploitation, defences.
- **Web Security** — practical web bugs.
- **Memory Errors** — heap, allocator-aware exploitation.
- **System Calls** — Linux syscall surface.
- **Sandbox Escapes** — seccomp / chroot / namespaces.
- **Cryptography**.
- **Architectural Vulnerabilities** — Spectre-class.
- New dojos added periodically.

Belts: white → yellow → blue → green → black → ... earned by completing.

## The pattern

For each challenge:

### 1. Read the description

The challenge briefly describes the vulnerability class. Re-read.

### 2. Examine the binary / source

If source is provided, read carefully — many challenges are CTF-style with the bug visible.

If only binary, use `file`, `checksec`, `strings`, then static analysis with Ghidra / IDA / radare2.

### 3. Identify the bug class

The dojo's topic constrains: in "Buffer Overflows" dojo, every challenge is a buffer overflow variant. Identify the specific variant.

### 4. Determine the primitive

What can the bug do?
- Single byte write?
- Multi-byte controlled write?
- Read arbitrary memory?
- Code execution at given address?

### 5. Build the exploit

Using `pwntools`:

```python
from pwn import *

context.binary = './challenge'
io = process('./challenge')

# Build payload
payload = b'A' * 64 + p64(0xdeadbeef)
io.sendline(payload)

io.interactive()
```

### 6. Debug if needed

`gdb-multiarch + pwndbg` or `gef`:
```sh
gdb -p $(pgrep challenge)
# or
gdb ./challenge -ex "b *0xaddress" -ex "r"
```

### 7. Submit

Pwn challenge servers grade automatically.

### 8. Read peer solutions (after solving)

Discord and writeups show alternative approaches. Adopt cleaner approaches.

## When stuck

- **Re-read** dojo introduction.
- **Re-do** earlier challenge that taught the prerequisite.
- **Read** the kernel of the challenge: source, binary.
- **Discord** — ask in challenge-specific channel. Strict no-spoiler rule means hints not direct answers.
- **Walk away** for a few hours; fresh eyes find things.

Don't read writeups before solving.

## Prerequisites — fill before starting

Before "Software Exploitation":
- Comfortable Linux command line.
- Basic C (functions, pointers, arrays, malloc/free).
- Basic x86-64 assembly (read it; don't need to write fluently).

See [[c-and-asm-primer]], [[bash-and-shell-primer]].

## Specific high-value dojos

### Software Exploitation

Buffer overflows → ret2win → ret2shellcode → ret2libc → ROP → ret2csu. Core foundation. Don't skip.

See [[stack-buffer-overflow]], [[rop-chains]], [[ret2libc]], [[ret2csu]].

### Reverse Engineering

Ghidra-driven analysis. Identify functions, understand control flow, recover algorithms.

See [[ghidra-decompiler]], [[ida-hexrays]].

### Memory Errors (heap)

`malloc` internals — chunks, bins, tcache. Exploitation:
- Tcache poisoning.
- Fastbin attack.
- Unsorted bin leak.
- House of techniques (Spirit, Orange, Force, Einherjar).

See [[heap-exploitation-linux]].

### System Calls

Direct syscalls, ASLR-defeating, sandbox-aware exploitation.

### Sandbox Escapes

seccomp filters, namespace isolation, chroot escape.

### Architectural Vulnerabilities

Spectre, Meltdown reproduction in controlled environment.

See [[spectre-meltdown-deep]].

## Tools

- **pwntools** — Python exploit framework.
- **pwndbg** / **gef** — gdb enhancements.
- **Ghidra**, **IDA**, **Binary Ninja**, **radare2**.
- **one_gadget** — find libc one-shot RCE addresses.
- **ROPgadget**, **ropper** — ROP chain discovery.
- **angr** — symbolic execution for hard challenges.

## Comparison to HTB

- **HTB**: web + Linux/Windows pen-test pipeline.
- **pwn.college**: binary exploitation pipeline.

They complement; don't substitute.

## Pacing

- **Hello dojos**: hours to days.
- **Software Exploitation**: 1–2 months working through.
- **Memory Errors**: 2–3 months.
- **Kernel / advanced**: 3–6 months.

Total to "black belt" — typically a year of consistent work.

## After pwn.college

Natural progressions:
- **CTF play** (pwn category) — picoCTF, RealWorldCTF, DEFCON Quals.
- **HEVD walkthroughs** ([[hevd-stack-overflow-walkthrough]], etc.) — kernel exploitation Windows.
- **OSEE / Pwn2Own preparation** — see [[osee-roadmap]], [[pwn2own-2024-2025-research-roundup]].

## Workflow to study

1. Create pwn.college account.
2. Start at Computing 101 even if you think you know it.
3. Work sequentially. Don't skip.
4. Note techniques in personal cheatsheet.
5. After Software Exploitation dojo, attempt CTF pwn challenges.

## Related

- [[htb-machine-walkthrough-methodology]]
- [[ctf-jeopardy-pwn-strategy]]
- [[oscp-style-box-attack-pattern]]
- [[c-and-asm-primer]]
- [[stack-buffer-overflow]]
- [[rop-chains]]
- [[heap-exploitation-linux]]
- [[ret2libc]]
- [[ret2csu]]
- [[format-string-bugs]]
- [[linux-kernel-pwn-walkthrough]]
- [[building-a-research-home-lab]]
- [[osee-roadmap]]

## References
- [pwn.college](https://pwn.college/)
- [Yan Shoshitaishvili (Zardus) talks](https://www.youtube.com/@zardus)
- [pwntools docs](https://docs.pwntools.com/)
- [LiveOverflow YouTube — binary exploitation series](https://www.youtube.com/@LiveOverflow)
- [Nightmare CTF binary exploitation course](https://guyinatuxedo.github.io/)
- See also: [[htb-machine-walkthrough-methodology]], [[c-and-asm-primer]], [[stack-buffer-overflow]], [[osee-roadmap]]
