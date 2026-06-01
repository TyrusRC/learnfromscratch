---
title: Target selection heuristics
slug: target-selection-heuristics
---

> **TL;DR:** Mature programs are picked over; bring a novel angle or move to fresh scope, new subsidiaries, or just-launched asset classes. Picking the right target dominates skill.

## What it is
A set of decision rules for choosing which target — and which slice of that target — to spend time on. The bug-bounty market is efficient inside well-trafficked programs; ten thousand hunters have already run `nuclei` against `*.target.tld`. Edge comes from finding the parts they have not yet ground over: new acquisitions, new feature launches, new tech adoption, or applying a new technique class. Closely related to [[program-selection-tactics]] which covers picking *programs*; this note covers picking *which corner of a chosen program* to work.

## Preconditions / where it applies
- You have already chosen a program ([[program-selection-tactics]])
- You have at least a one-day commitment to that target — anything shorter rewards drive-by checks but not deep hunting
- A note system ([[note-taking-while-hacking]]) to record decision rationale

## Technique
Score candidate slices on six axes and pick the highest:

1. **Age of asset.** Newer assets have less coverage. Anything tagged "added in last 30 days" on the program page is a target-of-opportunity.
2. **Novelty of angle.** If you can apply a technique class the target was likely not tested for — request smuggling, prototype pollution, dependency confusion, OAuth misconfig, SSRF via DNS rebinding — old assets become viable again.
3. **Surface volatility.** SPAs that ship a new bundle weekly leak fresh endpoints via [[js-endpoint-extraction]]. Static marketing sites do not.
4. **Tenancy model.** Multi-tenant SaaS with org/workspace isolation almost always has IDOR / cross-tenant bugs somewhere — high ratio of reward to effort.
5. **Acquisition tail.** Recent acquisitions ([[acquisitions-recon]]) often run pre-integration tech with the parent's bounty scope newly extended over it. Six-month window after the press release is gold.
6. **Payout / dupe ratio.** Check the program's published stats — bounty median, time-to-triage, dupe rate. High dupe rate on top assets is the signal to deprioritise them.

Anti-patterns to avoid:
- Picking the largest asset (`www.target.tld`) — everyone has hit it
- Picking based on the most interesting tech alone — a fascinating Kubernetes dashboard nobody can access is worth zero
- Time-investing without a quality bar — set a 4-hour exit checkpoint and rotate if no leads

Practical heuristic stack:
- Spend 20% of time on N-day sweeps ([[n-day-rapid-exploitation]])
- 30% on continuous-recon alerts ([[continuous-recon-automation]])
- 50% on a chosen "deep" slice picked by the six axes above

## Detection and defence
- Programs see hunter focus from report submissions; smart programs explicitly call out under-tested assets on policy pages
- For the hunter: rotate slices every few weeks to avoid burnout ([[burnout-and-pipeline]]) and to detect when a slice has become saturated
- For the defender: publishing "less-tested assets" lists is a known tactic to redirect hunter attention to newly-added scope

## References
- [HackerOne — hacking activity stats](https://www.hackerone.com/resources) — public payout/dupe data per program
- [Bugcrowd Inside the Mind of a Hacker reports](https://www.bugcrowd.com/resources/reports/) — community heuristics
- [HackTricks recon methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — recon basis for target slicing
