---
title: SMB enumeration
slug: smb-enum
---

> **TL;DR:** Identify dialect, signing status, accessible shares, and RPC pipes. Signing-disabled hosts feed [[ntlm-relay]]; anonymous IPC$ leaks users/groups; readable shares often contain credentials.

## What it is
SMB enumeration is the broad-surface review of 445/tcp (and legacy 139/tcp for NetBIOS session service). Four primitives matter: (1) dialect — SMBv1 is a vuln smell and an EternalBlue indicator, (2) signing — disabled signing makes the host a relay target, (3) share ACLs — anonymous or `Authenticated Users` reads on file servers regularly expose credentials, and (4) RPC over `\PIPE\srvsvc`, `\PIPE\lsarpc`, `\PIPE\samr` — used for user/group enumeration even from low-priv contexts.

## Preconditions / where it applies
- Reach to 445/tcp on Windows hosts or Samba servers.
- Either no credential (anonymous/null session — increasingly rare on modern Windows) or any domain credential for authenticated enumeration.
- Related: [[ldap-enum]], [[kerberos-enum]], [[password-spraying]], [[ntlm-relay]].

## Technique
Quick dialect/signing/OS fingerprint across a subnet:

```bash
nxc smb 10.0.0.0/24
# IP            HOSTNAME   SMB-Version  SigningRequired  OS
# 10.0.0.10     DC01       3.1.1        True             Windows Server 2022
# 10.0.0.25     SQL01      3.1.1        False            Windows Server 2019  <- relay target
```

Authenticated share inventory + readable-content sweep:

```bash
nxc smb 10.0.0.0/24 -u alice -p 'Spring2026' --shares
nxc smb 10.0.0.0/24 -u alice -p 'Spring2026' -M spider_plus -o EXTENSIONS=ini,xml,config,kdbx
```

RPC primitives — list users/groups even without LDAP reach (works against modern AD with any creds):

```bash
rpcclient -U 'CORP\alice%Spring2026' 10.0.0.10
rpcclient $> enumdomusers
rpcclient $> querydispinfo
rpcclient $> lookupnames Administrator
```

Or `enum4linux-ng` for an all-in-one dump (RID brute, shares, password policy, sessions). Coerce-trigger authentications (PetitPotam, PrinterBug, DFSCoerce) live in [[ntlm-relay]] — verify the prerequisite signing-disabled state from this enumeration first.

Anonymous null session probe (`-N`) — still worth trying against Samba and legacy Windows:

```bash
smbclient -L //10.0.0.50 -N
smbclient //10.0.0.50/shared -N
```

## Detection and defence
- 5145 (detailed file share access) is verbose; SACLs on sensitive shares plus 4663 give targeted hits.
- Burst of 4625 `Logon Type 3` from one source — spraying signature.
- Enforce SMB signing on all hosts (`RequireSecuritySignature = 1`); disable SMBv1 (`Set-SmbServerConfiguration -EnableSMB1Protocol $false`).
- Remove `Authenticated Users` from share/NTFS ACLs on file servers; audit `SYSVOL` for legacy `groups.xml` with GPP passwords.
- Network-segment 445/tcp east-west; only DCs and file servers should be reachable on it from user VLANs.

## References
- [HackTricks — pentesting SMB](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smb/index.html) — primitives and tool cookbook.
- [NetExec wiki](https://github.com/Pennyw0rth/NetExec/wiki) — modules, spider, and spray syntax.
- [The Hacker Recipes — SMB enumeration](https://www.thehacker.recipes/ad/recon/smb) — null-session and RPC pipe survey.
- [Microsoft — overview of SMB signing](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing-overview) — required vs negotiated semantics.
