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

### Week 2 — recon
- Read: `_learn/topics/network/` — `osint-recon`, `host-discovery`, `port-scanning`, `dns-enum`, `http-enum`, `smb-enum`.
- Labs: nmap against a HackTheBox starting-point machine; ffuf/gobuster against a deliberately vulnerable Wordpress instance.
- Deliverable: nmap + content-discovery template script you'll reuse on every host.

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

## References
- [Official OSCP exam guide](https://help.offsec.com/hc/en-us/articles/360050293792)
- [TJ Null OSCP-like list](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/)
- [HackTricks](https://book.hacktricks.xyz/) — encyclopedic reference (use with judgement)
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
- See also: [[oscp-exam-methodology]], [[oscp-full-chain-walkthrough]], [[report-writing-for-pentesters]], [[osep-roadmap]]

{% endraw %}
