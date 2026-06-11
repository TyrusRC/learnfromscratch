---
title: OSMR roadmap (EXP-312)
slug: osmr-roadmap
aliases: [osmr-prep-roadmap, exp-312-roadmap]
---
{% raw %}

> OSMR (EXP-312) is OffSec's macOS Control Bypasses certification: 48 hours of userland exploitation on Apple hardware covering TCC, Gatekeeper, SIP, Notarisation, dylib hijacking, XPC abuse, mach IPC, and an arm64(e) userland ROP chain — plus a written report. Plan on 12 focused weeks if you already read C and a little ASM; budget 16+ if Mach-O and dyld are new. Ideal candidate: a red teamer or appsec engineer who has shipped on macOS, can stomach Apple's documentation gaps, and is comfortable in lldb without a GUI hand-hold.

## Who this is for

- You have OSCP-level comfort with a debugger and can read x86_64 or arm64 assembly without panicking.
- You have written at least one buffer overflow exploit from scratch (Linux or Windows is fine).
- You own — or can rent — an Apple Silicon Mac (M1/M2/M3). Intel-only candidates will suffer on the arm64e portion.
- You can read Objective-C and a bit of Swift; most attack surface still ships in ObjC runtime.
- You are willing to spend a week purely on TCC plist semantics without writing a single exploit.

## What OSMR tests

- Format: 48-hour proctored practical exam, three target machines, single report due 24 hours after the exam window closes.
- Environment: dedicated macOS VMs (Apple Silicon-backed) reached via VPN; you bring your own host tooling.
- Scope: userland only — no kernel, no IOKit driver bugs, no SEP.
- Skills: dylib hijacking, TCC bypass, Gatekeeper/Notarisation evasion, XPC service abuse, mach port hijacking, and at least one userland ROP/JOP chain.
- Code reading: expect to audit Objective-C, Swift, and a little C source plus disassembly in Hopper or IDA.
- Deliverables: a professional report with reproduction steps, screenshots, and code for every flag.
- Passing: point-threshold based; partial credit exists but the report carries weight — sloppy reports fail otherwise-working exploits.
- Pace: faster than OSED. You will not have time to learn a new primitive mid-exam.

## Lab setup (do before week 1)

- Apple Silicon Mac running macOS 14 (Sonoma) or 15 (Sequoia); keep one VM on an older minor release for diffing TCC behaviour.
- UTM 4.x or VMware Fusion 13 Pro for spare macOS guests; snapshot before every payload.
- Xcode 15+ with command line tools; `xcrun`, `codesign`, `stapler`, `spctl`, `notarytool` all on `PATH`.
- Hopper Pro 5 or IDA Pro 8.4 with the Mac loader; Ghidra 11 as a free fallback.
- lldb from Xcode, plus `chisel` and `LLDBagility`; do not waste time porting gdb scripts.
- Homebrew for `radare2`, `rizin`, `binwalk`, `jtool2`, `ldid`, `class-dump`; optionally Nix for reproducible toolchains.
- Frida 16 and `objection` for runtime introspection on unsigned targets.
- A clean GitHub repo per week for notes, payloads, and report fragments — version everything.

## The 12 weeks

### Week 1 — arm64(e) assembly and Mach-O literacy

- Read: [[c-and-asm-primer]], [[macos-userland-mitigations]], [[macos-security]], [[oscp-osep-oswe-track-comparison]]
- Labs: disassemble `/bin/ls` and `/usr/bin/say` in Hopper; identify `LC_MAIN`, `__TEXT`, `__DATA_CONST`, and the chained fixups in a recent binary.
- Deliverable: a one-page cheatsheet of arm64 calling conventions and the PAC-relevant instructions (`pacia`, `autib`, `braa`).

### Week 2 — dyld, loader, and library search order

- Read: [[macos-userland-mitigations]], [[porting-public-exploits]]
- Labs: build a toy app that loads a weak `@rpath` dylib; trace with `DYLD_PRINT_LIBRARIES=1` and `dyld_info`.
- Deliverable: a written explanation of why hardened-runtime binaries ignore `DYLD_INSERT_LIBRARIES` and the three exceptions.

### Week 3 — code signing and Notarisation pipeline

- Read: [[macos-security]], [[macos-userland-mitigations]]
- Labs: sign, notarise, and staple a sample app with `codesign --options=runtime` and `notarytool submit --wait`; then strip a signature with `codesign --remove-signature` and observe Gatekeeper.
- Deliverable: a diagram of the Notarisation flow with the four failure points an attacker cares about.

### Week 4 — TCC internals

- Read: [[macos-security]], [[macos-userland-mitigations]]
- Labs: enumerate `TCC.db` schemas in the user and system stores; write a tool that prints every entitlement a target binary holds.
- Deliverable: a reproducible TCC bypass against a non-hardened app from a public CVE write-up.

### Week 5 — dylib hijacking from source review

- Read: [[macos-userland-mitigations]], [[porting-public-exploits]]
- Labs: audit two open-source `.app` bundles for `@rpath`/`@loader_path` weak references; plant a payload dylib and prove execution.
- Deliverable: a 200-line checklist for triaging a `.app` for hijacking surface.

### Week 6 — XPC service audit

- Read: [[macos-mach-port-exploitation-walkthrough]], [[macos-security]]
- Labs: list every privileged XPC service in `/Library/PrivilegedHelperTools` on a target VM; reverse one with Hopper and map its `NSXPCInterface`.
- Deliverable: a working PoC that talks to a vulnerable XPC helper without proper client validation.

### Week 7 — mach ports and message construction

- Read: [[macos-mach-port-exploitation-walkthrough]], [[macos-kernel-debugging]]
- Labs: craft a `mach_msg` send/receive pair in C; replicate a public task-port hijack write-up against a non-hardened target.
- Deliverable: a commented C file demonstrating port-right send, copy, and move semantics.

### Week 8 — userland ROP on arm64e

- Read: [[macos-userland-rop-walkthrough]], [[pac-arm64e-bypass]]
- Labs: build a ROP chain against a deliberately-vulnerable C binary using `ropper` and hand-curated gadgets; account for PAC on `LR`.
- Deliverable: an exploit that pops `calc` (or `Calculator.app`) from a stack overflow with full PAC awareness.

### Week 9 — Endpoint Security framework lens

- Read: [[macos-security]], [[macos-userland-mitigations]]
- Labs: write a minimal ES client that logs `ES_EVENT_TYPE_NOTIFY_EXEC`; then design a payload that survives the events you logged.
- Deliverable: a side-by-side table of ES events vs. the attacker techniques that trip them.

### Week 10 — chaining: Gatekeeper to TCC to code exec

- Read: [[macos-security]], [[osmr-exam-strategy]]
- Labs: build an end-to-end chain on a lab VM: signed dropper, Gatekeeper-clean, TCC-bypassing, dylib-hijacking final stage.
- Deliverable: a full report-quality write-up of the chain, including failed branches.

### Week 11 — full exam dress rehearsal

- Read: [[osmr-exam-strategy]], [[report-writing-for-pentesters]]
- Labs: 36-hour timed run against three retired or community boxes; no internet beyond Apple docs and your own notes.
- Deliverable: a complete report draft in your real exam template.

### Week 12 — gap fill and rest

- Read: [[osmr-exam-strategy]], [[report-writing-for-pentesters]]
- Labs: re-run every technique your dress rehearsal stumbled on; nothing new.
- Deliverable: a 1-page exam-day checklist, screen layout, and snippet library.

## Required tooling

- Hopper Pro 5 or IDA Pro 8.4 with Mac loader; Ghidra 11 as backup.
- lldb, `chisel`, `LLDBagility`, `dtrace` where SIP allows.
- `codesign`, `spctl`, `stapler`, `notarytool`, `xcrun`, `jtool2`, `ldid`.
- `class-dump`, `nm`, `otool`, `dyld_info`, `vmmap`, `lsof`.
- Frida 16, `objection`, `ropper`, `radare2`/`rizin`.
- Homebrew for tooling; Nix optional for reproducibility.

## Practice corpus

- OffSec EXP-312 official lab (non-negotiable; budget all 90 days).
- Patrick Wardle's "The Art of Mac Malware" volumes 1 and 2 sample binaries.
- Public CVE write-ups for TCC bypasses (CVE-2020-9934, CVE-2021-30713, CVE-2023-32369).
- HackTricks macOS pages for hands-on lab ideas.
- Objective-See's tool source as defender-perspective reading.
- WWDC sessions on Endpoint Security and hardened runtime.

## Pragmatic notes from people who sat the exam

- Most candidates underestimate Apple Silicon: x86_64 lab habits get punished by PAC and arm64e calling conventions — practise on M-series from day one.
- A week on TCC pays back for the rest of the cert; the database schema and the difference between user and system stores is exam-relevant.
- lldb is the debugger. Stop trying to make gdb work; the time spent porting `.gdbinit` is wasted.
- Hopper Pro is enough for most candidates; only buy IDA if you already own a licence or have employer reimbursement.
- The exam moves faster than OSED. Build a snippet library in week 11 — `mach_msg` templates, ES client skeleton, codesign one-liners — and copy-paste during the exam.
- Read every binary's entitlements before touching it. Half the "impossible" bypasses become trivial once you notice `com.apple.security.cs.disable-library-validation`.

## Failure modes to avoid

- Studying kernel internals or IOKit because they are "cooler" — OSMR is userland.
- Skipping the report. A working chain with a bad write-up will fail; do dry-run reports from week 4 onward.
- Building everything on Intel and discovering arm64e PAC quirks the week before the exam.
- Hoarding zero-days you cannot explain. The exam graders want reproducible primitives, not magic.
- Ignoring sleep. 48 hours means two real sleeps, not amphetamine-fuelled marathons.

## After OSMR

- Move into kernel and IOKit: start with [[macos-kernel-debugging]] and [[iokit-attack-surface]] before chasing a kernel cert.
- Publish one technique write-up; the macOS research community is small and reciprocal.
- Pair OSMR with OSED or OSEE depending on whether your day job is Windows-heavy or research-heavy.

## References

- https://www.offsec.com/courses/exp-312/
- https://developer.apple.com/documentation/security/hardened_runtime
- https://developer.apple.com/documentation/endpointsecurity
- https://objective-see.org/blog.html
- https://theevilbit.github.io/
- https://taomm.org/

See also: [[macos-userland-mitigations]], [[macos-userland-rop-walkthrough]], [[macos-mach-port-exploitation-walkthrough]], [[pac-arm64e-bypass]], [[osmr-exam-strategy]], [[macos-security]], [[report-writing-for-pentesters]], [[oscp-osep-oswe-track-comparison]]

{% endraw %}
