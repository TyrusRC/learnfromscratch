---
title: OSED roadmap (EXP-301)
slug: osed-roadmap
aliases: [osed-prep-roadmap, exp-301-roadmap]
---
{% raw %}

> OSED (EXP-301) is OffSec's Windows user-mode exploit-dev cert: a 48-hour practical exam against three custom binaries where you reverse the protocol, find the bug, and weaponise it past DEP and ASLR with a ROP chain — usually with an egghunter, custom encoder, and a staged payload. Budget twelve focused weeks if you already read x86 assembly; sixteen if you don't. Ideal candidate: someone comfortable with [[stack-buffer-overflow]] mechanics who wants to leave Metasploit behind and write exploits by hand.

## Who this is for

- You can read x86 assembly at conversational speed (call/ret, prologues, stack frames, calling conventions).
- You have written at least one vanilla EIP-overwrite exploit against vulnserver or SLMail.
- You know your way around WinDbg or Immunity with mona.py loaded.
- You can write tidy Python 3 — sockets, struct packing, byte juggling, no copy-paste.
- You have 10–15 quiet hours a week and a Windows lab you can revert quickly.

## What OSED tests

- 48-hour hands-on exam, then 24 hours for the report. No extensions.
- Three custom Windows binaries on Windows 10 with DEP and ASLR enabled.
- You must reverse-engineer a proprietary network/file protocol from a binary you have never seen.
- Each target needs a working PoC plus a fully weaponised exploit (popped calc or a meaningful primitive).
- Expect a ROP chain to defeat DEP, an info leak or non-ASLR module to defeat ASLR, plus a badchar gauntlet that forces a custom encoder/decoder.
- Egghunters and staged shellcode are fair game when buffer space is tight.
- Deliverable: a professional report with reproducible exploit scripts, screenshots of each stage, and clean writeups per target.
- Scoring is 60/100 over three challenges plus assignments; partial credit exists, so PoCs count.

## Lab setup (do before week 1)

- Windows 10 22H2 VM with VirtualBox or VMware — snapshots are your debugger time machine.
- WinDbg Preview (current) plus classic WinDbg from the Windows SDK for the `.load pykd` flow.
- Immunity Debugger 1.85 with mona.py from the Corelan GitHub — still the fastest ROP gadget hunter.
- x64dbg current build for a sane modern UI; pair with x32dbg for the 32-bit targets EXP-301 uses.
- IDA Free 8.x (functional enough) or Ghidra 11.x; pick one and learn its hotkeys cold.
- Python 3.11+ with `pwntools`, `keystone-engine`, `capstone`, `requests`.
- A Kali VM only for `msfvenom` sanity-checks and `nasm` — you will not use Meterpreter on the exam.
- A Git repo of your exploit template, mona configs, and gadget cheatsheets.

## The 12 weeks

### Week 1 — x86 refresher and tooling fluency

- Read: [[c-and-asm-primer]], [[stack-buffer-overflow]], [[stack-bof-walkthrough-end-to-end]], [[mona-py]]
- Labs: Solve five crackmes on crackmes.one in IDA/Ghidra; reproduce the classic vulnserver `TRUN` BOF.
- Deliverable: A markdown cheatsheet of WinDbg + Immunity + mona commands you actually use.

### Week 2 — Vanilla stack BOFs end to end

- Read: [[stack-bof-walkthrough-end-to-end]], [[bad-character-handling]], [[porting-public-exploits]]
- Labs: Exploit `vulnserver` `GMON`, `KSTET`, and `HTER` from scratch — no public PoCs.
- Deliverable: Personal Python exploit template (cyclic pattern, badchar finder, EIP control, jump stub).

### Week 3 — SEH chain overwrites

- Read: [[seh-overwrite]], [[mona-py]], [[bad-character-handling]]
- Labs: Build a SEH exploit against vulnserver `GMON`; replicate one historical SEH CVE on Windows 7 in a VM.
- Deliverable: A 1-page diagram of the SEH chain with POP/POP/RET selection rules.

### Week 4 — Egghunters and tiny buffers

- Read: [[egghunters]], [[osed-egg-hunter-and-staging-deep]], [[custom-windows-shellcode-writing]]
- Labs: Use Skylined's `w00tw00t` egghunter against a constrained buffer; write your own egghunter in NASM.
- Deliverable: Two egghunter variants (SEH-safe, IsBadReadPtr) with size and reliability notes.

### Week 5 — Shellcode hand-writing

- Read: [[custom-windows-shellcode-writing]], [[c-and-asm-primer]]
- Labs: Hand-write a `WinExec("calc",1)` payload via PEB-walk to `kernel32`; benchmark size vs `msfvenom`.
- Deliverable: A reusable PEB-walk shellcode skeleton committed to your repo.

### Week 6 — Custom encoders and decoders

- Read: [[osed-shellcode-encoder-decoder-development]], [[custom-decoder-development]], [[bad-character-handling]]
- Labs: Write an XOR-with-rolling-key encoder + decoder stub; defeat a synthetic 40-byte badchar set.
- Deliverable: A `encode.py` + NASM decoder that survives a printable-only constraint.

### Week 7 — ROP fundamentals

- Read: [[rop-chains]], [[dep-bypass]], [[mona-py]]
- Labs: Build a `VirtualProtect` ROP chain against a custom vulnerable C program you compile with `/NXCOMPAT`.
- Deliverable: A gadget-selection methodology doc (pivot, args, padding, return-to-shellcode).

### Week 8 — DEP bypass against real targets

- Read: [[dep-bypass]], [[rop-chains]], [[porting-public-exploits]]
- Labs: Port a public Easy File Sharing or Savant exploit to a fresh Windows 10 VM; rebuild the ROP from scratch.
- Deliverable: A clean exploit with `mona.py rop` output annotated gadget-by-gadget.

### Week 9 — ASLR bypass

- Read: [[aslr-bypass]], [[rop-chains]]
- Labs: Find a non-ASLR module in a target; build a partial-overwrite info leak against a toy server.
- Deliverable: A decision tree: "non-ASLR module → partial overwrite → info leak → brute force".

### Week 10 — Format strings and write primitives

- Read: [[aslr-bypass]], [[custom-windows-shellcode-writing]]
- Labs: Solve three pwn.college format-string challenges; build an arbitrary-write primitive on a Windows toy.
- Deliverable: Notes on how `%n` survives on modern Windows (and when it does not).

### Week 11 — Full kill-chain dry run

- Read: [[osed-custom-exploit-walkthrough]], [[osed-egg-hunter-and-staging-deep]], [[osed-shellcode-encoder-decoder-development]]
- Labs: Pick a binary you have not seen (TinyWeb, Disk Pulse, ALLMediaServer) — reverse, exploit, weaponise in 12 hours.
- Deliverable: Three working exploits with DEP+ASLR bypass and screenshots per stage.

### Week 12 — Report rehearsal and timing

- Read: [[report-writing-for-pentesters]], [[osed-custom-exploit-walkthrough]]
- Labs: Re-run week 11 targets timed; write the report inside the 24-hour window.
- Deliverable: Final exam report template (LaTeX or Word) with placeholders, snippets, and screenshot folders.

## Required tooling

- WinDbg Preview, Immunity 1.85, x64dbg/x32dbg, IDA Free or Ghidra.
- mona.py, pykd, pwntools, keystone-engine, capstone, NASM.
- Process Monitor, Process Hacker, API Monitor for runtime inspection.
- A Git repo of templates and a `snippets/` folder of working PoCs.

## Practice corpus

- vulnserver (all commands), TinyWeb, Easy File Sharing Server, Savant 3.1, ALLMediaServer, Disk Pulse Enterprise.
- exploit.education Phoenix (Windows builds where applicable) and pwn.college "Memory Errors" module.
- Corelan exploit-writing tutorials 1–11 — do every exercise yourself.
- Connor McGarr's blog walkthroughs for modern Windows internals primers.
- Sektor7 RED Team Operator: Windows Exploit Development Foundations for paid structured drills.

## Pragmatic notes from people who sat the exam

- Build the Python template before you sit — sockets, badchar generator, cyclic pattern, send/recv helpers. You will not have time to invent it at 02:00.
- Custom encoders/decoders are not optional. The exam picks badchar sets that kill `msfvenom` shikata; have your own XOR/ADD/SUB stub ready and tested.
- IDA Free is enough; the speed gain from Pro mostly matters for graph view on big functions. Do not let tooling debt block you.
- Snapshot the VM after every working stage. The "dump-and-resume" pattern (snapshot → crash → revert → tweak) is faster than restarting the target service.
- The report is the bottleneck, not the exploitation. Write each target up the moment it works; do not leave three writeups for hour 60.
- `pwntools` + `keystone` lets you assemble shellcode inline in Python — learn this; it removes a whole class of copy-paste errors.

## Failure modes to avoid

- Relying on Metasploit modules — the exam binaries are custom, no module exists.
- Skipping the egghunter and encoder weeks because "I'll figure it out on the day". You will not.
- Ignoring report rehearsals — failing OSED on reporting is the most painful way to fail.
- Building ROP chains in your head; always have `mona.py rop -m <module>` output checked in.
- Studying without a snapshot discipline — losing a working debugger state at hour 36 is a known killer.

## After OSED

- Move into kernel land with HackSysExtremeVulnerableDriver and the OSEE prep track.
- Or pivot to modern mitigation research: CET, CFG, XFG, hardware-enforced stack protection.

## References

- https://www.offsec.com/courses/exp-301/
- https://www.corelan.be/index.php/articles/
- https://connormcgarr.github.io/
- https://www.fuzzysecurity.com/tutorials.html
- https://github.com/corelan/mona
- https://docs.pwntools.com/en/stable/

See also: [[stack-buffer-overflow]], [[seh-overwrite]], [[egghunters]], [[rop-chains]], [[dep-bypass]], [[aslr-bypass]], [[osed-custom-exploit-walkthrough]], [[oscp-osep-oswe-track-comparison]]

{% endraw %}
