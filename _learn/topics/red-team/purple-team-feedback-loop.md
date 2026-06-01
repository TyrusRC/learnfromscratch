---
title: Purple-team feedback loop
slug: purple-team-feedback-loop
---

> **TL;DR:** Run a technique, ask the SOC exactly what fired, tune the payload or the procedure, re-run. The fastest path from "default tooling" to "operator-grade tradecraft."

## What it is
A purple-team engagement is red and blue working in the same room, coordinated by a planned set of TTPs. Unlike a black-box red team, the value is in the iteration: each run produces a detection signal, a missed signal, or a partial signal — the team analyses it and adjusts. Over a week you compress what would take a year of solo trial-and-error.

## Preconditions / where it applies
- A blue team with real-time SIEM/EDR access and the will to share what they see
- A red operator willing to repeat actions with tweaks
- A planning doc mapping each step to MITRE ATT&CK so results are catalogued

## Technique
**Plan structure (typical sprint).**
1. Pick a chain — e.g. initial access → execution → defence evasion → credential access → lateral.
2. For each step, define: the action, the tool, the expected telemetry (Sysmon event ID, EDR alert name, AV signature), and the success criterion ("we executed without alerting" or "we executed and alert fired with severity X").
3. Execute step. Blue confirms whether telemetry matches expectations.
4. If alerted: capture the rule name, the field that triggered. Red modifies — sleep change, signed binary swap, profile change. Re-run.
5. If silent: ask blue to write a detection from the available telemetry. Re-run with the new rule active.

**Tracking artifact.** A shared spreadsheet (or VECTR) per technique:
- ATT&CK ID
- Tool/command used
- Detection result (alert | telemetry only | silent)
- Detection rule reference
- Notes / variant used
- Detection improvement after iteration

**Common iteration patterns.**
- *AMSI bypass burns* → swap to obfuscated variant → swap to hardware-breakpoint variant → swap to no-bypass via dotnet-assembly-only load
- *Cobalt Strike default profile alerts* → switch to custom Malleable C2 → tune jitter + sleep mask → switch transport
- *Lateral via PsExec alerts* → switch to WMI → switch to WinRM → switch to scheduled task
- Each iteration teaches the blue team something specific to write a rule for

**Outcome documentation.**
- Per-technique: detection coverage matrix (executed / detected / response time)
- Per-tool: what configuration is still effective in this environment
- Per-rule: confidence + false-positive rate after exercise

## Detection and defence
- The whole point is to improve detection. Each iteration ends with a new SIEM rule, a new EDR custom indicator, or a confirmed gap that goes on the backlog
- Tabletop summary: which ATT&CK techniques are now detected vs which still need work
- Reusable atomic tests (Atomic Red Team) feed back into automated CI for the SOC

## References
- [SCYTHE — Purple Team Exercise Framework](https://www.scythe.io/ptef) — published framework
- [Atomic Red Team](https://atomicredteam.io/) — library of small, scriptable adversary tests
- [VECTR](https://vectr.io/) — purple-team tracking tool
- [MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/) — coverage visualisation
- [[opsec-fundamentals]]
