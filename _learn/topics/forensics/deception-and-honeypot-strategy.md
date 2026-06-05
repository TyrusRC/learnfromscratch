---
title: Deception and honeypot strategy
slug: deception-and-honeypot-strategy
aliases: [deception-strategy, honeypot-strategy, canary-tokens]
---

{% raw %}

> **TL;DR:** Deception tech places fake assets — files, credentials, hosts, API tokens — across your environment so any access to them is a high-signal alert. Layered: (1) canary tokens for the cheapest reach, (2) honey-credentials in code and configs, (3) honey-services on internal networks, (4) honey-files on file shares, (5) high-interaction honeypots for adversary characterisation. Goal: shift defender's signal-to-noise advantage. Companion to [[edr-rules-as-code-from-attack-patterns]] and [[ir-from-source-signals]].

## Why deception works

Detection on real assets requires distinguishing legit access from malicious. Deception flips it: nothing legit ever touches the honey-asset, so any touch is malicious by definition.

Trade-off:
- Real assets have lots of activity → noisy detection.
- Honey-assets have zero baseline → 100% signal on alert.

## Layer 1 — canary tokens

Cheapest and broadest. A canary token is a fake credential / URL / file that pings a server when accessed.

Types:
- **DNS canary**: a unique subdomain like `abc123.canarytokens.net`; any DNS resolution alerts.
- **HTTP canary**: a URL that pings when visited.
- **AWS API key canary**: looks like an `AKIA...` key; if anyone tries to use it, CloudTrail fires.
- **Word/PDF document canary**: opens with an embedded URL fetch.
- **SQL canary table**: a row that, when read, pings via a trigger.
- **WireGuard / VPN config canary**: configured client → ping on connect attempt.

Tools:
- [Thinkst Canary](https://canary.tools/) — commercial.
- [canarytokens.org](https://canarytokens.org/) — free, by Thinkst.
- Self-host via DNS+HTTPS server you control.

Deploy widely:
- README files in every repo.
- Last entry in `bash_history`.
- Stub admin in user directory.
- "Don't access — for executives" file on every share.

## Layer 2 — honey credentials

Plant credentials in places attackers look:
- Bash history.
- AWS credentials file with a fake `AKIA...` (canary).
- Slack message in a #ops channel "@kim, the staging DB is at db.staging.tld; creds in 1Password".
- Notion page "Important keys" with fake key.

When attacker enumerates `~/.aws/credentials` and tries the key → CloudTrail fires.

## Layer 3 — honey services

Stand up fake services in internal networks:
- Phantom RDP at the IP attacker would expect a jump host.
- Fake Redis with a `keys *` returning interesting names.
- Phantom Jenkins login page.
- Fake S3-compatible endpoint.

Even a basic listener that logs the connection attempt is enough.

Tools:
- [T-Pot](https://github.com/telekom-security/tpothoneypot) — combined honeypot framework.
- [HoneyDB](https://honeydb.io/) — high-interaction honeypots.
- [Cowrie](https://github.com/cowrie/cowrie) — SSH/Telnet medium-interaction.

## Layer 4 — honey files

Files attackers grep for:
- `passwords.xlsx` in HR's shared drive (with a canary).
- `production-creds.txt` on every server.
- `aws-prod.json` in `/etc/`.
- `confidential.docx` in C-suite's OneDrive.

Each file is a canary; any open / copy event alerts.

Detection at the file-system level requires Windows audit / Linux auditd / Defender for Endpoint file-monitor rule.

## Layer 5 — high-interaction honeypots

For threat-intel and adversary-characterisation work, run full honeypots that interact convincingly:
- Cowrie / Kippo for SSH (captures commands, downloaded files).
- Conpot for ICS protocols.
- ElasticHoney for Elasticsearch.
- Modbus pots for SCADA recon.

Output: real attacker tooling and TTPs you can feed into rules.

## Placement strategy

For each layer, ask: where would an attacker look?
- After foothold on a workstation: bash history, browser saved passwords, network shares.
- After getting cloud access: IAM keys in code, S3 bucket listings.
- After AD enumeration: groups with names like `Administrators`, `Backup Operators`.
- After web foothold: `.env`, `config.json`, `wp-config.php`.

Plant at each stage.

## False positives

Real users sometimes click canary files (curiosity, "what's this?"). Each canary should answer:
- Is this user-facing enough to alert in normal use?
- If so, lower-priority routing.
- Document the false-positive playbook so the SOC doesn't chase.

## Reporting on alerts

When a canary fires:
- Who accessed (user, host, IP).
- What canary (type, location).
- Time + frequency.
- Correlated activity (other alerts, EDR events).

A single canary alert is rarely the whole picture; correlate with EDR + audit logs.

## OPSEC for defenders

- Don't name canaries obviously ("honey-creds.txt") — attackers learn.
- Don't email about canaries on internal mail systems — attackers reading.
- Rotate canary tokens periodically.
- Test canaries via a chaos-engineering pass — confirm they still alert.

## What deception doesn't replace

- Real EDR / SIEM.
- Network segmentation.
- Patching.
- Threat modelling.

It augments by reducing time-to-detect and raising attacker cost.

## OSCP/OSEP relevance

For OSEP-style red-team operations: knowing what deception tech exists means avoiding it.
- Don't `cat` files that look too convenient.
- Treat any "discovered" credential as potentially-canary.
- Test stolen credentials only when ready to commit; CloudTrail alert is permanent.

The mature red-team OPSEC checklist includes "looked too easy" as a red flag.

## Implementation cost

Cheap layer (tokens):
- Thinkst Canary: $5-15k/yr for small org; free tier via canarytokens.org.
- Self-host: weekend project.

Pricey layer (high-interaction):
- Engineering ramp; dedicated VLAN; monitoring pipeline; ongoing tuning.

Most orgs get 80% of the benefit from tokens + file-share canaries alone.

## References
- [Thinkst — Canary blog and tools](https://blog.thinkst.com/)
- [SpecterOps — deception research](https://posts.specterops.io/)
- [MITRE Engage](https://engage.mitre.org/) — framework for adversary engagement
- [HoneyDB / The Honeynet Project](https://www.honeynet.org/)
- See also: [[edr-rules-as-code-from-attack-patterns]], [[ir-from-source-signals]], [[opsec-fundamentals]], [[purple-team-feedback-loop]]

{% endraw %}
