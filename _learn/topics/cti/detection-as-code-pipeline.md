---
title: Detection-as-Code pipeline
slug: detection-as-code-pipeline
aliases: [detection-as-code, dac, dac-pipeline, detection-ci-cd]
---

> **TL;DR:** Detection-as-Code (DaC) treats detection rules like software: version-controlled, peer-reviewed, CI-tested, and automatically deployed to SIEMs/EDR. The pipeline runs validation (schema, syntax), tests against Atomic Red Team data, maps coverage to ATT&CK, and measures detection maturity. Palantir's Alerting & Detection Strategy (ADS) framework and Elastic's DaC model are the two dominant blueprints. This is the operational backbone connecting [[sigma-rules-detection-as-code]], [[elastic-detection-rules]], and [[yara-rule-authoring]] to production SOC workflows.

## Why DaC matters

Traditional detection: analyst writes a Splunk search in the UI, nobody reviews it, it breaks silently after a log source change, and nobody knows it is gone.

DaC fixes this: rules live in git, changes require PR review, CI validates syntax and tests against sample data, deployment is automated, and coverage dashboards track what ATT&CK techniques are detected.

## Pipeline architecture

```
┌──────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐    ┌──────────┐
│  Author   │───▶│  PR +    │───▶│  CI/CD    │───▶│  Deploy   │───▶│ Monitor  │
│  rule     │    │  Review  │    │  Tests    │    │  to SIEM  │    │  & Tune  │
└──────────┘    └──────────┘    └───────────┘    └──────────┘    └──────────┘
    │                │               │                │                │
    │  TOML/YAML     │  Peer         │  Schema +      │  API push      │  FP rate,
    │  in git        │  review       │  Atomic RT     │  to prod       │  coverage
```

## CI stages

### 1. Validation

```yaml
# .github/workflows/detection-ci.yml
name: Detection CI
on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Sigma rules: schema + syntax check
      - run: pip install sigma-cli pysigma-validators-sigmahq
      - run: sigma check rules/sigma/

      # Elastic rules: TOML schema validation
      - run: pip install elastic/detection-rules
      - run: python -m detection_rules validate-all

      # YARA rules: compile check
      - run: |
          sudo apt-get install -y yara
          find rules/yara/ -name "*.yar" -exec yarac {} /dev/null \;
```

### 2. Testing against sample data

```yaml
  test:
    runs-on: ubuntu-latest
    steps:
      # Replay Atomic Red Team telemetry logs through rules
      - run: |
          # Convert Sigma rules to Splunk SPL
          sigma convert -t splunk -p sysmon rules/sigma/ -o build/
          # Run against recorded event logs
          python tests/replay_events.py \
            --rules build/ \
            --events tests/atomic_rt_logs/ \
            --expect tests/expected_hits.json

      # False-positive check against benign baseline
      - run: |
          python tests/replay_events.py \
            --rules build/ \
            --events tests/benign_baseline/ \
            --expect-zero
```

### 3. ATT&CK coverage mapping

```yaml
  coverage:
    runs-on: ubuntu-latest
    steps:
      - run: |
          python scripts/attack_coverage.py \
            --rules rules/ \
            --output coverage.json
          # Generate ATT&CK Navigator layer
          python scripts/generate_navigator_layer.py \
            --coverage coverage.json \
            --output navigator-layer.json
          # Post coverage diff as PR comment
          python scripts/coverage_diff.py \
            --base main \
            --head ${{ github.head_ref }}
```

## Atomic Red Team integration

[[atomic-red-team-emulation-deep]] provides the test corpus for DaC:

```bash
# Run an atomic test and capture telemetry
Invoke-AtomicTest T1003.001 -GetPrereqs
Invoke-AtomicTest T1003.001 -LoggingModule Sysmon

# Export Sysmon logs as EVTX or JSON for CI replay
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" |
  ConvertTo-Json | Out-File tests/atomic_rt_logs/T1003.001.json
```

Each detection rule's test case: run the atomic, capture the logs, assert the rule fires.

## Palantir Alerting & Detection Strategy (ADS)

Palantir's ADS framework formalizes the metadata every production detection needs:

| Field | Purpose |
|---|---|
| **Goal** | What adversary behavior does this detect? |
| **Categorization** | ATT&CK technique + tactic |
| **Strategy abstract** | How the detection works in plain English |
| **Technical context** | Log sources, fields, and assumptions |
| **Blind spots** | What this detection will NOT catch |
| **False positives** | Known benign triggers and tuning guidance |
| **Validation** | Steps to confirm the rule fires (Atomic test ID) |
| **Priority** | Severity and response SLA |
| **Response** | Link to [[soc-runbook-design]] playbook |

Store ADS metadata alongside rules in the same repo, or embed it in the rule's `meta:` / `[metadata]` block.

## Detection maturity model

Maturity levels per detection (adapted from Ryan Stillions' DML):

| Level | Name | Criteria |
|---|---|---|
| **0** | None | No detection for this technique |
| **1** | Draft | Rule written, not tested |
| **2** | Tested | Validated against Atomic RT / sample data |
| **3** | Deployed | Running in production SIEM |
| **4** | Tuned | FP rate measured and acceptable (<5 FP/week) |
| **5** | Automated | Response playbook triggers automatically |

Track maturity per rule in a YAML sidecar or database, visualize on ATT&CK Navigator with color-coded scores.

## False-positive tuning workflow

```
Alert fires  →  Analyst triages  →  True positive?
                                     ├── Yes → IR workflow
                                     └── No  → File FP ticket
                                               ├── Add exception to rule (PR)
                                               ├── CI retests against FP sample
                                               └── Merge, deploy, verify FP gone
```

Track FP rates per rule. Rules with >20 FP/week and no true positives in 90 days are candidates for demotion or rewrite.

## Repo structure (recommended)

```
detection-repo/
├── rules/
│   ├── sigma/           # Vendor-neutral Sigma rules
│   ├── elastic/         # Native EQL/KQL rules
│   ├── splunk/          # SPL correlation searches
│   ├── yara/            # File/memory scanning rules
│   └── sentinel/        # KQL analytics rules
├── tests/
│   ├── atomic_rt_logs/  # Captured telemetry per technique
│   ├── benign_baseline/ # Known-good logs for FP testing
│   └── expected_hits.json
├── scripts/
│   ├── attack_coverage.py
│   ├── deploy_to_splunk.py
│   └── deploy_to_elastic.py
├── coverage/
│   └── navigator-layer.json
├── ads/                 # Palantir ADS metadata per detection
└── .github/workflows/
    └── detection-ci.yml
```

## References
- [Palantir ADS framework](https://github.com/palantir/alerting-detection-strategy-framework)
- [Elastic Detection-as-Code blog](https://www.elastic.co/blog/elastic-detection-as-code)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [Ryan Stillions — Detection Maturity Level model](http://ryanstillions.blogspot.com/2014/04/the-dml-model_21.html)
- [MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)

See also: [[sigma-rules-detection-as-code]], [[elastic-detection-rules]], [[yara-rule-authoring]], [[atomic-red-team-emulation-deep]], [[soc-runbook-design]], [[detection-engineering-pyramid-of-pain]], [[threat-hunting-methodology]], [[mitre-d3fend-coverage]]
