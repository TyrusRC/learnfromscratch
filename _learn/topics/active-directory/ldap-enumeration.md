---
title: LDAP enumeration (AD)
slug: ldap-enumeration
---

> **TL;DR:** Walk the directory tree to fingerprint users, computers, groups, ACLs, delegation flags, AD CS templates, and policy — the foundation every subsequent AD attack relies on.

## What it is
AD exposes its data over LDAP on 389/636 and 3268/3269 (Global Catalog). After authentication (and sometimes anonymously), almost every object attribute is readable by `Authenticated Users` by default. Enumeration converts that read access into a target map: who has SPNs ([[kerberoasting]]), who has delegation flags ([[constrained-delegation]]/[[unconstrained-delegation]]), who can DCSync, what cert templates are vulnerable, what trusts exist, what the password policy is.

## Preconditions / where it applies
- 389/tcp or 636/tcp reachable to any DC (or 3268/3269 to a GC for cross-domain reads).
- Valid creds — password, NT hash, or Kerberos ticket. Anonymous bind is rare on modern AD but worth probing.
- Helps to have a hostname or DNS SRV reachability (`_ldap._tcp.dc._msdcs.<domain>`) so you can target a real DC.

## Technique
Identify the domain, then query selectively. Filtering reduces noise and limits paged-result alerts.

```bash
# RootDSE — no creds needed, returns naming contexts + supported controls
ldapsearch -x -h 10.0.0.1 -s base -b '' '(objectClass=*)' '*' '+'

# Authenticated dump
ldapsearch -h dc.corp.lab -D 'me@corp.lab' -w 'pw' -b 'DC=corp,DC=lab' \
  '(objectClass=user)' samaccountname memberof description useraccountcontrol
```

Specialised tools:

- **ldapdomaindump** — one-shot HTML/JSON dump of users, groups, computers, policy. `ldapdomaindump -u corp\\me -p 'pw' 10.0.0.1`.
- **windapsearch** — pre-baked queries (`--privileged-users`, `--unconstrained`, `--gpos`, `--spns`).
- **adidnsdump** — read the AD-integrated DNS zone via LDAP.
- **bloodhound-ce-python** — feeds [[bloodhound|BloodHound]].
- **nxc / netexec** `ldap` module — quick recon (`--users`, `--groups`, `--asreproast`, `--kerberoast`).

Useful filters worth memorising:

```
# Users with SPN
(&(samAccountType=805306368)(servicePrincipalName=*))
# AS-REP roastable
(&(samAccountType=805306368)(userAccountControl:1.2.840.113556.1.4.803:=4194304))
# Unconstrained delegation
(userAccountControl:1.2.840.113556.1.4.803:=524288)
# Disabled accounts
(userAccountControl:1.2.840.113556.1.4.803:=2)
# Computers with LAPS
(ms-Mcs-AdmPwd=*)
```

The bitwise OID `1.2.840.113556.1.4.803` is "and" against `userAccountControl`; `…804` is "or".

Don't forget the Configuration NC (`CN=Configuration,DC=corp,DC=lab`) — it holds sites, services, the `Public Key Services` container with AD CS templates and CAs, and the `Partitions` container listing trusts.

## Detection and defence
- 1644 (LDAP search statistics) when enabled logs query, filter, attributes — noisy but invaluable for hunting.
- Defender for Identity alerts on broad enumeration patterns (SAMR + LDAP combos).
- Mitigations are limited because reads are by design — but: enforce LDAP signing + channel binding, deny anonymous bind (`dsHeuristics` setting), reduce default `Read All Properties` on confidential attributes (LAPS `ms-Mcs-AdmPwd`, BitLocker recovery keys).
- Add honey-objects: a fake user with a juicy SPN that nobody legitimately queries — every TGS-REQ against it is hostile.

## References
- [HackTricks — LDAP enumeration](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-ldap.html) — filters and tools
- [the.hacker.recipes — LDAP](https://www.thehacker.recipes/ad/movement/dacl/grant-rights) — enumeration in context
- [Microsoft — useraccountcontrol values](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties) — UAC bit reference
- [GitHub — ldapdomaindump](https://github.com/dirkjanm/ldapdomaindump) — automated dumper
