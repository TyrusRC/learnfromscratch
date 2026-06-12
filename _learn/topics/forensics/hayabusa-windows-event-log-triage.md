---
title: Hayabusa — Windows event log triage
slug: hayabusa-windows-event-log-triage
---

> **TL;DR:** Hayabusa (Yamato Security, Rust) consumes EVTX archives and applies Sigma + Hayabusa-native rules to surface attacker tradecraft fast. Standard first-pass IR triage on Windows: ingest the host's `Security`, `Sysmon`, `PowerShell-Operational`, `System` EVTX, get a single CSV/HTML timeline ranked by severity in under a minute per host.

## What it is
`hayabusa` is a single Rust binary that walks EVTX files, applies a curated ruleset (Sigma format + Hayabusa extensions), and produces a unified hits CSV plus statistics. It ships pre-built rules tuned to be high-fidelity on cold-data forensic review — fewer false positives than raw SigmaHQ deployed to a live SIEM.

## Preconditions / where it applies
- Triage / IR scenario where you have collected EVTX (via [[kape-triage-collection]], `wevtutil epl`, or `Get-WinEvent -Path`)
- Windows endpoint with logs back at least a few days
- Sysmon installed makes the output dramatically more useful (process_creation rules drive much of the detection)

## Tradecraft

**Standard run:**

```bash
hayabusa csv-timeline \
  --directory ./EVTX \
  --output triage.csv \
  --profile timesketch-verbose
# Or HTML report
hayabusa html-report --directory ./EVTX --output report.html
```

Outputs per-event hits sorted by timestamp, each tagged with rule severity (informational → critical) and MITRE technique IDs. Open in TimeSketch / Excel / Timeline Explorer.

**Per-host metrics — figure out what to investigate first:**

```bash
hayabusa metrics --directory ./EVTX
# Prints event-ID frequency table per channel — anomalies stand out
hayabusa logon-summary --directory ./EVTX
# Lists every account that authenticated, source IP, success/failure counts
hayabusa pivot-keywords-list --directory ./EVTX
# Extracts IPs, hosts, users, hashes to feed external lookups
```

**Live host triage (one command, no separate collection step):**

```bash
hayabusa.exe csv-timeline -d C:\Windows\System32\winevt\Logs -o triage.csv
# Run elevated, ~30s on typical workstation
```

**Tune rules:**

```bash
hayabusa update-rules
# Pulls latest hayabusa-rules + sigma submodule
hayabusa list-profiles
# See available output profiles; profiles control which columns appear
```

**Common high-fidelity hits to scan for first:**
- `Possible Lateral Movement using PSExec` (rule severity high)
- `Suspicious LSASS Memory Dump`
- `New-Service with svchost.exe path` (persistence via fake service)
- `Successful Logon From Public IP` (4624 with non-RFC1918 source)
- `Schtasks With ServiceUI` (UAC bypass marker)
- `Sysmon ProcessAccess to LSASS with high access mask`

**Combining with Chainsaw:** Hayabusa is the "scan EVERY rule fast" tool; [[chainsaw-evtx-hunting]] is better at targeted hunts and custom Sigma. Pros run both back-to-back on the same dataset.

## Detection and defence (analyst tradecraft)

- Start with `--profile timesketch-verbose`, then narrow to `super-verbose` only for confirmed incidents — verbose modes can take 10× longer on multi-GB EVTX
- Hayabusa flags Sysmon EID 1 with parent `winword.exe` spawning `cmd.exe` as critical — a fast macro-malware triage
- Pivot from any high-severity hit to the same host's earlier `Logon` events (rule `4624_4625_4634`) to scope authentication chain
- Use `--enable-noisy-rules` only when targeting a specific scenario; default profile suppresses noisy rules

## OPSEC for defenders

- Don't run hayabusa on a compromised host — copy EVTX off first. Triage tools writing CSV to the same volume risk overwriting allocation evidence
- Match collection time to suspected dwell time. Default Windows Security log circular ~20MB caps to about 7 days of normal activity — pull MFT and shimcache too ([[mft-analysis]], [[shimcache-amcache]]) for older traces
- For domain-wide hunts, copy DC `Security.evtx` and run hayabusa logon-summary against it to find auth anomalies; pair with [[ad-recon-low-noise]] for known-good baselines

## References
- [Hayabusa repo](https://github.com/Yamato-Security/hayabusa)
- [Hayabusa rules](https://github.com/Yamato-Security/hayabusa-rules)
- [Yamato Security blog](https://yamatosecurity.medium.com/)
- [DFIR Report — Hayabusa in practice](https://thedfirreport.com/)

See also: [[windows-event-log-analysis]], [[chainsaw-evtx-hunting]], [[kape-triage-collection]], [[velociraptor-threat-hunting]], [[sigma-rules-detection-as-code]], [[ir-from-source-signals]], [[threat-hunting-methodology]], [[volatility-plugins]]
