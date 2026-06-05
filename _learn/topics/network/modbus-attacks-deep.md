---
title: Modbus attacks (TCP / RTU)
slug: modbus-attacks-deep
aliases: [modbus-attacks, modbus-tcp-attacks, modbus-rtu-attacks]
---

> **TL;DR:** Modbus is the simplest and most ubiquitous industrial protocol — designed 1979, no authentication or encryption. Modbus TCP (port 502) carries the same payload over IP. Attack surface: arbitrary register reads/writes, function-code abuse, address-space enumeration of PLCs. Modbus Security (RFC 8581) adds TLS but adoption minimal. Companion to [[dnp3-attacks-deep]] and [[ics-scada-protocols-attacks]].

## Why Modbus matters

- **Most-deployed ICS protocol** in the world by device count.
- **Used everywhere**: building automation, manufacturing, energy, water, oil/gas.
- **40+ years old** — predates security concerns.
- **No authentication** — any reachable client can issue any command.
- **TCP/502 widely exposed** when industrial networks "modernised" without isolation.

## Modbus basics

Two main variants:
- **Modbus RTU** — serial, binary frame.
- **Modbus TCP** — TCP-encapsulated, port 502.
- (Modbus ASCII — rarely used today.)

Frame structure:
- Address (RTU only; TCP uses unit ID).
- Function code.
- Data (registers or coils referenced).
- CRC (RTU only).

Function codes:
- **1 — Read Coils**.
- **2 — Read Discrete Inputs**.
- **3 — Read Holding Registers**.
- **4 — Read Input Registers**.
- **5 — Write Single Coil**.
- **6 — Write Single Register**.
- **15 — Write Multiple Coils**.
- **16 — Write Multiple Registers**.

## Class 1 — Unauthenticated reads

Anyone reaching the device can read all coils, registers. Reveals:
- Setpoints.
- Process variables.
- Operational state.
- Configuration.

Useful for reconnaissance before sabotage; also for industrial espionage.

## Class 2 — Unauthenticated writes

Write coils / registers:
- Change setpoints.
- Toggle outputs (open valve, start motor).
- Disable safety interlocks (if mapped to writable registers).

Physical impact possible. Stuxnet famously manipulated centrifuge speed via similar protocol-layer write.

## Class 3 — Function-code abuse

Less-common function codes:
- **8 — Diagnostics** — with sub-functions including restart, force listen-only.
- **17 — Report Slave ID** — fingerprint device.
- **20/21 — Read/Write File Record** — extended access.
- **43 — Encapsulated Interface Transport** — vendor-specific.

Diagnostics restart DoSes the PLC. Function 43 carries vendor-specific commands (read firmware, change config in some cases).

## Class 4 — Address-space enumeration

Map the PLC's holding registers by reading sequentially. Reveals memory layout, configuration, sometimes embedded credentials.

## Class 5 — Vendor-specific function-43 abuse

Schneider Electric Modicon, Siemens, others have custom function 43 sub-codes:
- Download program.
- Upload program.
- Run / stop CPU.

Function 43 abuse is essentially "PLC management protocol" without auth.

## Class 6 — Memory corruption in Modbus stacks

Various PLC firmware Modbus parsers have shipped with bugs:
- Buffer overflow in extended-length frames.
- Integer overflow.
- Function-code-confusion crashes.

Disclosed CVEs across Schneider, Siemens (in MODBUS contexts), Mitsubishi, Phoenix Contact.

## Class 7 — Modbus Security (RFC 8581) bypass

Modbus Security adds TLS:
- X.509 mutual auth.
- Confidentiality.

Adoption is low. When deployed, implementation flaws apply same as any TLS deployment.

## Recon

Internet-exposed Modbus devices: **search Shodan** for `port:502`. Tens of thousands of results — building automation, generators, even electricity meters.

Once on the network:
- `nmap -p 502 --script modbus-discover`.
- `mbtget` / `pymodbus` libraries for direct interaction.
- `modbus-cli`, `OpenPLC` for testing.

## Defensive baseline

- **Segregate** ICS from IT — Purdue Model layers.
- **Deny** Internet exposure of port 502.
- **Whitelist** master IP at PLC.
- **Deploy Modbus Security** where supported.
- **Network IDS rules** for Modbus (Snort / Suricata Dragos / Nozomi rules).
- **Patch** PLC firmware for Modbus stack CVEs.
- **Read-only access** where bidirectional not needed.

## Detection

- **Anomaly detection**: write commands during normal-read periods.
- **Volumetric**: unusual function-code mix.
- **Source-IP whitelist**: alert on new sources.
- **Time-of-day**: writes outside operational windows.
- **Function 8 (diagnostics)** — almost always suspicious in production.

## Workflow to study

1. Install OpenPLC, ModbusPal, or pymodbus.
2. Stand up a simulated PLC with registers.
3. Send reads / writes from pymodbus.
4. Capture traffic in Wireshark.
5. Try Snort / Suricata rules on captured traffic.
6. Read public PLC firmware CVEs for parser-bug shape.

## Real-world incidents

- **Stuxnet (2010)** used protocol-layer manipulation against Siemens S7 (similar approach; specific protocol was S7).
- **Various critical-infrastructure disclosures** — exposed Modbus devices on Internet.
- **DEF CON ICS Village** demonstrations.
- **Black Energy** (Ukraine) — broader campaign with ICS-protocol elements.

## Standards / regulatory

- **IEC 62443** — general ICS / OT cybersecurity.
- **NERC CIP** — North American utility.
- **EU NIS2** — covers many Modbus-deployed sectors.
- **TSA — pipeline security directives** — relevant for Modbus on oil/gas.

## Related

- [[dnp3-attacks-deep]]
- [[iec61850-attacks]]
- [[opc-ua-attacks]]
- [[profinet-ethercat-attacks]]
- [[ics-scada-protocols-attacks]]
- [[firmware-extraction]]
- [[freertos-audit]]

## References
- [Modbus organization](https://modbus.org/specs.php)
- [pymodbus](https://github.com/pymodbus-dev/pymodbus)
- [OpenPLC](https://www.openplcproject.com/)
- [Dragos research](https://www.dragos.com/blog/)
- [Claroty research](https://claroty.com/team82)
- See also: [[dnp3-attacks-deep]], [[iec61850-attacks]], [[opc-ua-attacks]], [[ics-scada-protocols-attacks]]
