---
title: Automate the boring, repeat the rest
slug: automation-and-rinse-repeat
---

> **TL;DR:** Push every mechanical step (recon, fingerprinting, low-noise nuclei templates) into a cron-driven pipeline; keep brain cycles for the manual exploitation that actually pays.

## What it is
A hunter's edge comes from the manual half of the job — reading JS, chaining auth flows, spotting business-logic flaws. Everything that can be expressed as "run X, save output, diff" should run without you. Automation is not about replacing the hunter; it is about making sure that when something new appears on the attack surface you are the first to see it. This is the operating model behind every "step three" recon stack and the prerequisite for [[continuous-recon-automation]].

## Preconditions / where it applies
- You have at least one wildcard program you intend to hunt long-term
- A cheap always-on VPS (or a serverless / GitHub Actions setup) — local laptop will not do scheduled work reliably
- A notification sink you actually read (Slack/Discord webhook, ntfy, Pushover)

## Technique
1. Split the workflow into three layers and only automate the first two:
   - **Layer 1 — Discovery:** subfinder/amass, dnsx, httpx, tlsx. Stable, idempotent.
   - **Layer 2 — Fingerprint and low-noise detect:** nuclei (cves + exposures + tech), gau/waybackurls, katana, [[js-endpoint-extraction]]. Output is structured.
   - **Layer 3 — Manual hunting:** browser + Burp + intuition. Never automate this.
2. Drive Layers 1 and 2 from a single shell or Python orchestrator. Pin tool versions. Run on a schedule (`cron`, `systemd timer`, GitHub Actions `schedule:`). Store output in a content-addressable folder per target per day.
   ```
   0 */6 * * * /opt/recon/run.sh target.tld >> /var/log/recon.log 2>&1
   ```
3. Compute and push only the diff (see [[asset-graphing]]). Three notification classes are enough: `NEW_HOST`, `NEW_TECH_OR_CVE`, `CHANGED_JS_BUNDLE`. Anything else is noise.
4. Build a personal triage SLA: every notification gets 10 minutes max — open it, screenshot, decide hunt-now / queue / drop. Refusing to triage immediately is what kills the pipeline.
5. Tune ruthlessly. Every false positive that fires twice is a filter rule. Every duplicate finding is a dedupe key. The pipeline is a product you maintain, not a one-time script.

## Detection and defence
- For the target: noisy scanners trip WAF rate-limits; throttle, rotate egress IPs, and respect the program's automation clause
- Many programs ban high-volume nuclei runs — read [[program-scope-reading]] before pointing the pipeline at production
- For the hunter: keep an emergency kill-switch (`pkill -f run.sh`) and a rate cap; one runaway scan can get you off a platform

## References
- [TomNomNom — automation primer](https://github.com/tomnomnom) — toolchain that composes well into pipelines
- [Project Discovery docs](https://docs.projectdiscovery.io/) — production-grade chainable recon
- [HackTricks recon methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — end-to-end recon flow this automates
