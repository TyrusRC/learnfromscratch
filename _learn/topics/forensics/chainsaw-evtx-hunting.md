---
title: Chainsaw — fast EVTX hunting
slug: chainsaw-evtx-hunting
---

> **TL;DR:** Chainsaw (F-Secure / WithSecure Labs) is a Rust EVTX hunter that applies Sigma rules AND first-class built-in detections (lateral movement, credential dumping, persistence). Standard companion to [[hayabusa-windows-event-log-triage]] — Hayabusa for breadth, Chainsaw for targeted hunts and custom rules.

## What it is
`chainsaw hunt` reads EVTX, applies Sigma rules + Chainsaw-native YAML detections, and outputs per-detection JSON/CSV with event context. It excels at:
- Mapping events to MITRE ATT&CK techniques
- Surfacing low-and-slow patterns (e.g., RDP brute force across days, 4624 anomalies across hosts)
- Custom hunts via simple YAML (no Sigma backend required)

## Preconditions / where it applies
- EVTX from triage collection or live host (`%SystemRoot%\System32\winevt\Logs`)
- Optional: Sysmon EID 1/3/11 dramatically improves hit rates
- Single binary, runs anywhere; no install

## Tradecraft

**Basic hunt with packaged rules:**

```bash
chainsaw hunt ./EVTX \
  -s sigma/ \
  --mapping mappings/sigma-event-logs-all.yml \
  -r rules/  \
  --output hits.csv --csv
```

`sigma/` is the SigmaHQ repo; `rules/` is Chainsaw's built-in YAML detections. The mapping translates Sigma field names to EVTX schema.

**Targeted single-rule run** (fast iteration during incident):

```bash
chainsaw hunt ./EVTX -s sigma/rules/windows/builtin/security/win_logon_explicit_credentials.yml \
  --skip-errors --csv -o pth-hits.csv
```

**Search keywords across all EVTX, no rule logic:**

```bash
chainsaw search ./EVTX -s 'mimikatz'
chainsaw search ./EVTX -e '4624' --json | jq '.Event.EventData.IpAddress' | sort -u
```

`-e` filters by EventID before keyword match — essential for big datasets.

**Built-in detections worth running on every IR:**
- `rules/lateral_movement/` — psexec, smbexec, wmiexec, evil-winrm
- `rules/credential_access/` — DCSync, ASREPRoast network markers, NTLM relay
- `rules/persistence/` — service install, scheduled task, run key

**Custom Chainsaw rule** (simpler than Sigma for ad hoc hunts):

```yaml
title: Suspicious NetExec User-Agent
group: ad
description: nxc default UA in HTTP-served PROPFIND
authors: [analyst]
kind: evtx
level: high
status: experimental
timestamp: Event.System.TimeCreated
fields:
  - name: User-Agent
    from: Event.EventData.UserAgent
logic:
  condition: matches
  match:
    User-Agent: 'NetExec/*'
```

**Pair with Hayabusa workflow:**

```bash
# 1. Hayabusa for fast triage scan
hayabusa csv-timeline -d EVTX/ -o triage.csv
# 2. Chainsaw for deeper hunt on the host hayabusa flagged
chainsaw hunt EVTX/HOSTNAME/ -s sigma/ -r rules/ --json -o deep.json
# 3. Chainsaw search to extract IOCs from suspicious time window
chainsaw search EVTX/HOSTNAME/ -e 4624 --from '2025-11-12T00:00:00' --to '2025-11-13T00:00:00'
```

**Dump-only mode** (research / pivot extraction):

```bash
chainsaw dump-config rules/
chainsaw analyse srum  ./srum_db   # SRUDB.dat parsing built in
chainsaw analyse shimcache ./SYSTEM
```

Chainsaw newer versions include forensic artifact analysers beyond EVTX — SRUM, Shimcache/Amcache, Prefetch.

## Detection and defence (analyst tradecraft)

- Always run with `--skip-errors`; corrupt EVTX is common, default behaviour aborts
- For multi-GB datasets, use `--load-unknown` only when investigating a specific channel — Chainsaw default skips unknown event IDs to keep performance up
- The output `Detections` column tells you which rule fired; group by that column to find patterns
- Pipe `--json` to `jq` for ad hoc aggregation across hosts: `jq -s 'group_by(.detection) | map({rule:.[0].detection, count:length})'`

## OPSEC for defenders

- Chainsaw, Hayabusa, and EvtxECmd produce different timestamp formats — pick one and stick with it for your case notes
- Sigma + Chainsaw built-in rules can overlap and double-count; filter duplicates by event RecordID before reporting numbers
- Don't trust Sigma rule levels blindly — your environment's noise profile differs. Calibrate on known-clean EVTX first

## References
- [Chainsaw repo](https://github.com/WithSecureLabs/chainsaw)
- [Chainsaw + Sigma mapping files](https://github.com/WithSecureLabs/chainsaw/tree/master/mappings)
- [Eric Zimmerman EVTX tools](https://ericzimmerman.github.io/) — complementary (EvtxECmd, Timeline Explorer)
- [DFIR Report](https://thedfirreport.com/) — Chainsaw in published reports

See also: [[hayabusa-windows-event-log-triage]], [[windows-event-log-analysis]], [[kape-triage-collection]], [[velociraptor-threat-hunting]], [[sigma-rules-detection-as-code]], [[shimcache-amcache]], [[prefetch-analysis]], [[mft-analysis]]
