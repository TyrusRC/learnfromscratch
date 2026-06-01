---
title: SharpHound
slug: sharphound
---

> **TL;DR:** SharpHound is the C# / Go collector that ingests Active Directory and feeds JSON/ZIP data into BloodHound. Choosing the right collection methods is the difference between a silent enumeration and a domain-wide IDS event — pick narrow methods first, broaden only when needed.

## What it is
SharpHound walks LDAP for users, computers, groups, GPOs, ACLs and trusts, then optionally pivots to each computer for session and local-group data via SMB, RPC (SAMR), or remote registry. The output is a set of JSON files describing nodes and edges that BloodHound's database ingests for graph queries. The Go rewrite (`sharphound` v2) ships with BloodHound CE; the legacy C# binary is still required for some Windows-only collection methods.

## Preconditions / where it applies
- Any authenticated domain credential (user or machine)
- Network reach to a DC (LDAP 389/636) for the cheap methods; reach to every endpoint for the expensive ones
- For session collection: RPC over SMB to TCP/445, with SAMR or remote registry permitted

## Technique
Methods, cheapest to noisiest:

```text
DCOnly      — LDAP only against a DC. Users, groups, ACLs, trusts, GPOs. Near-zero noise.
Default     — DCOnly + Sessions + LocalAdmin + RDP + DCOM (touches every computer)
Session     — NetSessionEnum on each host (post-KB5008383, requires admin on most builds)
LoggedOn    — Authenticated session pull; needs elevated rights, very noisy
ACL         — DACL retrieval (already in Default; cheap on its own)
GPOLocalGroup — Parses GPP/Restricted Groups XML on SYSVOL — silent and high-value
Trusts      — Domain/forest trust enumeration only
Container   — OU structure and links
```

OPSEC-friendly first pass:

```powershell
SharpHound.exe -c DCOnly,Trusts,Container,GPOLocalGroup --zipfilename dc.zip
```

When session data is required, throttle and randomise:

```powershell
SharpHound.exe -c Session --throttle 1500 --jitter 25 --excludedcs
```

Linux/Impacket equivalent (BloodHound.py) covers most of the same data with no agent on Windows:

```bash
bloodhound-python -u alice -p Pass -d corp.local -ns 10.0.0.10 \
  -c DCOnly,Trusts --zip
```

Common detections to dodge: `--excludedcs` (skip DCs for the LDAP query the second time), `--throttle` / `--jitter` to avoid bursty RPC, and `--collectallproperties` only when you actually need cert-template attributes.

## Detection and defence
- Microsoft Defender for Identity flags rapid LDAP enumeration patterns (`Reconnaissance using directory services queries`) and SAMR enumeration of local groups
- Enable LDAP query auditing on DCs; bulk searches with `objectClass=*` and large page sizes are SharpHound fingerprints
- Restrict SAMR remote calls (`SeDenyNetworkLogonRight` for unprivileged users, `Network access: Restrict clients allowed to make remote calls to SAM`)
- Detection rule: `wevtutil` event 5145 with object name patterns from session enumeration, or unusual TCP/445 fan-out from a single workstation

## References
- [SharpHound (Go)](https://github.com/SpecterOps/SharpHound) — current collector
- [SharpHound documentation](https://support.bloodhoundenterprise.io/hc/en-us/sections/17274904741403) — method definitions and OPSEC notes
- [BloodHound.py](https://github.com/dirkjanm/BloodHound.py) — Impacket-based alternative
- See also: [[bloodhound]], [[ldap-enumeration]], [[acl-abuse]]
