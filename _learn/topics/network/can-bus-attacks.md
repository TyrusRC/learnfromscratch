---
title: CAN bus attacks
slug: can-bus-attacks
aliases: [can-attacks, vehicle-can-bus, controller-area-network-attacks]
---

> **TL;DR:** Controller Area Network (CAN) is the dominant in-vehicle bus, connecting ECUs (engine, brakes, transmission, infotainment, body) on a shared multi-master broadcast medium. CAN has no authentication, no encryption, and no source verification — every frame is trusted. An attacker with physical CAN access can read every message and inject arbitrary commands. Remote access historically came through infotainment / telematics → CAN bridge. The Miller-Valasek 2015 Jeep attack established the canonical chain. Companion to [[obd2-uds-attacks]] and [[firmware-extraction]].

## Why CAN matters

- Standard in almost every vehicle since the mid-1990s.
- The bus carries safety-critical messages (brake activation, throttle position).
- No security at the protocol layer.
- New vehicles add more buses (CAN-FD, FlexRay, Automotive Ethernet) but CAN remains for many functions.
- Aftermarket / OBD-II port provides external physical access on most vehicles.

## CAN basics

- **Bus topology** — two-wire differential (CAN_H, CAN_L). 11-bit (standard) or 29-bit (extended) identifier.
- **Multi-master** — any node can transmit; arbitration by ID priority (lower ID wins).
- **Broadcast** — every node sees every frame.
- **Frame structure** — ID + DLC (data length 0–8 bytes for CAN, up to 64 for CAN-FD) + data + CRC.
- **No authentication**, **no encryption**, **no source identification**.

A frame says "engine RPM = 2400" but doesn't say "from the engine ECU." Any node can claim to be the engine ECU.

## Tooling for CAN access

- **CAN-USB adapter** — Peak PCAN-USB, CANable, Korlan USB2CAN. ~$50–150.
- **CANtact** — open-source.
- **Macchina M2** — Arduino-compatible board for OBD-II.
- **Software** — `can-utils` on Linux (`candump`, `cansniffer`, `cangen`), Vector CANoe (commercial), SocketCAN.
- **OBD-II adapters** for higher-level UDS (see [[obd2-uds-attacks]]).

Plug into OBD-II port. Linux: `sudo ip link set can0 up type can bitrate 500000`, then `candump can0`.

## Attack 1 — Replay

Record legitimate frames, retransmit later or in different context:
- Unlock doors via key-fob CAN message.
- Activate windshield wipers, headlights, horn.
- Some commands gate-controlled by speed / gear; retransmit while in different state.

Replay is the simplest CAN attack and works on most vehicles.

## Attack 2 — Spoofing

Craft frames with arbitrary IDs:
- Send "brake position = pressed" while no human input.
- Send "RPM = 5000" to confuse the dashboard.
- Send invalid speed to engage safety systems.

Some vehicles have basic plausibility checks; many don't.

## Attack 3 — Bus flooding / denial of service

Saturate the bus with high-priority (low-ID) frames:
- Legitimate ECUs can't transmit; vehicle behaviour degrades.
- DoS the safety-critical bus → vehicle goes into "limp mode" or stops.

Easy to do, hard to defend at the protocol level.

## Attack 4 — Internal-bus pivot

Reach CAN via:
- **Infotainment** — Wi-Fi / cellular / Bluetooth → infotainment OS → CAN bridge.
- **TPMS / wireless** — tyre pressure sensors transmit; some receivers process and forward.
- **OBD-II port** — physical access, but a malicious aftermarket dongle (insurance tracker, fleet tracker) creates remote access.
- **Telematics** — eCall, fleet management connected.

Miller-Valasek 2015: cellular → Sprint network → Jeep Uconnect head unit → V850 chip flashed to bridge messages to CAN → arbitrary CAN injection.

This chain takes months of research. The protocol layer (CAN) is easy; the bridge layer (head unit firmware) is the hard part.

## Attack 5 — UDS-layer commands

Above raw CAN sits Unified Diagnostic Services (UDS / ISO 14229). UDS supports:
- Reading / writing ECU memory.
- Calling diagnostic routines.
- Bootloader access — flash new firmware.
- Reading DTCs.

See [[obd2-uds-attacks]] for the detailed UDS attack surface.

## Defence

Vehicle manufacturers have added:
- **CAN segmentation** — high-speed (safety-critical) CAN isolated from comfort/infotainment CAN by gateway.
- **Message authentication codes** (CAN-MAC) — proposed in AUTOSAR; rare in production.
- **Intrusion detection** — anomaly detection on bus patterns (commercial: Argus, Karamba, GuardKnox).
- **Hardware security modules** on ECUs.
- **TEE / secure boot** on infotainment.
- **Bug bounty** for vehicle vulnerabilities (Tesla, GM, FCA).

But standard CAN protocol remains insecure; defence is at the perimeter (head unit / gateway) and detection.

## Workflow to study in a lab

Do not test on a public road vehicle. Options:
1. **Stand-alone CAN test bed** — ESP32 + MCP2515 + bench ECUs. Cheapest.
2. **Junkyard ECU + CAN adapter on a bench**.
3. **Vehicle parked in private lot with wheels off and battery isolated**. Even then, brake / steering injection can damage components.
4. **CARLA / OpenPilot simulation** — fully simulated.

Steps:
- Capture normal CAN traffic.
- Identify frame IDs for specific events (try button presses, observe correlated traffic).
- Reverse-engineer payload bytes per ID.
- Test replay / spoof on bench.

Tools: `can-utils`, Wireshark (with SocketCAN), `caringcaribou` (vehicle pen-test toolkit).

## Real-world disclosed attacks

- **Miller-Valasek Jeep (2015)** — defining attack; remote via cellular.
- **Tesla Model S / 3 via Pwn2Own** — multiple chains crossing infotainment to vehicle bus.
- **Tesla key fob (2018)** — Bluetooth crypto break.
- **Subaru / Kia / Hyundai (2024)** — connected-car platform IDOR (Sam Curry et al.).
- **Mazda CMU (2024)** — multiple vulnerabilities in connected services.

## Related

- [[obd2-uds-attacks]] — UDS / diagnostic protocol attacks.
- [[firmware-extraction]] — head-unit firmware analysis.
- [[firmware-emulation-firmadyne-qemu]] — emulation.
- [[uart-jtag-debug]] — hardware-level head-unit access.
- [[bluetooth-low-energy-attacks]] (if present) / [[ble-and-bluetooth-low-energy-attacks]] — radio side.
- [[physical-pentest-tradecraft]] — physical access.

## References
- [Miller & Valasek — Jeep paper (2015)](https://illmatics.com/Remote%20Car%20Hacking.pdf)
- [Charlie Miller — CAN attack writeups](https://illmatics.com/)
- [Sam Curry — connected-car bugs blog](https://samcurry.net/)
- [`can-utils` documentation](https://github.com/linux-can/can-utils)
- [caringcaribou](https://github.com/CaringCaribou/caringcaribou)
- See also: [[obd2-uds-attacks]], [[firmware-extraction]], [[bootloader-and-secure-boot-attacks]], [[hardware-implants-and-badusb]]
