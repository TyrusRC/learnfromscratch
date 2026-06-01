---
title: Burnout and pipeline
slug: burnout-and-pipeline
---

> **TL;DR:** Bug bounty is a long-tail income stream and a long-tail attention drain. Pace yourself with a multi-target rotation, explicit walking-away rules, and a paying-vs-learning split so a dry month doesn't end the career.

## What it is
Burnout is the silent attrition mechanism in bug bounty. Most hunters quit not because they stopped finding bugs but because the variance — paid weeks followed by zero-result months — exhausts motivation. A pipeline is the workflow scaffolding that makes the variance survivable: which targets are "in rotation" right now, how long you stay on one before switching, what counts as a session win, and when you stop for the day.

## Preconditions / where it applies
- You are hunting more than 5 hours/week sustainably; below that the variance doesn't bite
- You depend on bounty income or treat it as a primary skills-building activity (high stakes)
- You notice yourself returning to the same target out of habit, or staying up past your usable cognition window

## Technique
1. Run 3-5 targets in rotation, never one. Categorise each:
   - **Bread and butter** — a program you know cold, low payouts but reliable dupes-aside finds
   - **Fresh** — a new private invite or recently scoped asset, high payout potential, high competition timer
   - **Learning** — a tech stack you want to grow into; not where you bill hours
2. Time-box every session. 90-120 minute focused blocks beat 8-hour grinds. After each block, force a decision: continue this target, rotate, or stop.
3. Walking-away rules — pre-commit before the session:
   - "If I haven't found anything interesting in 2 sessions, rotate"
   - "If a single bug has taken >4 hours of impact-building, write it up at current severity and submit"
   - "Friday evening I do recon automation maintenance only, no hunting"
4. Keep a session log (one line per session in your notes — see [[note-taking-while-hacking]]): target, hours, outcome, mood. Patterns surface in weeks; you'll see exactly which targets are net negative.
5. Diversify income mentally. Treat bounty as one income stream alongside salary, contracting, or content. The "must-pay-rent" framing kills creativity — and creativity is the asset.
6. Off-keyboard recovery — sleep, exercise, hobbies that aren't sec — directly compound bug-finding capacity. The boring half is half the job.

## Detection and defence
- Watch yourself for these signals: doom-scrolling Burp history without forming hypotheses; submitting low-quality reports to "lock in" the day; obsessing over a single program's leaderboard; physical stress symptoms before opening laptop
- Counter-moves: rotate target, take a 48-hour break, downgrade hours, switch to a learning target with no income expectation
- Communities (Discord, Twitter) amplify both highs and lows — mute leaderboard talk during dry stretches

## References
- [Bug Bounty Forum — community](https://bugbountyforum.com/) — hunter-written posts on pacing and recovery
- [Programs and people threads on r/bugbounty](https://www.reddit.com/r/bugbounty/) — anecdotes about variance, rotation
