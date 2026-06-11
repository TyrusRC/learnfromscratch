---
title: OSWA roadmap (WEB-200)
slug: oswa-roadmap
aliases: [oswa-prep-roadmap, web-200-roadmap]
---
{% raw %}

> OSWA (WEB-200) is OffSec's entry-tier black-box web assessor cert: a 24-hour practical exam plus 24 hours for the report, hunting five flags across multiple live web apps with no source code. Plan ten focused weeks; ideal candidate has OSCP-level shell comfort, reads HTTP requests fluently, and wants to leave script-kiddie payload-spraying behind for methodical, Burp-driven web testing.

## Who this is for

- You can already pop a Linux box, but web targets in OSCP felt like guesswork.
- You read raw HTTP requests without squinting and know what a 302 with a Set-Cookie means.
- You have ~10 weeks at 10-15 hrs/week, or 6 weeks at 25 hrs/week.
- You want a black-box web cert before tackling [[oswe-roadmap|OSWE]] (whitebox, source-driven).
- You are comfortable with Python or Bash for one-off request tampering scripts.

## What OSWA tests

- Format: 24-hour hands-on exam, then 24 hours to write and submit the report.
- Environment: multiple independent web application targets in a VPN lab; no source code.
- Five flags total (typically `local.txt` / `proof.txt` style across apps); points distributed across targets.
- Passing score: 70/100, but only with a coherent report — exploitation alone is not enough.
- Coverage: OWASP-style bugs — XSS, SQLi, command injection, LFI/RFI, SSRF, XXE, IDOR, file upload, auth bypass, JWT tampering, SSTI.
- Black-box only: you will pivot through the app via the UI and proxied traffic, not by `grep`-ing source.
- Deliverable: PDF report with reproducible steps, payloads, screenshots, and remediation.
- Tooling is unrestricted within OffSec's rules (no commercial scanners that auto-exploit, no Metasploit auto-modules for web).

## Lab setup (do before week 1)

- Kali Linux 2025.x VM, 4 vCPU / 6 GB RAM minimum, snapshot before each lab session.
- Burp Suite Community 2024.x — Pro is nice but not required; learn Repeater + Intruder + Comparer cold.
- Firefox with FoxyProxy Standard, plus a dedicated Burp-trusted CA in the browser profile.
- Python 3.11+ with `requests`, `pyjwt`, `beautifulsoup4`, `urllib3` installed in a venv.
- ffuf, gobuster, wfuzz, sqlmap, jwt_tool, commix, dirsearch on `$PATH`.
- A local DVWA + Juice Shop + WebGoat stack via Docker Compose for warm-up:

```bash
git clone https://github.com/digininja/DVWA && cd DVWA
docker compose up -d
docker run -d -p 3000:3000 bkimminich/juice-shop
```

- PortSwigger Web Security Academy account (free) — single highest-leverage external resource.
- Obsidian or Joplin vault for payload notes; do NOT memorise payloads, index them.

## The 10 weeks

### Week 1 — HTTP, Burp, and methodology

- Read: [[http-and-web-primer]], [[burp-suite]], [[report-writing-for-pentesters]], [[oscp-roadmap]]
- Labs: PortSwigger Academy "Getting started" track; proxy DVWA through Burp and tag every request.
- Deliverable: a personal Burp project file with a custom scope, match/replace rules, and a saved Intruder payload set.

### Week 2 — Reflected, stored, and DOM XSS

- Read: [[cross-site-scripting]], [[burp-suite]], [[broken-access-control]]
- Labs: PortSwigger XSS labs (all apprentice + practitioner); Juice Shop XSS challenges 1-3.
- Deliverable: a 1-page XSS triage cheatsheet — context detection, sink, payload, bypass for CSP nonce.

### Week 3 — SQL injection

- Read: [[sql-injection]], [[http-and-web-primer]]
- Labs: PortSwigger SQLi labs apprentice through practitioner; manual UNION-based extraction on DVWA Medium without sqlmap.
- Deliverable: a manual-vs-sqlmap comparison note showing the same extraction by hand and with `sqlmap --batch --risk=3 --level=5`.

### Week 4 — Command injection, LFI, RFI

- Read: [[command-injection]], [[lfi-rfi]]
- Labs: PortSwigger OS command injection labs; HackTheBox "Included" and "Bastard"-style retired web boxes.
- Deliverable: a payload table for blind command injection (time-based, OOB DNS via Burp Collaborator or interactsh).

### Week 5 — SSRF, XXE, and out-of-band

- Read: [[ssrf]], [[xxe]]
- Labs: PortSwigger SSRF + XXE labs; deploy a public interactsh server or use Burp Collaborator for OOB.
- Deliverable: a working OOB exfil PoC against a lab XXE target, capturing a flag via DNS.

### Week 6 — Authentication, authorisation, IDOR

- Read: [[idor]], [[broken-access-control]], [[jwt-attacks]]
- Labs: PortSwigger access control and authentication labs; tamper IDs in Juice Shop's basket and order endpoints.
- Deliverable: an authorisation matrix template — role × endpoint × expected vs observed.

### Week 7 — JWT, sessions, and crypto-adjacent bugs

- Read: [[jwt-attacks]], [[deserialisation]]
- Labs: PortSwigger JWT labs (alg=none, weak HMAC, kid path traversal); use `jwt_tool` and `hashcat` for HS256 cracking.
- Deliverable: a JWT attack flowchart — header inspection to forged token, with exact `jwt_tool` invocations.

### Week 8 — SSTI, file upload, and RCE chains

- Read: [[ssti]], [[file-upload]], [[command-injection]]
- Labs: PortSwigger SSTI labs (Jinja2, Twig, Freemarker); upload-based RCE on a Tomcat lab (`.war`) and on a PHP app with extension filter bypass.
- Deliverable: an upload-bypass matrix — content-type, magic bytes, double extension, null byte, parser confusion.

### Week 9 — OffSec OSWA labs and full chains

- Read: [[report-writing-for-pentesters]], [[burp-suite]]
- Labs: complete all OffSec WEB-200 challenge labs end-to-end; replay one with no notes.
- Deliverable: a redacted mock report for one challenge lab in the exact OffSec template.

### Week 10 — Mock exam and report polish

- Read: re-read your own notes, not new material.
- Labs: 24-hour timed mock against 3-4 unseen Proving Grounds Practice web boxes (Snookums, Heist-style).
- Deliverable: a finalised report template with executive summary, methodology, findings (CVSS + remediation), and appendix.

## Required tooling

- Burp Suite Community 2024.x (Repeater, Intruder, Comparer, Collaborator-client or interactsh).
- ffuf, gobuster, dirsearch for content discovery.
- sqlmap, commix for assisted exploitation — know the manual equivalent.
- jwt_tool, hashcat, john for token attacks.
- Python 3 with `requests` and `pyjwt` for custom PoCs.
- HackTricks (web section) and PayloadsAllTheThings as live references.

## Practice corpus

- PortSwigger Web Security Academy — closest to the exam style, free.
- OffSec Proving Grounds Practice — filter for web-heavy boxes.
- HackTheBox retired web boxes and the "Starting Point" web track.
- OWASP Juice Shop, DVWA, WebGoat, bWAPP for local repetition.
- TryHackMe "OWASP Top 10" and "Web Fundamentals" paths for quick gaps.
- PentesterLab Pro — short, surgical exercises per bug class.

## Pragmatic notes from people who sat the exam

- PortSwigger Academy beats the OffSec courseware for payload depth; use both, but live in Academy.
- Burp Community is enough. If you cannot pass with Community, Pro will not save you — learn Repeater and Intruder cold.
- Pre-write your report template before exam day. Drop screenshots and payloads into placeholders as you go, not at hour 23.
- HackTricks is a better quick reference than memorising payload lists. Bookmark the web section by bug class.
- Read every cookie, every header, every redirect. The exam rewards observation over fuzzing volume.
- Sleep at hour 12. Tired pattern-matching misses the obvious IDOR.

## Failure modes to avoid

- Fuzzing for hours without proxying through Burp — you will lose the request that worked.
- Treating sqlmap as a black box. If it fails, you need to know which technique to force with `--technique=BEUSTQ`.
- Skipping the report. Five flags with a bad report still fails; three flags with a clean report can still pass.
- Burning the first 6 hours on one target. Rotate every 2 hours until you have a foothold on each.
- Ignoring out-of-band channels. SSRF and blind XXE often need Collaborator or interactsh.

## After OSWA

- Move to [[oswe-roadmap|OSWE (WEB-300)]] for whitebox, source-driven full-chain exploitation.
- Practise bug bounty on a narrow scope (one program, one bug class) to convert lab skill into wild-target skill.
- Consider BSCP if you want a second, cheaper web cert with a different testing style.

## References

- https://www.offsec.com/courses/web-200/
- https://portswigger.net/web-security
- https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html
- https://owasp.org/www-project-web-security-testing-guide/
- https://github.com/swisskyrepo/PayloadsAllTheThings
- https://portswigger.net/burp/documentation/desktop

See also: [[oscp-roadmap]], [[oswe-roadmap]], [[burp-suite]], [[http-and-web-primer]], [[cross-site-scripting]], [[sql-injection]], [[jwt-attacks]], [[report-writing-for-pentesters]]

{% endraw %}
