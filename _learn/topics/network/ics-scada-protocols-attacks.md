---
title: ICS/SCADA protocols and attacks
slug: ics-scada-protocols-attacks
aliases: [ics-attacks, scada-attacks, ot-protocols]
---

{% raw %}

> **TL;DR:** Industrial Control Systems run on protocols designed in the 1970s-90s with no authentication or encryption: Modbus (TCP/IP since 1999), DNP3, EtherNet/IP, Siemens S7, OPC-UA (newer, has auth). Attacks: (1) read tags / coils unauthenticated, (2) write control values (start/stop motors, open/close valves), (3) DoS via crafted frames, (4) lateral via engineering-workstation HMI. The blast radius is physical — process shutdowns, equipment damage, safety hazards. Companion to [[firmware-audit-methodology]] and [[network-pentesting]].

## Protocol landscape

| Protocol | Layer | Auth | Common use |
|---|---|---|---|
| **Modbus TCP** | TCP/502 | none | most PLCs, sensors, drives |
| **DNP3** | TCP/20000 | optional (Secure Authentication v5) | power utilities |
| **EtherNet/IP (CIP)** | TCP+UDP/44818,2222 | none (CIP Security adds it) | Allen-Bradley |
| **Siemens S7Comm** | TCP/102 | weak (password challenge) | Siemens S7-300/400/1200/1500 |
| **OPC-UA** | TCP/4840 | yes (X.509, username) | newer SCADA, MES |
| **OPC Classic (DCOM)** | random | weak | legacy SCADA |
| **BACnet** | UDP/47808 | none | building automation |
| **IEC 60870-5-104** | TCP/2404 | optional | substations |
| **MMS (IEC 61850)** | TCP/102 | optional | substations |

## Modbus — the simplest attack surface

Function codes you care about:
- 1, 2 — read coils / discrete inputs.
- 3, 4 — read holding / input registers.
- 5, 15 — write single / multiple coils.
- 6, 16 — write single / multiple registers.

Tooling:
```bash
nmap -p 502 --script modbus-discover 10.0.0.0/24
mbtget -r3 -a 0 -n 10 10.0.0.5            # read registers
mbtget -w6 -a 100 -n 1 -v 99 10.0.0.5     # write register

# python
from pymodbus.client import ModbusTcpClient
c = ModbusTcpClient('10.0.0.5')
print(c.read_holding_registers(0, 10).registers)
c.write_register(100, 99)
```

If you can write to coils that control physical devices, you can shut down a process from a network-reachable Modbus port. Most engagements treat this as "demonstrate the read; do *not* demonstrate the write" — physical damage is real.

## DNP3

```bash
nmap -p 20000 --script dnp3-info 10.0.0.5
```

DNP3 has Secure Authentication v5 (SAv5) — most deployments don't enable it. Read points, control points, time sync.

## Siemens S7

```bash
nmap -p 102 --script s7-info 10.0.0.5
# Snap7 library for Python
```

S7 has a "password" challenge but it's weak and bypassable in many CPU versions. Once authenticated, full read/write of memory blocks and program logic.

## OPC-UA

Modern, X.509-based, signed/encrypted messages — *when configured*. Many deployments use `None` security mode with anonymous auth (development default that never got changed).

```bash
nmap -p 4840 --script opcua-discover 10.0.0.5
```

Tools: UA Expert (free), Open62541, Python `asyncua`.

## Engagement methodology

1. **Scope confirmation** — physical-impact testing only with engineering sign-off.
2. **Network discovery** — find the ICS/OT subnet, often segmented.
3. **Passive listening** — Wireshark + dissectors for the protocol identified.
4. **Asset inventory** — every PLC, HMI, historian.
5. **Read-only enumeration** — coil counts, register ranges, alarm counts.
6. **Read sensitive points** — production data, recipes, operator-only points.
7. **Document write capability** — *without* actually writing, unless explicitly authorised on a safe target.
8. **Engineering-workstation lateral** — pivot through HMI Windows host into corporate domain.

## Common bugs found in ICS engagements

- Modbus exposed to internet via misconfigured firewall.
- PLC engineering ports (S7, EtherNet/IP) reachable from corp Wi-Fi.
- Historian database (Wonderware, OSIsoft PI) with default credentials.
- HMI Windows box on Windows 7 or XP without updates.
- VPN credentials hardcoded in engineering software.
- Schneider / Allen-Bradley / Siemens firmware CVEs not patched.

## Defence

- **Network segmentation** (Purdue model levels). OT in its own VLAN, no direct internet.
- **Unidirectional gateways / data diodes** for historian uploads.
- **Whitelisting** on engineering workstations.
- **Patching cadence** — different from IT; quarterly or per-shutdown.
- **Encrypted protocols** — OPC-UA with security mode `SignAndEncrypt`, DNP3 SAv5.
- **Monitor for unusual write frequencies and out-of-hours commands.**

## Safety, safety, safety

ICS engagements differ from IT in one big way: a write to the wrong register can:
- Open a valve that floods a tank.
- Stop a centrifuge mid-run, damaging it.
- Disable safety interlocks.
- Cause physical harm to operators.

Rule: **never write to a live PLC**. Demonstrate write capability on a test target the engineering team provides. Document the protocol-level achievability without exercising it.

## Tools

- **wireshark + ICS dissectors** — read frames.
- **PLC simulators** (Schneider Modbus Slave, Snap7) for safe practice.
- **Conpot** — ICS honeypot for defenders.
- **SamuraiSTFU** — VM with ICS tools pre-installed.
- **Industrial Security Scanner (Tenable.ot, Claroty, Dragos)** — commercial.

## Lab and study

- **MITRE ATT&CK for ICS** — reference taxonomy.
- **SANS ICS courses (ICS410/515)** — comprehensive curriculum.
- **CISA ICS Training Center** — free.

## OSCP/OSEP relevance

Out of scope. Crucial for energy, water, oil & gas, manufacturing, transit engagements.

## References
- [MITRE ATT&CK for ICS](https://attack.mitre.org/matrices/ics/)
- [Dale Peterson — Digital Bond](https://dale-peterson.com/)
- [SANS ICS](https://www.sans.org/cybersecurity-courses/?focus-area=industrial-control-systems-security)
- [CISA ICS advisories](https://www.cisa.gov/news-events/cybersecurity-advisories/ics-advisories)
- [Modbus specification](https://modbus.org/specs.php)
- See also: [[firmware-audit-methodology]], [[network-pentesting]], [[sdr-and-radio-recon]]

{% endraw %}
