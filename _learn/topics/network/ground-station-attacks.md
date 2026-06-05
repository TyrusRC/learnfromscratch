---
title: Ground-station attacks
slug: ground-station-attacks
aliases: [satellite-ground-station-attacks, gs-attacks, ka-sat-incident]
---

> **TL;DR:** Ground stations command and receive data from satellites; compromise of a ground station propagates to space-segment operations. Most ground stations run COTS Linux / Windows with custom mission-software stacks, often connected to corporate IT networks for convenience. The 2022 Viasat KA-SAT incident is the defining public case — VPN compromise → ground modem firmware update push → 30,000+ user terminals bricked. Companion to [[cubesat-attacks]] and [[case-study-snowflake-2024]].

## Why ground stations matter

- **Ground is the easier target** than space — physical access feasible, Internet-connected.
- **Compromise propagates** — modem firmware updates, command spoofing.
- **Critical infrastructure** — financial sector, GPS-correction services, broadcasting, defence all rely.
- **Limited security review** historically — assumed obscure / trusted.
- **Geopolitical target** — state actors disrupt civil / commercial services in conflict zones.

## What's in a ground station

- **Antennas** + rotors + RF front-end.
- **Modems** translating between RF and IP.
- **Operations workstations** running mission software.
- **Network infrastructure** — VPN, firewall, gateway.
- **Mission planning** software.
- **Data archive** systems.

Connections to public Internet for operator access, customer data delivery, vendor remote support.

## Class 1 — Operator workstation compromise

Standard IT attack chain:
- Phishing operator → corporate network.
- Lateral movement to ops network.
- Mission software access.
- Command satellite.

This is the Viasat KA-SAT chain shape (see below).

## Class 2 — Vendor remote-support backdoor

Vendors often have remote access for support. Bugs / compromise:
- VPN with weak / unpatched configuration.
- Vendor's own infrastructure compromised; vendor connection becomes attacker connection.
- Stale credentials.

## Class 3 — Modem firmware update push

Many user-terminal modems (satellite Internet, IoT terminals) support over-the-air firmware update from a network management system. Compromise of the management system:
- Push bad firmware.
- Brick large numbers of devices.
- Or install attacker firmware for persistent control.

This is Viasat 2022.

## Class 4 — Command authentication weakness

Ground-to-satellite commanding sometimes:
- Uses pre-shared keys with long lifetime.
- Replays accepted within wide window.
- Authentication on legacy radios uses weak algorithms.

Operator compromise + weak crypto = ability to fabricate commands.

## Class 5 — Telemetry tampering

Downlink telemetry is the operator's view of spacecraft state. Tamper:
- Replay legitimate telemetry to hide adverse state.
- Inject misleading data.

Less common attack scenario; more academic.

## Class 6 — Network gateway misconfig

Ground stations often have dual-homed gateways:
- One face on public Internet.
- One face on operations network.

Misconfiguration = attacker on Internet bridges into ops.

## The Viasat KA-SAT incident (24 February 2022)

A defining ground-segment cybersecurity case:

1. Attackers (attributed to Russian GRU by Five Eyes) gained access to Viasat's management infrastructure for KA-SAT modems.
2. They distributed a destructive firmware update — `AcidRain` wiper — to user-terminal modems serving customers in Europe.
3. ~30,000+ modems bricked simultaneously.
4. Disrupted Ukrainian military communications + civilian customers across Europe.
5. Critical impact extended to wind farm remote management in Germany (Enercon).

The attack reached the modems via legitimate management channels because the management system itself was compromised. Standard IT-style breach with extraordinary kinetic-equivalent impact.

## Other notable incidents / research

- **Hack-a-Sat 2022** — ground-segment challenges with real spacecraft simulators.
- **NASA / ESA OPS** — periodic security improvements following internal audits.
- **Iridium ground network** — academic security analyses.
- **Starlink ground** — multiple reverse-engineering disclosures (Lennert Wouters et al.).

## Defensive baseline

For operators:
- **Treat ground station as crown-jewel infrastructure** — same posture as PCI-CDE or HIPAA ePHI.
- **Segregate** ops network from corporate; physical air-gap where possible.
- **MFA** + hardware tokens for operator access; phish-resistant.
- **Modem firmware updates** signed + verified at modem; management system can't push unsigned.
- **Rate-limit** command issuance.
- **Audit log** all commands; retention sufficient for forensics (years).
- **Vendor remote access** through jump host with session recording.
- **Patch management** — like any IT system.
- **Tabletop exercise** for compromise scenarios.

For vendors:
- **Sign firmware** unequivocally; verify on device.
- **Limit management-system blast radius** — partition by tenant.
- **Provide upstream cryptographic separation** — vendor's own staff can't push without dual control.
- **Disclose security architecture** to customers for review.

## IR considerations

If a ground station is compromised:
- **All commands** during the window are suspect.
- **All telemetry** during the window is suspect.
- **All commanded actions** may have been attacker-directed.
- **All firmware updates** in the window need review.
- **Vendor coordination** — may need to recall / replace devices.
- **Regulatory reporting** — NIS2, CRA, GDPR, sector-specific.

## Workflow to study

1. Read AcidRain post-mortem (SentinelOne).
2. Read CCSDS standards on command authentication (SDLS).
3. Read Hack-a-Sat ground-segment writeups.
4. Stand up an amateur satellite ground station with SatNOGS for hands-on experience.

## Standards / regulatory

- **CCSDS Space Data Link Security (SDLS)** — modern crypto standards for command.
- **NIST 800-53** — applicable to ground IT.
- **NIST IR 8401** — Satellite Ground Segment Cybersecurity.
- **EU NIS2** — applies to space-sector entities ([[nis2-implementation]]).
- **CISA** — Space Systems Sector guidance.

## Related

- [[cubesat-attacks]]
- [[satellite-modem-attacks]]
- [[gps-gnss-spoofing]]
- [[case-study-snowflake-2024]] — adjacent ground-IT breach class
- [[nis2-implementation]]
- [[ir-from-source-signals]]
- [[siem-detection-use-case-catalog]]

## References
- [SentinelOne — AcidRain analysis](https://www.sentinelone.com/labs/acidrain-a-modem-wiper-rains-down-on-europe/)
- [Viasat — KA-SAT incident statement](https://news.viasat.com/blog/corporate/ka-sat-network-cyber-attack-overview)
- [CCSDS SDLS](https://public.ccsds.org/)
- [NIST IR 8401 — Satellite Ground Segment Cybersecurity](https://nvlpubs.nist.gov/nistpubs/ir/2022/NIST.IR.8401.pdf)
- [DEFCON Aerospace Village](https://aerospacevillage.org/)
- See also: [[cubesat-attacks]], [[satellite-modem-attacks]], [[gps-gnss-spoofing]], [[case-study-snowflake-2024]]
