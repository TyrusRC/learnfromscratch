---
title: Sigma rules — detection as code
slug: sigma-rules-detection-as-code
---

> **TL;DR:** Sigma is a YAML DSL for log-based detections, vendor-neutral. Authors write one rule; `sigmac` / `pysigma` compiles it to Splunk SPL, Elastic ESQL/EQL, Sentinel KQL, Chronicle YARA-L, etc. SOCs share rules via the SigmaHQ repo; modern detection engineering treats rules as code with PR review, tests, and CI.

## What it is
Sigma was published by Florian Roth (Nextron) in 2017 and is now the lingua franca of community detection sharing. A rule has metadata (id, status, level, mitre tags), `logsource` (product/category/service), `detection` (one or more selections + condition), and falsepositive notes.

## Anatomy

```yaml
title: Suspicious LSASS Access via Procdump
id: 5f5a1d10-2e9d-4ab7-b3ba-86d6e0c0b3a0
status: stable
description: Detects procdump.exe being used to dump LSASS memory
references:
  - https://attack.mitre.org/techniques/T1003/001/
author: example
date: 2024/11/15
tags:
  - attack.credential_access
  - attack.t1003.001
logsource:
  product: windows
  category: process_creation
detection:
  selection:
    Image|endswith: '\procdump.exe'
    CommandLine|contains:
      - 'lsass'
      - '-ma '
  condition: selection
falsepositives:
  - Authorized memory dumping by IR
level: high
```

## Tradecraft (detection-engineer perspective)

**Convert and deploy:**

```bash
pip install pysigma pysigma-backend-splunk pysigma-backend-elasticsearch
# Splunk SPL
sigma convert -t splunk -p sysmon rules/windows/process_creation/proc_procdump_lsass.yml
# Elastic Common Schema EQL
sigma convert -t elasticsearch -f eql -p ecs_windows rules/.../proc_procdump_lsass.yml
# Sentinel KQL
sigma convert -t kusto -p sentinel rules/.../proc_procdump_lsass.yml
```

**Pipelines** (`-p`) handle field-name normalisation — Sysmon ships `Image`, Defender ships `FileName`, Crowdstrike ships `ImageFileName`. Picking the right pipeline is half the work.

**Test before deploy** — `sigma-cli` supports `sigma analyse` for confidence/false-positive scoring, and `pysigma-validators-sigmahq` runs SigmaHQ style rules in CI.

**Modifiers worth knowing:**
- `|contains|all` — every list item must appear
- `|re` — regex (avoid in hot paths; backend performance varies)
- `|cased` — case-sensitive match (default is case-insensitive on Windows)
- `|windash` — handles `-` vs `/` flag styles automatically
- `null` value — field is absent (used with `1 of selection*`)

**CI workflow** (real SOC practice):

```yaml
# .github/workflows/sigma-ci.yml
- run: sigma check rules/
- run: sigma convert -t splunk -p sysmon -o build/splunk/ rules/
- run: python scripts/upload_to_splunk.py build/splunk/
```

Rules merged to `main` deploy to staging, then to prod with a soak period. Detection-as-code mirrors infra-as-code lifecycle.

## Tradecraft (red-team perspective)

Sigma rules expose YOUR opponent's detection logic. Public SigmaHQ rules + vendor enterprise feeds (Splunk ESCU, Elastic Detection Rules, Sentinel community) tell you:
- Exactly which CLI strings trigger ("`-ma lsass`", "`Get-NetUser`")
- Which event IDs they consume (4688? Sysmon 1? Defender EDR feed?)
- Which fields they expect normalized to (so you know the schema you're being matched against)

A quick recon pattern: clone SigmaHQ, grep for your planned technique, adjust trade-craft to evade. See [[edr-rules-as-code-from-attack-patterns]].

## Detection and defence
- Pin SigmaHQ commit hash and review diffs — rules added by community sometimes have collisions with your environment
- Track rule efficacy via Detection Maturity Level (DML) per rule
- For high-volume rules, convert to streaming aggregation in the backend (Splunk `tstats`, Elastic transforms) — naive `sigma convert` can produce expensive queries
- MITRE ATT&CK Navigator import: `sigma list mitre` to visualize coverage

## References
- [SigmaHQ rules repo](https://github.com/SigmaHQ/sigma)
- [pysigma + backends](https://github.com/SigmaHQ/pySigma)
- [Sigma specification](https://github.com/SigmaHQ/sigma-specification)
- [Florian Roth — Sigma blog series](https://cyb3rops.medium.com/)

See also: [[detection-engineering-pyramid-of-pain]], [[atomic-red-team-emulation-deep]], [[hayabusa-windows-event-log-triage]], [[chainsaw-evtx-hunting]], [[edr-rules-as-code-from-attack-patterns]], [[soc-runbook-design]], [[threat-hunting-methodology]], [[mitre-d3fend-coverage]]
