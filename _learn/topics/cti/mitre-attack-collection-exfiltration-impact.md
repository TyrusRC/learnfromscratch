---
title: "ATT&CK tactics: Collection, Exfiltration, and Impact"
slug: mitre-attack-collection-exfiltration-impact
aliases: [attack-collection, attack-exfiltration, attack-impact, t1486, t1567, t1048]
---

> **TL;DR:** Collection, Exfiltration, and Impact are the late-stage ATT&CK tactics that represent the adversary achieving their objective — stealing data or causing damage. Detection here is your last line of defense. This note covers the key techniques in each tactic with detection strategies, data sources, and example queries. These are the techniques where [[detection-engineering-pyramid-of-pain]] meets real-world ransomware ([[ransomware-affiliate-playbook]]) and data theft operations.

## Collection (TA0009)

The adversary gathers data of interest before exfiltrating.

### T1005 — Data from Local System

Files harvested from local drives: documents, databases, browser creds.

```spl
# Splunk: detect staging — many file reads from sensitive paths in short window
index=sysmon EventCode=11
| where TargetFilename LIKE "%\\Documents\\%" OR TargetFilename LIKE "%\\Desktop\\%"
  OR TargetFilename LIKE "%.kdbx" OR TargetFilename LIKE "%.pst"
| bin _time span=5m
| stats dc(TargetFilename) as files_touched by Image _time
| where files_touched > 20
```

**Data sources:** Sysmon Event ID 11 (FileCreate), EDR file access telemetry, DLP agents.

### T1039 — Data from Network Shared Drive

```eql
// Elastic EQL: process accessing many UNC paths rapidly
sequence by process.entity_id with maxspan=2m
  [file where file.path : "\\\\*\\*" and event.action == "open"] with runs=10
```

**Detection:** alert on single process opening 50+ files across network shares in <5min. Baseline normal share access per role first.

### T1114 — Email Collection

Sub-techniques: `.001` local email files, `.002` remote email (Exchange/O365 API), `.003` email forwarding rules.

```kql
// Sentinel: detect mailbox forwarding rule creation (T1114.003)
OfficeActivity
| where Operation in ("New-InboxRule", "Set-InboxRule")
| where Parameters has_any ("ForwardTo", "ForwardAsAttachmentTo", "RedirectTo")
| project TimeGenerated, UserId, Operation, Parameters
```

**O365 specific:** monitor `MailItemsAccessed` audit events for bulk mailbox access via Graph API.

### T1119 — Automated Collection

Scripts or tools systematically collecting files matching criteria (extensions, keywords).

```spl
# Detect file enumeration tools
index=sysmon EventCode=1
  (CommandLine="*dir /s*" OR CommandLine="*Get-ChildItem -Recurse*"
   OR CommandLine="*forfiles*" OR CommandLine="*robocopy*")
| where CommandLine LIKE "%.docx%" OR CommandLine LIKE "%.xlsx%"
  OR CommandLine LIKE "%.pdf%" OR CommandLine LIKE "%.pst%"
```

### T1213 — Data from Information Repositories

SharePoint, Confluence, wiki, internal Git. Often accessed via legitimate credentials.

**Detection:** baseline per-user download volume from SharePoint/Confluence. Alert on:
- User downloading >100 files in a session
- First-ever access to a sensitive site/space
- Access from unusual IP/location (correlate with [[cloud-ir-azure-activity-log]])

```kql
// Sentinel: SharePoint bulk download
OfficeActivity
| where OfficeWorkload == "SharePoint" and Operation == "FileDownloaded"
| summarize file_count=count(), files=make_set(OfficeObjectId) by UserId, bin(TimeGenerated, 1h)
| where file_count > 50
```

## Exfiltration (TA0010)

Data leaves the network. Detection depends on knowing what "normal" outbound traffic looks like.

### T1048 — Exfiltration Over Alternative Protocol

Data sent over DNS, ICMP, or non-standard protocols to bypass proxy/firewall monitoring.

```spl
# DNS exfiltration: high-entropy subdomain queries (Sysmon Event 22)
index=sysmon EventCode=22
| eval subdomain=mvindex(split(QueryName, "."), 0)
| eval entropy=len(subdomain)
| where entropy > 30
| stats count by Image QueryName
| sort -count
```

```eql
// Elastic: ICMP data exfiltration — large ICMP packets
network where network.protocol == "icmp" and network.bytes > 1000
```

**Key indicators:** DNS TXT queries to unusual domains, ICMP packets >64 bytes, outbound traffic on ports 53/443/8443 to non-CDN IPs.

### T1567 — Exfiltration to Cloud Storage

Adversary uploads to Mega, Dropbox, Google Drive, Azure Blob, S3.

```spl
# Detect uploads to cloud storage services
index=proxy
| where url LIKE "%mega.nz%" OR url LIKE "%dropbox.com/upload%"
  OR url LIKE "%drive.google.com/upload%"
  OR url LIKE "%blob.core.windows.net%"
| stats sum(bytes_out) as total_upload by src_ip user url
| where total_upload > 104857600
```

**Also watch for:** `rclone.exe`, `megacmd`, `aws s3 cp`, `azcopy` in process creation logs — these are commonly used by ransomware affiliates for double-extortion data theft.

### T1041 — Exfiltration Over C2 Channel

Data sent back through the existing C2 connection (most common for smaller exfil).

**Detection is hard** — blends with normal C2 traffic. Look for:
- Sudden increase in C2 beacon size (byte count analysis)
- Long POST requests to known C2 endpoints
- Correlate with collection activity: if T1005 staging detected, watch the originating process's network connections

### T1030 — Data Transfer Size Limits

Adversary breaks data into small chunks to avoid DLP thresholds.

```spl
# Detect chunked exfiltration: many small transfers to same destination
index=firewall action=allowed bytes_out>0
| bin _time span=1h
| stats count sum(bytes_out) as total_bytes dc(dest_port) as ports by src_ip dest_ip _time
| where count > 100 AND total_bytes > 50000000 AND ports < 3
```

**Defense:** DLP must aggregate transfer volume over time, not just inspect individual packets.

## Impact (TA0040)

The adversary's destructive endgame. Detection here is incident response, not prevention.

### T1486 — Data Encrypted for Impact (Ransomware)

The most financially devastating technique. Adversary encrypts files and demands ransom.

```spl
# Canary file monitoring: place honey files and alert on access
index=sysmon EventCode=11
| where TargetFilename LIKE "%\\canary_financial_report.xlsx%"
  OR TargetFilename LIKE "%\\DO_NOT_DELETE_IT_AUDIT.docx%"
| stats count by Image TargetFilename ComputerName
```

```eql
// Elastic: mass file rename with ransomware extensions
file where event.action == "rename"
  and file.extension : ("encrypted", "locked", "crypt", "enc", "ransom")
| count file.extension by process.name
| filter count > 50
```

**Ransomware canary pattern:**
1. Deploy decoy files in every share (`\\server\share\~canary_2024.xlsx`)
2. Set Sysmon/EDR to alert on ANY access to canary files
3. Canary access = kill switch: isolate host automatically via SOAR
4. Buys minutes before encryption spreads

### T1489 — Service Stop

Adversaries stop backup, AV, and database services before encrypting.

```spl
# Detect mass service stops (pre-ransomware)
index=wineventlog EventCode=7036
| where Message LIKE "%stopped%"
| bin _time span=5m
| stats dc(ServiceName) as services_stopped values(ServiceName) as svc_list by ComputerName _time
| where services_stopped > 5
```

**Critical services to monitor:** `vss` (Volume Shadow Copy), `MSSQLSERVER`, `wuauserv` (Windows Update), AV services, backup agent services.

### T1490 — Inhibit System Recovery

Delete shadow copies, disable recovery boot options, clear backup catalogs.

```spl
# Shadow copy deletion — the classic ransomware precursor
index=sysmon EventCode=1
| where (CommandLine LIKE "%vssadmin%delete%shadows%"
  OR CommandLine LIKE "%wmic%shadowcopy%delete%"
  OR CommandLine LIKE "%bcdedit%recoveryenabled%No%"
  OR CommandLine LIKE "%wbadmin%delete%catalog%")
```

**This query alone catches 80%+ of ransomware.** If `vssadmin delete shadows /all /quiet` runs, assume compromise.

### T1529 — System Shutdown/Reboot

Forced reboot to complete encryption (some ransomware encrypts the bootloader).

```spl
index=sysmon EventCode=1
| where (Image LIKE "%shutdown.exe%" AND CommandLine LIKE "%/r%")
  OR (Image LIKE "%powershell%" AND CommandLine LIKE "%Restart-Computer%")
| where User != "SYSTEM"
```

## Cross-tactic detection: the exfiltration timeline

Real attacks chain these tactics. Detect the pattern, not just individual techniques:

```
Collection (hours/days)         Exfiltration (hours)         Impact (minutes)
─────────────────────────────── ──────────────────────────── ─────────────────
T1005: Stage sensitive files    T1567: Upload to Mega        T1490: Delete shadows
T1039: Harvest network shares   T1048: DNS tunnel backup     T1489: Stop services
T1213: Scrape SharePoint        T1041: Exfil over C2         T1486: Encrypt everything
```

**Correlation rule:** if T1005/T1039 staging is detected AND outbound data volume spikes (T1567/T1048) within 24h, auto-escalate to P1 regardless of other context.

## References
- [MITRE ATT&CK — Collection](https://attack.mitre.org/tactics/TA0009/)
- [MITRE ATT&CK — Exfiltration](https://attack.mitre.org/tactics/TA0010/)
- [MITRE ATT&CK — Impact](https://attack.mitre.org/tactics/TA0040/)
- [DFIR Report — ransomware playbooks](https://thedfirreport.com/)

See also: [[ransomware-affiliate-playbook]], [[detection-as-code-pipeline]], [[sigma-rules-detection-as-code]], [[elastic-detection-rules]], [[sysmon-configuration-deep]], [[detection-engineering-pyramid-of-pain]], [[threat-hunting-methodology]], [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]]
