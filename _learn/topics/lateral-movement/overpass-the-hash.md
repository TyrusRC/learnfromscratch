---
title: Overpass the hash
slug: overpass-the-hash
---

> **TL;DR:** Feed an NT or AES Kerberos key to a local logon session, then request a TGT — converting an NTLM-only credential into a full Kerberos ticket that works against services rejecting NTLM.

## What it is
Overpass-the-hash (a.k.a. pass-the-key) bridges [[pass-the-hash]] and [[pass-the-ticket]]. Instead of replaying an NTLM hash to SMB/HTTP, you inject the user's long-term key (RC4-HMAC = the NT hash, or the AES128/AES256 Kerberos key) into LSA. The next Kerberos AS-REQ uses that key to decrypt the AS-REP, granting a real TGT. From there you authenticate to any Kerberos service — including ones with NTLM disabled.

## Preconditions / where it applies
- A captured NT hash or AES key for a domain account (from LSASS, NTDS.dit, DCSync, or DPAPI follow-ons).
- Network reachability to a domain controller for KDC traffic (TCP/UDP 88).
- Local admin or `SeTcbPrivilege` on the launching host (Mimikatz `sekurlsa::pth` writes the key into LSASS).
- Account not disabled, not requiring smart-card-only logon, and the chosen key type still accepted by the KDC.

## Technique
Mimikatz spawns a sacrificial process with the supplied key planted in its logon session:

```
sekurlsa::pth /user:alice /domain:corp.local /ntlm:<NThash> /run:powershell.exe
# or, preferred — AES256 avoids RC4 detections
sekurlsa::pth /user:alice /domain:corp.local /aes256:<key> /run:cmd.exe
```

Inside the new shell, any tool that calls `AcquireCredentialsHandle` for Kerberos (e.g. `klist`, `dir \\dc01\c$`) triggers an AS-REQ encrypted with the planted key and stores the resulting TGT in the session cache. Linux equivalent via Impacket:

```
getTGT.py -hashes :<NThash> corp.local/alice
export KRB5CCNAME=alice.ccache
psexec.py -k -no-pass corp.local/alice@target
```

Prefer AES keys when available — RC4-HMAC tickets are a high-signal hunt query (`Ticket Encryption Type 0x17` on 4768/4769).

## Detection and defence
- 4768 (AS-REQ) with `Ticket Encryption Type 0x17` for accounts whose `msDS-SupportedEncryptionTypes` is AES-only.
- 4624 logon type 9 with `LogonProcessName=seclogo` and `AuthenticationPackageName=Negotiate` — Mimikatz `pth` signature.
- LSASS read access from non-Microsoft processes (Sysmon EID 10, target `lsass.exe`, GrantedAccess `0x1010`/`0x1410`).
- Enforce AES-only, enable Credential Guard, tier admin accounts, and rotate krbtgt + privileged hashes after suspected compromise.

## References
- [Overpass-the-hash — the.hacker.recipes](https://www.thehacker.recipes/ad/movement/kerberos/pass-the-key) — protocol-level walkthrough.
- [Mimikatz sekurlsa::pth — GitHub wiki](https://github.com/gentilkiwi/mimikatz/wiki/module-~-sekurlsa) — flag reference.
- [Detecting Overpass-the-Hash — SpecterOps](https://posts.specterops.io/) — RC4-vs-AES hunting heuristics.
