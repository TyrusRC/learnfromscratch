---
title: Note-taking while hacking
slug: note-taking-while-hacking
---

> **TL;DR:** Notes during a session are the single biggest force multiplier in bug bounty. Capture parameter behaviour, oddities, hypotheses, and dead-ends so future-you (or tomorrow-you) doesn't redo the work and so a half-finished chain becomes a finishable one.

## What it is
A working note system is a personal knowledge base that turns ephemeral session findings into compounding intelligence. Without it, every return to a target re-spends the discovery hours; with it, each session builds on the last. Notes are the substrate that makes [[expanding-attack-surface]] and [[demonstrating-impact]] tractable on long-running programs.

## Preconditions / where it applies
- Any active testing session longer than 30 minutes
- Multi-day or multi-week engagement on the same target
- A pipeline of more than one target ([[burnout-and-pipeline]])

## Technique
1. Pick a structure that scales. Per-target directory with sub-pages — Obsidian, Logseq, Notion, a plain folder of Markdown all work. Layout:

```
/notes/programs/<target>/
  overview.md           # scope, in/out, payout ranges, last reviewed
  assets.md             # hosts, IPs, ASN, cloud accounts
  endpoints.md          # interesting URLs + what they do
  oddities.md           # weird headers, error messages, unknowns
  ideas.md              # hypotheses to test
  reports/<bug>.md      # one per submission
  session-log.md        # one line per session: date, hours, outcome
```

2. Write to a request log. For every interesting request:

```
## /api/v2/orders/:id  (2026-05-30)
- Returns 200 for own orders, 403 for others
- Tried IDOR via X-Real-User-Id header -> still 403
- Tried /api/v1/orders/:id -> 404 (no v1)
- Tried POST same body -> 405 (PUT works, no auth check!)
- TODO: explore PUT for write-side IDOR
```

That last line is gold — it's the thread you pick up tomorrow.
3. Capture screenshots and curl repros inline. Future-you will not remember which click reproduced the bug. Save `curl -i` of the bad and good request side by side.
4. Maintain an "oddities" file. Anything you don't understand at the time — strange cookie, unfamiliar header, undocumented endpoint, weird redirect, anomalous response time. Half of these become bugs once the pattern crystallises.
5. Idea triage. The `ideas.md` file is your backlog. After each session, review it; promote one idea to next session's focus.
6. After every report submitted, write a 5-line retro: what worked, what didn't, what to try next on this program. These compound into your personal methodology.

## Detection and defence
- For hunters: notes containing live credentials or PII are a leak risk — store in an encrypted vault, never commit to a public repo, redact before sharing
- Periodically prune. Old programs go cold; archive their notes to keep the active workspace focused
- For team red teams: shared notes systems with role-based access avoid duplicate effort and let multi-day chains span team members

## References
- [Obsidian for hackers](https://obsidian.md/) — Markdown-based personal KB, plugin ecosystem
- [Bug Bounty Bootcamp (Li)](https://nostarch.com/bug-bounty-bootcamp) — chapter on personal methodology
- [zseano methodology](https://www.bugbountyhunter.com/methodology/) — note-keeping examples in practice
