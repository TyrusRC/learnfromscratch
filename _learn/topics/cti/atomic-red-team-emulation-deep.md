---
title: Atomic Red Team / adversary emulation deep dive
slug: atomic-red-team-emulation-deep
aliases: [atomic-red-team, art-deep, adversary-emulation]
---

> **TL;DR:** Atomic Red Team (ART, Red Canary) is the most-adopted open-source library of attack-emulation tests, organised by MITRE ATT&CK technique. Each test is a small executable action with prerequisites + cleanup. Used for: testing whether detections trigger, building purple-team exercises, training analysts, and validating coverage. Complements (not replaces) full red-team exercises. Companion to [[detection-engineering-pyramid-of-pain]] and [[purple-team-feedback-loop]].

## Why ART

- **Pre-built test library** of 1000+ tests across ATT&CK.
- **Cross-platform** — Windows, Linux, macOS, AWS, GCP, Azure, K8s, containers.
- **Free + community-maintained**.
- **Standardised format** — YAML defining test name, ATT&CK ID, command, prerequisites, cleanup.
- **Invoke-AtomicRedTeam (Powershell)** + **Atomic Red Team Cli** wrappers.

## ART structure

Each test has:
```yaml
- name: "Test technique with X"
  auto_generated_guid: "..."
  description: "..."
  supported_platforms: [windows]
  input_arguments: { ... }
  dependency_executor_name: powershell
  dependencies: [...]
  executor:
    command: |
      <command to run>
    cleanup_command: |
      <cleanup>
    name: command_prompt
    elevation_required: true
```

Test library at `atomic-red-team/atomics/Txxxx/Txxxx.yaml`.

## Use cases

### 1. Detection validation

For each detection you've written:
- Find ART test for the technique.
- Run the test.
- Verify detection triggers.
- If not, fix detection or test.

### 2. Coverage assessment

For each ATT&CK technique you claim to cover:
- Run ART tests for it.
- Coverage = tests detected / tests run.

### 3. Purple-team exercise

- Blue team unaware which tests will run.
- Red team runs sequence of ART tests representing a campaign.
- Blue identifies as much as possible.
- Debrief shows gaps.

### 4. Analyst training

- New SOC analyst sees real attack telemetry.
- Walks through what each ART test produced.
- Trains on detection / response.

### 5. SIEM rule pre-deployment testing

- Before rule deploys to production, run ART test.
- Verify rule fires.
- Verify acceptable false-positive baseline.

## Running ART

### PowerShell (Invoke-AtomicRedTeam)

```powershell
Install-Module -Name invoke-atomicredteam,powershell-yaml
Invoke-AtomicTest T1059.001 -GetPrereqs
Invoke-AtomicTest T1059.001
Invoke-AtomicTest T1059.001 -Cleanup
```

### Atomic Operator CLI

Python-based; lets you run ART tests with a single command line.

```sh
atomic-operator run -t T1059.001
```

### Caldera

MITRE's adversary emulation platform; consumes ART + custom plugins; orchestrates complex scenarios.

## Beyond ART — full emulation

ART tests individual techniques. Real adversary emulation chains them:

### CALDERA (MITRE)

- Free, full emulation platform.
- Plugins for specific actors.
- Decision-tree-style operations.

### CALDERA, Vectr, AttackIQ, SafeBreach

- Commercial breach-and-attack simulation (BAS) platforms.
- Continuously test environment against simulated adversaries.

### Purple-team scenarios

- Pick an actor (e.g., APT29).
- Map their TTPs to ART tests.
- Run as a sequence over days / weeks.
- Measure detection / response per stage.

## Building custom atomics

If you have a unique detection, write a custom ART YAML:

```yaml
- name: "Detect my unusual thing"
  description: "..."
  supported_platforms: [windows]
  executor:
    name: command_prompt
    command: |
      <test command>
    cleanup_command: |
      <cleanup>
```

Contribute back to community or keep internal.

## ART caveats

- Tests trigger **standard signatures** — won't bypass production EDR; that's the point (validates detection).
- For evasion testing, you need **modified tools or custom techniques** — closer to actual red team.
- Some tests have **side effects** — modify registry, create files. Cleanup is important.
- Always **test in lab first**.

## Common gotchas

- **Permissions** — many tests need admin / specific roles.
- **Cleanup** — incomplete cleanup leaves artefacts.
- **Antivirus interference** — Defender / AV may block tests; need to allow.
- **Telemetry pipeline lag** — wait for events to propagate before judging "not detected".

## Workflow to study

1. Install Invoke-AtomicRedTeam.
2. Run T1059.003 (Windows Command Shell) — observe Windows Event 4688 / Sysmon process create.
3. Build a detection in your SIEM for it.
4. Re-run; observe detection.
5. Move to more complex techniques.

## Programme integration

For mature detection engineering:

- **Quarterly run** of ATT&CK coverage tests.
- **Per-detection commit** runs the relevant ART test in CI.
- **Annual purple team** with ART-based campaign.
- **Coverage tracking** in ATT&CK Navigator.

## Detection-as-code coupling

```
detection rule (Sigma) → SIEM
        ↓
atomic test (ART YAML) → validates detection
        ↓
ci pipeline runs test against test SIEM → pass/fail
```

This is the modern detection-engineering workflow.

## Related

- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[cti-collection-management]]
- [[purple-team-feedback-loop]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[ransomware-affiliate-playbook]]
- [[building-a-research-home-lab]]

## References
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [Invoke-AtomicRedTeam](https://github.com/redcanaryco/invoke-atomicredteam)
- [Atomic Operator CLI](https://github.com/swimlane/atomic-operator)
- [MITRE Caldera](https://caldera.mitre.org/)
- [Red Canary blog](https://redcanary.com/blog/)
- See also: [[detection-engineering-pyramid-of-pain]], [[cti-collection-management]], [[purple-team-feedback-loop]], [[edr-rules-as-code-from-attack-patterns]], [[caldera-mitre-emulation]], [[sigma-rules-detection-as-code]]
