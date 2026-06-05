---
title: Hardware glitching (voltage / clock fault injection)
slug: hardware-glitching-deep
aliases: [voltage-glitching, clock-glitching, chip-glitching]
---

> **TL;DR:** Voltage and clock glitching attacks corrupt instruction execution at a precise moment by briefly dropping voltage below spec or pulsing the clock. The CPU may execute wrongly — skip an instruction, misread memory, write wrong value. Used historically against game consoles, smart cards, microcontrollers; modern targets include automotive ECUs, BootROM analysis, and Pre-Silicon DUTs. ChipWhisperer is the standard hobbyist platform. Companion to [[fault-injection-laser-emfi]] and [[bootloader-and-secure-boot-attacks]].

## Why glitching matters

- **Hardware roots of trust** (Secure Boot, BootROM) are otherwise unreachable in software.
- **Game console history** (PS3, Xbox 360, Switch) shows the technique scales to commercial impact.
- **Automotive** ECUs use it to bypass UDS SecurityAccess in research contexts.
- **STM32 / nRF52 / ESP32** microcontrollers have published glitch-bypass for readout protection.
- **Pre-silicon tape-out** verification needs same techniques.

## Glitch types

### Voltage glitch

Drop VCC for nanoseconds. Cells temporarily can't reliably store / fetch. Effects:
- **Skip an instruction** — most common useful effect.
- **Misfetch operand**.
- **Misload register**.
- **Crash** (most common — useless).

Tuning: pulse width (ns), pulse depth (V), pulse position relative to trigger.

### Clock glitch

Inject extra clock pulses or skip pulses, faster than CPU can recover. Effects similar to voltage but more localised in CPU pipeline.

Targets that allow external clock easier to glitch.

### Combined (V+C)

Some platforms more susceptible to combined glitching.

## The attack model

You need:
1. **Trigger** — some observable signal indicating "the security check is about to run."
2. **Delay** — how long after trigger to glitch.
3. **Pulse shape** — width, depth.
4. **Target effect** — what you want to happen (skip the check).
5. **Observation** — confirmation glitch took effect.

Often: 1) trigger on a debug-pin or detected I/O pattern, 2) sweep delay across a window, 3) for each delay, sweep pulse parameters, 4) observe target's reaction (continued boot? failure? success?).

The campaign produces a heatmap of pulse-window vs glitch-success.

## Standard hobby platform — ChipWhisperer

Newae's ChipWhisperer family:
- **CW-Lite** — entry; ~$300.
- **CW-Pro** — research-grade.
- **CW-Husky** — modern; supports JTAG glitch routing.
- **CW-Nano** — pocket-sized basic.

Provides:
- Sub-nanosecond pulse generator.
- Voltage / clock glitching modes.
- Trigger inputs.
- ADC for power-trace capture (also useful for [[side-channel-power-em]]).
- Python API for sweeps.

## Common targets

### Game consoles

- **PS3**: voltage glitch of XDR memory enabled OtherOS recovery.
- **Xbox 360**: RGH (Reset Glitch Hack) — pull RESET pin during early boot to bypass Hypervisor checks.
- **PS Vita / 3DS**: various glitching attacks.
- **Switch**: BootROM bug + glitching for older consoles.

### Smart cards / SIM

Pay TV smart cards, banking smart cards have been glitched historically. Modern smart cards include glitch detectors but new variants continue.

### Microcontrollers

- **STM32**: ReadOut Protection (RDP) bypass via voltage glitch. Affects RDP-1; RDP-2 hardens but not perfectly.
- **nRF52**: similar approach for early production batches.
- **ESP32**: secure boot bypass research.
- **NXP LPC** family.

### Automotive ECUs

UDS SecurityAccess seed-key derivation often runs in custom microcode. Glitching at the right moment skips the bounds check on key length / shape, accepting attacker's key.

See [[obd2-uds-attacks]].

### BootROM / Secure Boot research

Glitch during signature verification → CPU skips comparison → invalid signature accepted → custom boot loaded.

Apple's BootROMs are hardened; some Android SoCs have been demonstrated as glitchable.

## Mitigations

- **Glitch detectors** — circuits detecting voltage / clock anomalies; trigger reset.
- **Active mesh** in package — pierce kills chip.
- **Redundant computation** — same check run multiple times; majority vote.
- **Hardware constant-time crypto**.
- **Brownout detection** with hysteresis.
- **Anti-tamper coatings** — physical removal triggers chip reset.

These raise the cost but don't eliminate the class for sufficiently determined attackers.

## Workflow to learn

1. Buy ChipWhisperer Lite + target board (STM32F0 typically included).
2. Run the standard tutorials.
3. Reproduce a published glitching attack on the target.
4. Move to custom target (your own STM32 board with a sensitive check).
5. Read public glitching writeups for novel targets.

This is hands-on learning; reading alone won't develop the skill.

## Detection

- Hardware integrity monitoring (BIST routines).
- Anomalous boot-loop count.
- Power telemetry (cloud / fleet management).

For research-grade defence: anti-tamper packaging audit.

## Workflow to study

Theoretical:
- Read ChipWhisperer documentation cover-to-cover.
- Read Chris Gerlinsky / chipnuts talks (DEF CON, recon).
- Read Limited Results blog (Yann Allain et al.).
- Read Toothless Consulting publications.

Practical:
- 6-month investment to be productive on a specific target.

## Related

- [[fault-injection-laser-emfi]] — adjacent.
- [[side-channel-power-em]] — adjacent platform.
- [[bootloader-and-secure-boot-attacks]] — adjacent target.
- [[obd2-uds-attacks]] — automotive target.
- [[uart-jtag-debug]] — debug-side adjacent.
- [[firmware-extraction]] — adjacent.
- [[android-trusty-tee-attacks]] — adjacent TEE-side.

## References
- [ChipWhisperer documentation](https://chipwhisperer.readthedocs.io/)
- [Newae](https://www.newae.com/)
- [Limited Results blog](https://limitedresults.com/)
- [Toothless Consulting writeups](https://toothless.co/blog/)
- [Recon.cx — fault-injection talks archive](https://recon.cx/)
- See also: [[fault-injection-laser-emfi]], [[bootloader-and-secure-boot-attacks]], [[obd2-uds-attacks]], [[side-channel-power-em]]
