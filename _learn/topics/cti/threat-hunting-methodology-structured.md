---
title: Structured threat hunting — frameworks and practice
slug: threat-hunting-methodology-structured
aliases: [structured-hunting, peak-framework, hunt-playbooks, hunting-queries]
---

> **TL;DR:** Structured threat hunting goes beyond ad-hoc searching: it applies repeatable frameworks (PEAK, ABLE, Sqrrl) to generate hypotheses, execute hunts with documented playbooks, and output new detections or confirmed incidents. This note covers the PEAK framework, data-driven vs hypothesis-driven approaches, ATT&CK Navigator for hunt planning, Jupyter notebooks for hunt analysis, and ready-to-use hunt queries for Splunk, Elastic, and Sentinel. Complements the existing [[threat-hunting-methodology]] note with operational depth and query examples.

## PEAK threat hunting framework

Developed by David Bianco (Splunk SURGe), PEAK defines three hunt types:

| Type | Trigger | Example |
|---|---|---|
| **Hypothesis-driven** | CTI report, ATT&CK technique, new TTP | "If APT29 is using Teams token theft, I should see abnormal `TokenBroker` access patterns" |
| **Baseline** | Establish normal, find outliers | Profile all scheduled tasks across the fleet; flag new/unique ones |
| **Model-Assisted (M-A)** | ML/statistical model surfaces anomalies | Rare process tree clustering, unusual network volume per host |

**PEAK workflow:**

```
1. PREPARE   → Scope: which hosts, data sources, time range
              → Validate data quality (are the logs actually there?)
2. EXECUTE   → Run queries, pivot on findings
              → Document every query and observation (notebook)
3. ACT       → Outcome: incident ticket, new detection rule, data gap report
              → Always produce an artifact — a hunt with no output is wasted
4. KNOWLEDGE → Share findings, update ATT&CK coverage, file hunt report
```

## Hypothesis-driven hunting

The hypothesis is the hunt's thesis statement. It must be **testable** and **falsifiable**.

**Good hypothesis:**
> "If an attacker is performing Kerberoasting (T1558.003), we will see Event ID 4769 with encryption type 0x17 (RC4) from non-service accounts during non-business hours."

**Bad hypothesis:**
> "Something suspicious might be happening."

**Building hypotheses from CTI:**

```
1. Read CTI report (e.g., Mandiant APT report)
2. Extract techniques → T1558.003 (Kerberoasting)
3. Map to data source → Windows Security Event Log 4769
4. Formulate testable statement
5. Write the query
6. Execute, document, produce outcome
```

## Data-driven hunting (baseline hunts)

No hypothesis needed — let the data surface anomalies:

```
1. Pick a telemetry source (e.g., all process creation on DCs)
2. Establish baseline: what is NORMAL? (30-day frequency analysis)
3. Stack/count: sort by rarity
4. Investigate outliers manually
5. Feed confirmed-bad into detection pipeline
```

**Stacking** is the core technique: group by a field, count, sort ascending. Rare = interesting.

## Hunt playbook template

```yaml
hunt_id: HUNT-2024-042
title: "Kerberoasting detection via RC4 ticket requests"
hypothesis: "Attackers requesting RC4-encrypted service tickets from non-service accounts"
mitre_technique: T1558.003
data_sources:
  - windows_security_4769
  - active_directory
scope:
  hosts: "All domain controllers"
  timeframe: "Last 30 days"
  
queries:
  splunk: |
    index=wineventlog EventCode=4769 Ticket_Encryption_Type=0x17
    | where ServiceName != "$*"
    | stats count by Account_Name ServiceName Client_Address
    | where count < 5
    | sort count
  elastic: |
    event.code: "4769" AND winlog.event_data.TicketEncryptionType: "0x17"
    AND NOT winlog.event_data.ServiceName: "$*"
  sentinel: |
    SecurityEvent
    | where EventID == 4769 and TicketEncryptionType == "0x17"
    | where ServiceName !startswith "$"
    | summarize count() by Account, ServiceName, ClientAddress

expected_outcomes:
  - true_positive: "Escalate to IR, document compromised accounts"
  - false_positive: "Legacy apps using RC4 — add to tuning allowlist"
  - detection_gap: "Write Sigma rule, add to detection-as-code pipeline"
  - data_gap: "Event ID 4769 not forwarded from all DCs — file ticket"

references:
  - https://attack.mitre.org/techniques/T1558/003/
```

## ATT&CK Navigator for hunt planning

```bash
# Export current detection coverage
python scripts/attack_coverage.py --rules rules/ --output current_coverage.json

# Load into ATT&CK Navigator (https://mitre-attack.github.io/attack-navigator/)
# Color code:
#   Green  = detection rule exists and tested
#   Yellow = detection exists, not tested
#   Red    = no detection (hunt priority)
#   Blue   = hunted within 90 days
```

Hunt priority = red cells (no detection) that are relevant to your threat model. Cross-reference with [[cti-collection-management]] priority intelligence requirements (PIRs).

## Jupyter notebooks for hunting

Notebooks document the hunt reproducibly — queries, results, analyst notes in one artifact.

```python
# hunt_kerberoasting.ipynb
import pandas as pd
from splunklib import client, results

# Connect to Splunk
service = client.connect(host="splunk", port=8089, token=SPLUNK_TOKEN)

# Run hunt query
query = """
search index=wineventlog EventCode=4769 Ticket_Encryption_Type=0x17
| where ServiceName != "$*"
| stats count by Account_Name ServiceName Client_Address
| sort -count
"""
job = service.jobs.create(query, earliest_time="-30d", latest_time="now")

# Analyze results
df = pd.DataFrame([r for r in results.JSONResultsReader(job.results(output_mode="json"))])
print(f"Total RC4 ticket requests: {len(df)}")
print(f"Unique accounts: {df['Account_Name'].nunique()}")

# Flag accounts with > threshold
suspicious = df[df['count'].astype(int) > 10]
print(f"\nSuspicious accounts (>10 RC4 requests):\n{suspicious}")
```

**MSTICPy** (Microsoft Sentinel's hunting library) and **SecurityWhale** provide pre-built hunting notebooks.

## Common hunt queries

### Lateral movement — PsExec-style remote service creation

```spl
# Splunk
index=wineventlog EventCode=7045 ServiceType="user mode service"
| regex ServiceFileName=".*\\\\(ADMIN\$|C\$|IPC\$).*"
| stats count by ComputerName ServiceName ServiceFileName Account_Name
```

### Living-off-the-land binary (LOLBin) abuse

```eql
// Elastic EQL
process where process.name in ("certutil.exe","mshta.exe","regsvr32.exe",
  "rundll32.exe","msiexec.exe","wmic.exe","cmstp.exe")
and process.args : ("http*", "\\\\*", "/i:http*", "-urlcache")
```

### Anomalous scheduled task creation

```kql
// Sentinel KQL
SecurityEvent
| where EventID == 4698
| extend TaskXml = parse_xml(EventData)
| extend TaskAction = tostring(TaskXml.EventData.Data[5])
| where TaskAction has_any ("powershell", "cmd", "wscript", "mshta")
| project TimeGenerated, Computer, SubjectUserName, TaskAction
```

### DNS beaconing detection

```spl
# Splunk — periodic DNS beacon pattern
index=sysmon EventCode=22
| bucket _time span=10m
| stats count dc(QueryName) as unique_queries by Image _time
| where count > 50 AND unique_queries < 5
| stats stdev(count) as beacon_regularity by Image
| where beacon_regularity < 3
```

## Hunt output requirements

Every hunt MUST produce one of:
1. **Incident ticket** — confirmed compromise, escalate to IR
2. **New detection rule** — push to [[detection-as-code-pipeline]]
3. **Tuning recommendation** — improve existing rule (reduce FP or expand coverage)
4. **Data gap report** — required telemetry missing, file engineering ticket
5. **Negative report** — "hunted T1558.003, no findings, coverage confirmed" (still valuable)

## References
- [PEAK threat hunting framework — David Bianco](https://www.splunk.com/en_us/blog/security/peak-threat-hunting-framework.html)
- [Sqrrl Hunting Maturity Model](https://www.threathunting.net/sqrrl-archive)
- [MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)
- [MSTICPy — Jupyter hunting tools](https://github.com/microsoft/msticpy)

See also: [[threat-hunting-methodology]], [[hypothesis-driven-hunting]], [[sigma-rules-detection-as-code]], [[detection-as-code-pipeline]], [[cti-collection-management]], [[atomic-red-team-emulation-deep]], [[detection-engineering-pyramid-of-pain]], [[structured-analytic-techniques-for-hunters]]
