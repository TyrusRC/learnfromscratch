---
title: HackTheBox machine walkthrough methodology
slug: htb-machine-walkthrough-methodology
aliases: [htb-methodology, htb-box-walkthrough, hackthebox-method]
---

> **TL;DR:** HackTheBox machines reward a methodical approach: aggressive enumeration → service-specific recon → vulnerability identification → exploitation → privilege escalation. Most failures come from giving up on enumeration too early or moving past a low-hanging service without exhausting checks. This note covers the universal pattern; specific service tactics live in [[exposed-services]], [[smb-enum]], [[http-enum]] etc. Companion to [[oscp-style-box-attack-pattern]] and [[ctf-jeopardy-pwn-strategy]].

## Why HTB matters

- **Pen-test simulation** — closer to real OSCP-style boxes than CTFs.
- **Active boxes** — current; free tier limited.
- **Retired boxes** — archive of writeups available; learn from solutions.
- **Pro Labs** — multi-machine AD networks (Dante, Offshore, RastaLabs); closer to real engagement.

## The universal pattern

```
┌─────────────────────────────────────────────────────────┐
│  1. Port scan (TCP + UDP, full-range, top-then-deep)    │
│  2. Service enumeration per port                         │
│  3. Web-app deep-dive if HTTP                            │
│  4. Pick attack vector → exploit foothold                │
│  5. Initial enumeration as user (`whoami`, sudo, etc.)   │
│  6. Privilege escalation                                 │
│  7. Persistence (skip for HTB; relevant for engagements) │
└─────────────────────────────────────────────────────────┘
```

Each step is exhaustive before the next.

## Step 1 — Port scan

```sh
sudo nmap -sV -sC -p- 10.10.10.X -oA initial    # full TCP
sudo nmap -sU --top-ports 50 10.10.10.X -oA udp # UDP top 50
```

`-p-` is non-negotiable. Most failures come from missing a non-default-port service.

For Windows boxes always check:
- 53 (DNS).
- 88 (Kerberos).
- 135 / 139 / 445 (SMB).
- 3268 / 3269 (LDAP GC).
- 5985 / 5986 (WinRM).
- 1433 (MSSQL).

For Linux:
- 22 (SSH).
- 80 / 443 / 8080 / 8443 (HTTP).
- 21 (FTP).
- 25 (SMTP).
- 3306 (MySQL).
- 5432 (PostgreSQL).
- 6379 (Redis).
- 27017 (MongoDB).

## Step 2 — Service enumeration

For each open port, run the specific enum recipe:

- HTTP → directory bust + tech fingerprint + JS analysis ([[http-enum]], [[content-discovery]]).
- SMB → null sessions + share enum + smb-vuln-* scripts ([[smb-enum]]).
- LDAP → anonymous bind, then enum ([[ldap-enum]]).
- DNS → axfr, subdomain brute-force ([[dns-enum]]).
- Etc.

**Don't move past a service** without:
- Banner-grabbed version.
- CVE search for that version.
- Default-credential test.
- Service-specific enum scripts.

## Step 3 — Web app deep-dive

The dominant initial-access vector. Process:

1. **Open in browser** — read content.
2. **Source view** — look for hidden links, comments, JS.
3. **Tech fingerprint** — Wappalyzer; identify framework, language, version.
4. **Robots.txt, sitemap.xml**, `/.well-known/`.
5. **Subdomain brute-force** if hostname pattern present.
6. **Path brute-force** with `ffuf` / `gobuster` (use `seclists` wordlists).
7. **Parameter brute-force** with `arjun` / `ffuf` (uncommon params on found endpoints).
8. **VHost enumeration** if hosts header matters ([[vhost-enumeration]]).
9. **Spider** with Burp.
10. **Cookies / headers** analysis.
11. **Authentication flow** examination.
12. **API discovery** — `/api`, `/graphql`, OpenAPI.

Run each step before assuming "no vuln here".

## Step 4 — Pick attack vector

Based on enumeration, pick the highest-likelihood vector:

- Known CVE for software version (use `searchsploit`, NVD).
- Auth bypass / SQLi on login.
- File-upload vuln.
- SSRF reaching internal port.
- Misconfig (anonymous SMB, weak FTP creds, etc.).

Standard web bug classes: see [[testing-methodology-checklists]].

## Step 5 — Initial enumeration as foothold user

Got a shell. Stabilise:
- Linux: `python -c 'import pty; pty.spawn("/bin/bash")'`, then `Ctrl+Z`, `stty raw -echo`, `fg`.
- Windows: upgrade to fully-interactive via `nc.exe` + ConPTY tricks.

Then enumerate:

Linux:
- `whoami`, `id`, `sudo -l`, `groups`.
- `uname -a`, `cat /etc/os-release`.
- `ps -ef`, `netstat -tlnp`.
- SUID binaries: `find / -perm -4000 2>/dev/null`.
- Cron jobs, scheduled tasks.
- World-writable, group-writable.
- Run `linpeas`.

Windows:
- `whoami /all`, `net user`, `net localgroup`.
- `systeminfo`.
- `tasklist /v`, `netstat -ano`.
- `Get-LocalUser`, `Get-LocalGroup`.
- `cmdkey /list`.
- Run `winpeas`.

See [[linpeas-and-enumeration-flow]], [[winpeas-enumeration-flow]].

## Step 6 — Privilege escalation

Pick highest-likelihood vector based on enumeration:

Linux:
- `sudo -l` allowing `NOPASSWD` for known-exploitable binary.
- SUID binaries — GTFOBins.
- Capabilities — `getcap -r / 2>/dev/null`.
- Kernel exploit if version old.
- Service-binary world-writable.
- PATH hijacking.

See [[linux-privesc-vectors]].

Windows:
- Token impersonation if `SeImpersonatePrivilege` ([[token-impersonation]], [[sedebug-privilege-abuse]]).
- Unquoted service paths.
- Always-Install-Elevated.
- DLL hijacking.
- Service binary writable.
- Kernel exploit if old.

See [[windows-privesc-checklist]].

## Common mistakes

- **Stopping enumeration too early** — missed service on uncommon port.
- **Picking too hard a vector first** — try low-hanging before complex.
- **Not stabilising shell** — many tools break in unstable shell.
- **Skipping `linpeas` / `winpeas`** — they find more than manual most of the time.
- **Treating web differently** — HTTP is just another service requiring enum.
- **Web spidering manually** — use Burp.

## Pacing

For active boxes:
- **Easy**: 1–3 hours target.
- **Medium**: 3–8 hours.
- **Hard / Insane**: 8–40 hours.

If stuck >2 hours on enumeration without finding entry point — backtrack to step 1; you missed something.

## When to look at writeups

For active boxes — only after solving (writeups are for retired only).
For retired — read after attempting. Don't read writeup before trying.

Patterns:
- Look at multiple writeups for one box; compare approach.
- Note the **enumeration step that revealed the entry point**.
- Add that pattern to your personal methodology.

## Building a personal methodology

After 20-30 HTB boxes, you'll have your own checklist. Build it as:
- Per-port enumeration template.
- Per-service quick-checks.
- Common exploitation patterns.
- Privesc flow per OS.

This is what carries to OSCP and pen-test work.

## Tools

Standard kit:
- nmap, masscan.
- gobuster / ffuf / dirsearch.
- enum4linux-ng, smbclient.
- ldapsearch, kerbrute.
- impacket suite.
- linpeas, winpeas, pspy, BloodHound (for AD).
- Burp Suite (Community / Pro).
- searchsploit, msfconsole.
- chisel, ligolo-ng for pivoting.

## Workflow to study

1. Solve 5 easy retired boxes; read writeups after.
2. Solve 5 mediums.
3. Map your wins and failures — what enum step revealed the entry?
4. Build a personal methodology file.
5. Solve 5 hards.
6. Move to active boxes.
7. Try a Pro Lab (Dante, Offshore).

## Related

- [[oscp-style-box-attack-pattern]]
- [[pwn-college-walkthrough-methodology]]
- [[vulnhub-walkthrough-pattern]]
- [[ctf-jeopardy-pwn-strategy]]
- [[testing-methodology-checklists]]
- [[linpeas-and-enumeration-flow]]
- [[winpeas-enumeration-flow]]
- [[oscp-exam-methodology]]
- [[building-a-research-home-lab]]

## References
- [HackTheBox Academy](https://academy.hackthebox.com/)
- [IppSec — HTB walkthrough videos](https://www.youtube.com/@ippsec)
- [0xdf — HTB writeups](https://0xdf.gitlab.io/)
- [HackTricks](https://book.hacktricks.xyz/)
- [GTFOBins](https://gtfobins.github.io/)
- See also: [[oscp-exam-methodology]], [[oscp-style-box-attack-pattern]], [[building-a-research-home-lab]], [[testing-methodology-checklists]]
