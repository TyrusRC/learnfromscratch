---
title: PROFINET and EtherCAT attacks
slug: profinet-ethercat-attacks
aliases: [profinet-attacks, ethercat-attacks, industrial-ethernet-attacks]
---

> **TL;DR:** PROFINET (Siemens-dominant) and EtherCAT (Beckhoff-dominant) are real-time Ethernet-based industrial protocols. PROFINET layers on standard Ethernet with vendor-defined frames; EtherCAT uses a custom MAC-level protocol with hardware-implemented slave processing. Attack surface: unauthenticated process-data manipulation, configuration changes via DCP, memory corruption in stacks, and physical-network access bypassing all controls. Companion to [[iec61850-attacks]] and [[modbus-attacks-deep]].

## Why these matter

- **PROFINET** dominant in European manufacturing automation. Siemens, Phoenix Contact, others.
- **EtherCAT** dominant in motion control and very high-rate (sub-100µs) applications.
- **No application-layer auth by default** for process data.
- **Physical Ethernet access** = total control.
- **Long-deployed**, slow to update.

## PROFINET architecture

PROFINET RT (real-time): non-IP, Ethernet Type 0x8892. Cyclic process data.
PROFINET IRT (isochronous real-time): even tighter, with TDMA-style scheduling.
PROFINET NRT: standard IP (HTTP, SNMP, DCP for discovery).

Discovery and Basic Configuration Protocol (DCP):
- L2 broadcast for device discovery.
- Set/reset device parameters.
- No auth.

## PROFINET Class 1 — DCP spoofing

Attacker on LAN sends DCP commands:
- Rename devices.
- Change IP configuration.
- Set parameters.
- Force reset.

Effective DoS or substitution attack.

## PROFINET Class 2 — Process data injection

PROFINET RT cyclic frames carry process data (sensors, actuators). Attacker on same VLAN can:
- Inject frames with attacker-chosen values.
- Override real device state.
- Cause actuators to operate.

Requires being on PROFINET network segment.

## PROFINET Class 3 — Memory corruption

Siemens / Phoenix / others have shipped PROFINET stack with classic memory bugs. Disclosed CVEs over years.

## PROFINET Class 4 — Engineering workstation / TIA Portal

Configuration deployed via Siemens TIA Portal or equivalent. Compromise of engineering workstation:
- Modify ladder logic.
- Change network configuration.
- Plant logic bombs.

Engineering-station attacks parallel [[case-study-3cx-supply-chain]] for IT-side.

## EtherCAT architecture

- Master sends a frame around a daisy-chained loop of slaves.
- Each slave reads from / writes to specific bytes in the frame as it passes.
- Hardware (ESC — EtherCAT Slave Controller) implements protocol — extremely fast.
- Some control / config via Mailbox protocol (Ethernet/IP-like CoE, EoE, FoE, SoE).

## EtherCAT Class 1 — Physical network access

Any device on EtherCAT loop can:
- Read all process data.
- Modify it.

Compromise of any slave or insertion of a malicious device = full network compromise.

Slave masquerade attacks demonstrated in academic settings.

## EtherCAT Class 2 — Mailbox protocol abuse

Mailbox sub-protocols carry configuration:
- **CoE (CANopen over EtherCAT)** — device parameters.
- **FoE (File over EtherCAT)** — firmware updates.
- **SoE (Servo over EtherCAT)** — motion parameters.

FoE without auth = arbitrary firmware load. Some slaves accept; others verify.

## EtherCAT Class 3 — Master device compromise

Master orchestrates the bus. Compromise master = control entire loop.

Master is typically a PC or PLC; standard IT attack surface applies.

## Common deployment mistakes (both protocols)

- **No network segmentation** — PROFINET / EtherCAT on same Ethernet as IT.
- **Engineering laptops** connected to both networks.
- **Default credentials** on management interfaces.
- **No firmware updates** for years.
- **Physical security** — anyone with access to a panel can plug in.

## Defensive baseline

### Both

- **Strict physical access control** to OT network panels and patch fields.
- **VLAN isolation** from IT.
- **Network IDS** with vendor-specific rules (Dragos, Claroty, Nozomi).
- **Patch firmware** when vendors release.
- **Audit engineering-workstation hardening**.

### PROFINET-specific

- **PROFINET Security Class 1/2/3** — recent standard extension for crypto / signing. Adopt where supported.
- **Block DCP** at network edge.

### EtherCAT-specific

- **No EtherCAT outside the loop boundary** — physical-segment isolation.
- **CoE/FoE configuration management** with signed firmware where supported.
- **Slave whitelist** at master.

## Detection

- **Volumetric anomaly** detection on cyclic data.
- **DCP traffic** outside commissioning periods.
- **Source-MAC** whitelisting.
- **Firmware-change** audit logs.

## Workflow to study

1. Install pn-dcp (Python PROFINET DCP library).
2. Install pysoem (Python SOEM EtherCAT master).
3. Stand up simulated devices in software.
4. Practice DCP / process-data manipulation in isolated lab.
5. Read Claroty / Dragos disclosures for vendor-stack CVEs.

## Real-world incidents

- Multiple disclosed CVEs in Siemens PROFINET stacks.
- Academic demonstrations of EtherCAT slave masquerade.
- Industrial-environment IR cases (publicly: few specific PROFINET / EtherCAT attributions but ICS broadly is targeted).

## Standards / regulatory

- **PROFINET Security Class 1/2/3** extension.
- **IEC 62443** — broad ICS / OT cybersecurity framework.
- **NIS2**, **CRA** apply.

## Related

- [[modbus-attacks-deep]]
- [[dnp3-attacks-deep]]
- [[iec61850-attacks]]
- [[opc-ua-attacks]]
- [[ics-scada-protocols-attacks]]
- [[freertos-audit]]
- [[firmware-extraction]]
- [[hardware-glitching-deep]] — adjacent for slave compromise

## References
- [PROFIBUS / PROFINET International (PI)](https://www.profibus.com/)
- [EtherCAT Technology Group (ETG)](https://www.ethercat.org/)
- [pn-dcp](https://github.com/codewerft/pnio_dcp)
- [pysoem](https://github.com/bnjmnp/pysoem)
- [Claroty Team82 research](https://claroty.com/team82)
- See also: [[modbus-attacks-deep]], [[iec61850-attacks]], [[opc-ua-attacks]], [[ics-scada-protocols-attacks]]
