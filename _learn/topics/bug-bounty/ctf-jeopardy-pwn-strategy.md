---
title: CTF jeopardy pwn strategy
slug: ctf-jeopardy-pwn-strategy
aliases: [ctf-jeopardy-strategy, jeopardy-ctf-pwn]
---

> **TL;DR:** Jeopardy CTFs reward fast triage, category specialisation, and disciplined team handoff. Pwn challenges in particular reward fluent toolchain habits (pwntools, gdb-gef/pwndbg, one_gadget) and a small mental library of foothold patterns (stack-based BOF, format string, fmt-leak then ret2libc, heap UAF, kernel module pwn). This note distils a workflow that ports cleanly to bug bounty triage (see [[ctf-to-bug-bounty-transition]] and [[pwn-college-walkthrough-methodology]]).

## Why it matters

CTFs are the cheapest sparring ground for exploit dev, deep web bugs, and crypto/rev fundamentals. A coherent strategy turns 48 hours of caffeine into ranked points and lasting skill, instead of three half-solved challenges and a writeup envy spiral. The same triage instincts (point/effort ratio, foothold-first thinking) port directly to red-team ops and bounty hunts.

### What "jeopardy" means

Independent challenges across categories (pwn, web, rev, crypto, misc, forensics, OSINT, hardware, ICS). Each has a point value (often dynamic: more solves = fewer points). You pick what to solve in what order. Contrast with attack-defense (live services, patch + exploit live).

### Headline events to study

- **picoCTF** — yearly, beginner-to-intermediate, archives stay open.
- **GoogleCTF** — well-scoped, high-quality crypto and web, sharp pwn.
- **DEFCON Quals (Nautilus / Order of the Overflow / current org)** — brutal but defining; obscure architectures and creative pwn.
- **RealWorldCTF (RWCTF)** — heavy on browser, kernel, IoT, blockchain; trends mirror Pwn2Own (see [[pwn2own-2024-2025-research-roundup]]).
- **HITCON, PlaidCTF, SEKAI CTF, Hack.lu, Dragon CTF** — high-signal pwn and crypto sets.

## Triage: choose what to solve

### Read the whole board first

Before opening any challenge, scroll the entire list. Note:

- Point values (low solves on a "100pt" challenge = sandbagged, attack it early; high points with many solves = unlock chain).
- Released time (late drops often easier — authors front-loaded the hard ones).
- Tag/category clusters (a chain of three "warmup" web challenges signals an intro track).

### Point/visible-complexity matrix

| Bucket | Action |
|---|---|
| Low points, low complexity | Solve first to warm up and bank early points. |
| High points, low complexity | Sandbagged or unsolved — prioritise. |
| High points, high complexity | Long-haul; assign your strongest player. |
| Low points, high complexity | Skip unless you're stuck everywhere. |

### Time-box ruthlessly

Set a 25-minute "first contact" budget. If after first contact you have no foothold or hypothesis, drop it on the team channel and rotate. Personal rule: at 90 minutes with no progress beyond initial recon, log a tracker comment and switch challenges. Coming back fresh beats forcing it.

## First-look by category

### Pwn

1. `file ./chal`, `checksec ./chal`, `strings ./chal | head`, `./chal` to see prompts.
2. Note mitigations: NX, PIE, RELRO, canary, ASLR (kernel side).
3. Load in IDA/Ghidra/Binary Ninja; find `main`, `vuln`, suspicious `gets`/`scanf("%s")`/`read` with oversized buffer.
4. Identify the libc: provided file? `ldd`? remote `puts@got` leak strategy?
5. Build a pwntools template (local + remote toggle, `context.binary`, `gdb.attach`).

### Web

1. Open the app in browser + Burp. Map auth, sessions, parameters.
2. Read source if provided — CTF web is usually whitebox.
3. Search for the trope: SSTI ([[ssrf]] and [[host-header-injection]] adjacencies), prototype pollution, deserialisation, SQLi via odd driver, JWT alg confusion, OAuth misconfig, cache deception ([[cache-deception]]), request smuggling ([[http-request-smuggling]]).
4. Diff the framework against known CVEs when versioned.

### Reverse

1. `file`, `strings`, run in a sandbox to see behaviour.
2. Static: Ghidra/IDA for control flow; rename quickly; identify crypto constants (AES S-box, RC4 init, magic primes).
3. Dynamic: `ltrace`, `strace`, frida, gdb scripted. Symbolic execution (angr) for keygens with tractable constraint sets.
4. For VMs/obfuscation: extract handler table, lift to a custom disassembler.

### Crypto

1. Read the source. Identify the primitive (RSA, ECC, AES mode, hash, custom).
2. Match to known attacks: low-e RSA, common modulus, LSB oracle, ECB cut-paste, CBC bit flipping, nonce reuse, Pohlig-Hellman, lattice (LLL) for small-roots problems.
3. SageMath is your friend; CryptoHack writeups are the canon.

### Misc / Forensics / OSINT

- Misc often hides in plain sight: zsteg, exiftool, binwalk, foremost, `strings` with `-e l`, audio spectrogram (Sonic Visualiser), QR/Aztec reassembly.
- Forensics: memory dumps with Volatility 3, disk with Autopsy, packet captures with Wireshark + tshark + Zeek.
- OSINT: reverse image search (TinEye, Yandex), Sentinel/EO satellite for geoint, Wayback Machine, `crt.sh`.

## Pwn-specific foothold patterns

### Stack-based BOF with no canary, no PIE

`pop rdi; ret` gadget + `puts(puts@got)` to leak libc, return to `main`, then second stage to `system("/bin/sh")` using one_gadget.

### Format string

Leak canary + libc base from the stack. Overwrite GOT or `__free_hook`/`__malloc_hook` (glibc < 2.34) or `_IO_2_1_stdout_` via FSOP for newer libc.

### Heap (glibc tcache era)

- Tcache poisoning: double free into tcache, overwrite next ptr to attacker-controlled address.
- Safe-linking (glibc >= 2.32): need a heap leak to compute the obfuscated next ptr.
- House of Botcake, House of Husk, large-bin attacks for constrained primitives.

### Kernel pwn

- Modprobe path overwrite, `core_pattern` overwrite, `usermodehelper` abuse.
- KASLR leak via `prctl`, `dmesg`, or a side channel.
- Modern mitigations: SMEP, SMAP, KPTI, FG-KASLR — plan ROP into kernel text, not userland callbacks.

### Browser / JIT (RWCTF tier)

- Type confusion in V8/JSC/SpiderMonkey, addrof/fakeobj primitives, WASM RWX trampoline (or JIT spray on older engines), sandbox escape via renderer-broker IPC.
- Cross-reference current Pwn2Own writeups ([[pwn2own-2024-2025-research-roundup]]).

## When to persist vs give up

Persist when:

- You have a working PoC locally and only need to stabilise for remote.
- The leak primitive works; you only need a better gadget.
- Two independent hunches converge on the same vuln class.

Give up (for now) when:

- You don't understand the binary's intended state machine after an hour.
- You're guessing at randomness without a model.
- The challenge requires a primitive (e.g., kernel infoleak) you have no template for — bank the learning, move on, read the post-CTF writeup.

Always leave a structured note in the team tracker so a teammate can pick up cold.

## Working with teammates

### Channel hygiene

One channel per category, one thread per challenge. Pin the challenge text + provided files at the top. Update a single "status" line: `triaging | foothold | exploit-dev | stuck | flagged`.

### Handoffs

When dropping a challenge, write three bullets: what you tried, what failed, what you'd try next. This is the same muscle as bug bounty handoffs ([[report-writing-step-by-step]]).

### Pair on pwn

Pwn benefits from a driver/navigator split: one in gdb, one in the disassembler and pwntools. Crypto similarly benefits from a "math" + "coder" pairing.

### Role specialisation

Across a season, designate primary owners per category. Generalists float and pick low-hanging fruit. Track per-event solves to spot training gaps (see [[testing-methodology-checklists]]).

## Workflow to study

1. Build a personal "first 10 minutes" checklist for each category. Print it. Use it every event.
2. Maintain a templates repo: pwntools skeletons (local/remote, leak, ret2libc, tcache), Sage notebooks, Ghidra scripts, Burp configs.
3. Solo-run picoCTF + previous DEFCON Quals/RWCTF challenges from archive. Time-box each like a real event.
4. After every CTF, read the top-3 writeups for every challenge you didn't solve. Add new patterns to your notes.
5. Replay one challenge per week from memory after a month, to cement the pattern.
6. Track ELO against teammates internally to surface category gaps.

## Post-CTF learning

- Within 48 hours, write a personal post-mortem: solves, near-solves, drops, lessons.
- Star or fork the official writeups repo if the org publishes one (GoogleCTF, HITCON do).
- Push your team writeup before reading others' — protects original thinking.
- Build at least one challenge yourself per quarter; authoring is the fastest way to deepen a category.

## Related

- [[pwn-college-walkthrough-methodology]]
- [[ctf-to-bug-bounty-transition]]
- [[oscp-style-box-attack-pattern]]
- [[htb-machine-walkthrough-methodology]]
- [[vulnhub-walkthrough-pattern]]
- [[pwn2own-2024-2025-research-roundup]]
- [[reading-public-pocs-effectively]]
- [[one-day-from-patch-diff]]
- [[testing-methodology-checklists]]
- [[report-writing-step-by-step]]

## References

- picoCTF archive and learning gym: https://picoctf.org/
- GoogleCTF challenge repository: https://github.com/google/google-ctf
- DEF CON CTF archive and Order of the Overflow history: https://www.defcon.org/html/links/dc-ctf.html
- RealWorldCTF official site: https://realworldctf.com/
- pwntools documentation: https://docs.pwntools.com/
- CTFtime event calendar and writeup index: https://ctftime.org/
