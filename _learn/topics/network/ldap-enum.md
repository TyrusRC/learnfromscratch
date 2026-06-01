---
title: LDAP enumeration
slug: ldap-enum
---

> **TL;DR:** Query 389/636 to inventory users, groups, computers, ACLs and SPNs. Anonymous bind on non-AD directories gives full read; on AD you typically need any valid credential to read most attributes.

## What it is
LDAP enumeration is the structured read of a directory's schema and objects. In Active Directory, the DC exposes 389/tcp (LDAP), 636/tcp (LDAPS), 3268/tcp (Global Catalog) and 3269/tcp (GC over TLS). Anonymous bind on AD returns very little by default since Windows Server 2003, but the RootDSE is always readable and exposes `defaultNamingContext`, `dnsHostName`, `domainFunctionality`, and the configuration NC location. With one authenticated set of creds the entire directory — including descriptors that drive [[bloodhound]]-style attack paths — is readable.

## Preconditions / where it applies
- Network reach to a DC or LDAP server on 389/636/3268.
- For anonymous: a non-AD directory (OpenLDAP, 389 Directory Server) or a misconfigured AD with `dsHeuristics` allowing anonymous reads.
- For authenticated: any domain account, including a low-priv user — read access is the default for `Authenticated Users` on most attributes.

## Technique
RootDSE probe (no auth required):

```bash
ldapsearch -x -H ldap://10.0.0.10 -s base -b "" \
  defaultNamingContext rootDomainNamingContext supportedLDAPVersion
```

Authenticated full dump with ldapdomaindump (HTML + JSON inventory):

```bash
ldapdomaindump -u 'CORP\alice' -p 'Spring2026' 10.0.0.10 -o dump/
```

Or via `ldapsearch` for targeted queries — SPN-bearing accounts (Kerberoast surface):

```bash
ldapsearch -x -H ldap://10.0.0.10 -D 'alice@corp.local' -w 'Spring2026' \
  -b 'DC=corp,DC=local' \
  '(&(objectClass=user)(servicePrincipalName=*))' \
  sAMAccountName servicePrincipalName
```

AS-REP-roastable accounts (`UAC` bit `0x400000` = `DONT_REQ_PREAUTH`):

```bash
ldapsearch ... '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))' sAMAccountName
```

For ACL-driven attack paths, run `bloodhound-python` (collector) which pulls users, groups, sessions and ACEs over LDAP + SMB into a Neo4j graph for analysis. Other useful filters: `adminCount=1` (protected accounts), `description=*pass*` (legacy creds in description fields), and `ms-Mcs-AdmPwd` reads (legacy LAPS attribute) when ACLs are loose.

## Detection and defence
- 4662 (directory object accessed), 1644 (expensive LDAP query — enable `Field Engineering` log), and Azure ATP/MDI surface large-scale LDAP enumeration.
- Disable LDAP anonymous bind on all directories; on AD, enforce LDAP signing and channel binding (the controls that close the [[ntlm-relay]] path against LDAP).
- Restrict `Authenticated Users` reads on sensitive OUs and remove legacy creds from `description`/`info` attributes.
- The new LAPS (Windows LAPS) stores the password encrypted and gated by an ACL rather than a clear-text attribute.

## References
- [HackTricks — pentesting LDAP](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-ldap.html) — query cookbook and tool list.
- [ldapdomaindump](https://github.com/dirkjanm/ldapdomaindump) — JSON/HTML dump tool.
- [The Hacker Recipes — LDAP enumeration](https://www.thehacker.recipes/ad/recon/ldap) — filter syntax and AD-specific attribute notes.
- [Microsoft — userAccountControl flags](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties) — bit decoder for UAC filters.
