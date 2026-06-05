---
title: IEC 61850 (substation automation) attacks
slug: iec61850-attacks
aliases: [iec61850-attacks, goose-attacks, sv-attacks, mms-attacks]
---

> **TL;DR:** IEC 61850 is the modern protocol family for power-substation automation — replacing legacy DNP3 / Modbus in new deployments worldwide. Sub-protocols: GOOSE (real-time multicast, sub-4ms breakers), Sampled Values (raw measurement multicast), MMS (TCP for parameters/control). GOOSE and SV are unauthenticated multicast by default; IEC 62351 adds crypto but adoption is slow. Companion to [[dnp3-attacks-deep]] and [[modbus-attacks-deep]].

## Why IEC 61850 matters

- **Modern utility standard** — every greenfield substation worldwide adopts.
- **Real-time** — GOOSE for breaker tripping has sub-4ms requirement, leaves no room for handshake.
- **Multi-layer protocol** — GOOSE / SV / MMS each have own surface.
- **Long deployment lifetime** — substations live 20+ years.
- **Critical infrastructure** — direct physical impact possible.

## Protocol family

### GOOSE — Generic Object Oriented Substation Event

- Ethernet multicast.
- Sub-4ms latency requirement.
- Real-time status / trip signals.
- No application-layer auth.
- Per-VLAN multicast.

### SV — Sampled Values

- Ethernet multicast.
- Raw analogue measurements (currents, voltages) digitised by Merging Units.
- High-rate (4800 samples/sec at 60Hz, 4000 at 50Hz).
- No auth.

### MMS — Manufacturing Message Specification

- TCP/102 (or specific ports).
- Parameter changes, control commands.
- File transfer, logs.
- Auth optional and weak by default.

### IEC 62351

The security extension family:
- 62351-3 — TLS for MMS.
- 62351-6 — GOOSE / SV authentication via R-GOOSE / R-SV variants (replicated, authenticated, routed).
- 62351-9 — key management.

Adoption: most substations don't use it. Operational concerns (key management at scale, performance) slow deployment.

## Class 1 — GOOSE spoofing

Attacker on substation LAN sends GOOSE packets with the right multicast MAC + ApplD:
- Fake "trip" signals to breaker IED.
- Cause unintentional trips.
- Fake "no trip" to suppress legitimate.

If an attacker controls anything on the substation Process Bus or Station Bus, GOOSE spoofing is trivial.

## Class 2 — GOOSE replay

Even without spoofing, capture and replay GOOSE messages causes confusion:
- Replay status changes that already happened.
- Replay trip/closes out of order.

GOOSE has state-tracking (St, SqNum counters) but receivers vary in strictness.

## Class 3 — Sampled Values manipulation

Tamper with SV measurements:
- Inject false current readings.
- Make breakers think there's a fault when there isn't (cause unnecessary trip).
- Hide fault from breakers (suppress legitimate trip → equipment damage).

High-rate, easy to insert via network tap or compromised switch.

## Class 4 — MMS exploitation

MMS controls parameters and runs commands. Without crypto:
- Read all IED parameters.
- Change settings.
- Restart IEDs.
- Download data sets.

With weak crypto (or pre-shared keys), similar.

## Class 5 — Configuration file (SCD/CID) manipulation

Substations are configured via SCD (Substation Configuration Description) XML files. Compromise of engineering workstation:
- Modify SCD.
- Deploy to IEDs.
- Subtle changes — e.g., trip-curve adjustments.

Often the initial-access vector for sophisticated substation attacks.

## Class 6 — Memory corruption in IED firmware

GOOSE / SV / MMS parsers are complex C code in embedded IEDs. Disclosed CVEs:
- Buffer overflows in IEC 61850 stack.
- ASN.1 parse confusion in MMS.

Public bugs against SEL, ABB, Siemens, GE IEDs over the years.

## Class 7 — Process Bus vs Station Bus

Modern substations: **Process Bus** (SV + GOOSE for protection) vs **Station Bus** (slower MMS for HMI / SCADA gateway).

If networks aren't isolated:
- IT-side compromise reaches Process Bus.
- Trip / DoS impact.

Audit physical / VLAN isolation.

## Class 8 — Time synchronisation attacks

IEC 61850 relies on PTPv2 (IEEE 1588) for sub-microsecond time. Compromise PTP:
- Differential protection misaligns.
- Recordings desync.
- Real-time decisions distort.

See [[gps-gnss-spoofing]] for upstream time-source attack.

## Recon and lab

- **Wireshark** has dissectors for GOOSE, SV, MMS.
- **libIEC61850** open-source stack.
- **OpenPLC** + simulated IEC 61850 IEDs.
- **`iec61850-toolset`** — Python helpers.
- **GOOSE replay**: capture + re-transmit on Process Bus VLAN.

For lab, use Faraday-isolated bench environment.

## Defensive baseline

- **Strict VLAN / network isolation** Process Bus from Station Bus from IT.
- **Deploy IEC 62351** crypto where feasible.
- **Engineering workstation hardening** — limited access, MFA.
- **Configuration management** — signed SCD pipelines.
- **IDS rules** for GOOSE / SV / MMS anomalies.
- **Time-source diversity** — multiple GPS + atomic backup.
- **Firmware updates** on IEDs.
- **Physical security** — substation access controls.

## Detection

- **Anomaly detection** on GOOSE state-changes.
- **Volumetric SV checks** — bandwidth predictable; deviation suspicious.
- **MMS audit logs** for unexpected parameter changes.
- **Dragos / Claroty / Nozomi / Tenable.OT** — commercial.

## Real-world incidents

- **Ukraine 2015 / 2016** — substation-level disruption using mix of techniques.
- **Various research disclosures** at S4 conference (Digital Bond), Black Hat ICS.
- **CVE-tracked vulnerabilities** in major IED vendors.

## Standards / regulatory

- **IEC 61850** — the standard itself.
- **IEC 62351** — security extensions.
- **NERC CIP** — North American utility.
- **IEEE C37.240** — substation cyber.
- **EU NIS2** — applies.

## Workflow to study

1. Install libIEC61850; run sample server / client.
2. Configure GOOSE publisher / subscriber.
3. Capture in Wireshark.
4. Spoof GOOSE from another host on same VLAN.
5. Read public IED CVEs.
6. Read S4 conference talks archive.

## Related

- [[dnp3-attacks-deep]]
- [[modbus-attacks-deep]]
- [[opc-ua-attacks]]
- [[profinet-ethercat-attacks]]
- [[ics-scada-protocols-attacks]]
- [[gps-gnss-spoofing]]
- [[firmware-extraction]]

## References
- [IEC 61850 (international standard; paywalled)](https://webstore.iec.ch/publication/63319)
- [libIEC61850](https://github.com/mz-automation/libiec61850)
- [Dragos / Claroty / Nozomi research](https://www.dragos.com/blog/)
- [S4 conference (Digital Bond)](https://s4xevents.com/)
- See also: [[dnp3-attacks-deep]], [[modbus-attacks-deep]], [[opc-ua-attacks]], [[ics-scada-protocols-attacks]]
