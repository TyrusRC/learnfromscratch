---
title: OSCP roadmap (PEN-200)
slug: oscp-roadmap
aliases: [oscp-prep-roadmap, pen-200-roadmap]
---

{% raw %}

> **TL;DR:** A zero-to-OSCP study path that uses only this repo plus official OffSec material and free practice platforms. Twelve-week plan, ordered so each week builds on the last. Pair with [[oscp-exam-methodology]] and [[oscp-full-chain-walkthrough]].

## Who this is for
You have:
- Basic computer literacy and curiosity.
- No prior pentest or programming background required, but it helps.
- 15-20 hours a week to study.

You want:
- To pass OSCP within 12 weeks of focused study.

## How to use the path
- Each week lists *notes to read*, *labs to run*, and a *deliverable* (a small artefact that proves you can do the thing).
- Stop at the end of each week and rebuild your tooling VM with what you learned.
- After week 12, sit a mock exam under exam rules. If you pass it, book the real one.

## The 12 weeks

### Week 1 — terminal and HTTP
- Read: [[kali-linux-primer]], [[bash-and-shell-primer]], [[http-and-web-primer]].
- Labs: install Kali, complete TryHackMe "Linux Fundamentals 1–3" and "Networking Fundamentals".
- Deliverable: a 1-page bash one-liner cheat sheet you wrote (not copied).

### Week 2 — recon and service enumeration
- Read: [[osint-recon]], [[host-discovery]], [[port-scanning]].
- Read service enum: [[ftp-enum]], [[ssh-enum]], [[smtp-enum]], [[dns-enum]], [[http-enum]], [[smb-enum]], [[snmp-enum]], [[msrpc-enum]], [[ldap-enum]], [[kerberos-enum]], [[mssql-enum]], [[mysql-enum]], [[redis-enum]], [[rdp-enum]], [[winrm-enum]].
- Browse the rest of `_learn/topics/network/` index so you know where to look later.
- Labs: nmap against a HackTheBox starting-point machine; ffuf/gobuster against a deliberately vulnerable WordPress instance; manually grab banners from FTP/SSH/SMTP/SNMP on at least three different boxes (no helper tools).
- Deliverable: nmap + content-discovery template script you'll reuse on every host, plus a one-page "given an open port, what do I check first" matrix.

### Week 3 — web attacks (first half)
- Read: [[cross-site-scripting]], [[sql-injection]], [[command-injection]], [[lfi-rfi]], [[file-upload]], [[idor]].
- Labs: PortSwigger Web Security Academy — all "apprentice" and the first half of "practitioner" labs in each category.
- Deliverable: a web-vuln cheat sheet by class with payloads.

### Week 4 — web attacks (second half)
- Read: [[ssrf]], [[xxe]], [[ssti]], [[csrf]], [[broken-access-control]], [[deserialisation]].
- Labs: complete the rest of PortSwigger practitioner labs you care about.
- Deliverable: a one-page "given a web app, here's my methodology" doc.

### Week 5 — Linux privilege escalation
- Read: [[linpeas-and-enumeration-flow]], [[linux-privesc-vectors]], [[sudo-misconfig]], [[suid-sgid-binaries]], [[capabilities-privesc]], [[cron-jobs]], [[path-hijacking]], [[nfs-no-root-squash]], [[kernel-exploits-linux]].
- Labs: TryHackMe "Linux PrivEsc" + 5 retired easy/medium Linux boxes on HTB.
- Deliverable: a Linux privesc enumeration script and a checklist.

### Week 6 — Windows privilege escalation
- Read: [[windows-privesc-checklist]], [[winpeas-enumeration-flow]], [[weak-service-permissions]], [[unquoted-service-paths]], [[dll-hijacking-privesc]], [[always-install-elevated]], [[token-impersonation]], [[user-account-control]].
- Labs: TryHackMe "Windows PrivEsc" + 5 retired Windows boxes (focus on SeImpersonate Potato chains).
- Deliverable: a Windows privesc enumeration script and a checklist.

### Week 7 — public exploits + buffer overflow
- Read: [[searchsploit-and-public-exploit-workflow]], [[porting-public-exploits]], [[c-and-asm-primer]], [[stack-buffer-overflow]], [[stack-bof-walkthrough-end-to-end]], [[bad-character-handling]], [[mona-py]].
- Labs: complete TryHackMe "Buffer Overflow Prep" room three times under different vulnserver commands.
- Deliverable: a 32-bit Windows BOF template (Python) plus your own working exploit against vulnserver/TRUN and vulnserver/GMON (SEH).

### Week 8 — Metasploit + client-side
- Read: [[metasploit-fundamentals]], [[client-side-attacks-primer]].
- Labs: complete two HTB boxes using msfvenom + multi/handler only (no auto-exploit).
- Deliverable: msfvenom and handler-setup script templates you'll reuse.

### Week 9 — tunneling, pivoting, password attacks
- Read: [[ssh-tunneling]], [[port-forwarding]], [[chisel]], [[ligolo-ng]], [[password-spraying]], [[password-cracking-toolkit]].
- Labs: a HTB lab that requires pivoting through a jump host (most "labs" boxes do).
- Deliverable: a pivot template (chisel server + client config), a password-spray script.

### Week 10 — Active Directory (foundations)
- Read: [[ldap-enumeration]], [[bloodhound]], [[sharphound]], [[kerberos]], [[kerberoasting]], [[asreproast]], [[ntlm]].
- Labs: TryHackMe "Attacktive Directory" + HTB Active + HTB Forest.
- Deliverable: a clean BloodHound output of a small lab AD with annotated attack paths.

### Week 11 — Active Directory (movement)
- Read: [[pass-the-hash]], [[pass-the-ticket]], [[overpass-the-hash]], [[dcsync]], [[golden-tickets]], [[silver-tickets]], [[acl-abuse]], [[gpo-abuse]], [[unconstrained-delegation]], [[constrained-delegation]], [[resource-based-constrained-delegation]].
- Labs: OffSec PWK lab — at minimum the AD sets; alternatively, GOAD lab or Cybernetics Pro Labs.
- Deliverable: a worked path of foothold → DA across at least two distinct AD environments.

### Week 12 — methodology, mock exam, report
- Read: [[oscp-exam-methodology]], [[oscp-full-chain-walkthrough]], [[report-writing-for-pentesters]].
- Labs: full 24-hour mock against 4 TJ-Null-list boxes + a small AD set.
- Deliverable: a complete OSCP-format report on the mock results.

## Exam booking checklist
- [ ] Passed the mock with ≥ 70 points without any AI assistance.
- [ ] Reporting template prepared, finding skeleton drafted.
- [ ] All tools on Kali updated; clean snapshot saved.
- [ ] OpenVPN connection tested.
- [ ] OffSec portal ID verification done.
- [ ] Sleep schedule sane for the 48 hours before.

## Beyond OSCP
- Mobile (HTB Mobile, OSWE Web Expert path), or
- Continue with [[osep-roadmap]] and the shift in [[oscp-vs-osep-mindset]].

## Practice platforms (free or low-cost)
- TryHackMe — beginner-friendly rooms, OSCP-prep paths.
- HackTheBox — retired machines, TJ Null OSCP-like list.
- OffSec Proving Grounds Practice — paid, closest to exam feel.
- VulnHub — old but still gold for BOF practice.
- PortSwigger Web Security Academy — web only, but the best free web-vuln training in existence.

## Quick decision matrix — given an open port

This is the one-page artefact most candidates wish they had built earlier. Print it. Pin it.

| Port  | Service        | First check                                                                 | Then                                                                  |
|-------|----------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------|
| 21    | FTP            | `nc -nv $IP 21` for banner; anonymous login (`ftp $IP`, user `anonymous`)   | `[[ftp-enum]]`, look for writable dirs + web-root overlap             |
| 22    | SSH            | banner version → searchsploit                                                | `[[ssh-enum]]`, user enum (CVE-2018-15473), key reuse                 |
| 25    | SMTP           | `nc $IP 25`, `VRFY`/`EXPN` user enum                                         | `[[smtp-enum]]` for open relay, internal-only injection paths         |
| 53    | DNS            | `dig axfr @$IP $domain`                                                      | `[[dns-enum]]`, subdomain brute with gobuster dns                     |
| 80/443| HTTP(S)        | `whatweb $IP`, `nikto -h $IP`, `ffuf -u http://$IP/FUZZ`                     | `[[http-enum]]`, framework-specific (WordPress wpscan, Drupal droopescan) |
| 111   | rpcbind        | `rpcinfo -p $IP`                                                             | look for NFS (port 2049), `showmount -e $IP`                          |
| 135   | MSRPC          | `rpcclient -U "" $IP`                                                        | `[[msrpc-enum]]`, null sessions, anonymous SAMR enum                  |
| 139/445| SMB           | `smbclient -L //$IP -N`, `enum4linux-ng $IP`                                 | `[[smb-enum]]`, null shares, EternalBlue era CVEs, signing status     |
| 161   | SNMP           | `onesixtyone -c community.txt $IP`, `snmpwalk -v2c -c public $IP`            | `[[snmp-enum]]`, community brute, walk for creds in `sysDescr`        |
| 389/636| LDAP          | `ldapsearch -x -H ldap://$IP -s base namingcontexts`                         | `[[ldap-enum]]`, anonymous bind, BloodHound from null                 |
| 1433  | MSSQL          | `mssqlclient.py -p 1433 sa@$IP`                                              | `[[mssql-enum]]`, `xp_cmdshell`, link abuse                           |
| 3306  | MySQL          | `mysql -h $IP -u root -p`                                                    | `[[mysql-enum]]`, default creds, into outfile                         |
| 3389  | RDP            | `rdesktop -u guest $IP`, `crackmapexec rdp $IP -u ... -p ...`                | `[[rdp-enum]]`, BlueKeep era, sticky-keys persistence post-foothold   |
| 5985/5986| WinRM       | `evil-winrm -i $IP -u user -p pass`                                          | `[[winrm-enum]]`, paired with valid AD creds                          |
| 6379  | Redis          | `redis-cli -h $IP`                                                           | `[[redis-enum]]`, write SSH key via CONFIG SET dir                    |

If a port is not on this list, search `_learn/topics/network/` index. If still nothing, banner-grab and search-sploit.

## Useful one-liners — paste these into your template

```bash
# Full TCP scan, then service-version on found ports — two-stage pattern that survives slow targets
nmap -p- --min-rate 5000 -oA scans/full $IP
ports=$(awk -F'/' '/^[0-9]/{print $1}' scans/full.nmap | tr '\n' ',')
nmap -sV -sC -p$ports -oA scans/svc $IP

# UDP top-100 (slow — run in background while you start TCP work)
sudo nmap -sU --top-ports 100 -oA scans/udp $IP

# Content discovery — Big lists, json output for grep later
ffuf -u http://$IP/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -of json -o ffuf.json -mc 200,204,301,302,307,403

# vhost discovery when you suspect name-based hosting
ffuf -u http://$IP/ -H "Host: FUZZ.$DOMAIN" -w subdomains-top1million-110000.txt -fs <size-of-default-vhost>

# Reverse shell catcher with auto-upgrade (paste tty trick after callback)
rlwrap nc -lvnp 4444
# in the shell once landed:
# python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl-Z; stty raw -echo; fg; export TERM=xterm-256color; stty rows $(tput lines) columns $(tput cols)
```

Keep these in `~/oscp/template.sh` and source it on every box.

## Pragmatic notes from people who sat the exam
A few patterns turn up repeatedly in candidate write-ups that are worth treating as defaults:
- **Host OS:** run your tooling inside a Kali VM on a Windows or macOS host, not Kali as the bare-metal host. Two candidates' worth of pain came from clipboard, copy-paste, and snapshot issues using Kali as the primary OS.
- **Privesc bias:** OSCP weighs privesc much more heavily than real engagements do. Real pentests usually stop at "RCE proven, here is the impact". Lean into privesc grind anyway — it is what the exam tests.
- **IppSec videos:** watching retired-box walkthroughs at 1.25–1.5x is often higher-leverage than another raw lab grind once you can already pop easy boxes. Use them to internalise privesc reasoning rather than as a step-by-step script.
- **Mental model shift after OSCP:** expect to feel uncomfortable about how little client-side and web-app testing the exam covers compared to real day-to-day work — that gap is exactly why [[oscp-vs-osep-mindset]], [[oswe-roadmap]], and a bug-bounty side practice matter.

## References
- [Official OSCP exam guide](https://help.offsec.com/hc/en-us/articles/360050293792)
- [TJ Null OSCP-like list](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/)
- [HackTricks](https://book.hacktricks.xyz/) — encyclopedic reference (use with judgement)
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
- Candidate experience reports (Vietnamese):
  - [OSCP — exam experience and link to pentest work](https://viblo.asia/p/trai-nghiem-thi-oscp-va-su-lien-quan-toi-cong-viec-penetration-testing-bJzKmqNOK9N)
  - [OSEP — advanced evasion and breaching defenses, lessons](https://viblo.asia/p/cach-osepadvanced-evasion-techniques-and-breaching-defenses-lam-kho-toi-a-little-bit-EbNVQ5jWVvR)
  - [OSWE — joy and disappointment](https://viblo.asia/p/oswe-niem-vui-va-su-that-vong-aAY4qw1wLPw)
- [DEFCON 27 offensive C# workshop (mvelazc0)](https://github.com/mvelazc0/defcon27_csharp_workshop) — useful primer for the C# tradecraft that shows up later in OSEP
- See also: [[oscp-exam-methodology]], [[oscp-full-chain-walkthrough]], [[report-writing-for-pentesters]], [[osep-roadmap]]

{% endraw %}
