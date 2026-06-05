---
title: CubeSat / small satellite attacks
slug: cubesat-attacks
aliases: [smallsat-attacks, cubesat-security, nanosatellite-attacks]
---

> **TL;DR:** CubeSats and small satellites have proliferated as cheap research / commercial platforms. Most run constrained MCUs or COTS Linux, with minimal security beyond obscurity. Attack surface: uplink radio (often unauthenticated commands), bus-protocol design flaws, supply-chain in OEM components, ground-station compromise leading to space-segment control. Hack-a-Sat and DEF CON Aerospace Village have raised public awareness. Companion to [[ground-station-attacks]] and [[gps-gnss-spoofing]].

## Why small-sat security matters

- **>9,000 active satellites** as of 2025, mostly Starlink + smaller constellations + CubeSats.
- **Academic launches** typically have low budgets, minimal security review.
- **Commercial earth observation** sells imagery; access manipulation has commercial value.
- **Adversarial-disruption** scenarios — state actors interfering with civil / commercial systems.
- **Hack-a-Sat (USAF)** and DEFCON Aerospace Village have published vuln classes.

## The space segment

A typical CubeSat:
- **OBC (On-Board Computer)** — ARM Cortex-M or low-end Linux SBC.
- **EPS** — power.
- **ADCS** — attitude determination/control.
- **COMMS** — UHF/VHF radio for command + S/X-band for data.
- **Payload** — imager / experiment.

Software:
- Custom command parsers (no standard like ground systems).
- Often C / C++ on MCU.
- Occasionally Linux with COTS stack.

Critical: many run **without authentication** on command links, relying on:
- Low transmit power requiring large dish to reach.
- Obscurity (frequency, protocol).
- Constrained command repertoire.

These aren't security; the threat model assumed no determined adversary.

## Class 1 — Unauthenticated uplink commands

Many CubeSat radio links accept commands without cryptographic auth. With:
- Knowledge of frequency (often FCC-published).
- Knowledge of protocol (AX.25 + custom command set).
- Sufficient transmit power (or SDR + amp + dish).

Attacker sends commands. Possibilities depend on the spacecraft.

Various academic and hobbyist demonstrations of unauthorised uplinks against amateur radio satellites.

## Class 2 — Replayed authenticated commands

Some satellites authenticate but accept replays:
- Capture a legitimate command.
- Replay later.

Defence: nonce / sequence in command, time-bound MAC.

## Class 3 — Command-parser memory corruption

Constrained C parsers on MCUs:
- Buffer overflows in field parsing.
- Integer overflow in length checks.
- Malformed packets → memory corruption → arbitrary code on OBC.

Hack-a-Sat exercises have shown such bugs in challenge spacecraft.

## Class 4 — Bus protocols

CubeSat internal buses: I2C, SPI, CAN, RS-485. Subsystems trust messages on bus.
- Attacker who reaches the bus (via initial OBC compromise) can:
  - Power-cycle subsystems.
  - Reconfigure ADCS.
  - Spoof EPS to other components.

## Class 5 — Software-defined radio (SDR) misconfig

Some smallsats use SDR for flexibility. Misconfig:
- Firmware loaded over the air.
- Loader accepts unsigned images.
- Attacker uploads attacker firmware.

## Class 6 — Supply-chain in COTS components

OBC kits, radio modules, ADCS units come from vendors. Vendor compromise = field-deployment compromise.

## Class 7 — Ground-station compromise → space

See [[ground-station-attacks]]. If ground is compromised, all spacecraft under its control are.

## Class 8 — Payload command channel

Payload often has its own command interface separate from spacecraft bus. Payload compromise can:
- Steer optics / antennas.
- Capture and exfiltrate imagery.
- DoS by overconsuming power.

## Class 9 — Decommissioning / safe-mode override

Many spacecraft have safe-mode commands intended for ground-recovery. If attackers can invoke:
- Force into safe-mode (DoS).
- Override safe-mode (recovery hijack).

## Real-world history

- **Hack-a-Sat 2020-2023** — USAF-sponsored CTF targeting representative spacecraft. Lots of public reverse-engineering writeups.
- **Viasat / KA-SAT incident (2022)** — ground-segment compromise propagated to user-terminal modems; not spacecraft itself but related.
- **Several amateur satellites** — academic demonstrations of unauthorised commanding.
- **Reported Russian / Chinese interference** in commercial earth-observation. Public details limited.

## Defensive baseline

For mission designers:
- **Authenticate every command** — HMAC-bound to monotonic counter + time.
- **Code signing** for firmware uploads.
- **Parser hardening** — fuzz-tested before launch (you can't patch easily after).
- **Bus authentication** — internal messages MAC'd.
- **Watchdog + safe-mode** with cryptographic unlock.
- **Crypto-agility** — pre-deploy with PQC ready ([[post-quantum-crypto-attack-surface]]).

For ground:
- **Treat ground station as crown-jewel** — see [[ground-station-attacks]].
- **Limit operator workstation network exposure**.
- **MFA**, hardware tokens.

## Workflow to study

1. SDR (HackRF, BladeRF, USRP) + amateur antenna.
2. Listen to amateur satellite beacons (legal in most countries).
3. Read AMSAT amateur-satellite documentation.
4. Hack-a-Sat archive — challenges + writeups.
5. DEFCON Aerospace Village content.

For research uplink: requires licence in most jurisdictions. Don't transmit without authorisation.

## Standards / regulatory landscape

- **CCSDS** (Consultative Committee for Space Data Systems) — standard protocols for space comms.
- **ITU** — radio frequency coordination.
- **FCC / national regulators** — licensing.
- **NIST SP 800-181** / various — emerging space-sector security frameworks.
- **DoD Space Systems Engineering and Cyber Resiliency Guide**.

## Related

- [[ground-station-attacks]]
- [[gps-gnss-spoofing]]
- [[satellite-modem-attacks]]
- [[sdr-and-radio-recon]]
- [[firmware-extraction]]
- [[freertos-audit]]
- [[zephyr-audit]]

## References
- [Hack-a-Sat archive](https://hackasat.com/)
- [DEFCON Aerospace Village](https://aerospacevillage.org/)
- [CCSDS standards](https://public.ccsds.org/)
- [AMSAT — amateur satellite](https://www.amsat.org/)
- [Aerospace Corp — Cyber-Space Engineering](https://aerospace.org/research/cybersecurity)
- See also: [[ground-station-attacks]], [[gps-gnss-spoofing]], [[satellite-modem-attacks]], [[sdr-and-radio-recon]]
