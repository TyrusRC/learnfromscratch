---
title: RowHammer attacks
slug: rowhammer-attacks
aliases: [rowhammer, dram-rowhammer, half-double, rowpress]
---

> **TL;DR:** DRAM stores bits in capacitors that leak charge over time. Repeated activation of one row ("hammering") induces electrical disturbance that flips bits in adjacent rows. Attackers convert bit flips into security primitives: privilege escalation by flipping page-table entries, sandbox escape, key recovery. Generations of mitigation (TRR, ECC, refresh increases) have been followed by new variants: TRRespass, Half-Double, RowPress, Phoenix. Companion to [[spectre-meltdown-deep]] and [[hardware-glitching-deep]].

## Why RowHammer matters

- **DRAM is the foundation** — every system relies on it.
- **No software-only fix is bulletproof** — the physics is the problem.
- **Crosses all software boundaries** — kernel, sandbox, VM, container.
- **Pure software exploitation possible** — no special hardware access needed.
- **Demonstrated against real targets** — Rowhammer.js (browser), Drammer (Android), GLitch (mobile GPU).

## The physics

DRAM cells are arranged in rows. Activating (reading) a row charges its bit lines. Adjacent rows experience slight electrical disturbance. With repeated activations within the refresh interval (~64 ms), adjacent rows accumulate enough disturbance for bits to flip.

DRAM specs assume max activation rate per row per refresh interval; aggressive workloads exceed.

## Attack primitives

### Single-sided / double-sided

- **Single-sided** — hammer one row N times.
- **Double-sided** — hammer two rows adjacent to a target.

Double-sided gets reliable flips faster.

### Bit-flip → security primitive

A flip in a memory location the attacker doesn't own normally; but with careful page-table manipulation:
- Flip a bit in an attacker-controlled page-table entry → escalate.
- Flip a bit in a kernel data structure.
- Flip a bit in a sandbox check.

The chain is "spray memory to position your target near your hammered rows, hammer, hope for the right flip."

## Variants

### Rowhammer.js (2015)

JavaScript in browser hammers via `array.x` accesses; ASLR + accurate timing. Modern browsers added mitigations.

### Drammer (2016)

Android mobile devices — `ION` allocator behaviour aids spray.

### GLitch (2018)

Used the GPU's WebGL surface to hammer from inside browser.

### One-Location Hammering / Half-Double (2021)

Hammering further away (rows two-removed) still causes flips on intermediate rows. Defeats some mitigations targeting only directly-adjacent.

### TRRespass (2020)

Target Row Refresh (TRR) was an in-DRAM mitigation. TRRespass found patterns that evaded TRR's heuristic.

### RowPress (2024)

Holding a row open longer (not just hammering rapidly) also causes flips. New attack vector.

### Phoenix (2024-2025)

Latest hammering technique that evades existing defenses in DDR5.

## Mitigations

### In-DRAM

- **Target Row Refresh (TRR)** — DRAM refreshes counters; refreshes rows near hot ones.
- **DRAM ECC** (with limitations — single-bit correction misses multi-flip).
- **In-DRAM scrubbing**.
- **DDR5 refresh management** — RFM commands.

### System-level

- **ECC RAM** + scrub interval — corrects some flips.
- **PARA (Probabilistic Adjacent Row Activation)** — academic; activate adjacent rows probabilistically on each read.
- **Refresh-rate doubling** — doubles refresh frequency. Battery / power cost.
- **Memory isolation** — keep sensitive pages in protected memory areas.

### OS / kernel

- **ANVIL** — track suspicious row-activation patterns.
- **Refresh-rate adjustment** at OS level.

## Cloud implications

- **Cross-VM RowHammer** demonstrated in academic settings.
- Cloud providers use:
  - ECC RAM (correct most single-bit flips).
  - Hardware refresh management.
  - Tenant-density limits in some configurations.

For confidential workloads, dedicated-instance or bare-metal isolation is recommended.

## Workflow to study

1. Read original Yoongu Kim et al. paper (2014).
2. Read Rowhammer.js and Drammer follow-ups.
3. Test with `rowhammer-test` (Google) on a dedicated lab machine. May or may not produce flips depending on DRAM generation.
4. Read TRRespass and successors for hardware-mitigation analysis.

Testing destroys long-term DRAM cell health; use sacrificial hardware.

## Defensive baseline

For server / workstation:
- **ECC RAM** mandatory for high-assurance.
- **Modern DDR5** with mitigation support.
- **Cloud-instance type** with dedicated DRAM (confidential VMs, dedicated host).
- **Kernel patches** for known software-level mitigations.

For mobile / embedded:
- Vendor-shipped DRAM with TRR.
- Memory allocator hardening.
- Limited by hardware.

## Real-world incidents

- Public attacks have been research-grade.
- No widely-attributed public criminal use as of 2025.
- Risk is primarily in cloud multi-tenancy and high-value targets where dedicated attackers may invest.

## Related

- [[spectre-meltdown-deep]] — adjacent microarchitectural class.
- [[hardware-glitching-deep]] — adjacent.
- [[side-channel-power-em]] — adjacent.
- [[kpti-meltdown-implications]] — adjacent.

## References
- [Yoongu Kim et al. — original RowHammer paper](https://ieeexplore.ieee.org/document/6853210)
- [Google Project Zero — RowHammer exploits](https://googleprojectzero.blogspot.com/2015/03/exploiting-dram-rowhammer-bug-to-gain.html)
- [TRRespass paper](https://www.vusec.net/projects/trrespass/)
- [Half-Double (Google)](https://security.googleblog.com/2021/05/introducing-half-double-new-hammering.html)
- [RowPress paper](https://safari.ethz.ch/projects_and_seminars/spring2024/lib/exe/fetch.php?media=rowpress.pdf)
- See also: [[spectre-meltdown-deep]], [[hardware-glitching-deep]], [[side-channel-power-em]], [[kpti-meltdown-implications]]
