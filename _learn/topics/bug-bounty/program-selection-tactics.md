---
title: Program-selection tactics
slug: program-selection-tactics
---

> **TL;DR:** Pick programs by tier and freshness: VDPs to practice without payout pressure, public-paid programs for volume, private invites for fresh and uncrowded attack surface. Match the program to your current goal — learning, income, or signature finds.

## What it is
A bounty hunter's program portfolio is as important as a developer's tech stack. The wrong program for your skill and goals is the fastest path to burnout. Selection is a strategic exercise: identify the goal of the next 4-week sprint, then pick 3-5 programs whose properties (payout range, scope size, response time, dupe density) support it.

## Preconditions / where it applies
- Active on at least one platform (HackerOne, Bugcrowd, Intigriti, YesWeHack, self-hosted programs)
- You can articulate your goal for the next month (cash, reputation, learning a new bug class)
- You have data on past performance (your own hit rate per program / per bug class)

## Technique
1. Classify programs by tier:
   - **VDP (no bounty)** — no money, but no competition either. Excellent for practice and for reports that build your H1/BC profile
   - **Public paid** — high competition, high dupe rate, well-known scopes; income is steady once you have a methodology that beats dupes ([[dupe-mental-model]])
   - **Private invite** — fresh scope, less competition, typically higher signal-per-hour. Earn invites via VDP + early-public participation
2. Score each candidate program before committing time:
   - Avg response time (slow triage = capital tied up in pending reports)
   - Median bounty for the severity tiers you usually find
   - Scope size + breadth (wildcards beat single domains for [[continuous-recon-automation]])
   - Recent disclosure activity ("everything found 2 years ago" = stale)
   - Stack alignment with your strengths
3. Build a rotation of 3-5. Mix:
   - 1 "bread and butter" you know cold
   - 1-2 fresh private invites (perishable advantage)
   - 1 learning target (tech stack you want to grow into)
   - 1 VDP for reputation
4. Re-evaluate monthly. Programs go cold; new ones launch. Drop programs where your hit rate has fallen below your hourly threshold and replace with new candidates.
5. Read the small print before investing. Out-of-scope assets, prohibited test types (no rate-limit testing, no DoS, no third-party impact), reward caps. A program that pays $5k max for critical impact may not justify a complex chain.
6. Track meta-metrics personally: hours per program, dollars per hour per program, dupe rate per program. The numbers tell you which targets to fire.

## Detection and defence
- Program operators: bounty competitiveness is a market — under-pricing leads to attrition of skilled hunters; over-pricing attracts spammy low-quality reports. Calibrate based on hunter retention not just submission count
- Private invite quality matters more than quantity for both sides; rolling small batches of trusted hunters into a private beta beats opening a new public program
- For hunters: never participate in a program whose policies you haven't read; out-of-scope reports waste your time and theirs

## References
- [HackerOne directory](https://hackerone.com/directory/programs) — public programs sortable by scope, response time
- [Bugcrowd public programs](https://bugcrowd.com/programs) — alternative platform
- [Intigriti](https://www.intigriti.com/programs) — EU-focused platform
- [Bug Bounty Forum](https://bugbountyforum.com/) — hunter discussions on program quality
