---
title: DNP3 attacks
slug: dnp3-attacks-deep
aliases: [dnp3-deep, distributed-network-protocol-3]
---

> **TL;DR:** DNP3 (Distributed Network Protocol 3, IEEE 1815) is the dominant SCADA protocol in North American electric utility distribution, water/wastewater, and oil/gas. Three-layer stack (application/transport/data-link) sits on TCP/UDP 20000 or serial. Pre-Secure Authentication (SA) deployments accept any command; SA v5 adds challenge-response but adoption uneven. Memory-corruption CVEs in popular stacks (Triangle MicroWorks, others) provide remote code execution against RTUs. Companion to [[modbus-attacks-deep]] and [[ics-scada-protocols-attacks]].

## Why DNP3 matters

- **Major North American electric utility distribution** uses it heavily.
- **Real-time** control of substations, generators.
- **Deployments are long-lived** — RTUs from 1990s still in service.
- **No encryption** by default (Secure Authentication v5 adds auth, not crypto privacy).
- **TCP/UDP exposed** in many utility networks, particularly when "modernised" to IP.

## DNP3 architecture

Layers:
- **Application layer** — request/response, function codes (1=Read, 2=Write, 5=Direct Operate, etc.).
- **Transport layer** — fragmentation.
- **Data-link layer** — frame structure with CRC.

Ports:
- TCP 20000 (default), UDP 20000.
- Serial RS-232 / RS-485 historically.

Master / outstation model:
- **Master** = SCADA control system.
- **Outstation** (RTU / IED) = field device controlling physical equipment.

## Class 1 — Unauthenticated command injection

Pre-SA DNP3 has no authentication. Anyone reaching the outstation:
- Send Direct Operate (function code 5) to actuate.
- Open/close breakers.
- Change setpoints.

Combined with poor network segmentation, this is "Internet → utility actuation" in worst-case scenarios.

## Class 2 — Function-code abuse

DNP3 function codes include:
- **5 — Direct Operate** — execute immediately.
- **6 — Direct Operate, No Acknowledge** — fire and forget.
- **13 — Cold Restart** — full restart of outstation.
- **14 — Warm Restart**.
- **15 — Initialize Data**.
- **16 — Initialize Application**.
- **18 — Stop Application**.

Without auth, restart commands DoS the substation.

## Class 3 — Memory corruption in DNP3 stack

The protocol parsing is complex. Stack implementations have shipped with classic memory bugs:
- Buffer overflows in fragmentation reassembly.
- Integer overflows in length fields.
- Object-parse confusion.

Triangle MicroWorks (popular DNP3 library used by many vendors) has had multiple CVEs over the years. SEL, GE, Schneider products affected.

Disclosed PoCs for some bugs allow pre-auth remote code execution on the RTU — much more impactful than just protocol abuse.

## Class 4 — Secure Authentication bypass / weakness

DNP3 SA v5:
- Adds challenge-response on critical commands.
- HMAC-based with pre-shared key.
- Sequence numbers prevent replay.

Bypass / weaknesses:
- **Key management** — keys often hard-coded or shared across substations.
- **HMAC implementation bugs** in some stacks.
- **Aggressive Mode** — fewer round-trips; some configurations vulnerable.
- **Pre-deployment keys** never rotated.

When SA is deployed but keys are weak, attacker can still craft authenticated commands.

## Class 5 — DoS via malformed frames

Even with SA, malformed pre-auth frames can crash the outstation. Many implementations don't gracefully handle adversarial input.

DoS on a substation outstation is operational; recovery is on-site.

## Class 6 — MITM via spanning-tree / serial-to-IP gateways

DNP3 traffic on shared switches is sniffable. Serial-to-IP gateways concentrate traffic; gateway compromise = MITM all.

## Defensive baseline

- **Segregate** ICS network from IT.
- **Deny** Internet exposure of DNP3 ports.
- **Deploy SA v5** with strong, rotated keys.
- **Update DNP3 stack** firmware on RTUs.
- **Whitelist** master IP at outstations.
- **Encrypt at the network layer** — IPsec for site-to-site if exposed.
- **Monitor** — Snort / Suricata rules for DNP3 anomalies (Dragos, Nozomi, Claroty publish).

## Detection

- **DNP3-specific IDS rules** in Snort / Suricata.
- **Whitelist** known-good function codes; alert on unexpected.
- **Baseline** typical traffic; alert on deviation.
- **Dragos / Claroty / Nozomi** ICS-focused platforms.

## Workflow to study

1. Install OpenDNP3 (C++) or pydnp3.
2. Stand up a master + outstation in a lab.
3. Capture traffic in Wireshark (has DNP3 dissector).
4. Send unauthenticated commands to outstation.
5. Apply SA; observe authentication overhead.
6. Read disclosed Triangle MicroWorks CVEs for parser-bug shape.

## Real-world incidents

- **Ukraine 2015 / 2016 (industrial)** — used a mix of techniques including protocol abuse; ICS-specific elements involved different protocols too.
- **Various Dragos / Claroty disclosures** of vulnerable substation deployments.
- **DEF CON ICS Village** demonstrations.

## Standards / regulatory

- **NERC CIP** (North American Electric Reliability Corporation Critical Infrastructure Protection) — required controls for utility ICS.
- **IEC 62351** — security for power-system communications.
- **CISA / NSA / DOE** ICS guidance.

## Related

- [[modbus-attacks-deep]]
- [[iec61850-attacks]]
- [[opc-ua-attacks]]
- [[profinet-ethercat-attacks]]
- [[ics-scada-protocols-attacks]]
- [[freertos-audit]]
- [[firmware-extraction]]

## References
- [IEEE 1815 DNP3 standard](https://standards.ieee.org/standard/1815-2012.html)
- [OpenDNP3](https://github.com/dnp3/opendnp3)
- [DNP3 Users Group](https://www.dnp.org/)
- [Dragos research blog](https://www.dragos.com/blog/)
- [Triangle MicroWorks CVE history](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=triangle+microworks)
- See also: [[modbus-attacks-deep]], [[iec61850-attacks]], [[opc-ua-attacks]], [[ics-scada-protocols-attacks]]
