---
title: Live Hacking Event (LHE) playbook
slug: live-hacking-event-playbook
aliases: [h1-lhe, bugcrowd-bash, live-event-bb]
---

> **TL;DR:** Live Hacking Events (HackerOne LHE, Bugcrowd Bash) are invite-only, multi-day sprints where a curated group of hunters hammers a single program with on-site triage, live bonuses, and MVP awards. Winning requires pre-event recon, on-event pacing, and social capital with program staff and peers. This is the field guide companion to [[hackerone-platform-deep]], [[bugcrowd-platform-deep]], [[collaborative-bug-bounty-hunting]], and [[testing-methodology-checklists]].

## Why it matters

Live Hacking Events compress months of bug bounty value into 3-5 days:

- **Concentrated payouts.** Live bonuses, MVP, "Most Valuable Hacker", "Best Collaboration", "Best Report" awards stack on top of base bounties. Top hunters routinely six-figure a single event.
- **Direct line to the program.** You sit in the same room (or Discord/Zoom) as security engineers, triage, and product owners. Bugs that would normally take weeks to triage get accepted in hours.
- **Career rocket fuel.** Invites compound: do well once, get invited again. Networking with peers from [[collaborative-bug-bounty-hunting]] often turns into long-term collab squads.
- **Program insight.** You see how the company actually thinks about risk — input that shapes future hunting per [[program-selection-tactics]] and [[target-selection-heuristics]].

LHEs are also where reputational damage is loudest: dupes, weak reports, and bad-faith disclosure get noticed by everyone. The [[dupe-mental-model]] and [[report-writing-step-by-step]] disciplines matter more here, not less.

## How invites work

### Selection criteria

Platforms use a blend of signals:

- **Reputation/rank** on the platform (top N hunters; H1 uses reputation + signal + impact; Bugcrowd uses Priority/Points and trust score).
- **Recent activity on the target program** — already-invited private program participants get priority.
- **Skill match.** A cloud-heavy LHE will pull hunters strong in [[cloud-red-team]] and [[aws-imds-ssrf-pivot]]; a mobile-heavy event pulls [[mobile-security]] specialists.
- **Behavior signals.** Clean disclosure history, no platform violations, professional comms (see [[disclosure-and-comms]]).
- **Diversity & region.** Platforms try to balance regions and skill domains.

### Invite cadence

- Invites land 4-8 weeks before the event via private platform DMs.
- An NDA and a logistics survey come first. Sign quickly — slots are sometimes capacity-limited.
- Travel, hotel, and per-diem are typically covered for in-person attendees. Remote slots are offered for hunters who can't travel.

## Event formats

### In-person

- 3-5 day on-site sprint, usually at the company HQ or a hotel ballroom.
- Day 0 is briefing + scope walkthrough + sometimes a Capture-the-Flag-style warmup.
- Days 1-N are hacking with rolling triage. Live leaderboard often projected on a screen.
- Final night: awards ceremony, MVP, dinner, group photo.

### Remote-only / hybrid

- Same structure compressed onto Discord/Zoom + a dedicated submission queue.
- No travel, but you lose hallway access to engineers — compensate by being aggressive in chat channels.

### Themed events

- Some are scoped narrowly: "all mobile", "all GraphQL", "all AI features", "all new acquisitions". Pre-event prep should match — review [[graphql-attacks]], [[mobile-security]], or [[llm-application-source-review]] depending on the focus.

## Prize structure

Typical award stack:

- **Base bounties** at standard program rates (sometimes 1.5-2x multipliers during the event window).
- **Live bonuses** for first-to-report on a specific bug class (e.g., "first auth bypass: +$5k").
- **MVH / MVP** — top earner or top impact, judged by panel. Often $10-50k.
- **Most Valuable Report** — best-written single report. Bonus reward for [[report-writing]] excellence.
- **Best Collaboration** — joint submissions; see [[collaborative-bug-bounty-hunting]] for splits.
- **Best Newcomer** — first-time LHE attendees.
- **Audience choice / fan favorites** — voted by peers.

Stacking matters: a P1 + first-to-report + MVP nomination can 5x a single bug's headline payout.

## Pre-event recon

### Scope confirmation

- Read the LHE scope doc carefully. It often differs from the public program: more assets in scope, sometimes including pre-prod or unreleased features.
- Apply [[program-scope-reading]] and [[scope-vertical-vs-horizontal]] thinking. Note any exclusions explicitly.

### Asset mapping

- Run continuous recon ([[continuous-recon-automation]]) on the in-scope perimeter starting the day invites go out.
- Build a target inventory: subdomains, mobile apps, APIs, third-party integrations. Cross-reference with [[expanding-attack-surface]] tactics.
- Snapshot baseline behavior so you can detect feature flags or new code drops during the event.

### N-day prep

- Check disclosed reports on the same program ([[h1-disclosed-report-reading-method]]) and any recent CVEs in their stack ([[n-day-rapid-exploitation]], [[one-day-from-patch-diff]]).
- Build a private wiki page of every soft spot you've noticed on past engagements.

### Tooling readiness

- Burp + Caido projects pre-configured per target.
- Auth tokens / test accounts requested ahead of time — programs usually provision LHE-specific accounts.
- Mobile devices flashed and pinned with [[ssl-pinning-bypass]] / [[frida-hook]] ready.
- VPN / proxy config tested. Live event Wi-Fi is hostile; bring your own LTE backup.

### Team formation

- Decide solo vs. squad before invites finalize. Use [[collaborative-bug-bounty-hunting]] to formalize splits in writing.
- Squad strengths should complement: one recon specialist, one web/auth, one mobile/cloud.

## On-event pacing

### Day 0 (briefing)

- Show up early. Ask scope questions in person — answers are binding for the event.
- Identify the triage lead and product owner faces. You'll need them.
- Don't burn bugs you found in pre-event recon yet; wait until submission window opens to avoid "out of window" disputes.

### Day 1 morning rush

- Submit the strongest pre-event findings first. First-to-report bonuses are awarded by submission timestamp.
- Don't dump everything at once — pace submissions to avoid clogging triage and to keep leaderboard pressure.

### Mid-event grind

- Rotate between attack surfaces every 2-3 hours to avoid tunnel vision (see [[burnout-and-pipeline]]).
- Keep checking the leaderboard and the "bugs found by others" feed (if public) — it tells you which areas are saturated.
- Eat, hydrate, sleep. The hunters who win Day 4 are the ones who slept on Day 2.

### Final-day push

- Final hours often have "double bonus" windows or special challenges. Read announcements carefully.
- Save one polished, high-impact report for the last submission — judges remember the closing act for MVP voting.

## Communicating with program staff in person

- **Walk over, don't DM.** If you can physically tap the security engineer on the shoulder, do it. Decisions in person are 10x faster than in a triage thread.
- **Sketch the bug on a whiteboard.** Live walkthroughs land impact like nothing else; see [[demonstrating-impact]].
- **Disagree professionally.** If severity is contested, escalate via [[disclosure-and-comms]] norms — calm, evidence-first.
- **Bring printed/markdown reports.** Some triage staff prefer reviewing a PDF over the platform UI on Day 1 when the queue is on fire.

## Social dynamics and networking

- LHEs are a small world. Be the person others want to collab with next time.
- Share scope-safe tips with newcomers — pay it forward, build long-term reputation.
- Don't trash other hunters' reports publicly. Industry is small; words travel.
- Hallway conversations with program staff often turn into private invites, consulting gigs, or full-time offers.
- Take the group photo. It's how invites compound for the next event.

## Post-event cleanup

### Reporting hygiene

- Within 48 hours: revisit every report, add missing repro detail, polish per [[report-writing-step-by-step]].
- Mark "not exploitable in production" findings honestly. Burning credibility costs more than one bounty.

### Payout tracking

- Live bonuses and MVP prizes often pay through a different rail than normal bounties. Confirm payment methods and tax docs (W-8BEN / W-9 / local equivalents) on the spot.
- Track expected vs. received payouts in a spreadsheet. Follow up at 30/60/90 days if anything is missing.

### Disclosure timing

- LHE bugs often have embargoes (90-180 days) before public disclosure. Respect them — see [[responsible-disclosure-across-jurisdictions]].
- When disclosure unlocks, write a polished retrospective. Reuse the structure from [[case-study-h1-top-disclosed-2024-2025]] and [[case-study-orange-tsai-research-pattern]].

### Retrospective

- Within a week, do a personal retro: what worked, what didn't, what new attack pattern do you want to add to [[testing-methodology-checklists]]?
- Update [[automation-and-rinse-repeat]] notes — many LHE wins started as one-off recon scripts worth productizing.

## Defensive baseline (for programs running LHEs)

- Spin a dedicated triage team with surge capacity; pre-stage decision-makers for severity disputes.
- Provision per-hunter test accounts and isolated environments.
- Publish a scope doc with explicit do/don't lists; include known-issue list to reduce dupe noise per [[dupe-mental-model]].
- Run a transparent leaderboard and announce live bonuses early.
- Debrief engineering teams afterward — fold findings into [[expanding-attack-surface]] coverage and threat models.

## Workflow to study

1. Get invite. Sign NDA. Read scope doc end-to-end.
2. Lock down recon and N-day prep 3-4 weeks out.
3. Form/confirm squad and splits in writing.
4. Day 0: attend briefing, ask scope questions, identify triage staff.
5. Day 1 AM: submit pre-event findings in priority order.
6. Mid-event: rotate surfaces, watch leaderboard, sleep.
7. Final day: save a banger for the close.
8. Post-event: polish reports, track payouts, log retrospective lessons.

## Related

- [[hackerone-platform-deep]]
- [[bugcrowd-platform-deep]]
- [[collaborative-bug-bounty-hunting]]
- [[testing-methodology-checklists]]
- [[program-selection-tactics]]
- [[program-scope-reading]]
- [[continuous-recon-automation]]
- [[report-writing-step-by-step]]
- [[demonstrating-impact]]
- [[burnout-and-pipeline]]
- [[disclosure-and-comms]]
- [[dupe-mental-model]]
- [[case-study-h1-top-disclosed-2024-2025]]

## References

- HackerOne Live Hacking Events overview — https://www.hackerone.com/events
- Bugcrowd Bash events — https://www.bugcrowd.com/about/events/
- HackerOne LHE recap blog index — https://www.hackerone.com/blog
- Bugcrowd Inside Bugcrowd blog — https://www.bugcrowd.com/blog/
- "How to get invited to a Live Hacking Event" (HackerOne hacker resources) — https://docs.hackerone.com/en/articles/8410902-live-hacking-events
