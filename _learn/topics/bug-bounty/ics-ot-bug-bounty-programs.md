---
title: ICS / OT bug bounty programs
slug: ics-ot-bug-bounty-programs
aliases: [ics-bb, ot-bb-programs]
---

> **TL;DR:** ICS / OT bug bounty is a small, specialized corner of the industry. The biggest paydays sit at ZDI Pwn2Own ICS/SCADA (Miami every January), with smaller vendor programs (Schneider, Siemens, Rockwell, ABB, Honeywell) and CISA-coordinated disclosure handling the rest. Scope is mostly engineering software, HMIs, gateways and (occasionally) PLC firmware. Compared to web bounty work, the bar is high: you need a hardware lab, patience for 90-180 day patch cycles and a strict no-live-infrastructure ethic. Companion to [[ics-scada-protocols-attacks]], [[dnp3-attacks-deep]], [[modbus-attacks-deep]], [[iec61850-attacks]], [[opc-ua-attacks]] and [[freertos-audit]].

## Why it matters

ICS / OT vendors historically did not run public bounties — vulnerabilities flowed through CERT/CC, ICS-CERT (now CISA) or vendor PSIRTs. Two things changed that:

- **Pwn2Own ICS/SCADA** (since 2020) put real money — six figures per chain — on PLC, HMI and OPC UA exploits, and forced vendors to publish PSIRT contacts and SBOMs.
- **NIS2 / CRA in the EU** and **CISA Secure-by-Design pledges** in the US pushed asset-owners to demand documented disclosure programs as a procurement condition.

For a bug hunter this means: scoped programs exist, payouts are predictable at Pwn2Own, and even "unpaid" CISA advisories are career-grade portfolio pieces. See [[building-a-research-home-lab]] for the lab side and [[program-selection-tactics]] for choosing where to spend your time.

## Programs and how they actually work

### ZDI Pwn2Own ICS/SCADA (Miami)

- Annual, January. Targets are announced ~10 weeks before — usually a mix of OPC UA servers/clients, engineering workstations (TIA Portal, Studio 5000, EcoStruxure), data historians and DNP3 gateways.
- Prize per category historically USD 20k-40k; chains can reach USD 75k-100k.
- Registration is free but you compete for a slot. Read [[pwn2own-2024-2025-research-roundup]] for recent winning chains and the kinds of bugs (file-parsing in project files, unauthenticated RPC, OPC UA cert validation) that keep landing.
- ZDI also runs a year-round programme (ZDI program) that buys ICS bugs outside of Pwn2Own; payouts are lower but the bar to entry is also lower.

### CISA coordinated disclosure (ICSA advisories)

- Free intake at the CISA portal; CISA acts as broker between you and the vendor and publishes an **ICSA-YY-DDD-NN** advisory.
- No money, but advisories are well-indexed and become CVE-of-record. Good for credibility, terrible for rent.
- Coordination timeline is typically 90-180 days. Vendors who drag are publicly tracked.

### Vendor programs

| Vendor | Program style | Notes |
|---|---|---|
| Siemens | Private PSIRT, occasional invitation-only HackerOne | Big SBOM publication, advisories at SSA-XXXXXX |
| Schneider Electric | PSIRT + bug bounty via Bugcrowd (private) | EcoStruxure family, Modicon PLCs |
| Rockwell Automation | PSIRT only | Studio 5000, Logix controllers; coordinates via CISA |
| ABB | PSIRT only | 800xA, RobotWare |
| Honeywell | PSIRT only | Experion PKS, ControlEdge |
| Emerson | PSIRT only | DeltaV, Ovation |
| Phoenix Contact, WAGO, Beckhoff | Public PSIRT pages, CERT@VDE coordination | Strong EU CERT pipeline |

Pay is rare outside Schneider's invite-only Bugcrowd; most submissions earn credit + advisory. See [[program-scope-reading]] for how to interpret vendor PSIRT pages as if they were bounty scopes.

## In-scope target classes

### Engineering / configuration software

- **Examples**: Siemens TIA Portal, Rockwell Studio 5000, Schneider EcoStruxure Control Expert, ABB Automation Builder.
- **Bug classes**: project-file parsing (XML, ZIP, custom containers) hitting deserialization or path-traversal; license-server RPC; unauth localhost services. Same techniques as [[apk-reverse-tools]]-style file-format fuzzing but on Windows.

### HMI and SCADA servers

- **Examples**: WinCC, FactoryTalk View, GE iFIX, AVEVA / Wonderware InTouch, Ignition.
- **Bug classes**: web-HMI auth bypass, project import RCE, OPC UA cert pinning bugs (see [[opc-ua-attacks]]), SQL/Sybase historians.

### Protocol gateways and field devices

- **Examples**: Moxa, Red Lion, Phoenix Contact gateways; Allen-Bradley CompactLogix, Modicon M340.
- **Bug classes**: protocol parser bugs in [[modbus-attacks-deep]], [[dnp3-attacks-deep]], [[iec61850-attacks]], [[profinet-ethercat-attacks]]; firmware update authentication; web-config CSRF/auth-bypass.

### PLC firmware

- Hardest category. Often [[freertos-audit]] / [[zephyr-audit]] / VxWorks / custom RTOS underneath. Extraction techniques live in [[firmware-extraction]] and [[uart-jtag-debug]]; emulation in [[firmware-emulation-firmadyne-qemu]].

## Challenges that make ICS bounty different

- **No public PoCs**. Unlike web bounty where you can study [[h1-disclosed-report-reading-method]] feeds, ICS PoCs are gated. You will rebuild bugs from terse ICSA bullet points and patch diffs — apply [[one-day-from-patch-diff]] aggressively.
- **Three-way coordination**. Vendor + asset-owner + CISA. Patch availability does not equal patch deployment; some power utilities take 12-24 months to apply.
- **Long patch cycles**. Plan for 6-12 months between report and public credit. Build a pipeline (see [[burnout-and-pipeline]]) so you are not staring at a single report.
- **Hardware acquisition**. PLCs and HMIs cost USD 500-5000 on eBay/Reverse-Industrial. Engineering software is usually free to download with vendor account but locked to dongles for full features.
- **Legal exposure**. CFAA / EU Computer Misuse Act treat critical infrastructure aggressively. Stay on your bench. Re-read [[responsible-disclosure-across-jurisdictions]] before touching anything that is reachable from the internet.

## Ethical baseline — never test live infrastructure

- **Buy or borrow hardware**. Asset-owner labs are great if you have access; otherwise eBay and the vendor's online demo VMs.
- **Never scan Shodan-discovered devices**. Even a TCP connect against a substation IED can trip protection relays. Use [[ics-scada-protocols-attacks]] safely-in-lab guidance.
- **Avoid sending real protocol writes** (Modbus FC06/16, DNP3 operate, IEC 61850 control-with-enhanced-security) anywhere outside an air-gapped lab.
- **Disclose to CISA if you accidentally find something live**. Do not exploit, do not screenshot operator data, document and walk away.

## Lab requirements

Minimum viable ICS research bench:

- One PLC per vendor family you target (Siemens S7-1200, AB MicroLogix or CompactLogix L16, Schneider M221).
- One HMI or HMI software running in a Windows 10 VM.
- USB-to-serial + Ethernet TAP + managed switch with port mirroring (for protocol capture).
- Logic analyzer + cheap JTAG (J-Link EDU Mini, BusPirate) for the firmware-extraction path in [[firmware-extraction]] / [[uart-jtag-debug]].
- A dedicated, fully isolated VLAN (or air-gapped switch). Document it; if you ever need to prove safety to a vendor or to law enforcement you will want photos and diagrams.

Budget realistically: USD 2-5k entry, USD 10-20k for a serious multi-vendor bench. Pwn2Own travel and lodging is on you until you win.

## Workflow to study

1. **Pick a vendor family** that matches hardware you can afford. Don't try to cover all of them. Cross-reference [[target-selection-heuristics]].
2. **Read 12 months of that vendor's PSIRT / ICSA advisories**. Cluster by component. Patterns emerge — e.g. Rockwell's CIP stack has had recurring auth-bypass bugs; Siemens WinCC keeps having license-server RCE.
3. **Pull the latest patched firmware and the immediately previous version**. Diff. Use [[one-day-from-patch-diff]] and [[reading-public-pocs-effectively]] muscle.
4. **Stand up the device in your lab**. Reproduce one known bug end-to-end before hunting new ones — this builds the harness you will reuse.
5. **Pick a parser**. Project-file parsers (CSV, XML, ZIP, custom) are the highest-yield surface for engineering software and frequently land at Pwn2Own.
6. **Decide your disclosure path early**: ZDI (paid, embargoed until Pwn2Own), vendor PSIRT (sometimes paid), or CISA (free, advisory). Write the report using [[report-writing-step-by-step]]; communications go through [[disclosure-and-comms]].
7. **Track your pipeline**. ICS reports sit open for months; treat it like the long-tail half of [[automation-and-rinse-repeat]].

## Defensive baseline for asset owners reading this

- Subscribe to vendor PSIRT RSS + CISA ICS advisories.
- Maintain an asset inventory keyed to CPE so advisories can be matched in minutes.
- Segment per ISA-95 / IEC 62443 zones; protocol-aware firewalls (Modbus, DNP3, IEC 61850, OPC UA whitelisting).
- Patch windows: aim for 90 days on engineering workstations, 180 days on controllers, with compensating controls (read-only mode, ACLs) in between.
- Have a coordinated-disclosure intake of your own — researchers will email security@ your domain; make sure that mailbox is monitored.

## Related

- [[ics-scada-protocols-attacks]]
- [[dnp3-attacks-deep]]
- [[modbus-attacks-deep]]
- [[iec61850-attacks]]
- [[opc-ua-attacks]]
- [[profinet-ethercat-attacks]]
- [[freertos-audit]]
- [[firmware-extraction]]
- [[firmware-audit-methodology]]
- [[firmware-emulation-firmadyne-qemu]]
- [[uart-jtag-debug]]
- [[pwn2own-2024-2025-research-roundup]]
- [[one-day-from-patch-diff]]
- [[program-scope-reading]]
- [[program-selection-tactics]]
- [[target-selection-heuristics]]
- [[building-a-research-home-lab]]
- [[responsible-disclosure-across-jurisdictions]]
- [[disclosure-and-comms]]
- [[report-writing-step-by-step]]

## References

- ZDI Pwn2Own Miami rules and target list — https://www.zerodayinitiative.com/Pwn2OwnMiami
- CISA ICS advisories index — https://www.cisa.gov/news-events/cybersecurity-advisories
- Siemens ProductCERT PSIRT page — https://www.siemens.com/global/en/products/services/cert.html
- Schneider Electric cybersecurity support portal — https://www.se.com/ww/en/work/support/cybersecurity/overview.jsp
- Rockwell Automation PSIRT — https://www.rockwellautomation.com/en-us/trust-center/security-advisories.html
- CERT@VDE coordinated disclosure (Phoenix Contact, WAGO, Beckhoff and others) — https://cert.vde.com/
