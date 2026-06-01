---
title: Continuous recon (diff-on-change)
slug: continuous-recon-automation
---

> **TL;DR:** Run your enumeration stack on a schedule, store baseline state, and push a webhook only when something is new — a fresh subdomain, a changed JS bundle, a freshly-exposed admin panel.

## What it is
Continuous recon turns the one-shot "first day on a target" enumeration into a heartbeat. The pipeline ([[automation-and-rinse-repeat]], [[asset-graphing]]) runs every few hours; output is compared to the previous snapshot; only the delta is notified. The signal you care about is *change* — new attack surface, new technology, new content — because that is when defenders have not yet caught up.

## Preconditions / where it applies
- A wildcard or large fixed-scope program where the attack surface is non-stationary
- A small always-on host (cheap VPS, EC2 t4g, or GitHub Actions on a `schedule:` trigger)
- Stable storage (S3, git repo, sqlite on persistent disk) for the baseline; ephemeral CI runners lose state otherwise

## Technique
1. Define one source of truth per target — a directory keyed by date:
   ```
   ~/recon/target.tld/2026-06-01/{subs.txt,httpx.json,nuclei.json,js.txt,fav.txt}
   ```
2. The orchestration script chains the usual tools. Keep it boringly imperative — exotic frameworks rot:
   ```bash
   subfinder -d target.tld -all -silent > subs.txt
   dnsx -l subs.txt -resp -silent > dns.txt
   httpx -l subs.txt -json -title -tech-detect -favicon -o httpx.json
   nuclei -l subs.txt -t cves/ -t exposures/ -severity medium,high,critical -j -o nuclei.json
   ```
3. Diff against the previous run with `comm` / `jq` / a small Python script. Three signals are usually enough:
   - `comm -13 yesterday/subs.txt today/subs.txt` → new hosts
   - `jq '.[].favicon_mmh3' httpx.json | sort -u` diff → new tech (Jenkins, GitLab, phpMyAdmin favicons jump out)
   - bundle hashes from [[js-endpoint-extraction]] changing → re-extract endpoints
4. Push only the delta through `notify` (Project Discovery), a Discord webhook, or ntfy. Format short: `[NEW] api-stage.target.tld 200 nginx [jenkins-favicon]` so triage is one tap.
5. Tag each notification with the original baseline date so you can prove freshness in your report ("this host did not exist 12h before disclosure").

## Detection and defence
- Defenders see a steady low-volume scan from your egress; rate-limit and rotate IPs to stay polite within program rules
- Some programs explicitly forbid continuous scanning — read [[program-scope-reading]] before deploying
- For the target: subscribing to the same CT firehose ([[certificate-transparency]]) closes the window you are exploiting

## References
- [projectdiscovery/notify](https://github.com/projectdiscovery/notify) — webhook multiplexer for recon pipelines
- [projectdiscovery/subfinder](https://github.com/projectdiscovery/subfinder) — passive subdomain layer
- [HackTricks external recon methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — the wider flow this loops
