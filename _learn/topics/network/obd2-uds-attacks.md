---
title: OBD-II / UDS protocol attacks
slug: obd2-uds-attacks
aliases: [uds-attacks, iso14229-attacks, obd2-attacks]
---

> **TL;DR:** Unified Diagnostic Services (UDS, ISO 14229) is the protocol manufacturers use over CAN/Automotive-Ethernet for diagnostics, programming, and ECU calibration. It supports memory read/write, firmware flashing, and routine activation — all with weak "seed-key" authentication that's often bypassable. Combined with OBD-II physical access (every car) or wireless OBD-II dongles, UDS becomes a route to ECU compromise. Companion to [[can-bus-attacks]] and [[firmware-extraction]].

## Why UDS matters

- It's the **mechanic's interface** — designed for trusted, authorised access. Implementations vary by manufacturer; many have weak auth.
- Provides **memory operations** at very low level — read RAM, write flash.
- **Bootloader / programming** mode allows replacing ECU firmware.
- Available over **OBD-II port** which is in every car since 1996 (US) / 2001 (EU).
- Wireless OBD-II dongles (insurance, fleet) extend the attack surface to remote.

## OBD-II vs UDS

- **OBD-II** is the standardised diagnostic port + a subset of protocols (PIDs for emissions data) for regulatory compliance. Low capability.
- **UDS** is the richer manufacturer-specific protocol layered on top of CAN (or Automotive Ethernet via DoIP). High capability.

Both share the OBD-II physical port. Real attacks live in UDS.

## UDS services

UDS defines numbered "Services" (each a one-byte service ID, SID):

- `0x10 DiagnosticSessionControl` — switch session type (Default, Programming, ExtendedDiagnostic).
- `0x11 ECUReset` — reset.
- `0x14 ClearDiagnosticInformation` — clear DTCs.
- `0x19 ReadDTCInformation`.
- `0x22 ReadDataByIdentifier` — read parameters.
- `0x23 ReadMemoryByAddress` — read RAM / flash.
- `0x27 SecurityAccess` — seed-key authentication.
- `0x2E WriteDataByIdentifier`.
- `0x31 RoutineControl` — run manufacturer-defined routines.
- `0x34 RequestDownload` — request to write data (firmware upload).
- `0x35 RequestUpload` — request to read data (firmware download).
- `0x36 TransferData`.
- `0x37 RequestTransferExit`.
- `0x3D WriteMemoryByAddress`.

Each session level unlocks different services.

## Attack 1 — Brute SecurityAccess

The `0x27 SecurityAccess` service exchanges a "seed" and expects a "key" derived by a manufacturer-secret algorithm.

Common weaknesses:
- **Algorithm leaks** — keys algorithms have been disclosed for many manufacturers.
- **Short keys** (16 or 24 bits) susceptible to brute force.
- **Linear-feedback shift register** style transforms reversible.
- **Constant seed** in some implementations.

Once you have the seed→key transform, every car of that model is unlocked.

Disclosed keygen algorithms (publicly studied):
- Various GM / Ford / VW seed-key implementations.
- Some Mercedes / BMW had short-key implementations historically.

Tools: `gallia`, `caringcaribou` have UDS modules; community keygen databases.

## Attack 2 — Memory read / write

With ExtendedDiagnostic or Programming session unlocked:
- `0x23 ReadMemoryByAddress` — dump ECU RAM / flash.
- `0x3D WriteMemoryByAddress` — patch in place.

Useful for:
- Extracting firmware for offline analysis.
- Extracting cryptographic keys.
- Patching code paths (immobiliser, emissions, performance).

## Attack 3 — Routine activation

`0x31 RoutineControl` runs manufacturer routines like:
- Adapt clutch.
- Run diagnostics.
- Force open / close (windows, locks).
- Activate test mode.

Some routines are dangerous (force fuel injector, force airbag).

## Attack 4 — Firmware reflash

`0x34 RequestDownload` + `0x36 TransferData` + `0x37 RequestTransferExit` flashes new firmware to the ECU.

If the ECU lacks **secure boot** or the bootloader accepts arbitrary signed/unsigned firmware:
- Replace firmware with attacker version.
- ECU now runs attacker code at every start.

Many older / cheaper ECUs accept unsigned flashing. Modern premium-brand ECUs require a manufacturer-signed image.

## Attack 5 — Remote via dongle

Insurance / fleet OBD-II dongles often:
- Have **default credentials** for management.
- Bridge CAN to cellular / Bluetooth.
- Run **embedded Linux** with weak security.

Compromise the dongle → CAN injection or UDS commands. Some have shipped with bugs allowing remote shell.

## Attack 6 — Doip over Automotive Ethernet

Newer vehicles use DoIP (Diagnostic over IP) — UDS over TCP over Automotive Ethernet. Attackers reach DoIP via:
- Internal Ethernet bus.
- Service-bay Ethernet port.
- Wi-Fi infotainment bridge.

UDS services unchanged; transport differs.

## Defence

- **Strong SecurityAccess** — long keys (≥64 bit), modern crypto.
- **Hardware security module** in ECU for key storage.
- **Secure boot** on ECUs — only signed firmware boots.
- **Session restrictions** — Programming session requires physical key + vehicle-stationary check.
- **Manufacturer key rotation** when algorithms leak.
- **Bus segmentation** (see [[can-bus-attacks]]).
- **Authenticated diagnostics** (UDS over TLS in DoIP, manufacturer-specific schemes).

## Workflow to study in a lab

Same caveat as CAN: don't test on a road vehicle.

1. Junkyard ECU on a bench with bench harness providing power + CAN.
2. CAN-USB adapter; open-source UDS tool (`gallia`, `python-uds`, `caringcaribou`).
3. Send `0x10 0x03` (ExtendedDiagnostic session); observe response.
4. Send `0x27 0x01` (SecurityAccess seed request); observe seed.
5. If algorithm is known, compute key; send `0x27 0x02 <key>`.
6. With unlocked session, attempt `0x22` read.

## Tooling

- **`gallia`** — UDS pen-test framework (Volkswagen Open Source).
- **`caringcaribou`** — broader vehicle pen-test toolkit; UDS module.
- **`python-uds`** — Python UDS library.
- **`PCAN-Explorer`** / commercial — easier interaction.
- **CAN-LIN-FlexRay analyser** for higher-end.

## Real-world / public research

- **CHIPSEC for ECUs** — projects to apply firmware-audit techniques.
- **DEFCON Car Hacking Village** — annual.
- **Pwn2Own Automotive** (Tokyo) — UDS / CAN exploits.

## Related

- [[can-bus-attacks]] — bus layer.
- [[firmware-extraction]] — flash extraction.
- [[firmware-emulation-firmadyne-qemu]] — emulation.
- [[bootloader-and-secure-boot-attacks]] — ECU boot chain.
- [[uart-jtag-debug]] — hardware debug.

## References
- [ISO 14229-1 UDS spec](https://www.iso.org/standard/72439.html) (paywalled; mirror summaries online)
- [gallia](https://github.com/Fraunhofer-AISEC/gallia)
- [caringcaribou](https://github.com/CaringCaribou/caringcaribou)
- [Pwn2Own Automotive — ZDI](https://www.zerodayinitiative.com/blog/)
- See also: [[can-bus-attacks]], [[firmware-extraction]], [[bootloader-and-secure-boot-attacks]], [[firmware-audit-methodology]]
