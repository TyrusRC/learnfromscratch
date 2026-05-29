---
title: References
slug: references
aliases: [refs, external-references, sources]
---

> External wikis, standards, labs, books, blogs, talks, and communities
> the topic pages link out to. Curated, not exhaustive — favourites
> kept current as of 2026.

## Wikis and methodology references

- [HackTricks](https://hacktricks.wiki/en/index.html) — broad pentest
  wiki (Carlos Polop).
- [HackTricks Cloud](https://cloud.hacktricks.wiki/en/index.html) —
  cloud and Kubernetes companion.
- [ired.team](https://www.ired.team/) — Windows and AD tradecraft
  reference (Ondrej Mihalek).
- [The Hacker Recipes](https://www.thehacker.recipes/) — methodology
  reference.
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
  — payloads and bypass tricks by class.
- [SecLists](https://github.com/danielmiessler/SecLists) — wordlists.
- [GTFOBins](https://gtfobins.github.io/) — Unix binaries that bypass
  local security.
- [LOLBAS](https://lolbas-project.github.io/) — living-off-the-land
  binaries and scripts for Windows.
- [WADComs](https://wadcoms.github.io/) — interactive AD / Windows
  command cheatsheet.

## OWASP — standards and testing guides

- [OWASP WSTG](https://owasp.org/www-project-web-security-testing-guide/)
  ([GitHub](https://github.com/OWASP/wstg)) — the Web Security Testing
  Guide; canonical structured test methodology, one technique per
  section.
- [OWASP ASVS](https://github.com/OWASP/ASVS) — Application Security
  Verification Standard; verification levels and per-control checks.
- [OWASP MASTG / MASVS](https://mas.owasp.org/) — Mobile Application
  Security Testing Guide + Standard.
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) —
  succinct defensive cheat sheets, useful for understanding what good
  code looks like.
- [OWASP API Security Top 10](https://owasp.org/API-Security/) —
  current edition.
- [OWASP LLM Top 10 / Gen AI Security](https://genai.owasp.org/) —
  LLM-specific risks.
- [OWASP Threat Modeling
  resources](https://owasp.org/www-community/Threat_Modeling).
- [OWASP WebGoat](https://owasp.org/www-project-webgoat/) — practice
  app for web bug classes.
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/) —
  intentionally vulnerable modern JS app.

## MITRE knowledge bases

- [MITRE ATT&CK](https://attack.mitre.org/) — adversary TTP taxonomy.
- [MITRE D3FEND](https://d3fend.mitre.org/) — defensive countermeasure
  taxonomy mapped to ATT&CK.
- [MITRE CWE](https://cwe.mitre.org/) — weakness taxonomy used by CVEs.
- [MITRE CAPEC](https://capec.mitre.org/) — attack pattern catalogue.
- [MITRE ATLAS](https://atlas.mitre.org/) — adversarial tactics against
  ML systems.

## Vulnerability databases and disclosed reports

- [HackerOne hacktivity](https://hackerone.com/hacktivity).
- [Bugcrowd disclosure
  archive](https://bugcrowd.com/disclosures).
- [Intigriti researcher
  blog](https://www.intigriti.com/researchers/blog) — Bug Bytes
  monthly + technique posts.
- [YesWeHack blog](https://www.yeswehack.com/blog) — EU bounty platform
  research + annual report.
- [huntr.com (Protect AI)](https://huntr.com/) — bounty platform for
  AI/ML supply-chain vulnerabilities.
- [Pentesterland Bug Bounty
  Writeups](https://pentester.land/list-of-bug-bounty-writeups.html).
- [InfoSec Write-ups](https://infosecwriteups.com/) — aggregator;
  filter by author reputation.
- [Exploit-DB](https://www.exploit-db.com/) — public exploit archive.
- [Packet Storm](https://packetstormsecurity.com/).
- [CVE / Mitre](https://cve.mitre.org/) ·
  [NVD](https://nvd.nist.gov/).
- [AttackerKB](https://attackerkb.com/) — exploitability assessments.
- [VulnCheck](https://vulncheck.com/browse) — KEV-style feeds.

## Hands-on labs and platforms

- [PortSwigger Web Security
  Academy](https://portswigger.net/web-security) — free, structured.
- [PortSwigger All Labs
  catalogue](https://portswigger.net/web-security/all-labs) — every
  Academy lab, by topic and difficulty.
- [TryHackMe](https://tryhackme.com/) — guided rooms.
- [Hack The Box](https://www.hackthebox.com/) — machines, Pro Labs,
  Academy, Offensive AI Security track.
- [pwn.college](https://pwn.college/) — free ASU binary-exploitation
  curriculum + CTF Archive of replayable challenges.
- [OffSec Proving Grounds](https://www.offsec.com/labs/) — paid lab
  environment.
- [GOAD](https://github.com/Orange-Cyberdefense/GOAD) — AD lab.
- [HackingHub](https://www.hackinghub.io/) — paid bug-bounty practice.
- [VulnLab](https://www.vulnlab.com/) — paid AD / red-team labs.
- [CloudGoat](https://github.com/RhinoSecurityLabs/cloudgoat) —
  vulnerable-by-design AWS scenarios.
- [Stratus Red Team](https://stratus-red-team.cloud/) — granular
  adversary emulation across AWS / Azure / GCP / Kubernetes.
- [KubeHound](https://github.com/DataDog/KubeHound) — BloodHound-style
  attack-path graphing for Kubernetes.

## CTF and learning-by-CTF

- [CTFtime](https://ctftime.org/) — canonical CTF calendar, team
  rankings, writeup index.
- [pwn.college CTF
  Archive](https://pwn.college/) — replay past challenges.
- *Handbook for CTFers* (Nu1L Team, Springer) — the structured
  written companion.
- [Awesome CTF](https://github.com/apsdehal/awesome-ctf) — curated
  tooling and resources.
- [0xdf write-ups](https://0xdf.gitlab.io/) — HTB and CTF.

## Research blogs — high signal, currently active

### Web and N-day teardowns
- [PortSwigger Research](https://portswigger.net/research) — James
  Kettle and team; novel HTTP / cache / smuggling research and the
  yearly Top 10 Web Hacking Techniques.
- [watchTowr Labs](https://labs.watchtowr.com/) — rapid-turnaround
  enterprise edge-appliance N-day teardowns (Ivanti, Fortinet, etc.).
- [Horizon3.ai Attack
  Research](https://horizon3.ai/category/attack-research/) —
  reproducible CVE writeups with PoCs.
- [GitHub Security Lab](https://securitylab.github.com/research/) —
  CodeQL-driven variant analysis and OSS advisories.
- [Orange Tsai](https://blog.orange.tw/) — protocol-level web bugs;
  Apache Confusion Attacks, WorstFit, Phrack #72.
- [Assetnote Research](https://www.assetnote.io/resources/research).
- [Doyensec](https://blog.doyensec.com/).

### Active Directory and Entra ID
- [dirkjanm.io](https://dirkjanm.io/) — Dirk-jan Mollema; Entra ID,
  dMSA abuse, NTLM relay, AD CS internals.
- [adsecurity.org](https://adsecurity.org/) — Sean Metcalf; long-running
  AD hardening + Kerberoasting reference.
- [Akamai Security
  Research](https://www.akamai.com/blog/security-research) — BadSuccessor
  (dMSA escalation) and AD protocol research.
- [SpecterOps blog](https://posts.specterops.io/) — BloodHound, AD CS
  (Certified Pre-Owned), Kerberos.
- [Itm4n](https://itm4n.github.io/) — Windows / AD primitives.

### Windows internals and kernel
- [Connor McGarr](https://connormcgarr.github.io/) — approachable deep
  Windows kernel exploitation tutorials.
- [Project Zero](https://projectzero.google/) — Google Project Zero;
  cross-platform kernel and browser research, structured 90-day
  disclosure write-ups.
- [hasherezade](https://hshrzd.wordpress.com/) — Windows internals
  reverse engineering.
- [Modexp](https://modexp.wordpress.com/) — Windows tradecraft
  primitives.

### Linux kernel
- [xairy/linux-kernel-exploitation](https://github.com/xairy/linux-kernel-exploitation)
  — continuously updated index of meaningful Linux-kernel exploit
  papers and talks.
- [Phrack](https://phrack.org/) — revived in 2025 with Issue 72; the
  highest-signal venue for long-form exploit dev.

### macOS and iOS
- [DoubleYou](https://www.doubleyou.io/blog) — Patrick Wardle + Csaba
  Fitzl; macOS offensive and defensive primitives.
- [TAOMM](https://taomm.org/) — *The Art of Mac Malware* vol. 2, free
  online and maintained by Wardle.
- [Objective-See](https://objective-see.org/blog.html) — Patrick
  Wardle's older blog, still useful archive.
- [theevilbit](https://theevilbit.github.io/) — macOS primitives,
  TCC, sandbox.
- [Wojciech Reguła](https://wojciechregula.blog/) — macOS / iOS
  research.

### Cloud and Kubernetes
- [Wiz Research](https://www.wiz.io/blog/tag/security-research).
- [Datadog Security
  Labs](https://securitylabs.datadoghq.com/) — rigorous cloud
  detection-engineering + home of Stratus Red Team + KubeHound.
- [Rhino Security Labs](https://rhinosecuritylabs.com/blog/) —
  maintainers of Pacu and the GCP IAM privesc matrix.
- [ramimac](https://ramimac.me/) — independent cloud-security
  analysis; meta-reviews of vendor reports.
- [Mandiant / Google Cloud Threat
  Horizons](https://cloud.google.com/blog/topics/threat-intelligence)
  — frontline IR data on how cloud and SaaS identities get compromised.
- [HackingTheCloud](https://hackingthe.cloud/) — practical attack-side
  cloud reference.
- [PEACH framework](https://peach.bonfire.security/) — SaaS-tenancy
  isolation model.

### Red team tradecraft
- [SpecterOps Adversary
  Tactics](https://posts.specterops.io/) — AD and red team.
- [Cobalt Strike Research
  Labs](https://www.cobaltstrike.com/blog) — joint Fortra + Outflank
  research on UDRLs, sleep masks, injection tradecraft.
- [MDSec Research](https://www.mdsec.co.uk/research/) — veteran UK red
  team shop; EDR evasion, COM hijack.
- [Outflank blog](https://www.outflank.nl/blog/).
- [Black Hills Information
  Security](https://www.blackhillsinfosec.com/blog/) — practitioner
  blog plus free webcasts.

### AI / LLM security
- [Embrace the Red (Johann
  Rehberger)](https://embracethered.com/blog/) — agent and
  exfil-channel research.
- [Simon
  Willison](https://simonwillison.net/tags/prompt-injection/) —
  curated prompt-injection coverage.
- [NVIDIA AI Red Team
  blog](https://developer.nvidia.com/blog/tag/ai-red-team/) —
  practical attack notes from a working AI red team.
- [Microsoft Security Blog (AI
  posts)](https://www.microsoft.com/security/blog/) — MSRC perspective
  on agentic AI vulnerabilities.
- [HiddenLayer Research](https://hiddenlayer.com/research/).
- [Lakera blog](https://www.lakera.ai/blog).

### Bug bounty methodology and writeups
- [Sam Curry](https://samcurry.net/) — long-form chain writeups.
- [Intigriti Bug
  Bytes](https://www.intigriti.com/researchers/blog).
- [YesWeHack blog](https://www.yeswehack.com/blog).
- [Pentesterland](https://pentester.land/list-of-bug-bounty-writeups.html).
- [Bug Bounty Reports
  Explained](https://www.youtube.com/@BugBountyReportsExplained) —
  video deep-dives of disclosed reports.

### Aggregators
- [tl;dr sec](https://tldrsec.com/) — weekly aggregator.

## YouTube / video

- [IppSec](https://www.youtube.com/@ippsec) — HTB walkthroughs as the
  best free practical learning material.
- [LiveOverflow](https://www.youtube.com/@LiveOverflow) — binary
  exploitation, browser, and research-style explainers.
- [John Hammond](https://www.youtube.com/@_JohnHammond) — CTF /
  malware analysis breakdowns.
- [Off-by-One
  Security](https://www.youtube.com/@OffByOneSecurity) — practitioner
  interviews and live red-team streams.
- [OffensiveCon talks](https://www.youtube.com/@OffensiveCon) —
  annual Berlin con; canonical recorded source for Windows / kernel /
  hypervisor exploit talks.
- [OALabs](https://www.youtube.com/@OALabs) — malware reversing.
- [13Cubed](https://www.youtube.com/@13cubed) — Windows DFIR; useful
  for understanding what defenders see.

## Conferences

- [DEF CON Media](https://media.defcon.org/) — talks archive.
- [Black Hat archives](https://www.blackhat.com/html/archives.html).
- [OffensiveCon](https://www.offensivecon.org/) — Windows / kernel /
  hypervisor exploitation focus.
- [Hexacon](https://www.hexacon.fr/) — French exploitation con.
- [POC](https://powerofcommunity.net/) — Korean exploitation con.
- [Insomni'hack](https://insomnihack.ch/).
- [NorthSec](https://www.nsec.io/).
- [x33fcon](https://www.x33fcon.com/) — red team + blue team
  symbiosis.
- [HITB](https://conference.hitb.org/) — Hack In The Box.

## Awesome lists

- [awesome-pentest](https://github.com/enaqx/awesome-pentest).
- [awesome-web-security](https://github.com/qazbnm456/awesome-web-security).
- [awesome-windows-kernel-security-development](https://github.com/ExpLife0011/awesome-windows-kernel-security-development).
- [awesome-malware-analysis](https://github.com/rshipp/awesome-malware-analysis).
- [awesome-k8s-security](https://github.com/magnologan/awesome-k8s-security).
- [awesome-aws-security](https://github.com/jassics/awesome-aws-security).
- [awesome-Azure-Pentest](https://github.com/Kyuu-Ji/Awesome-Azure-Pentest).
- [awesome-llm-security](https://github.com/corca-ai/awesome-llm-security).
- [awesome-ctf](https://github.com/apsdehal/awesome-ctf).
- [awesome-incident-response](https://github.com/meirwah/awesome-incident-response).
- [Awesome-RCE-techniques](https://github.com/p0dalirius/Awesome-RCE-techniques).

## Books — web and bug bounty

- *The Web Application Hacker's Handbook* — Stuttard & Pinto. Still
  the reference text for chained logic bugs and methodology framing.
- *Bug Bounty Bootcamp* — Vickie Li (No Starch, 2021). Drawn on for
  the bug-class taxonomy under [[web-index]] and methodology
  ordering under [[bug-bounty-methodology]].
- *Real-World Bug Hunting* — Peter Yaworski (No Starch, 2019).
  Disclosed-report case studies that informed bug-class framing
  (HPP, HTML injection, CRLF, subdomain takeover, memory bugs in
  web stack).
- *Hacking APIs* — Corey Ball (No Starch, 2022). Structural source
  for the API discovery, endpoint analysis, BOLA / BFLA / mass
  assignment, JWT, GraphQL, and XAS topics under [[api-index]].
- *Bug Bounty Playbook V2* — Alex Thomas / Ghostlulz. CMS, exposed
  databases, subdomain takeover, and per-DB SQLi coverage that
  shaped [[web-index]] additions.
- *zseano's Methodology* — Sean Roesner. Informed the
  hacker-mindset and workflow stubs under [[bug-bounty-index]].
- *Enumerating Esoteric Attack Surfaces* — Jann Moon (2024). Deep
  recon framing — vertical vs horizontal scope, ASN / reverse-whois
  / acquisitions / cert-transparency / vhost / analytics-tag
  correlation surfaced under [[bug-bounty-index]].
- *How To Shot Web* (Jason Haddix, DEF CON 23, 2015). Bug-bounty
  philosophy and recon-stack framing.

## Books — Windows, Linux, exploit dev, CTF

- *Windows Internals, Part 1 & 2* — Russinovich, Solomon, Ionescu.
- *The Shellcoder's Handbook* — Anley, Heasman, Lindner, Richarte.
- *Practical Binary Analysis* — Dennis Andriesse.
- *A Guide to Kernel Exploitation* — Perla, Oldani.
- *Hacking: The Art of Exploitation* — Jon Erickson.
- *Handbook for CTFers* — Nu1L Team (Springer, 2022). Cited as the
  structural source for the crypto, forensics, mobile, code-auditing,
  AWD, and CTF-style PWN topic categories in this hub.

## Books — macOS / iOS

- *The Art of Mac Malware* (vols 1–2) — Patrick Wardle.
- *macOS and iOS Internals* trilogy — Jonathan Levin.

## Books — cloud / container

- *Container Security* — Liz Rice.
- *Hacking Kubernetes* — Andrew Martin, Michael Hausenblas.
- *Hands-On AWS Penetration Testing with Kali Linux* — Karl Gilbert,
  Benjamin Caudill.

## Books — AI red team

- *Adversarial AI Attacks, Mitigations, and Defense Strategies* —
  John Sotiropoulos.
- *Not with a Bug, But with a Sticker* — Ram Shankar Siva Kumar &
  Hyrum Anderson (ML threat-model framing).

## Communities

- Discord / Slack workspaces around HTB, TryHackMe, PortSwigger,
  individual bug-bounty platforms, BloodHound, and AI red team
  groups.
