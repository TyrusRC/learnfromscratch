---
title: Payload staging
slug: payload-staging
---

> **TL;DR:** Staged = small stub fetches the real payload at runtime (smaller dropper, more wire signal); stageless = entire beacon ships in one blob (heavier dropper, no fetch). In-proc = post-ex runs in the beacon thread (quieter, riskier); fork-and-run = post-ex spawns a sacrificial process.

## What it is
Staging is the choice between shipping a small loader that pulls the implant over the network ("stager") versus shipping the whole implant ("stageless"). Within an active implant, "fork-and-run" vs "in-proc" describes whether post-ex tooling runs in the beacon's own process or in a freshly-spawned sacrificial one. Both decisions are detection-surface tradeoffs.

## Preconditions / where it applies
- You control the payload-generation step of your C2 framework
- You're making an explicit OPSEC choice based on what the target's EDR / network monitoring is good at

## Technique
**Stager vs stageless.**
- Stager: dropper is tiny (a few KB) — easier to fit in a phishing attachment, easier to obfuscate, but the runtime fetch from stage-2 hosting is visible on the wire. Classic CS HTTP stager hits `/<checksum8>`.
- Stageless: dropper is the whole beacon (hundreds of KB to MB) — no fetch, but the artifact itself contains all signatures. Modern OPSEC defaults to stageless because edge content inspection often flags the stager's deterministic checksum URI.

**In-proc vs fork-and-run for post-ex (Cobalt Strike model, applies broadly).**
- In-proc BOF (Beacon Object File): post-ex runs as a thread inside the beacon process. No extra process create. Failure crashes the beacon. No fork-and-run cleanup.
- Fork-and-run: spawn `rundll32` (or a configured sacrificial process), inject the post-ex tool, run it, exit. Detection-rich because of the spawn + injection pattern. Survives tool crashes. Default for legacy `mimikatz` etc.

Choose:
- **Use in-proc BOF** when the post-ex action is fast, well-tested, and you've already paid the cost of having beacon in memory
- **Use fork-and-run** when the tool is unstable (.NET assemblies, large legacy code) or when you want to push the noise into a process that's *expected* to be noisy
- **Use module-stomping / process-injection variants** when even the spawn is too loud — overwrite a benign DLL's `.text` with shellcode inside an existing process

**Other staging modes.**
- *DLL stager:* drops a DLL, loaded via LOLBin (rundll32, regsvr32)
- *Shellcode loader:* PE → shellcode (Donut, sRDI, pe2shc) → injector → memory
- *Self-contained EXE:* signed via stolen cert, packed, anti-emulation

## Detection and defence
- Stagers: deterministic URI patterns, fixed sizes, fixed cipher results — Suricata rules catch them within hours of public release
- Fork-and-run: parent (legitimate proc) spawns child (rundll32/sacrificial) → immediately injected → makes outbound — three-step rule is broadly written
- In-proc BOF: harder to detect on process tree but memory artifacts (unbacked executable) still show
- Defenders should monitor for unbacked RX/RWX memory in long-running processes (Moneta, PE-sieve, HollowsHunter)

## References
- [Cobalt Strike blog](https://www.cobaltstrike.com/blog/) — staging/stageless rationale
- [Outflank blog](https://www.outflank.nl/blog/) — in-proc post-ex BOF design notes
- [TrustedSec blog](https://www.trustedsec.com/blog/) — sacrificial processes and OPSEC guidance
- [[c2-protocol-design]] [[process-injection-techniques]]
