---
title: CRTO roadmap (Certified Red Team Operator)
slug: crto-roadmap
aliases: [crto-prep-roadmap, rto-roadmap, zero-point-security-roadmap]
---

{% raw %}

> **TL;DR:** An eight-week study path for Zero-Point Security's Certified Red Team Operator exam. CRTO tests assumed-breach Active Directory red team operations using Cobalt Strike in a Windows-heavy lab environment. Different from OSCP (general pentest) and OSEP (custom tooling / evasion-heavy). Pair with [[c2-frameworks]], [[oscp-vs-osep-mindset]], and [[ad-attack-path-playbook]].

## Who this is for

- You have OSCP-level AD fundamentals (or equivalent hands-on experience with Kerberos, NTLM, lateral movement).
- You can navigate Windows command-line and PowerShell without a tutorial.
- You want to certify the *assumed-breach red team operations* skill set — Cobalt Strike, AD attack paths, OPSEC-aware tradecraft.

## What CRTO tests

The 48-hour exam gives you a multi-machine Active Directory lab environment. You start with an assumed-breach foothold (a Cobalt Strike beacon on an initial workstation). From there:

- Enumerate the domain and identify attack paths.
- Move laterally through the network.
- Escalate privileges through AD misconfigurations and delegation abuse.
- Achieve domain dominance (Domain Admin or equivalent).
- Collect flags planted across the environment (six of eight required to pass).

All operations use Cobalt Strike as the C2 framework. You do not need to write custom tooling or bypass EDR — the focus is on AD tradecraft and Cobalt Strike proficiency.

## Required mental model

- **Assumed breach, not initial access.** You already have a beacon. The exam is about what you do after landing.
- **Cobalt Strike is the platform.** Know its commands, BOFs, pivoting, and OPSEC features cold.
- **AD attack path thinking.** BloodHound-driven: enumerate, identify the shortest path to DA, execute.
- **OPSEC awareness, not EDR evasion.** The lab does not have advanced EDR, but the course teaches you to think about detection. Sloppy tradecraft (e.g., dumping LSASS with Mimikatz on disk) is unnecessary risk.

## The eight weeks

### Week 1 — C2 fundamentals and Cobalt Strike

- Read: [[c2-frameworks]], [[c2-protocol-design]], [[cobalt-strike-malleable-c2-profiles]], [[infrastructure-design]].
- GAP: `[[cobalt-strike-operator-primer]]` — a dedicated note on Cobalt Strike basics (listeners, beacons, payloads, beacon commands, the console, team server setup) does not yet exist. The existing [[c2-frameworks]] note covers the landscape but not CS operator workflow.
- Labs: set up a Cobalt Strike team server, create HTTP and HTTPS listeners, generate and execute payloads, establish a beacon, practice basic commands (`shell`, `run`, `execute-assembly`, `upload`, `download`, `sleep`, `jobs`).
- Deliverable: a Cobalt Strike quick-reference card with listener configs, common commands, and Aggressor script snippets.

### Week 2 — Host reconnaissance and situational awareness

- Read: [[windows-enumeration]], [[linux-enumeration]], [[tokens-and-privileges]], [[windows-processes-and-threads]].
- GAP: `[[host-recon-post-exploitation]]` — a note focused on post-exploitation host reconnaissance (local users, groups, processes, network connections, installed software, AV/EDR enumeration, scheduled tasks) in a red-team context does not yet exist.
- Labs: from a beacon, enumerate the local system: users, groups, processes, network shares, scheduled tasks, installed software, AV products. Use Cobalt Strike's built-in commands and Seatbelt BOF.
- Deliverable: a host-enumeration checklist for post-exploitation.

### Week 3 — Domain reconnaissance and BloodHound

- Read: [[bloodhound]], [[bloodhound-ce-deployment]], [[sharphound]], [[ldap-enumeration]], [[kerberos]], [[ad-recon-low-noise]], [[snaffler-share-mining]].
- Labs: run SharpHound from a beacon (execute-assembly), ingest data into BloodHound, identify shortest paths to DA. Use LDAP queries for backup enumeration. Mine file shares with Snaffler for credentials.
- Deliverable: a BloodHound-annotated attack path from initial foothold to DA in the lab.

### Week 4 — Credential theft and privilege escalation

**Credential dumping**
- Read: [[credential-dumping]], [[lsa-secrets]], [[dpapi-secrets]], [[cached-domain-credentials]], [[wdigest-cleartext-enable]], [[lsass-protection-ppl]].
- Labs: dump credentials via Cobalt Strike's Mimikatz integration (`logonpasswords`, `dcsync`). Extract DPAPI secrets, cached credentials, and LSA secrets.

**Local privilege escalation**
- Read: [[windows-privesc-checklist]], [[winpeas-enumeration-flow]], [[weak-service-permissions]], [[unquoted-service-paths]], [[dll-hijacking-privesc]], [[always-install-elevated]], [[token-impersonation]], [[user-account-control]], [[uac-bypass-techniques]].
- Labs: escalate from a medium-integrity beacon to SYSTEM using token impersonation, UAC bypass, and service misconfigurations.

- Deliverable: a credential-theft and privesc decision tree for Cobalt Strike operations.

### Week 5 — Lateral movement

- Read: [[pass-the-hash]], [[overpass-the-hash]], [[pass-the-ticket]], [[psexec-family]], [[wmi-exec]], [[winrm-exec]], [[dcom-exec]], [[smb-exec]], [[socks-proxies]].
- Read also: [[pivoting-and-tunneling]], [[modern-tunnelling-chains-chisel-ligolo-gost]].
- Labs: move laterally using Cobalt Strike's `jump` and `remote-exec` commands. Practice PsExec, WMI, WinRM, and DCOM methods. Set up SOCKS proxying through a beacon for tool proxying.
- Deliverable: a lateral movement matrix: method, required privilege level, network requirements, detection footprint.

### Week 6 — Domain escalation and persistence

**Kerberos attacks**
- Read: [[kerberoasting]], [[asreproast]], [[unconstrained-delegation]], [[constrained-delegation]], [[resource-based-constrained-delegation]], [[s4u2self-abuse]].
- Labs: Kerberoast service accounts, AS-REP roast users without pre-auth, abuse delegation misconfigurations to impersonate DA.

**ACL and GPO abuse**
- Read: [[acl-abuse]], [[gpo-abuse]], [[adminsdholder-abuse]].
- Labs: identify abusable ACLs with BloodHound (GenericAll, GenericWrite, WriteDACL, WriteOwner on users/groups/computers), exploit them to escalate.

**AD CS attacks**
- Read: [[adcs-attacks]], [[certipy-toolkit-deep]].
- Labs: identify misconfigured certificate templates (ESC1, ESC4, ESC8), request certificates to impersonate DA.

**NTLM relay and coercion**
- Read: [[ntlm-relay]], [[petitpotam-coercion]], [[printer-bug-spoolsample]], [[ad-coercion-and-relay-matrix-2025]].
- GAP: `[[ntlm-coercion-relay-cobalt-strike]]` — a note on executing NTLM relay and coercion attacks specifically from a Cobalt Strike beacon (portfwd, SOCKS, tool proxying) does not yet exist.
- Labs: coerce authentication from a machine account, relay to LDAP/HTTP for RBCD or shadow credentials.

**Domain persistence**
- Read: [[golden-tickets]], [[silver-tickets]], [[diamond-and-sapphire-tickets]], [[dcsync]], [[ad-persistence]], [[shadow-credentials]].
- Labs: perform DCSync, forge golden and silver tickets, establish persistence through skeleton key or AdminSDHolder abuse.

- Deliverable: a domain escalation playbook — ordered by noise level and prerequisite.

### Week 7 — OPSEC, evasion awareness, and pivoting

**OPSEC fundamentals**
- Read: [[opsec-fundamentals]], [[living-off-the-land]], [[living-off-the-land-binaries-lolbas]].
- GAP: `[[cobalt-strike-opsec-guide]]` — a note on OPSEC-specific Cobalt Strike tradecraft (sleep/jitter, process injection choices, named pipe vs. TCP beacons, spawn-to configuration, argue command, blockdlls) does not yet exist.

**Process injection and beacon management**
- Read: [[process-injection-techniques]], [[parent-pid-spoofing]].
- Labs: practice inject, spawn, and argue commands. Understand spawn-to and blockdlls.

**Application whitelisting awareness**
- Read: [[applocker-bypass-techniques]], [[amsi-bypass]], [[etw-bypass]].
- Labs: execute tooling through Cobalt Strike's execute-assembly (which loads .NET in-memory), understanding why this evades basic application whitelisting.

**Network pivoting**
- Read: [[ssh-tunneling]], [[port-forwarding]], [[chisel]], [[ligolo-ng]], [[pivoting-and-tunneling]].
- Labs: pivot through a compromised host to reach a segregated network using Cobalt Strike's SOCKS proxy and port forwarding (`rportfwd`, `socks`).

- Deliverable: an OPSEC checklist for red team operations — things to configure before and during an engagement.

### Week 8 — Mock exam and full-chain practice

- Read: [[osep-ad-attack-chain-walkthrough]], [[ad-attack-path-playbook]], [[report-writing-for-pentesters]].
- Labs: reset the RTO lab and run a full assumed-breach exercise: initial beacon → host recon → domain recon → credential theft → lateral movement → domain escalation → DA. Collect all flags under a 48-hour timer.
- Practice: restart and do it again with a different path. The exam rewards flexibility — if one path is blocked, pivot to another.
- Deliverable: a complete attack narrative from foothold to DA, documenting every step, tool, and command.

## Gap summary — notes that need writing

These notes are referenced above but do not currently exist in the KB:

| Slug | Topic | Why it matters for CRTO |
|------|-------|------------------------|
| `cobalt-strike-operator-primer` | Cobalt Strike basics — team server, listeners, beacons, core commands, Aggressor scripting | Foundation of the entire exam; every lab exercise and the exam itself uses CS |
| `host-recon-post-exploitation` | Systematic post-exploitation host enumeration (users, AV, network, tasks) | Week 2 core — first thing you do after landing a beacon |
| `ntlm-coercion-relay-cobalt-strike` | NTLM relay/coercion from a Cobalt Strike beacon (portfwd, SOCKS, tool proxying) | Domain escalation — coercion attacks need specific CS pivot setup |
| `cobalt-strike-opsec-guide` | CS-specific OPSEC — sleep/jitter, spawn-to, named pipes, blockdlls, argue, process injection choices | OPSEC awareness is tested throughout; sloppy defaults cost time |

Existing notes that partially cover these gaps:
- [[c2-frameworks]] covers the C2 landscape broadly but not Cobalt Strike operator workflow.
- [[windows-enumeration]] covers host enumeration but not the post-exploitation/red-team-specific flow.
- [[ntlm-relay]] covers the technique but not the Cobalt Strike execution specifics.
- [[opsec-fundamentals]] covers principles but not CS-specific implementation.

## Exam day strategy

### Time allocation (48 hours, 6 of 8 flags required)
1. **0–2 hours:** establish beacon stability, enumerate the local host thoroughly, run SharpHound, load BloodHound.
2. **2–6 hours:** identify attack paths, begin lateral movement and credential theft. Target low-hanging fruit first (Kerberoast, AS-REP roast, credential files on shares).
3. **6–24 hours:** execute the main attack path — delegation abuse, ACL abuse, ADCS, or relay attacks. Move toward DA.
4. **24–36 hours:** collect remaining flags, try alternative paths for any you missed.
5. **36–48 hours:** buffer for stuck flags and clean documentation of commands used.

### Key exam tips
- **Sleep times matter.** Set beacons to a reasonable sleep (5–10s) for interactive work. Don't leave them at the default 60s during active exploitation.
- **Multiple beacons.** Maintain beacons on every host you compromise. If one dies, you don't have to re-exploit.
- **BloodHound is the map.** Every escalation path is visible in BloodHound if you collect the right data. Re-run collection after gaining new privileges.
- **Token impersonation.** Cobalt Strike's `steal_token` and `make_token` are fundamental. Use them constantly for lateral movement.
- **Take notes as you go.** Document every command and its output. The exam doesn't require a formal report, but tracking your path saves time when you need to backtrack.

## RTO course module mapping

For reference, here is how the Zero-Point Security RTO course modules map to this study plan:

| RTO Module | Study Week |
|------------|-----------|
| C2 Introduction / Cobalt Strike | Week 1 |
| External Reconnaissance | (not exam-tested — assumed breach) |
| Initial Compromise | (not exam-tested — you start with a beacon) |
| Host Reconnaissance | Week 2 |
| Host Persistence | Week 6 (persistence) |
| Host Privilege Escalation | Week 4 |
| Credential Theft | Week 4 |
| Domain Reconnaissance | Week 3 |
| User Impersonation | Week 5 |
| Lateral Movement | Week 5 |
| Session Passing | Week 7 (beacon management) |
| Pivoting | Week 7 |
| Data Protection / DPAPI | Week 4 |
| Kerberos | Week 6 |
| Active Directory Certificate Services | Week 6 |
| Group Policy | Week 6 |
| MS SQL Servers | Week 5 (via [[mssql-trusted-links]], [[mssql-xp-cmdshell-impersonation-chains]]) |
| Domain Dominance | Week 6 |
| Forest & Trust Abuse | Week 6 (via [[cross-forest-trust-abuse]], [[child-to-forest-root]], [[sidhistory-injection]]) |
| LAPS | Week 4 (via [[windows-laps-v2-attacks]]) |
| AppLocker | Week 7 |
| Data Hunting & Exfiltration | Weeks 3, 7 |

## Practice environments

- **Zero-Point Security RTO Lab** — the official lab environment. Complete every exercise at least once.
- **HackTheBox Pro Labs** — Offshore and Dante provide multi-machine AD environments.
- **GOAD (Game of Active Directory)** — free, self-hosted multi-forest AD lab.
- **TryHackMe** — Holo, Wreath, and throwback networks for AD chains.

## CRTO vs OSCP vs OSEP — one paragraph each

- **CRTO**: assumed-breach AD red team. Cobalt Strike. 48h practical. Focus on AD attack paths and C2 tradecraft.
- **OSCP**: network/web pentest. Black-box. No assumed breach, no C2 framework required. 24h.
- **OSEP**: advanced assumed-breach. Custom tooling required, EDR evasion emphasis, AV bypass, AMSI/ETW. 48h. Harder than CRTO on the evasion axis.

See [[oscp-roadmap]], [[osep-roadmap]], [[oscp-vs-osep-mindset]], [[oscp-osep-oswe-track-comparison]].

## Pragmatic notes from people who sat the exam
- **Do the course labs twice.** The exam re-uses techniques from the course labs in slightly different configurations. Muscle memory on the Cobalt Strike commands matters more than theory.
- **BloodHound CE vs. Legacy:** the course may reference legacy BloodHound, but BloodHound CE works fine for the exam. Know both UIs.
- **Cobalt Strike 4.x changes:** if your course materials reference older CS versions, verify that commands still work the same way. `jump` and `remote-exec` have evolved.
- **Pace yourself.** 48 hours is generous if you know the material. Candidates who rush through flags and make mistakes burn more time than those who work methodically.
- **The exam is fair.** Every flag is achievable with techniques taught in the course. If you find yourself trying something exotic, you are probably overthinking it.

## References
- [Zero-Point Security — Red Team Ops course](https://training.zeropointsecurity.co.uk/courses/red-team-ops)
- [Zero-Point Security — CRTO exam info](https://training.zeropointsecurity.co.uk/pages/red-team-ops-exam)
- [Cobalt Strike documentation](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/)
- [BloodHound documentation](https://bloodhound.readthedocs.io/)
- [HackTricks — Active Directory](https://book.hacktricks.xyz/windows-hardening/active-directory-methodology)
- [The Hacker Recipes — Active Directory](https://www.thehacker.recipes/ad/)
- See also: [[c2-frameworks]], [[ad-attack-path-playbook]], [[osep-roadmap]], [[oscp-roadmap]], [[oscp-vs-osep-mindset]], [[report-writing-for-pentesters]]

{% endraw %}
