---
title: Bug bounty methodology
slug: bug-bounty-methodology
aliases: [bug-bounty]
---

> Bug bounty is the discipline of turning technical knowledge into paid
> reports. The skills are roughly: pick the right target, recon at the
> right depth, find an actual bug, prove impact, write it up so triage
> resolves it on first read.

## Prereqs

- [[web-application-security]] stage 1.
- A scriptable workflow — Bash, Python, or Go.

## Stage 1 — target selection and scope

- [[program-scope-reading]] — what every clause actually means.
- [[target-selection-heuristics]] — pick mature scope only if you have
  novel angle; otherwise pick fresh scope.
- [[asset-graphing]] — apex, subdomain, ASN, source-of-truth diff.

## Stage 2 — recon

- [[subdomain-enumeration]] — passive + active sources.
- [[content-discovery]] — wordlists, smart fuzzing,
  [`ffuf`](https://github.com/ffuf/ffuf).
- [[js-recon]] — secrets, endpoints, parameters in client bundles.
- [[github-recon]] — dorks, code-search, leaked tokens.
- [[third-party-recon]] — vendor SaaS hosted under target.
- Recon stacks: [recon-ng], [Amass], [Subfinder], [httpx], [nuclei],
  [GoSpider], [katana].

## Stage 3 — execution and reporting

- [[testing-methodology-checklists]] — per-bug-class checklist,
  applied per endpoint.
- [[report-writing]] — title, summary, repro, impact, recommendation,
  CVSS where relevant.
- [[demonstrating-impact]] — when to chain, when to stop.
- [[dupe-mental-model]] — predicting when something has already been
  found.
- [[disclosure-and-comms]] — tone, escalation, mediator usage.
- [[burnout-and-pipeline]] — the boring part nobody talks about.

## References

- *Bug Bounty Bootcamp* (Vickie Li).
- *Real-World Bug Hunting* (Peter Yaworski).
- *The Web Application Hacker's Handbook* (Stuttard, Pinto) — still the
  reference text for chained logic bugs.
- Jason Haddix — *The Bug Hunter's Methodology* talks (latest edition).
- [zseano's methodology](https://www.bugbountyhunter.com/).
- HackerOne / Bugcrowd disclosed reports — read 200 of them.
