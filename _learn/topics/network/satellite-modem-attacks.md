---
title: Satellite modem attacks
slug: satellite-modem-attacks
aliases: [satcom-modem-attacks, vsat-modem-attacks, starlink-modem-research]
---

> **TL;DR:** Satellite modems (Viasat, Hughes, Starlink user terminals, Iridium, Inmarsat) are embedded Linux devices with custom firmware. Attack surface: management protocols, firmware update channels, web admin interface, RF parsers, and the user-side LAN integration. The 2022 Viasat / AcidRain incident wiped 30k+ modems via the management channel. Public research on Starlink user-terminal (Lennert Wouters) demonstrated voltage glitching → debug shell. Companion to [[ground-station-attacks]] and [[firmware-extraction]].

## Why modems matter

- **Last-mile satellite Internet** for ships, planes, rural users, IoT.
- **Critical-infrastructure deployments** — wind farms, financial branches, military communications.
- **Embedded Linux** — bug surface familiar.
- **Cloud-managed** with vendor pushed firmware — chain-of-control matters.

## What's in a satellite modem

- **RF subsystem** — modulation/demodulation, beam-pointing.
- **MCU or ARM SoC** running embedded Linux or RTOS.
- **Web admin interface** (Hughes, Viasat).
- **Vendor management protocol** for OTA configuration.
- **LAN side** — Ethernet / WiFi.

User terminals like Starlink Dishy are sophisticated SDR-based with phased-array antennas; modern Cortex-A SoC running Linux.

## Class 1 — Web admin interface

Modems with web UI for setup, status, advanced. Often:
- Default / weak credentials.
- Outdated software stacks.
- Exposed to LAN side; sometimes WAN by misconfig.

Standard router-class bugs apply.

## Class 2 — Management-protocol exploitation

Vendor backend → modem via:
- HTTPS REST.
- Vendor-proprietary TCP.
- TR-069 / TR-369.

Compromise of vendor backend = compromise of fleet. AcidRain (Viasat KA-SAT, 2022) followed this path.

## Class 3 — Firmware update channel

OTA firmware updates pushed from vendor. If:
- Updates accepted without signature.
- Signature bypass possible.
- Management backend compromised → push bad firmware.

The defining incident class.

## Class 4 — Physical compromise — Starlink Dishy research

Lennert Wouters' research (Black Hat 2022):
- Decapped Dishy SoC.
- Voltage glitching on bootROM.
- Bypassed signature check; loaded modified firmware.
- Obtained debug shell.

Persistent compromise possible per-unit. Doesn't compromise the network — Starlink's segmentation limits per-modem blast radius.

## Class 5 — LAN-side initial access

Modem on LAN with web UI; LAN-side attacker:
- Default credentials.
- Cross-site request forgery via browser.
- DNS rebinding attacks ([[dns-rebinding]]).
- LAN-to-modem ARP / DHCP spoofing.

## Class 6 — RF parsing bugs

Modem demodulates and parses incoming RF protocol stack:
- Custom waveform parsing.
- Network-layer protocol parsing (IP, etc.).
- Vendor-specific over-the-air protocol bugs.

Less commonly attacked publicly; nation-state targeting plausible.

## Class 7 — Pivoting from modem to user network

Compromised modem is on user LAN. Pivot:
- Scan LAN.
- Attack LAN devices.
- Exfil data.

For corporate / industrial deployments, modem is inside firewall — high-impact pivot.

## Specific operator considerations

### Maritime / aviation

- ICAO / IMO regs for safety; cyber adjacent.
- Onboard networks often weakly segregated.
- Long deployments without firmware updates.

### Cellular backhaul via satellite

- Critical infrastructure dependency.
- Outages widespread.

### IoT / SCADA via satellite

- Industrial controllers reachable via modem.
- Often legacy with weak auth.
- See [[ics-scada-protocols-attacks]].

## Defensive baseline

### Operators

- Patch modem firmware promptly.
- Change defaults.
- Segregate LAN behind modem.
- Don't expose web UI to WAN.
- Network monitoring on modem-to-vendor traffic.

### Vendors

- Sign firmware unequivocally; verify on device.
- Limit management-backend privilege per tenant.
- Dual-control for firmware push.
- Customer notification on update.
- Network rate-limiting on management commands.

### Mission-critical deployments

- Diversify across multiple providers.
- Treat modems as untrusted; place behind firewall + IDS.
- Tabletop for modem-vendor compromise scenario.

## Workflow to study

1. Pick up a used Hughes / Viasat / Iridium consumer modem.
2. Read firmware via UART / JTAG ([[uart-jtag-debug]]) if accessible.
3. Use binwalk + ghidra to explore.
4. Read Lennert Wouters' Starlink talks for shape.
5. Practice on cheap consumer routers first (firmware analysis is the same skill).

Avoid testing against operational deployments; legal exposure.

## Real-world incidents / research

- **AcidRain (Viasat KA-SAT, 2022)** — fleet wipe via management. See [[ground-station-attacks]].
- **Starlink Dishy (Wouters, 2022)** — physical research.
- **Iridium ground network** — academic security analyses.
- **Inmarsat BGAN devices** — historical recovery / debug interfaces.

## Standards / regulatory

- **NIST IR 8401** — Satellite Ground Segment Cybersecurity.
- **CCSDS** — for space-segment crypto; modem-side increasingly adopting.
- **TR-069 / TR-369** — management protocols.

## Related

- [[ground-station-attacks]]
- [[cubesat-attacks]]
- [[gps-gnss-spoofing]]
- [[firmware-extraction]]
- [[firmware-emulation-firmadyne-qemu]]
- [[uart-jtag-debug]]
- [[hardware-glitching-deep]] — Wouters' Starlink technique
- [[case-study-snowflake-2024]] — adjacent IT-side class

## References
- [Lennert Wouters — Starlink Dishy hack (Black Hat USA 2022)](https://www.blackhat.com/us-22/briefings/schedule/#glitched-on-earth-by-humans-a-black-box-security-evaluation-of-the-spacex-starlink-user-terminal-26326)
- [SentinelOne — AcidRain](https://www.sentinelone.com/labs/acidrain-a-modem-wiper-rains-down-on-europe/)
- [NIST IR 8401](https://nvlpubs.nist.gov/nistpubs/ir/2022/NIST.IR.8401.pdf)
- See also: [[ground-station-attacks]], [[cubesat-attacks]], [[gps-gnss-spoofing]], [[firmware-extraction]]
