---
title: Spectre / Meltdown / transient-execution attacks
slug: spectre-meltdown-deep
aliases: [transient-execution, spectre-deep, meltdown-deep, microarchitectural-attacks]
---

> **TL;DR:** Modern CPUs perform speculative and out-of-order execution. When a speculative instruction reads data it shouldn't, the architectural state is rolled back — but microarchitectural state (cache lines, branch predictor entries, port pressure) persists. Attackers craft transient-execution windows that touch secret data and leak it through cache-based covert channels. Spectre (branch prediction), Meltdown (privileged read), MDS, L1TF, Foreshadow, RIDL, ZombieLoad, Inception, Downfall, Reptar, GhostRace — the class keeps spawning variants. Companion to [[kpti-meltdown-implications]] and [[side-channel-power-em]].

## Why this class matters

- **Affects almost every modern CPU** — Intel, AMD, ARM, IBM POWER.
- **Cannot be fully fixed in software** — mitigations cost real performance.
- **Hardware redesign** has reduced but not eliminated the class; new variants surface yearly.
- **Cloud multi-tenancy** stakes are huge — cross-VM leakage breaks isolation.
- **Crypto leaks** make it weaponisable beyond academic curiosities.

## Foundational primitives

### Speculation

CPU guesses branch direction and executes ahead. If guess wrong, rolls back architectural state.

### Out-of-order execution

CPU executes instructions as data dependencies allow, not strict program order.

### Cache

Memory hierarchy. Loading X into cache leaves a measurable timing fingerprint.

### Covert channel: FLUSH+RELOAD

Attacker flushes a chosen line; victim runs; attacker reloads chosen line. Cached lines load fast; uncached slow. Bit-by-bit secret leak.

### Branch predictor

CPU caches taken/not-taken history per branch. Cross-process state in some designs.

## Spectre variants

### Spectre v1 — Bounds Check Bypass (CVE-2017-5753)

Speculatively execute past a bounds check. The transient code reads `secret[i]` for attacker-chosen `i` and signals through cache. Patching = serialising barriers (`lfence`) before sensitive bounds checks.

### Spectre v2 — Branch Target Injection (CVE-2017-5715)

Train the branch predictor with attacker-chosen target. Victim's indirect branch speculates to attacker code. Mitigations: IBRS, retpolines, eIBRS, BHB clearing.

### Spectre v4 — Speculative Store Bypass (CVE-2018-3639)

Reorder load before earlier store; transient state reads stale value.

### Spectre-RSB — Return Stack Buffer

Pollute RSB; subsequent returns speculate to attacker target.

## Meltdown (CVE-2017-5754)

User-mode code dereferences kernel memory; access fault, but transient window reads the value. KPTI ([[kpti-meltdown-implications]]) is the OS mitigation: separate page tables for user/kernel.

Only Intel affected widely; AMD and ARM mostly immune.

## MDS class — Microarchitectural Data Sampling

- **RIDL** (Rogue In-flight Data Load).
- **Fallout**.
- **ZombieLoad**.
- **L1TF / Foreshadow**.

Leak from internal CPU buffers (line fill buffers, load ports, store buffers). Affects cross-hyperthread.

## Newer variants

- **CrossTalk** (2020) — cross-core.
- **Cacheout / VRS** (2020).
- **PortSmash** (2018) — port contention side channel.
- **Inception** (AMD Zen 1-4, 2023) — return-address prediction.
- **Downfall** (Intel, 2023, CVE-2022-40982) — Gather instruction side channel.
- **Reptar** (Intel, 2023) — instruction-fetch confusion.
- **GhostRace** (2024) — speculative-race-condition primitives.
- **RowPress** (2024) — DRAM-related.

The class is open-ended; CPU vendors patch microcode and OS code repeatedly.

## Mitigations and their costs

- **KPTI / KAISER** — separate kernel page tables (Meltdown).
- **Retpolines** — return-trampolined indirect calls (Spectre v2).
- **eIBRS / IBPB** — Intel/AMD hardware indirect-branch restricted speculation.
- **SSBD** — speculative store bypass disable.
- **MDS-buffer flush** on context switch.
- **Microcode updates** for transient-window narrowing.
- **Disable simultaneous multithreading (SMT)** — eliminates cross-thread channels but halves throughput.

Performance overhead: 5–30% depending on workload. Database / context-switch-heavy workloads hit hardest.

## Cloud implications

- **AWS / GCP / Azure** apply mitigations + dedicate cores for tenant isolation.
- **Confidential computing** (SGX, SEV, TDX) was historically affected by some variants.
- **VM exit paths** — Spectre variants leak across VM boundary.
- Cloud-provider patches lag occasionally; check vendor advisories.

## Exploit feasibility

In practice:
- **Kernel-secret extraction** via Meltdown demonstrated reliably pre-KPTI.
- **Crypto-key extraction** via cache side-channels on real targets (AES, RSA, ECDSA).
- **Cross-VM leakage** demonstrated for some variants.
- **Browser-side Spectre** demonstrated (SharedArrayBuffer + high-resolution timer); browsers added mitigations (timer coarsening, Cross-Origin Isolation).

But: real-world malicious use is rare — exploits are intricate and slow, and other vulnerabilities are easier to deploy. The class is mostly an inhibitor of certain trust assumptions in cloud + browsers, not a routine attack vector.

## Detection / defensive

- **Microcode current**.
- **OS patches applied**.
- **Browser updates** — Cross-Origin Isolation, COOP/COEP.
- **Anti-cache-timing-protected libraries** for crypto (constant-time code).
- **Disable SMT** in high-assurance contexts.

## Workflow to study

1. Read original Spectre / Meltdown papers.
2. Try a published PoC on a controlled VM (lab-only).
3. Read libgcrypt / OpenSSL constant-time crypto code for defensive patterns.
4. Read Intel / AMD security disclosures for new variants.

## Related

- [[kpti-meltdown-implications]] — KPTI mitigation.
- [[side-channel-power-em]] — adjacent class.
- [[cryptography-side-channels-survey]] — adjacent.
- [[rowhammer-attacks]] — adjacent hardware class.
- [[hardware-glitching-deep]] — adjacent.
- [[browser-exploitation-primer]] — adjacent target.

## References
- [Spectre paper (Kocher et al.)](https://spectreattack.com/spectre.pdf)
- [Meltdown paper (Lipp et al.)](https://meltdownattack.com/meltdown.pdf)
- [transient.fail](https://transient.fail/) — variant catalogue
- [Intel security advisories](https://www.intel.com/content/www/us/en/security-center/default.html)
- [AMD product security](https://www.amd.com/en/resources/product-security.html)
- See also: [[kpti-meltdown-implications]], [[rowhammer-attacks]], [[side-channel-power-em]], [[cryptography-side-channels-survey]]
