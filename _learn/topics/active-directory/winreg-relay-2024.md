---
title: WinReg relay (2024 disclosures)
slug: winreg-relay-2024
aliases: [winreg-relay, remoteregistry-relay, akamai-winreg-research]
---

> **TL;DR:** The Windows Remote Registry service (`RemoteRegistry`) exposes the `winreg` RPC interface. Akamai's 2024 research showed RPC calls into `winreg` could be coerced from a target then relayed via NTLM to other services (notably ADCS for ESC8). Adds a new coercion primitive next to PetitPotam / PrinterBug / DFSCoerce. Mitigated by Microsoft as CVE-2024-43532. Companion to [[petitpotam-coercion]], [[printer-bug-spoolsample]], [[dfscoerce]].

## Why this matters

- Each new coercion primitive prolongs the **NTLM-relay-to-ADCS** chain for attackers.
- `RemoteRegistry` is enabled by default in older builds; many tier-0 boxes still expose it.
- Disclosed by Akamai (Stiv Kupchik); Microsoft assigned CVE-2024-43532.
- Adds another box to consider in [[adcs-attacks]] / ESC8 chains.

## The coercion primitive

When a low-privilege user calls a `winreg` RPC method on a target, the target authenticates back to the attacker if the call falls through certain transports. The fall-back authentication uses NTLM and can be relayed (no signing on the channel).

Akamai's method exploited the `winreg` IDL methods that touch SCM-like paths under specific conditions.

The result: any user who can reach `RemoteRegistry` on a target can cause the target to NTLM-authenticate to an attacker host.

## The relay chain

1. Attacker controls a relay host (`ntlmrelayx`).
2. Attacker calls a winreg method on the victim that triggers the target to authenticate.
3. Authentication arrives at the relay (because attacker chose the host).
4. Relay forwards to the ADCS Web Enrollment endpoint (ESC8) or LDAP or SMB.
5. Relay obtains a certificate or session as the victim machine account.

The chain ends with the attacker holding a machine-account TGT (via PKINIT with the cert) — full lateral movement to that machine, often domain-tier escalation when the victim is a DC.

## Pre-conditions

- `RemoteRegistry` service enabled on the target.
- Target is reachable from the attacker over RPC (TCP ports 135 + dynamic, 445 for SMB transport).
- Target's NTLM authentication is not enforced-signing on the channel used.
- Relay target (ADCS Web Enrollment) doesn't enforce EPA (Extended Protection for Authentication) or signing.

This last point — EPA on ADCS — is the recommended mitigation.

## The patch

Microsoft's October 2024 cumulative update changed `winreg` RPC behaviour so the coerced authentication path no longer triggers in the same shape.

The patch is partial in the sense that the **wider class** of NTLM-relay-via-coercion remains until full mitigations (LDAP signing, SMB signing, EPA on ADCS, RemoteRegistry hardening) are deployed.

## Workflow to study in a lab

1. Stand up a small AD environment (DC + ADCS + member server).
2. Enable ADCS Web Enrollment (default in many labs).
3. From the attacker host (Kali), run `ntlmrelayx.py -t http://adcs/certsrv/certfnsh.asp --adcs --template DomainController`.
4. Use Akamai's PoC (or community variant) to coerce the target via winreg.
5. Observe ntlmrelayx capturing the auth and issuing a cert.
6. Use Rubeus / certipy to exchange the cert for a TGT.

(Lab-only. Do not run against any environment without explicit authorisation.)

## Detection

- `winreg` RPC calls from unexpected source IPs.
- Sudden NTLM authentications from servers to non-DC hosts.
- ADCS issuing certificates with subject = machine account where there's no automation reason.
- Event ID 4768 for PKINIT-based TGTs for machine accounts.

## Defensive baseline

- **Disable `RemoteRegistry`** on tier-0 / tier-1 hosts.
- Apply October 2024 cumulative update.
- Enable **EPA** on ADCS Web Enrollment endpoints.
- Require **HTTPS-only** for ADCS Web Enrollment.
- Enforce **LDAP signing + channel binding**.
- Enforce **SMB signing** on DCs.
- Disable **NTLM** on internal hosts where possible (modern Kerberos-only AD).
- Limit issuance permissions on certificate templates ([[adcs-attacks]]).

## Related coercion primitives

- **PrinterBug / SpoolSample** — see [[printer-bug-spoolsample]].
- **PetitPotam** — see [[petitpotam-coercion]].
- **DFSCoerce** — see [[dfscoerce]].
- **ShadowCoerce** — see [[shadowcoerce]].
- **MS-EVEN6** (Event Log) — adjacent recent disclosures.

Each new primitive only matters because NTLM and the ADCS / LDAP / SMB receivers haven't been hardened. The fix is the same.

## NTLM relay mitigation roadmap context

Microsoft's Windows Server 2025 / Windows 11 24H2 release continued the deprecation roadmap for NTLM. See [[ntlm-relay-ws2025-mitigations]] for the broader picture. Coercion primitives will lose impact as defaults harden; until then they're still operationally relevant.

## References
- [Akamai research blog — winreg](https://www.akamai.com/blog/security-research)
- [Microsoft advisory CVE-2024-43532](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2024-43532)
- [Certipy](https://github.com/ly4k/Certipy)
- [ntlmrelayx](https://github.com/SecureAuthCorp/impacket)
- See also: [[petitpotam-coercion]], [[printer-bug-spoolsample]], [[dfscoerce]], [[adcs-attacks]], [[ntlm-relay-ws2025-mitigations]]
