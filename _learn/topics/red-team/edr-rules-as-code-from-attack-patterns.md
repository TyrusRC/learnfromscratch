---
title: EDR rules-as-code from attack patterns
slug: edr-rules-as-code-from-attack-patterns
aliases: [edr-rules-as-code, detection-engineering]
---

{% raw %}

> **TL;DR:** Detection engineering turns red-team tradecraft into running rules. The pipeline: study an attack technique → identify telemetry signals it must produce → write a rule (Sigma, KQL, Splunk SPL, EDR-vendor DSL) → tune for false positives → land in CI alongside the rule corpus. The goal isn't to alert on every attack — it's to alert *deterministically* on attack patterns the team has chosen to detect. Companion to [[purple-team-feedback-loop]] and [[ir-from-source-signals]].

## The four-step pipeline

1. **Technique selection** — usually MITRE ATT&CK technique IDs (T1059, T1003, T1078...).
2. **Telemetry mapping** — which sensor produces which event.
3. **Rule authoring** — Sigma (vendor-neutral) → translate per platform.
4. **Tuning + deploy** — ship via git, measure FP rate, decommission stale rules.

## Step 1 — pick attacks worth detecting

Not every attack technique merits a rule. Triage:

| High-value | Low-value |
|---|---|
| Used by adversaries against your sector | Rare in the wild |
| Hard to bypass without changing approach | Cosmetic; trivial bypass |
| Telemetry is reliable | Requires log sources you don't have |
| Low false-positive ceiling | Generates 1000 events/day baseline |

Pull adversary profiles from MITRE ATT&CK Navigator for your sector (FIN6, APT29, Conti, etc.). Map their techniques; prioritise.

## Step 2 — telemetry mapping

For each technique, list the events that *must* fire when the attack runs.

T1059.001 — PowerShell:
- Sysmon EventID 1 (process create) with `Image=powershell.exe` or `pwsh.exe`.
- Sysmon EventID 10 (process access) on lsass.exe.
- Windows EventID 4104 (PowerShell ScriptBlock logging).
- Windows EventID 800/4103 (module/pipeline logging).

If you don't have ScriptBlock logging enabled, that detection class won't work. Confirm before writing.

## Step 3 — write the rule in Sigma

Sigma is vendor-neutral; translates to Splunk SPL, Elastic EQL/KQL, Microsoft KQL, CrowdStrike LogScale, etc.

```yaml
title: PowerShell with suspicious encoded command
id: 1a2b3c4d-5e6f-7g8h-9i0j-k1l2m3n4o5p6
status: experimental
description: Detects PowerShell invocations with -EncodedCommand and base64 payloads
references:
  - https://attack.mitre.org/techniques/T1059/001/
author: detection-eng-team
date: 2026/06/05
tags:
  - attack.execution
  - attack.t1059.001
logsource:
  product: windows
  category: process_creation
detection:
  selection_img:
    Image|endswith:
      - '\powershell.exe'
      - '\pwsh.exe'
  selection_cmd:
    CommandLine|contains:
      - ' -enc '
      - ' -EncodedCommand '
      - ' -ec '
  condition: selection_img and selection_cmd
falsepositives:
  - DevOps tooling that uses encoded commands
level: medium
```

Translate:
```bash
sigma convert -t splunk powershell-encoded.yml
sigma convert -t kql   powershell-encoded.yml
```

## Step 4 — tune for false positives

A rule with > 1 FP/day per host is a rule the team will mute.

Steps:
1. Run the rule in *audit mode* (no alert; collect matches) for one week.
2. Review every match. Tag as TP, FP, or "informational".
3. Add exception clauses to push FP-rate below threshold.
4. Promote to *alert mode*.

```yaml
filter:
  CommandLine|contains:
    - 'DevopsScript.ps1'        # known good
    - 'ScheduledTask=BackupJob' # known good
condition: selection_img and selection_cmd and not filter
```

## Storage and rollout

Rules live in git, like code:

```
detection-rules/
  README.md
  CONTRIBUTING.md
  rules/
    execution/
      t1059-001-powershell-encoded.yml
      t1059-003-cmd-suspicious.yml
    credential-access/
      t1003-001-lsass-dump.yml
    ...
  tests/
    t1059-001-test-events.json
```

CI:
- `sigma check` validates syntax.
- Unit tests with synthetic events confirm rule matches what it should.
- Conversion to platform DSL produces artefacts uploaded to SIEM/EDR via API.
- Rule deprecation requires PR + review.

## Common detection categories

| Category | Anchor events |
|---|---|
| Credential dumping (LSASS) | Sysmon 10 access to lsass.exe with `GrantedAccess=0x1010` |
| Mimikatz | command-line containing `sekurlsa::logonpasswords` / known PE imports |
| Persistence via Run keys | Sysmon 13 (registry value set) on `HKLM\...\Run` |
| WMI persistence | Sysmon 19/20/21 on EventSubscription |
| Scheduled-task creation | Windows 4698 |
| LOLBin abuse | process create with parent / arg / hash patterns |
| AMSI bypass | PowerShell 4104 with known patterns; AMSI failure events |
| ASR rule triggered | Defender 1121/1122 |

## Detection-as-code anti-patterns

- **Detection by hash** — adversary recompiles, bypass.
- **Detection by ImageFileName** — adversary renames `mimikatz.exe` to `update.exe`.
- **Detection by command-line literal** — adversary changes case, encoding, splits string.
- **Detection on a single event** — single events get tuned out; chain multiple correlations.

Better:
- Behavioural — LSASS access by a non-system process.
- Frequency — N events of type X within Y minutes.
- Anomaly — process spawns child it's never spawned in the baseline.
- Sequence — process A spawns process B which writes file C, all within seconds.

## Atomic Red Team integration

Atomic Red Team (Red Canary) provides MITRE-aligned per-technique tests:

```bash
git clone https://github.com/redcanaryco/atomic-red-team
cd atomic-red-team/atomics/T1059.001
# follow tests; each test should trigger your rule
```

CI loop: nightly, run a subset of atomics in a controlled VM; verify rules fire; alert if any expected fire is missing.

## SOC handoff

For each rule, document:
- **What it detects** — plain-English description.
- **What an analyst should do first** — runbook link.
- **Common false-positive patterns** — context for triage.
- **Severity rationale** — why it's a "high", not a "medium".
- **Owner** — team or person to ping.

Without these, the SOC ignores or auto-closes alerts; the rule "works" but produces no IR value.

## Bridging to the red team

The purple-team loop ([[purple-team-feedback-loop]]):
- Red team runs technique.
- Detection team observes detection (or non-detection).
- Detection team writes/updates rule.
- Red team verifies bypass technique still works (or finds new variant).
- Repeat.

This is how mature programmes evolve. The OSEP-shaped attack chain ([[osep-full-chain-walkthrough]]) maps directly to a detection backlog.

## Anti-detection by the red team

For OSEP-style operations:
- Read your customer's published detection-rule corpus (if any).
- Identify the assumptions each rule makes (image name, command-line shape, parent process).
- Pick a technique that violates none of the assumptions.

The red team's job in detection-mature orgs is *not* finding a bug — it's finding a technique without a rule. Detection engineering's job is shrinking that gap.

## References
- [Sigma](https://github.com/SigmaHQ/sigma)
- [MITRE ATT&CK](https://attack.mitre.org/)
- [Atomic Red Team](https://atomicredteam.io/)
- [Splunk Surge — detection engineering](https://www.splunk.com/en_us/blog/security.html)
- [Red Canary — detection engineering posts](https://redcanary.com/blog/)
- See also: [[purple-team-feedback-loop]], [[ir-from-source-signals]], [[osep-full-chain-walkthrough]], [[opsec-fundamentals]]

{% endraw %}
