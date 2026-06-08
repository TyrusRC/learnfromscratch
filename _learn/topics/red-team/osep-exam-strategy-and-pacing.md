---
title: OSEP exam strategy and pacing
slug: osep-exam-strategy-and-pacing
aliases: [osep-exam-strategy, pen300-exam-strategy]
---

> **TL;DR:** OSEP is a 48-hour exam against a single connected Active Directory environment plus a 24-hour report window. The pass bar sits around 100 points, with `secret.txt` files on individual hosts giving partial credit even if you never reach domain-wide compromise. The win condition is not exotic AV bypass craft; it is fast initial access via prepared client-side payloads, disciplined enumeration, and grinding lateral movement through the AD topology before fatigue costs you the late hours. This note pairs with [[osep-roadmap]], [[oscp-exam-methodology]], [[oscp-osep-oswe-track-comparison]], [[oscp-vs-osep-mindset]], [[osep-payload-development-toolkit]], and [[osep-network-filter-bypass-techniques]].

## Why it matters

OSEP (PEN-300) is the Offensive Security exam most often failed because of scheduling and ego, not technique. Candidates assume it is a harder OSCP and walk in planning to live-improvise their loader, only to burn six hours fighting Defender on host #1 while the AD path to domain admin sits enumerated and ignored.

The exam tests a specific operator profile: someone who already has a working tradecraft kit (custom loader, AMSI bypass variant, syscall stub, beaconing C2 profile) and can pivot it through a multi-host AD estate inside two days. Build that kit before the exam, not during it. See [[osep-payload-development-toolkit]] for the actual artifacts you should carry in.

The pacing strategy below is what separates candidates who finish at the 100-point line with hours to spare from candidates who hit 80 points at hour 47 and submit a panicked report.

## Exam structure (what is publicly known)

### Format and scoring

- **48 hours** of hands-on engagement time against an isolated lab.
- **24 hours** after that for the written report.
- **Single connected environment**: hosts share an AD forest / domain trust structure rather than being independent boxes like OSCP. Pivots are mandatory; you cannot finish without lateral movement.
- **Partial credit via `secret.txt`** files on individual hosts. Compromising hosts in isolation earns points even if full domain takeover is not achieved.
- **Bonus objective** (publicly described as a "secret flag" / final objective) for chained domain-wide compromise.
- **Pass threshold**: approximately 100 points. Confirm the current official figure on the Offensive Security exam page; the scoring has been adjusted at least once in recent years.

### Connectivity and tooling rules

- VPN connection with proctoring (webcam + screen share).
- All standard tooling allowed: BloodHound, Mimikatz/Rubeus equivalents, C2 frameworks, custom loaders. Forbidden items are the usual short list (commercial Cobalt Strike unlicensed, certain automated exploitation suites, multi-engagement reuse against other students). Re-read the current exam guide the week before sitting.
- You are expected to write or significantly modify payloads. Off-the-shelf `msfvenom` shellcode dropped into a public loader will get caught and waste hours.

## The pacing model

Treat the 48 hours as four phases. The clock targets are deliberately conservative; real exams compress or expand them, but the proportions hold.

### Hour 0 to 2: enumeration sweep

Goal: build the full target map before touching any payload.

- Port-scan every in-scope subnet. Capture banners, SMB shares, web roots, certificate templates, ADCS endpoints.
- Spider any public-facing web app for client-side delivery surfaces (file upload, email submission form, "contact us" with attachment review workflow).
- Identify which host is the realistic initial-access target. OSEP exams typically gate one or two entry points behind client-side execution (phishing-style payload run by a simulated user) and the rest behind AD lateral movement.
- Do **not** fire payloads in this window. You are reading the topology.

If you finish enumeration in 90 minutes you are doing it right. If you are still scanning at hour 3 you skipped the OSCP-style discipline and will pay for it later. See [[oscp-exam-methodology]] for the enumeration template that ports over.

### Hour 2 to 12: initial access via client-side

Goal: get one stable C2 callback from the simulated user host.

- Pick the lowest-friction delivery primitive the box hints at: a macro-enabled document if the target review workflow accepts Office, an HTA / JScript loader if the upload is web-based, a signed installer wrapper if AppLocker is in scope. Compare [[office-vba-macros-initial-access]] and [[jscript-hta-wsh-initial-access]] for the prep work.
- Use the loader you built before the exam. If you find yourself rewriting your AMSI bypass at hour 4, stop and use a simpler payload: a fresh process spawn with patched `AmsiScanBuffer`, indirect syscalls, beacon over HTTPS to a redirector. See [[amsi-bypass]] and [[syscall-direct-and-indirect]].
- Verify the callback is **stable** before pivoting. A one-shot beacon that dies after two minutes is worse than no beacon because you will assume the host is yours.
- Pull local context: tokens, integrity level, AV product, network position, domain join state.

Twelve hours sounds generous. It is. Client-side initial access is where 60% of failed candidates lose the exam by overcomplicating the loader. Land the beacon, then move.

### Hour 12 to 30: AD lateral movement

Goal: collect partial-credit `secret.txt` files and reach a privileged context.

- Drop a [[bloodhound]] collector early in this phase. SharpHound's stealth collection methods are fine inside the exam; you are not evading a real EDR tuning team, you are passing a lab.
- Walk the obvious AD paths in order: [[kerberoasting]], [[asreproast]], [[constrained-delegation]] / [[resource-based-constrained-delegation]] / [[unconstrained-delegation]], [[s4u2self-abuse]], [[adcs-attacks]] for ESC1/ESC8 templates.
- Pivot via SOCKS through your initial beacon. See [[chisel]], [[ligolo-ng]], [[ssh-tunneling]], and [[pivoting-and-tunneling]] for the tunneling layer.
- Collect `secret.txt` on every host you touch, immediately, before trying privilege escalation on that host. The flag is the points; the SYSTEM shell is the bonus.
- Maintain a running notes file with: host, credentials harvested, secret file collected (yes/no), points contribution, next pivot lead.

This is the longest phase and the one where fatigue starts. Schedule a real sleep block around hour 22-26 if your circadian rhythm cooperates. Candidates who refuse to sleep make worse decisions in the final phase than candidates who lose four hours to rest.

### Hour 30 to 48: capture remaining + report buffer

Goal: hit the points threshold with cushion, then stop hacking and start writing.

- Re-run BloodHound with the credentials accumulated so far. New paths appear once you own service accounts.
- Target the remaining `secret.txt` flags by points-per-hour expected value, not by interest. A boring SMB share with weak ACLs beats a fascinating kernel exploit lead.
- **Hard stop at hour 42 for offensive work** if you have crossed the pass threshold. Spend the last six hours producing report-quality screenshots, command logs, and a clean exploit chain narrative. The report is graded; sloppy reports fail otherwise-passing exams.
- If you have not crossed the threshold at hour 42, switch to the highest-confidence remaining lead and give it until hour 46. Then stop and write whatever you have. A submitted report at 90 points beats a non-submitted report at 110.

## Common time sinks

These are the patterns that cost candidates the exam. Recognise them in yourself.

### Overcomplicating AV bypass when a simpler payload works

You spent three months building a perfect indirect syscall loader with a custom call stack spoof. The exam host runs default Defender. A plain process-hollowing payload with a one-line AMSI patch would have worked in five minutes. Use the simple thing first. Save the elegant thing for when the simple thing fails.

### Missing easy-win lateral moves

The exam often includes a misconfigured share, a service account with `GenericAll` on another principal, or an ADCS template with `Client Authentication` EKU and `Enrollee Supplies Subject`. These are flagged by [[bloodhound]] in the first five minutes of post-exploitation enumeration. Candidates who tunnel-vision on one host while ignoring the BloodHound output are throwing 30 points away.

### Tunnel-visioning on a single host

If you have spent four hours on a single privilege escalation, leave it and come back. Other hosts have partial credit available. The exam scoring rewards breadth before depth.

### Rebuilding your toolkit during the exam

Every minute spent compiling your loader on exam day is a minute not spent hacking. Compile, sign, and stage everything beforehand. See [[osep-payload-development-toolkit]].

### Skipping the report buffer

A report written in panic between hours 47 and 48 will be missing screenshots, exploit code listings, and the AD attack path diagram that graders look for. Reports fail more candidates than missing points do.

## Pre-exam payload preparation

Build these artifacts in the two weeks before the exam, not during it:

- **Custom loader**: PE that resolves `Nt*` syscalls dynamically, allocates RW then RX (or uses APC injection), loads encrypted shellcode from disk or registry. See [[process-injection-techniques]].
- **AMSI bypass variant**: at least two methods (patch + provider tampering). See [[amsi-bypass]] and [[amsi-providers-tampering]].
- **ETW bypass**: optional but cheap. See [[etw-bypass]].
- **Syscall stub generator**: SysWhispers-style or your own. Indirect syscalls preferred. See [[syscall-direct-and-indirect]].
- **Macro / HTA / JScript droppers**: pre-tested against current Defender signatures. See [[office-vba-macros-initial-access]] and [[jscript-hta-wsh-initial-access]].
- **C2 profile**: HTTPS beacon on a redirector with a sane sleep / jitter. Test it end-to-end. See [[c2-frameworks]] and [[sliver-c2-deep]].
- **Tunneling kit**: pre-built [[ligolo-ng]] or [[chisel]] binaries for Windows and Linux targets.
- **AppLocker bypass primer**: at least one working LOLBin route. See [[applocker-bypass-techniques]].

## Enumeration discipline

OSEP rewards the same discipline as OSCP, scaled up. The pattern from [[oscp-style-box-attack-pattern]] applies per-host: nmap, web spider, SMB enum, then service-specific deep dive. The difference is you also maintain a forest-wide view: domain trusts, ADCS templates, GPO links, certificate authorities, MSSQL link chains.

Keep one structured notes file (Markdown, Obsidian, CherryTree, whatever). Each host gets: IP, hostname, FQDN, OS, services, creds harvested, secret flag status, escalation path, related hosts.

## When to use BloodHound vs targeted manual enumeration

- **BloodHound** for: shortest-path queries once you have multiple credentials, finding non-obvious DACL paths, certificate template enumeration.
- **Manual `Get-DomainComputer` / `Get-DomainUser` / `Get-NetSession`** for: confirming a single suspected misconfiguration, working from a host where you cannot drop SharpHound, validating BloodHound results that look too good.
- Run SharpHound once early (with `Default,LoggedOn` collection method if the C2 supports a session collection privilege check), then re-run after major credential harvests.

## Comparison to OSCP exam strategy

| Dimension | OSCP | OSEP |
|---|---|---|
| Duration | 24h exam + 24h report | 48h exam + 24h report |
| Targets | 3 independent boxes + AD set | 1 connected AD environment |
| Initial access | Public CVE or weak service | Client-side payload (phishing-shaped) |
| Required AV bypass | Minimal | Mandatory, prepared in advance |
| Lateral movement | AD set only | Required across exam |
| Pass condition | Points threshold per box + AD | Points threshold across forest |
| Failure mode | Tunnel-vision on one box | Tunnel-vision on AV bypass |

Read [[oscp-exam-methodology]] and [[oscp-vs-osep-mindset]] together. The OSCP "pace yourself across independent boxes" mindset must be replaced with a "pace yourself across one large connected estate" mindset.

## Defensive baseline (for the report)

Even though the exam is offensive, the report is graded partly on remediation quality. Have boilerplate ready for:

- AMSI / ETW hardening (audit, alert on patched `amsi.dll`).
- LAPS deployment for local admin password rotation.
- ADCS template hardening (no `Enrollee Supplies Subject`, no `Any Purpose` EKU on user-enrollable templates). See [[adcs-attacks]].
- Constrained delegation review, removal of unconstrained delegation. See [[unconstrained-delegation]] and [[constrained-delegation]].
- Tiered admin model and protected users group enrollment.
- AppLocker / WDAC publisher rules instead of path rules. See [[applocker-bypass-techniques]].

## Workflow to study

1. Complete the [[osep-roadmap]] lab work and the official challenge labs.
2. Build the kit in [[osep-payload-development-toolkit]] until it works on a current patched Windows 11 + Defender VM you control.
3. Do a 48-hour timed dress rehearsal against HackTheBox Pro Labs (Offshore, Dante, RastaLabs) using only your kit and the pacing model above.
4. Review the dress rehearsal: where did you lose hours? Fix those before the real exam.
5. Sleep eight hours before exam day. Do not study the morning of.

## Related

- [[osep-roadmap]]
- [[oscp-exam-methodology]]
- [[oscp-osep-oswe-track-comparison]]
- [[oscp-vs-osep-mindset]]
- [[osep-payload-development-toolkit]]
- [[osep-network-filter-bypass-techniques]]
- [[oscp-style-box-attack-pattern]]
- [[bloodhound]]
- [[active-directory]]
- [[amsi-bypass]]
- [[syscall-direct-and-indirect]]
- [[client-side-attacks-primer]]

## References

- Offensive Security, PEN-300 / OSEP course and exam page: https://www.offsec.com/courses/pen-300/
- Offensive Security, OSEP exam guide (current version): https://help.offsec.com/hc/en-us/articles/360050293792-OSEP-Exam-Guide
- TJ Null, OSEP-style preparation list and walkthroughs: https://github.com/0xVIC/myOSEPjourney
- BloodHound documentation, collection and Cypher queries: https://bloodhound.specterops.io/
- SpecterOps, Certified Pre-Owned (ADCS attack paper): https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf
- MITRE ATT&CK, Active Directory tactics mapping: https://attack.mitre.org/techniques/T1550/
