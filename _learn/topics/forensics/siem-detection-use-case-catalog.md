---
title: SIEM detection — use-case catalog
slug: siem-detection-use-case-catalog
aliases: [siem-use-cases, detection-catalog]
---

{% raw %}

> **TL;DR:** A SIEM is only useful for detections you've actually built. This is a starter catalog of high-value use cases mapped to log sources: AD events, authentication anomalies, lateral-movement primitives, exfiltration, persistence indicators, and cloud control-plane events. Each entry includes the log source, a sketch query, and tuning notes. Companion to [[edr-rules-as-code-from-attack-patterns]] and [[ir-from-source-signals]].

## Use-case categories

For each, the question "what would a SIEM alert me to that I'd otherwise miss?".

## A. Authentication

### A1 — Impossible travel
Same user authenticating from two geographically distant IPs within minutes.

- Source: Azure AD Sign-in logs, Okta, on-prem AD (4624 events with source IP enrichment).
- Logic: `time_diff < travel_time(source1_geoip, source2_geoip)`.
- Tuning: VPN endpoints; whitelisted IP ranges.

### A2 — Authentication spike
Sudden rise in auth-failure rate.

- Source: Windows 4625; Azure AD 50126.
- Logic: failures per user per hour > threshold.
- Tuning: scheduled tasks with expired passwords; vendor systems.

### A3 — Successful login after many failures
4625 storms followed by 4624 within minutes for same user — likely password spray or brute force success.

### A4 — Login outside business hours (high-value users)
Admin / exec accounts logging at 3am from a new IP.

- Source: Sign-in logs.
- Logic: user in `high_value_users` AND hour-of-day in `unusual_hours` AND IP not in `known_ips`.

## B. Active Directory

### B1 — Kerberoasting
Mass requests for service tickets.

- Source: Windows 4769 (Kerberos service ticket).
- Logic: same user account requesting > N service tickets within X minutes.
- Tuning: monitoring tools that legitimately enumerate.

### B2 — DCSync
Replication request from non-DC account.

- Source: Windows 4662 with `ms-DS-Replication-Sync` or `Directory-Service-Changes`.
- Logic: 4662 with the directory-replication GUIDs from a non-DC source.
- Tuning: known AD migration tools.

### B3 — Privileged group changes
Membership change on Domain Admins, Enterprise Admins, Schema Admins, AdminSDHolder, GPO containers.

- Source: 4728/4729 (security global group), 4732/4733 (security local group).
- Alert immediately, no threshold.

### B4 — Service account NTLM logon
NTLM auth (logon type 3) by a service account (gMSA expected to use Kerberos).

### B5 — `SeBackup` privilege used
A user with SeBackupPrivilege reading SAM/SYSTEM hives.

## C. Lateral movement

### C1 — PsExec / WMI exec / WinRM
Detection on the *executing* host.

- Source: Sysmon EventID 1 (process create).
- Logic: `psexec.exe`, `wmic.exe` with `process call create`, `winrs.exe`, `powershell.exe` with `enter-pssession`.
- Tuning: admin scripted maintenance.

### C2 — RDP from non-jumphost
RDP session (4624 type 10) to a workstation from a non-management IP.

### C3 — Pass-the-Hash signatures
Kerberos pre-authentication with anomalous flags (e.g., RC4 instead of AES with a domain configured for AES-only).

### C4 — Token impersonation
4673/4674 events showing privilege use by non-admin SID with admin SID handle.

## D. Credential access

### D1 — LSASS access
Sysmon EventID 10 (process accessed) where target is `lsass.exe` and access mask includes 0x1010 or 0x1410.

- Tuning: known security tools (CrowdStrike falconctl, ProcessHacker by sysadmin).

### D2 — Volume Shadow Copy creation
Possible Mimikatz / NTDS dump.

- Source: Windows 4672 or 7045 with `vssadmin.exe create shadow`.

### D3 — Mimikatz signature
PowerShell ScriptBlock contains known Mimikatz strings (heavily evaded but still useful baseline).

## E. Persistence

### E1 — Run/RunOnce changes
Registry write to `HKLM\Software\Microsoft\Windows\CurrentVersion\Run` from a non-installer process.

- Source: Sysmon EventID 13.

### E2 — Scheduled-task creation
4698 with command-line including PowerShell or download from URL.

### E3 — WMI event subscription
Sysmon 19/20/21.

### E4 — Service install
4697 with service binary outside standard paths.

## F. Defense evasion

### F1 — AMSI bypass
4104 PowerShell ScriptBlock containing `AmsiUtils` / `AmsiScanBuffer` patches.

### F2 — Disable Windows Defender
PowerShell `Set-MpPreference -DisableRealtimeMonitoring $true`.

### F3 — Disable audit log
1102 (audit log cleared).

### F4 — Disable Sysmon
Sysmon service stopped.

## G. Exfiltration

### G1 — Large data upload
Outbound bytes to a single external IP > threshold.

- Source: firewall logs, EDR network telemetry.
- Tuning: backup destinations.

### G2 — Data to file-sharing services
DNS / proxy to mega.nz, anonfiles, transfer.sh.

### G3 — DNS exfiltration
Large volume of unique subdomains for one parent.

## H. Cloud control plane

### H1 — AWS console login from new IP
CloudTrail `ConsoleLogin` event, IP not in known set.

### H2 — IAM policy change
CloudTrail `PutUserPolicy`, `AttachUserPolicy`, `CreatePolicy` granting wide perms.

### H3 — STS AssumeRole chain
Long chain of `AssumeRole` events across accounts.

### H4 — S3 public ACL change
CloudTrail `PutBucketAcl` or `PutBucketPolicy` granting `Principal: *`.

### H5 — Azure AD app consent
New application consent for a user.

### H6 — GCP service-account key creation
Audit log `google.iam.admin.v1.IAMService.CreateServiceAccountKey`.

## I. Web app / API

### I1 — Successful 401-to-200 transition
A request to a sensitive endpoint that 401'd minutes ago now 200s — possible auth bypass.

### I2 — Unusual user-agent
Requests from `curl`, `python-requests`, `Go-http-client` to user-only endpoints.

### I3 — SQLi error spikes
HTTP 500 with SQL-error patterns increasing.

## Tuning rules — rule lifecycle

For each rule:
1. **Audit mode** — collect matches for a week without alerting.
2. **Triage** — every match labelled TP / FP / informational.
3. **Refine** — exception clauses.
4. **Promote** — alert priority.
5. **Decommission** — when the technique is obsolete or the threat model changes.

A SIEM with 5000 rules and 4500 muted-by-analyst alerts is worse than one with 200 well-tuned rules.

## Source maturity ladder

Without these, SIEM use cases above don't function:

1. Centralised authentication logs (AD + cloud IdP).
2. EDR with Sysmon-equivalent event detail.
3. Network telemetry (proxy, firewall, NetFlow).
4. Cloud control-plane logs (CloudTrail, Audit Logs, Activity Logs).
5. Web access logs.
6. Database audit logs.

Targeted use-cases require deeper sources (e.g., AD attack detection needs Windows event logs with verbose auditing enabled).

## Tools

- **Splunk**, **Microsoft Sentinel**, **Elastic Security**, **Sumo Logic**, **Chronicle** — commercial.
- **Wazuh** (open-source SIEM).
- **Sigma** — vendor-neutral rule format; convert per platform.

## OSCP/OSEP/OSWE relevance

OSEP: knowing what defenders watch shapes which techniques avoid detection.
For defenders: critical operational knowledge.

## References
- [Sigma rule repository](https://github.com/SigmaHQ/sigma)
- [MITRE ATT&CK detection-mapped rules](https://attack.mitre.org/)
- [SpecterOps detection blog](https://posts.specterops.io/)
- [Microsoft Sentinel — built-in rules](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Splunk Security Essentials](https://splunkbase.splunk.com/app/3435)
- See also: [[edr-rules-as-code-from-attack-patterns]], [[deception-and-honeypot-strategy]], [[ir-from-source-signals]], [[purple-team-feedback-loop]]

{% endraw %}
