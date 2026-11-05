---
title: Elastic Security detection rules
slug: elastic-detection-rules
aliases: [elastic-detection, eql, elastic-eql, elastic-siem-rules]
---

> **TL;DR:** Elastic Security ships a public detection-rules repo with 800+ rules in TOML format covering ATT&CK techniques. Rules use EQL (Event Query Language) for sequenced/stateful detections, KQL for simple matches, threshold rules for volume anomalies, and ML jobs for behavioral baselines. Understanding the rule format, the CI pipeline, and EQL's sequence/join operators is core detection engineering skill. Complements [[sigma-rules-detection-as-code]] (vendor-neutral) with Elastic-native power features.

## Rule types

| Type | Best for | Example |
|---|---|---|
| **KQL (query)** | Simple field matches | `process.name: "mimikatz.exe"` |
| **EQL (eql)** | Ordered event sequences, joins, pipes | Process spawns child that makes network connection |
| **Threshold** | Volume anomalies | >50 failed logins from one IP in 5 min |
| **ML** | Behavioral baselines | Rare process for this host/user |
| **New terms** | First-seen detections | New service installed for the first time |
| **Indicator match** | IOC enrichment | IP/hash matches threat feed |

## EQL deep dive

EQL is the crown jewel — it matches ordered sequences across event types.

```eql
/* Detect credential dumping: process accesses LSASS then writes a file */
sequence by host.id with maxspan=1m
  [process where process.name == "procdump.exe"
     and process.args : "*lsass*"]
  [file where file.path : "*\\lsass*.dmp"]
```

**Key operators:**

```eql
/* Sequence with join key */
sequence by user.name with maxspan=5m
  [authentication where event.outcome == "failure"] with runs=5
  [authentication where event.outcome == "success"]

/* Pipe — post-filter on sequence results */
sequence by process.entity_id
  [process where process.name == "cmd.exe"]
  [process where process.parent.name == "cmd.exe"]
| filter length(process.args) > 200

/* Any event type */
any where network.bytes > 10000000 and destination.port == 443
```

**Functions:** `length()`, `stringContains()`, `wildcard()`, `cidrMatch()`, `match()` (regex), `between()`.

## KQL for hunting

KQL is simpler — no sequences, but fast for ad-hoc hunts in Kibana:

```
process.name: "certutil.exe" and process.args: ("-urlcache" or "-encode" or "-decode")
and not process.parent.name: ("sccm*" or "ccm*")
```

## TOML rule format

Every rule in the `elastic/detection-rules` repo is a `.toml` file:

```toml
[metadata]
creation_date = "2024/01/15"
integration = ["endpoint"]
maturity = "production"
min_stack_comments = "EQL sequence syntax"
min_stack_version = "8.11.0"
updated_date = "2024/10/20"

[rule]
author = ["Elastic"]
description = "Detects LSASS memory dumping via procdump."
name = "LSASS Memory Dump via Procdump"
risk_score = 73
severity = "high"
type = "eql"
query = '''
sequence by host.id with maxspan=1m
  [process where process.name == "procdump.exe" and process.args : "*lsass*"]
  [file where file.path : "*\\lsass*.dmp"]
'''
threat = [
  {framework = "MITRE ATT&CK", technique = [
    {id = "T1003", name = "OS Credential Dumping", subtechnique = [
      {id = "T1003.001", name = "LSASS Memory"}
    ]}
  ], tactic = {id = "TA0006", name = "Credential Access"}}
]

[rule.exceptions_list]
# Tuning goes here or in Kibana UI

[[rule.false_positives]]
value = "IT admin using procdump for legitimate debugging"
```

## Repo structure and CI

```
elastic/detection-rules/
├── rules/                    # Rules organized by OS/domain
│   ├── windows/
│   ├── linux/
│   ├── macos/
│   ├── integrations/         # Rules requiring specific integrations
│   └── cross-platform/
├── tests/                    # Unit + integration tests
├── detection_rules/          # Python CLI tooling
│   ├── rule_loader.py
│   ├── schemas/              # JSON schema for TOML validation
│   └── eql_utils.py
└── .github/workflows/        # CI pipeline
```

**CI pipeline tests every PR:**

```bash
# Install tooling
pip install -e .
# Validate all rules against schema
python -m detection_rules validate-all
# Run unit tests (checks EQL syntax, field coverage, ATT&CK mapping)
python -m detection_rules test
# Check for duplicate rule IDs
python -m detection_rules check-duplicates
```

## Building custom rules

```bash
# Use the CLI to scaffold a new rule
python -m detection_rules create-rule \
  --type eql \
  --name "Custom: Suspicious PowerShell Download Cradle" \
  --risk-score 47 \
  --severity medium

# Export rules to Kibana-importable NDJSON
python -m detection_rules export-rules --rule-id <uuid> -o export.ndjson

# Import via Kibana API
curl -X POST "https://kibana:5601/api/detection_engine/rules/_import" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@export.ndjson"
```

## Tradecraft (red-team perspective)

The entire rule set is public — `git clone https://github.com/elastic/detection-rules`. Read the EQL queries targeting your planned technique chain. Key evasion patterns:
- **Break sequences** — insert a benign event between the two the EQL `sequence` expects
- **Rename binaries** — many rules match on `process.name`, not hash or signature
- **Evade `with maxspan`** — slow down the attack steps beyond the rule's time window
- Threshold rules reveal the exact count that triggers — stay one under

## References
- [Elastic detection-rules repo](https://github.com/elastic/detection-rules)
- [EQL language reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/eql-syntax.html)
- [Elastic Security detection engine](https://www.elastic.co/guide/en/security/current/detection-engine-overview.html)

See also: [[sigma-rules-detection-as-code]], [[detection-as-code-pipeline]], [[detection-engineering-pyramid-of-pain]], [[sysmon-configuration-deep]], [[yara-rule-authoring]], [[threat-hunting-methodology]]
