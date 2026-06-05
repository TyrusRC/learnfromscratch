---
title: Laser and EMFI fault injection
slug: fault-injection-laser-emfi
aliases: [emfi, laser-fault-injection, electromagnetic-fault-injection]
---

> **TL;DR:** Beyond voltage / clock glitching ([[hardware-glitching-deep]]), advanced fault injection uses focused electromagnetic pulses (EMFI) or pulsed laser (LFI) to induce single-cell faults — flipping specific bits or skipping specific instructions with spatial precision. Costlier rigs (Riscure Spider, ChipShouter, custom laser setups) but devastating against modern targets including secure enclaves, TPM, automotive HSMs, and game-console boot. Companion to [[hardware-glitching-deep]] and [[side-channel-power-em]].

## Why EMFI / LFI

- **Bypasses glitch detectors** designed for VCC / clock perturbation.
- **Spatial selectivity** — target specific area of die (one register, one cache line).
- **Bypasses package shielding** in some cases (EMFI through epoxy).
- **Defeats modern hardened secure boot** where voltage glitch fails.
- **Game-console / smart-card / military-grade** research.

## EMFI

Electromagnetic fault injection. A coil or probe generates a brief, high-intensity magnetic pulse that induces eddy currents in chip wires. The localised current upsets one or a few transistors.

Effects:
- Bit flips in registers / SRAM.
- Instruction skip.
- ALU computation error.

Tools:
- **NewAE ChipShouter** — research tool; ~$3000.
- **Riscure Spider / Spider2** — high-end commercial.
- **Custom rigs** with arbitrary waveform generator + RF amplifier + coil.

Precision: tip placement within ~1 mm matters. Translation stages for fine positioning.

## LFI — Laser Fault Injection

Pulsed laser focused on decapsulated chip. Photons knock electrons; localised state upset.

- **Front-side LFI** — through the top metal layers; requires careful decapping.
- **Back-side LFI** — through silicon substrate (after thinning). Better access to active layer.

Tools:
- **Riscure laser stations**.
- **Custom rigs** with 1064 nm or 1450 nm pulsed laser + microscope.

Costs: $10k+ for entry research rig; $100k+ for production research.

Precision: single-transistor.

## Targets

### Smart cards (banking, pay-TV, ID)

Glitch SecurityAccess or PIN check. Industry hardens; cat-and-mouse.

### Game consoles

- **Xbox 360 Reset Glitch Hack** — used voltage glitch but EMFI used in subsequent research.
- **Nintendo Switch BootROM** — partially EMFI-researched.

### Automotive HSMs

ECU's HSM unlocks signed firmware. EMFI bypass for development access.

### TPM

Academic work demonstrates EMFI against TPMs. Required for confidential-computing trust assumptions.

### Apple T1 / T2 / Secure Enclave

T2 chip on Intel Macs had reported research vulnerabilities discoverable via fault injection.

### Pixel Titan-M

Research has demonstrated single-bit fault models on similar secure-enclave designs.

## Mitigations

### Hardware

- **Pulsed fault detectors** — sensors on chip detect EMFI / LFI pulse, trigger reset.
- **Redundancy** — same computation N times.
- **Lockstep cores** — two CPUs execute in lockstep; mismatch triggers fault.
- **Anti-tamper meshes** — packaging integrity.
- **Optical sensors** — detect LFI.
- **Time-redundant verification** — repeat checks at unpredictable intervals.
- **Cryptographic integrity** of working state.

### Software-level

Limited. Hardware is the right layer.

## Workflow to learn

Theoretical: read papers from CHES, FDTC (Fault Diagnosis and Tolerance in Cryptography workshop).

Practical:
- ChipShouter is the entry rig.
- Reproduce a published bug on a known-target board.
- Move toward novel targets with experience.

5-10 year investment to be a senior practitioner. This is a small specialist field.

## Detection

- Anti-tamper alarms.
- Boot-loop monitoring.
- Fleet telemetry of unusual reset patterns.
- Sealed enclosure inspection.

## Real-world incidents / research

- Game-console rooting (multiple generations).
- Pay-TV smart-card breaks.
- Academic demonstrations on TPM, secure enclaves.
- Defence sector — assumed but unpublished.

## Costs and access

- Entry: $3-5k (ChipShouter + decapping + microscope).
- Mid: $30-50k (better generator + positioning).
- High: $100k-1M (Riscure systems).

Access often gated by NDAs / research-program enrolment.

## Related

- [[hardware-glitching-deep]] — entry-level cousin.
- [[side-channel-power-em]] — adjacent.
- [[bootloader-and-secure-boot-attacks]] — target class.
- [[hardware-security-module-attacks]] — target class.
- [[android-trusty-tee-attacks]] — adjacent target.
- [[firmware-extraction]].

## References
- [Riscure publications](https://www.riscure.com/)
- [FDTC workshop proceedings](https://web.archive.org/web/2024/http://fdtc.cr.yp.to/)
- [CHES proceedings](https://ches.iacr.org/)
- [ChipShouter (NewAE)](https://www.newae.com/products/NAE-CW520)
- [Limited Results blog](https://limitedresults.com/)
- See also: [[hardware-glitching-deep]], [[side-channel-power-em]], [[bootloader-and-secure-boot-attacks]], [[hardware-security-module-attacks]]
