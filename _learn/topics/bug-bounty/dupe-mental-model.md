---
title: Dupe mental model
slug: dupe-mental-model
---

> **TL;DR:** A duplicate is a finding someone else reported first. You can't avoid all dupes, but you can predict which surfaces are dupe-saturated and which are still virgin — feature freshness, complexity floor, and scope half-life are the three knobs.

## What it is
Every public bug bounty program has a sediment of low-hanging bugs that hundreds of hunters have already submitted. Working on those surfaces is paid in dupes. The dupe mental model is a heuristic for estimating, before you invest hours, whether a given bug class on a given asset is likely to be fresh or stale.

## Preconditions / where it applies
- A program that has been live more than a few months (newly launched programs have no dupe sediment)
- You can afford to skip "obvious" bugs in favour of harder, fresher attack surface
- You're tracking historical disclosure activity on the program (Hacktivity, public hall-of-fame, changelog)

## Technique
1. Feature freshness — when did the surface ship?
   - New endpoints shipped in the last release notes / blog post / git tag are fresh; thousands of eyeballs haven't crawled them yet
   - Watch the target's status page, release blog, mobile app changelog, npm package versions
   - Subscribe to their GitHub org's tag feed; rebuild your asset graph weekly
2. Complexity floor — how much skill does the bug class require?
   - Low floor (reflected XSS, missing security headers, open redirect on the docs site) → dupes everywhere; don't bother unless you're learning
   - High floor (race conditions, second-order SSRF, OAuth state-confusion across IDPs) → fewer hunters can find or weaponise it; lower dupe rate
3. Scope half-life — how fast does this surface change?
   - A marketing site rarely changes → bugs found years ago still apply → high dupe risk
   - A core API under active development → today's bug didn't exist three months ago → low dupe risk
4. Combine into a dupe probability estimate before committing time:

```
fresh feature + high floor + active scope  = invest, low dupe risk
old feature  + low floor   + static scope  = skip, almost certainly a dupe
```

5. Mitigate the cost of dupes you do hit: report fast (first-to-file wins on ties), keep your submissions short and re-usable, and rotate to fresher targets at the first dupe ([[burnout-and-pipeline]]).
6. Read your own historical close reasons. If you've been duped 8 times on the same kind of finding, the model is telling you something — change targets or change bug class.

## Detection and defence
- Programs publishing changelogs that include security-affecting changes accidentally signal fresh surface to hunters; that's a tradeoff worth making for transparency
- For hunters: maintain a private notes file per program of "what I've reported, what I've seen disclosed publicly, what looks crowded" — call it your dupe map
- Don't take dupes personally. A dupe means your methodology found a real bug; the only cost is opportunity

## References
- [HackerOne Hacktivity](https://hackerone.com/hacktivity) — public dupe data per program
- [Bug Bounty Bootcamp (Li)](https://nostarch.com/bug-bounty-bootcamp) — chapters on program selection and pacing
- [zseano methodology](https://www.bugbountyhunter.com/methodology/) — fresh-surface targeting
