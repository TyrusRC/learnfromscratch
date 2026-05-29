---
title: Active Directory
slug: active-directory
aliases: [ad-attacks, windows-domain]
---

> AD is the gravity well of every internal engagement. Understand the
> directory, the auth protocols, and the trust model — then everything
> else is pattern matching.

## Prereqs

- [[network-pentesting]] stages 1–2.
- A lab: [GOAD](https://github.com/Orange-Cyberdefense/GOAD), build your
  own forest with at least one child domain, or an HTB Pro Lab.

## Stage 1 — fundamentals

- AD object model — users, groups, OUs, computers, GPOs, ACEs.
- Auth protocols: [[ntlm]], [[kerberos]].
- DNS, LDAP, and SMB in an AD context.
- Enumeration:
  [[bloodhound]] · [[sharphound]] ·
  [[ldap-enumeration]] · [[adidnsdump]].

## Stage 2 — intermediate

Kerberos abuse:
- [[asreproast]] · [[kerberoasting]].
- [[unconstrained-delegation]] · [[constrained-delegation]] ·
  [[resource-based-constrained-delegation]] (RBCD).

ACL & object abuse:
- [[acl-abuse]] (GenericAll, WriteDACL, WriteOwner, ForceChangePassword,
  GenericWrite, AddMembers, AllExtendedRights).
- [[gpo-abuse]] · [[shadow-credentials]].

Credential primitives:
- [[dcsync]] · [[dpapi-secrets]] ·
  [[lsa-secrets]] · [[silver-tickets]] · [[golden-tickets]].

## Stage 3 — advanced

- [[adcs-attacks]] — ESC1 through ESC16, CA compromise.
- [[child-to-forest-root]] — SID history, krbtgt, trust keys.
- [[cross-forest-trust-abuse]].
- [[ms-rpc-abuse]] — PetitPotam, PrinterBug, DFSCoerce.
- [[ad-persistence]] — AdminSDHolder, DCShadow, Skeleton Key.
- [[mssql-trusted-links]] in AD.
- Detection-aware operations: see [[red-team-operations]].

## When you're "done"

- You can describe every step in the path from a domain user to
  Enterprise Admin, including which detection rules each step trips and
  what the safer alternative is.
- You can read a BloodHound graph in seconds and pick the lowest-noise
  edge.

## References

- ired.team AD section: <https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse>.
- The Hacker Recipes: <https://www.thehacker.recipes/>.
- HackTricks AD pages:
  <https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/index.html>.
