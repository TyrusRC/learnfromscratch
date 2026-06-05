---
title: OSCP-style box attack pattern
slug: oscp-style-box-attack-pattern
aliases: [oscp-box-method, oscp-attack-pattern]
---

> **TL;DR:** The OSCP exam has 100-point format spread across one Active Directory set (40 points) and three standalone machines (20 points each). The OSCP-style attack pattern emphasises **methodical enumeration**, **single low-tier vector per box** (rare chained-exploit boxes), and **time discipline**. Companion to [[oscp-exam-methodology]] and [[htb-machine-walkthrough-methodology]].

## Why OSCP-style differs from HTB

- OSCP exam boxes are **less creative** than HTB.
- **Standard CVE / misconfig** vectors dominate.
- **Time-pressured**: 23h45m for 100 points + 1 retake exam window.
- **Reporting** required: 70 points + lab + report ≈ pass.

The methodology rewards **mechanical, methodical execution** rather than ingenuity.

## The 100-point structure

- **AD set (40 pts)**: 3 connected machines you compromise sequentially.
- **Standalone 1 (20 pts)**: independent.
- **Standalone 2 (20 pts)**: independent.
- **Standalone 3 (20 pts)**: independent.

Partial credit: 10 points for a foothold (user shell) on a standalone; full 20 for root. AD set: 10 / 20 / 40 milestones.

## Time discipline

Recommended pacing:

- **Hour 0-1**: enumerate everything.
- **Hour 1-7**: AD set — typically the longest chain.
- **Hour 7-12**: standalone 1.
- **Hour 12-17**: standalone 2.
- **Hour 17-22**: standalone 3.
- **Hour 22-24**: buffer + screenshots + restart-checks.

Adjust per personal pace. Most candidates take more time on AD.

## Universal pattern per box

Same as [[htb-machine-walkthrough-methodology]]:

1. nmap full TCP + top 50 UDP.
2. Enumerate every service.
3. Web deep-dive if HTTP.
4. Identify vector.
5. Foothold.
6. Privesc.
7. Screenshot proof.

## OSCP-typical vectors

### Standalone Linux

- Vulnerable web app (LFI, RCE in framework, file upload).
- Known CVE in service (Tomcat, Drupal, WordPress plugin, Joomla).
- Default credentials.
- Anonymous FTP with sensitive file.

Privesc:
- `sudo -l` allowing exploitable binary (GTFOBins).
- SUID binary with abuse path.
- Kernel exploit if old (uncommon on OSCP).
- Writable scripts called by cron.
- Service binary writable.

### Standalone Windows

- Default credentials on RDP / SMB.
- Known CVE in web app.
- Public exploit (msfvenom or copy-paste).

Privesc:
- `SeImpersonatePrivilege` → PrintSpoofer / GodPotato.
- Unquoted service path.
- Always-Install-Elevated.
- Service binary writable.

### AD set

- One box external-facing — initial foothold via standard vector.
- Use foothold to enumerate AD.
- BloodHound / shadow credentials / kerberoasting.
- Lateral movement: pass-the-hash, RDP, WinRM with stolen creds.
- Privesc to Domain Admin via standard AD attack (DCSync, golden ticket, ACL abuse).

See [[active-directory]], [[osep-roadmap]] for deeper AD content.

## What to skip

- **Don't go down rabbit holes** on rare CVEs. If a CVE isn't widely known, it's probably not the path.
- **Don't write custom exploits** unless time abundant. Use Metasploit / public PoCs.
- **Don't waste time on obscure ports** if standard ports have obvious vectors.

## Metasploit usage rules

- OSCP allows **one Metasploit module per exam** (in addition to msfvenom and meterpreter sessions inherited from that one module). Use it strategically.
- Most boxes solvable without Metasploit; using it = quicker but you "spent" your one allowance.
- Typical use: complex Windows AD foothold (e.g., EternalBlue if applicable).

## Lab methodology

OffSec PG Practice + OSCP lab content (PEN-200):

- Ramp from easy boxes.
- Exhaustive enumeration each.
- Write your own writeups (skill builder + report-writing practice).
- Aim for ~100 lab boxes before exam.

## Personal tools / scripts

Prepare:
- One-line port-scan command.
- Universal enum scripts (linpeas, winpeas) hosted on accessible HTTP.
- Reverse shell one-liners cheatsheet (bash, python, php, powershell).
- Privesc-check cheatsheets.
- Note-taking system (Obsidian, CherryTree, OneNote, Markdown).

## Reporting

70-point pass requires a report:
- Executive summary.
- Per-box findings: enumeration, exploitation, post-exploitation, remediation.
- Screenshots of proof files (`proof.txt` on user / root).

Report template provided by OffSec; populate.

Bad report = no pass even with technical success.

## Common mistakes

- **Spending too long on one box** without acknowledging defeat.
- **Skipping rest** during the 24-hour window. Plan a 4-hour sleep.
- **Forgetting to screenshot** as you go.
- **Lab boxes only easy** — try difficult ones for stretch.
- **Not practicing report writing**.

## Post-OSCP

Natural progression:
- **OSEP** ([[osep-roadmap]]) — evasion / AD deeper.
- **OSWE** ([[oswe-roadmap]]) — web-source-review.
- **Bug bounty** ([[ctf-to-bug-bounty-transition]]).
- **Real pen-test work** ([[pentest-engagement-execution]]).

## Workflow to study

1. Read PEN-200 textbook cover to cover.
2. Do all 25+ exercise boxes in lab.
3. Aim for 100 PG Practice boxes.
4. Take the exam.

## Related

- [[oscp-roadmap]]
- [[oscp-exam-methodology]]
- [[oscp-osep-oswe-track-comparison]]
- [[oscp-vs-osep-mindset]]
- [[htb-machine-walkthrough-methodology]]
- [[pwn-college-walkthrough-methodology]]
- [[vulnhub-walkthrough-pattern]]
- [[ctf-jeopardy-pwn-strategy]]
- [[osep-roadmap]]
- [[active-directory]]
- [[linpeas-and-enumeration-flow]]
- [[winpeas-enumeration-flow]]

## References
- [Offensive Security PEN-200 / OSCP](https://www.offsec.com/courses/pen-200/)
- [TJnull's recommended HTB / VulnHub boxes for OSCP prep](https://www.netsecfocus.com/oscp/2021/05/06/The_Journey_to_Try_Harder-_TJNulls_Preparation_Guide_for_PEN-200_PWK_OSCP_2.0.html)
- [IppSec — OSCP-style walkthroughs](https://www.youtube.com/@ippsec)
- [Heath Adams (TCM) — PEH course](https://academy.tcm-sec.com/)
- See also: [[oscp-roadmap]], [[oscp-exam-methodology]], [[htb-machine-walkthrough-methodology]], [[osep-roadmap]]
