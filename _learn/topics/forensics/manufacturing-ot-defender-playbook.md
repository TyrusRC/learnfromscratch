---
title: Manufacturing / OT defender playbook
slug: manufacturing-ot-defender-playbook
aliases: [ot-defender, manufacturing-cyber-playbook, ics-defender-playbook]
---

> **TL;DR:** Defending manufacturing / OT is not "IT security with PLCs." Production lines run on twenty-year-old controllers, safety logic that cannot be rebooted on a whim, and vendor remote-access tunnels nobody is allowed to break. This playbook covers Purdue-model segmentation, the realistic threat landscape (Volt Typhoon pre-positioning per [[apt-tradecraft-chinese-mss]], ransomware operators with OT impact per [[ransomware-affiliate-playbook]]), protocol-specific risk for [[modbus-attacks-deep]] / [[dnp3-attacks-deep]] / [[iec61850-attacks]] / [[opc-ua-attacks]], SIS isolation, and the regulatory floor from [[nis2-implementation]]. It is written for the security engineer / architect who has to keep the plant running, not for executives buying a brochure.

## Why it matters

Downtime in manufacturing is measured per hour, not per day. An automotive assembly plant losing production sits in the USD 1-2M/hour band; semiconductor fabs are an order of magnitude higher because in-flight wafers are scrap and tools must be re-qualified. A refinery emergency shutdown can take a week to restart safely. That asymmetry is why ransomware affiliates target manufacturers (they pay fast) and why nation-state pre-positioning campaigns prefer power, water and pipelines (strategic leverage without firing a shot).

Three lessons keep recurring:

- **Norsk Hydro (2019, LockerGoga).** Active Directory was the blast radius. IT compromise forced manual operation across 170 sites; the company spent USD 70M+ and recovered by being transparent. The lesson is not "have backups," it is "design plants to run in manual / island mode for days."
- **Colonial Pipeline (2021, DarkSide).** OT was never directly compromised. The pipeline was shut down because billing / SCADA-adjacent IT systems went down and the operator could not invoice deliveries. IT-OT convergence means IT outages cause OT outages even when the controllers are fine.
- **Volt Typhoon (2023-2024).** Chinese MSS-linked pre-positioning inside US critical-infrastructure networks via SOHO router botnets and living-off-the-land. The objective is not data theft; it is being ready to disrupt during a Taiwan-strait scenario. See [[apt-tradecraft-chinese-mss]].

If your threat model still says "script kiddies and disgruntled insiders," you are ten years behind.

## The Purdue model in practice

The Purdue Enterprise Reference Architecture (PERA) is the lingua franca, even though every real plant violates it somewhere.

### The levels

- **Level 0 — Process.** Physical sensors and actuators. Valves, motors, flow meters. Attacks here are physical.
- **Level 1 — Basic control.** PLCs, RTUs, IEDs. This is where Modbus / DNP3 / Profinet / EtherNet/IP live.
- **Level 2 — Supervisory.** HMIs, local SCADA, engineering workstations. Operators stare at these screens for 12-hour shifts.
- **Level 3 — Site operations.** Historians (PI, Wonderware), MES, batch management, plant Active Directory. The "OT DMZ" boundary lives between L3 and L3.5.
- **Level 3.5 — Industrial DMZ (iDMZ).** Jump hosts, reverse proxies, one-way data diodes for historian replication. The only level where IT and OT meet by design.
- **Level 4 — Enterprise (site).** Business IT for the plant: email, file shares, badge systems.
- **Level 5 — Enterprise (corporate).** Corporate domain, ERP, internet.

### What actually breaks the model

- Engineer laptops dual-homed L2 and L4 because "we need internet for the vendor portal."
- Vendor remote-access boxes (TeamViewer, AnyDesk, BeyondTrust) terminating directly into L2.
- Wi-Fi handhelds for inventory bridging warehouse Wi-Fi (L4) and PLC scanners (L1).
- Historians configured for bidirectional sync instead of one-way push to corporate.
- Phone-home features on modern PLCs (Siemens, Rockwell) reaching the vendor cloud through whatever firewall hole IT was talked into.

The defender's job is rarely to "build the Purdue model" — it is to document where the plant deviates and either fix it or compensate.

## Threat landscape

### Ransomware with OT impact

Most "OT ransomware" incidents are actually IT ransomware where operators voluntarily shut down OT because they cannot trust IT supervisory layers. JBS (2021), Clorox (2023), MKS Instruments (2023), Brunswick (2023), Boeing (2023) all followed this pattern. The affiliate model is covered in [[ransomware-affiliate-playbook]]; the OT-specific twist is that the negotiation timer is measured against per-hour production loss, not data-disclosure embarrassment.

Groups historically interested in OT-aware tooling: CL0P (less so), BlackBasta (industrial sector targeting), Akira and Play (manufacturing-heavy victimology), and the historical Conti / Ryuk lineage. None of them write PLC malware; they just stop the plant from being trustable.

### Nation-state and ICS-specific malware

- **Industroyer / CRASHOVERRIDE (2016, Ukraine).** Custom IEC 60870-5-104 / 61850 / OPC payloads.
- **TRITON / TRISIS (2017, Saudi petrochemical).** Targeted Schneider Triconex SIS controllers. The first malware specifically designed to defeat a safety system. See [[iec61850-attacks]] for the substation analogue.
- **Industroyer2 (2022, Ukraine).** Ukrenergo attack, hardcoded IEC-104 target config.
- **PIPEDREAM / INCONTROLLER (2022).** Modular toolkit for Schneider, Omron and OPC UA assets. Dragos disclosed it before it was used in anger.

### Hacktivist and opportunistic

CyberAv3ngers (Iran-linked) attacking exposed Unitronics PLCs in US water utilities (2023) — default credentials, internet-exposed Modbus / web UI. The Cl0p MOVEit incidents reached manufacturers as IT events. Pro-Russia hacktivists hitting exposed HMIs of small utilities, mostly for psy-ops.

## Defensive baseline

### Segmentation and architecture

- Enforce a real iDMZ at L3.5 with explicit allow-lists. No "any/any" between corp AD and plant AD.
- Plant AD must be a **separate forest** from corporate AD with selective trust, not a child domain. Krbtgt compromise in corporate should not be game-over for the plant — see [[bloodhound]] and [[dcsync]] for the playbook adversaries actually use.
- Data diodes (Owl, Waterfall, Fend) for historian → corporate where bidirectional is not needed. Yes, they are expensive; they are also unidirectional in physics, not in policy.
- Vendor remote access through a single broker (Claroty SRA, Dragos, Cyolo, Xona) with session recording, MFA, and just-in-time approval. Never persistent VPN.

### Asset inventory and visibility

You cannot defend what you cannot see. Passive monitoring is the OT-safe path:

- **Dragos Platform** — strong threat intel and detections from the WorldView team, opinionated.
- **Claroty xDome / CTD** — broad protocol coverage, good for mixed environments.
- **Nozomi Guardian** — strong on visualisation, easier integration with traditional SOC stacks.
- **Microsoft Defender for IoT (ex-CyberX)** — sensible if you are a Microsoft shop and want Sentinel integration.

All four do SPAN/TAP-based protocol parsing for Modbus, DNP3, IEC 61850, OPC UA, S7, EtherNet/IP, Profinet. Active polling exists but must be ring-fenced — a misconfigured Nmap scan against a PLC can stop a production line. There are documented cases of Allen-Bradley PLCs faulting on full SYN scans.

### Patching reality

The IT mantra "patch within 30 days" does not survive contact with OT. Realistic constraints:

- **Vendor approval.** Rockwell / Siemens / ABB must qualify the patch for the firmware version and HMI driver pairing. This can take months.
- **Validation windows.** Pharma (GxP / 21 CFR Part 11) and automotive (IATF 16949) require re-qualification testing after changes. Re-qual can cost more than the breach.
- **Maintenance windows.** Continuous-process plants (refining, steel, glass, cement) have one or two annual turnarounds. Outside of those, you are negotiating for minutes.
- **Compensating controls.** Virtual patching at the iDMZ, protocol-aware IPS, application whitelisting on HMIs (Carbon Black App Control, TXOne StellarProtect) are how you live with the lag.

Triage by **exploitable in this network**, not by CVSS. A CVSS 9.8 in an FTP service that does not exist on this PLC firmware is noise; a CVSS 6.5 in the engineering-workstation software that runs on every laptop is the priority.

### Safety-instrumented systems (SIS)

SIS (Triconex, HIMA, Yokogawa ProSafe-RS, Siemens S7-400FH) must be physically and logically isolated from the basic process control system (BPCS). IEC 61511 requires it; TRITON proved why. Practical hardening:

- Keep the keyswitch in **RUN**, not PROGRAM, in production. Sounds obvious; TRITON exploited PROGRAM mode being left engaged.
- No engineering workstation should reach the SIS network except via a deliberately-cabled jump host with no internet path.
- Log every key-position change. Some controllers expose this over Modbus; tie it to your SIEM (see [[siem-detection-use-case-catalog]]).

### Detection use cases worth building

Detection engineering in OT borrows from IT (see [[detection-engineering-pyramid-of-pain]]) but the high-value detections are protocol-aware:

- New Modbus master appearing on the wire — see [[modbus-attacks-deep]].
- DNP3 unsolicited-response storms or class-0 polling from unexpected sources — see [[dnp3-attacks-deep]].
- IEC 61850 GOOSE with stNum reset or unexpected publisher MAC — see [[iec61850-attacks]].
- OPC UA session from outside the iDMZ allow-list — see [[opc-ua-attacks]].
- Engineering software (RSLogix, TIA Portal, Studio 5000, PCS 7) launching on a non-engineer workstation.
- USB insertion on HMI / engineering hosts (still the #1 initial-access vector in air-gapped plants).

## Workflow to study

1. Read the **NIST SP 800-82r3** Guide to OT Security cover-to-cover once. It is dry but it is the shared vocabulary with auditors and management.
2. Walk a real plant. Map the actual cables. Compare to the network diagram you were given. The delta is your work.
3. Build a home lab: an old Siemens S7-1200 or Allen-Bradley MicroLogix off eBay, a Raspberry Pi running OpenPLC, Wireshark with the Modbus / S7Comm / DNP3 dissectors. Pair with [[building-a-research-home-lab]].
4. Run Dragos' free **OT-CERT** community materials, the SANS ICS 410 if budget allows, and the ISA/IEC 62443 cybersecurity-fundamentals specialist track.
5. Subscribe to CISA ICS advisories, Dragos year-in-review, and Claroty Team82 research. Track the **MITRE ATT&CK for ICS** matrix the way you track Enterprise ATT&CK.
6. Tabletop a ransomware-into-iDMZ scenario with the plant manager, EHS lead, and a vendor rep. The first run will reveal whoever cannot be reached on a Sunday.
7. Build the **manual-operation runbook** with operations. If SCADA dies, who reads which gauge, who turns which valve, and how long can you sustain it.

## Common gaps observed in assessments

- Plant AD admin accounts shared between three integrators, password unchanged since commissioning.
- Default credentials on PLCs (`1100` on Unitronics, blank on older Siemens, `admin/admin` on countless HMIs). [[ics-scada-protocols-attacks]] catalogues the protocol side.
- Engineering laptops with corporate AV that conflicts with the engineering software, so AV is disabled "temporarily" for the last three years.
- Vendor jump host with a static reverse SSH tunnel out to the integrator's office because "the firewall was annoying."
- Wireless instrumentation (WirelessHART, ISA100) deployed with default join keys.
- Historian replication using a shared service account with domain admin in the plant forest.
- No allow-list on serial-to-Ethernet gateways (Moxa, Lantronix) — anyone on the L2 subnet can talk Modbus to anything.

## Career and day-to-day reality

OT security pay tracks IT security with a small premium for willingness to travel and wear PPE. US ranges in 2024-2025: USD 130-180k for senior OT security engineer, USD 180-240k for principal / architect at an asset-owner; vendor-side (Dragos, Claroty, Nozomi) sales-engineering can exceed USD 250k OTE. EU is roughly 60-75% of US numbers; Gulf petrochemical pays a premium for on-site rotations.

Day-to-day is unglamorous: reading P&IDs, arguing with integrators about firewall rules, scheduling change windows around production. The people who succeed have either an OT-engineering background who learned security, or a security background who is comfortable being the least-experienced person in the control room and willing to listen. The people who struggle treat the plant like a corporate LAN and propose "just patch it."

## Related

- [[ics-scada-protocols-attacks]]
- [[modbus-attacks-deep]]
- [[dnp3-attacks-deep]]
- [[iec61850-attacks]]
- [[opc-ua-attacks]]
- [[profinet-ethercat-attacks]]
- [[apt-tradecraft-chinese-mss]]
- [[ransomware-affiliate-playbook]]
- [[nis2-implementation]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[building-a-research-home-lab]]

## References

- NIST SP 800-82 Rev. 3, Guide to Operational Technology Security — https://csrc.nist.gov/pubs/sp/800/82/r3/final
- CISA, ICS Advisories and Joint Advisory on Volt Typhoon — https://www.cisa.gov/news-events/cybersecurity-advisories
- Dragos Year in Review (annual) — https://www.dragos.com/ye-2024/
- MITRE ATT&CK for ICS — https://attack.mitre.org/matrices/ics/
- ISA/IEC 62443 series overview — https://www.isa.org/standards-and-publications/isa-standards/isa-iec-62443-series-of-standards
- Schneider Electric / FireEye TRITON technical analysis — https://www.mandiant.com/resources/blog/attackers-deploy-new-ics-attack-framework-triton
