---
title: OSDA roadmap (SOC-200)
slug: osda-roadmap
aliases: [osda-prep-roadmap, soc-200-roadmap]
---
{% raw %}

> OSDA (SOC-200) is OffSec's hands-on defensive analyst exam: 24 hours live triage in an Elastic-backed lab plus 24 hours to deliver a written incident report that reconstructs the full attack chain. You will pivot through Kibana, Sysmon, Security event logs, auditd, Zeek and Suricata, and the pass criterion is narrative quality, not screenshot count. Plan ~10 focused weeks if you already have a year of blue-team or strong sysadmin time; budget 14-16 weeks if SIEM is new. Ideal candidate: junior-to-mid SOC analyst, detection engineer in training, or pentester who wants to argue with blue team using their own language.

## Who this is for

- Analysts with 6-18 months in a SOC who can read raw Windows event XML without flinching.
- People comfortable on a Linux shell and able to read PowerShell and basic Bash without a reference.
- Anyone who has built at least one detection rule (Sigma, Elastic EQL, or Splunk SPL) end-to-end.
- Pentesters who already hold OSCP and want to learn how their tradecraft looks from the defender side.
- Not for absolute beginners: do [[soc-fundamentals]] and a Sec+ or BTL1 first, otherwise the OffSec lab pace will crush you.

## What OSDA tests

- Format: proctored, hands-on, 23 hours 45 minutes of investigation in a shared Elastic Security tenant.
- Deliverable: a professional incident report submitted within 24 hours after the lab window closes.
- Environment: Kibana with KQL, Lens, Timeline, plus Sysmon, Windows Security/Defender logs, auditd, Zeek, Suricata.
- You must reconstruct multiple attack chains across Windows and Linux hosts, mapping events end-to-end.
- Each chain is graded on causality: initial access -> execution -> persistence -> credential access -> lateral -> impact.
- You cite specific event IDs, timestamps (UTC), hostnames, users, process IDs, and parent-child relationships.
- Passing requires telling the story; raw IOC dumps without narrative do not score.
- No Metasploit, no exploitation — you are the analyst, the attacker already ran.

## Lab setup (do before week 1)

- A laptop with 32 GB RAM ideal, 16 GB workable, plus 200 GB free SSD.
- Elastic Stack 8.x single-node with Fleet and the Elastic Agent (mirror what OffSec ships).
- Sysmon 15+ with a tuned config — start from SwiftOnSecurity or Olaf Hartong's modular config.
- A Windows 10/11 lab VM and a Windows Server 2022 DC joined to a small domain.
- An Ubuntu 22.04 VM with auditd, the Elastic Agent, and the auditd integration enabled.
- Zeek 6.x and Suricata 7.x on a span port or a pcap replay rig (tcpreplay against a bridge).
- Atomic Red Team and Caldera for repeatable adversary emulation against your own telemetry.
- KAPE and Velociraptor for offline triage drills; you will not run them in the exam but the muscle memory pays off.

## The 10 weeks

### Week 1 — Elastic Security and KQL fluency

- Read: [[siem-analyst-playbook]], [[soc-fundamentals]], [[detection-engineering-fundamentals]], [[mitre-attack-mapping]].
- Labs: ingest your Sysmon and Security logs into Elastic; write 20 KQL queries from raw memory (no copy-paste).
- Deliverable: a personal KQL cheat sheet covering process, network, file, registry, and authentication events.

### Week 2 — Windows event log internals

- Read: [[windows-event-log-internals]], [[sysmon-config-deep]], [[siem-analyst-playbook]], [[detection-engineering-fundamentals]].
- Labs: enable advanced audit policy and Sysmon; trigger 4624/4625/4672/4688/4697/4698 and map to Sysmon 1/3/7/10/11/13.
- Deliverable: a one-page "event ID rosetta" linking Security log IDs to Sysmon equivalents and EID gaps.

### Week 3 — Linux audit, auditd and journald

- Read: [[soc-fundamentals]], [[detection-engineering-fundamentals]], [[threat-hunting-fundamentals]], [[mitre-attack-mapping]].
- Labs: write auditd rules for execve, connect, openat on /etc/shadow; ingest into Elastic and search by syscall.
- Deliverable: an auditd ruleset covering T1059, T1078, T1543.003, T1548.001 with the matching KQL.

### Week 4 — Network forensics with Zeek and Suricata

- Read: [[detection-engineering-fundamentals]], [[threat-hunting-fundamentals]], [[siem-analyst-playbook]], [[mitre-attack-mapping]].
- Labs: replay Malware-Traffic-Analysis pcaps through Zeek and Suricata; pivot from a Suricata alert to Zeek conn.log.
- Deliverable: a written triage walk-through of one pcap from alert to C2 attribution.

### Week 5 — Initial access tradecraft and IoCs

- Read: [[ransomware-affiliate-playbook]], [[detection-engineering-fundamentals]], [[edr-rules-as-code-from-attack-patterns]], [[mitre-attack-mapping]].
- Labs: detonate macro-laden docs and ISO/LNK payloads in your VM; confirm Sysmon 1/11/15 chains land in Elastic.
- Deliverable: a KQL rule pack for office-spawned children, mark-of-the-web bypass, and ISO mount events.

### Week 6 — Credential theft

- Read: [[lateral-movement-playbook]], [[ad-recon-low-noise]], [[sysmon-config-deep]], [[detection-engineering-fundamentals]].
- Labs: run Mimikatz and `comsvcs.dll` LSASS dumps in the VM; correlate Sysmon 10 with Security 4663/4656.
- Deliverable: a "LSASS access in 7 forms" hunt query covering process access, minidump, comsvcs, and procdump.

### Week 7 — Lateral movement

- Read: [[lateral-movement-playbook]], [[ad-recon-low-noise]], [[edr-rules-as-code-from-attack-patterns]], [[siem-analyst-playbook]].
- Labs: run PsExec, WMI, WinRM, and SMB-admin moves; chase 4624 type 3, 4648, Sysmon 1/3, and `wsmprovhost.exe`.
- Deliverable: a lateral-movement Timeline saved view that pivots logon to remote process to remote file write.

### Week 8 — Persistence and privilege escalation

- Read: [[detection-engineering-fundamentals]], [[edr-rules-as-code-from-attack-patterns]], [[mitre-attack-mapping]], [[threat-hunting-fundamentals]].
- Labs: drop run keys, scheduled tasks, services, WMI subscriptions, and Linux systemd units; verify each path lands.
- Deliverable: a persistence matrix mapping technique to event ID(s) and a single hunt query per row.

### Week 9 — Full chain emulation and triage drills

- Read: [[threat-hunting-fundamentals]], [[siem-analyst-playbook]], [[ransomware-affiliate-playbook]], [[mitre-attack-mapping]].
- Labs: run a Caldera or Atomic Red Team operator profile end-to-end; reconstruct the chain from telemetry alone.
- Deliverable: an Elastic Timeline export plus a 2-page incident summary using your future exam template.

### Week 10 — Report writing and dry run

- Read: [[report-writing-for-pentesters]], [[siem-analyst-playbook]], [[detection-engineering-fundamentals]], [[mitre-attack-mapping]].
- Labs: sit a self-imposed 24-hour mock against a CyberDefenders or BlueTeamLabs scenario; write the full report.
- Deliverable: a polished incident report template with screenshots, KQL appendix, and a MITRE ATT&CK mapping.

## Required tooling

- Elastic Stack 8.x with Kibana, Fleet, Elastic Agent.
- Sysmon 15+, Sysinternals suite, PowerShell 7.
- auditd, ausearch, journalctl on Ubuntu 22.04.
- Zeek 6.x, Suricata 7.x, Wireshark, tcpreplay.
- Atomic Red Team, Caldera, Sigma CLI, Chainsaw, Hayabusa.
- Obsidian or any markdown notebook for your event/timestamp running notes.

## Practice corpus

- BlueTeamLabs Online — investigation paths align tightly with the OSDA narrative format.
- LetsDefend SOC and DFIR queues — fast pattern-recognition reps.
- CyberDefenders Blue Team Labs — pcap and event-log heavy, free tier is generous.
- Malware-Traffic-Analysis.net pcaps — gold standard for Zeek/Suricata pivots.
- Splunk Boss of the SOC v1-v3 — different SIEM, identical analyst skills.
- HackTheBox Sherlocks — modern, well-scoped DFIR chains.
- DetectionLab and SimuLand for self-hosted attack telemetry.

## Pragmatic notes from people who sat the exam

- The exam grades the chain, not the discovery: a perfect IOC list with no causality fails; a tight story with two missing events passes.
- Every claim in the report cites event ID, timestamp in UTC, hostname, user, and process tree. No screenshots without captions.
- Build a "given event X, look for Y next" playbook before the exam — under fatigue you will not invent it on the fly.
- Use Kibana Timeline aggressively; saved searches and Lens visualisations are time sinks compared to a sequenced timeline.
- Write the report as you investigate, not after. The 24-hour report window is for polish, not first drafts.
- Sleep is a control. Plan a 5-6 hour break in the 24-hour window; tired analysts miss parent PIDs.

## Failure modes to avoid

- Treating it like a CTF: there is no flag, only a story. Stop hunting "the answer".
- Over-reliance on alerts — OffSec seeds noise; pivot from raw process and network events.
- Skipping UTC discipline; mixing local time in the report sinks the timeline grade.
- Ignoring Linux telemetry because Windows feels comfortable; expect at least one Linux pivot.
- Writing the report from memory after the lab closes; you will misremember PIDs and lose points.

## After OSDA

- Move into [[detection-engineering-fundamentals]] and ship Sigma rules from your exam playbook.
- Sit GCFA or CRTIA next; both reward the narrative skills OSDA forced you to build.
- Cross-train with [[lateral-movement-playbook]] and [[ad-recon-low-noise]] so you can argue with red team on equal terms.

## References

- https://www.offsec.com/courses/soc-200/
- https://www.elastic.co/guide/en/security/current/index.html
- https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon
- https://attack.mitre.org/
- https://docs.zeek.org/en/master/
- https://suricata.readthedocs.io/en/latest/

See also: [[soc-fundamentals]], [[siem-analyst-playbook]], [[sysmon-config-deep]], [[windows-event-log-internals]], [[detection-engineering-fundamentals]], [[threat-hunting-fundamentals]], [[lateral-movement-playbook]], [[report-writing-for-pentesters]]

{% endraw %}
