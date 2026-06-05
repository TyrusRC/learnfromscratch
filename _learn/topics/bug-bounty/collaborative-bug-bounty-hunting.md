---
title: Collaborative bug bounty hunting
slug: collaborative-bug-bounty-hunting
aliases: [collab-bb, team-bb-hunting]
---

> **TL;DR:** Collaborative bug-bounty hunting pairs hackers with complementary skills (web + cloud + mobile + recon) on a single program, dividing scope and pooling findings under a written split agreement. It accelerates impact chains that no solo hunter could complete in a reasonable time, but only works with explicit role definitions, platform-aware submission rules, and a conflict-resolution protocol. Pair this note with [[burnout-and-pipeline]], [[live-hacking-event-playbook]], and [[testing-methodology-checklists]] for the operational side of running a duo or pod.

## Why it matters

Modern programs have surfaces that exceed any single specialist's bandwidth. A typical fintech BBP exposes web, mobile (iOS + Android), public APIs, GraphQL, OAuth tenants, AWS/GCP cloud, partner SSO, and sometimes on-prem appliances. A solo hunter who only does web leaves 60-80% of the surface unscanned. A two- or three-person team with complementary skills can:

- Chain a mobile JWT leak (see [[mobile-auth-token-handling-audit]]) into a web BOLA (see [[bola]]) into a cloud IAM pivot (see [[aws-imds-ssrf-pivot]]) within hours.
- Run [[continuous-recon-automation]] across a horizontal scope (see [[scope-vertical-vs-horizontal]]) while a partner does deep manual review on the assets that wake up.
- Cover live-hacking events where the clock matters more than the per-bug payout. See [[live-hacking-event-playbook]].
- Sustain a pipeline through burnout cycles. See [[burnout-and-pipeline]].

The economic question is not "do I lose money splitting?" but "what is my expected payout per hour, with and without a partner?" For high-impact chains, the answer almost always favors collaboration.

## Team shapes and skill stacks

### Complementary-skill duos

The most common shape. Each hunter owns a vertical and contributes findings only the other could not produce alone.

- Web + Cloud: one person hunts SSRF, IDOR, auth flaws ([[broken-access-control]], [[ssrf]], [[oauth-modern-attacks]]); the partner takes any cloud touchpoint and turns it into impact ([[ssrf-to-cloud]], [[ssrf-to-cloud-advanced-chains]], [[cloud-iam-misconfig-patterns]]).
- Web + Mobile: paired on a target with thick clients. Web hunter maps the API; mobile hunter extracts undocumented endpoints, cert pinning bypass routes, and signing logic ([[apk-reverse-tools]], [[ssl-pinning-bypass]], [[frida-hook]], [[ios-source-review-methodology]]).
- Recon + Manual: one person owns continuous discovery ([[continuous-recon-automation]], [[expanding-attack-surface]]); the partner does deep review on whatever surfaces.
- Web + AppSec source review: one external blackbox hunter, one partner with access to leaked or open-source code does [[graphql-source-review]] or [[llm-application-source-review]].

### Three-to-five-person pods

Pods scale better for live events and sprints. Typical seats:

1. Recon lead (asset enumeration, change detection)
2. Web/API lead ([[api-fuzzing-wide-vs-deep]], [[graphql-attacks]])
3. Mobile lead
4. Cloud/identity lead
5. Reporter/coordinator (owns the queue, writes reports, manages dedup)

Pods over five start to suffer from coordination overhead and dupe-internal risk.

### Mentor-mentee pairs

Asymmetric splits (e.g. 70/30 favoring the experienced hunter) in exchange for direct teaching, report review, and target picking. The mentee absorbs methodology faster than any course teaches it. See [[ctf-to-bug-bounty-transition]] and [[hacker-mindset-questioning]].

## Splitting scope without stepping on toes

The two failure modes are (a) two hunters working the same asset and producing internal dupes, and (b) leaving large patches of scope cold. Mitigations:

### Recon-side split

- Divide by subdomain prefix range, ASN block, or product line.
- Use a shared notes board (private GitHub repo, Obsidian vault on a private sync, or Notion) that lists "owned" assets with timestamps.
- Run discovery centrally and post results to a shared channel; each hunter claims targets explicitly before touching them.

### Skill-side split

- Each hunter owns a vuln class, not an asset. One hunts auth/session bugs across all assets; another hunts IDOR/BOLA across all assets ([[idor]], [[bfla]]).
- Useful when targets are small and not easily partitioned.

### Surface-side split

- One on mobile, one on web, one on third-party integrations. Natural skill alignment; minimal collision risk.

Whichever split you pick, write it down in the team charter and revisit weekly.

## Sharing access to discovered surfaces

Found a staging environment, an undocumented API, a leaked token, or a vulnerable IDP tenant? The team needs a way to share it without burning operational security.

- Private repo with `assets.md` and timestamped entries.
- Shared password manager (1Password, Bitwarden) with a team vault for test accounts.
- Notes on access tokens, refresh tokens, test PII, and any cleanup obligations.
- Strict rule: never share credentials outside the team, and rotate the moment the team composition changes.

## Payout-split arrangements

Decide before the first submission, in writing. Common models:

### 50/50 (or even split N-ways)

Simplest. Works when team members trust each other and contributions roughly balance over a quarter. Pros: no accounting overhead. Cons: free-rider risk if one hunter coasts.

### By-effort

Track hours or task tickets; split proportionally. More fair on paper but exhausting to administer. Reasonable for short sprints (a single live event).

### By-finding

Whoever lands the bug keeps a larger share (e.g. 70%), with the rest going to the partner who contributed recon, mobile extraction, or chain pieces. Rewards initiative; punishes deep-but-quiet recon work unless explicitly credited.

### Hybrid

Base split (e.g. 60/40 for the primary finder) plus a per-month true-up if the totals skew badly. Works best with quarterly retrospectives.

Always document: who pays platform fees, who handles taxes (most platforms 1099 only the named submitter), how disputes are resolved, what happens if a team member leaves mid-investigation.

## Platform support for team submissions

Treat platform rules as load-bearing; misreading them costs payouts.

- HackerOne supports collaboration via the "Add collaborator" feature; bounties can be split natively, and disclosure credits both hunters. This is the cleanest path.
- Bugcrowd has team support but with limits; check program-specific rules.
- Intigriti and YesWeHack support collaborator submissions on many programs.
- Self-hosted/private programs frequently do not support multi-hunter payouts. The named submitter receives the full bounty and must pay the partner privately.
- Government programs (CISA-coordinated, certain VDP-only programs) often forbid third-party involvement entirely. See [[responsible-disclosure-across-jurisdictions]].

Read every program's rules under the [[program-scope-reading]] lens before assuming collaboration is allowed. Some programs reward the first submitter only; collaboration can void payouts if discovered after the fact.

## Communication tooling

- Discord: low-friction voice and screen-share; pair-hacking in real time. Use a private server with limited members and 2FA enforced.
- Signal: out-of-band for sensitive credentials, victim PII, and out-of-platform comms with program staff. Disappearing messages for high-sensitivity material.
- Private GitHub/GitLab repos: shared notes, recon outputs, draft reports, Burp project files (encrypted), exploit code.
- Shared Burp Suite (with care): Burp Enterprise or self-hosted collaboration setups; for solo Pro, share `.burp` project files via the repo.
- Kanban: a single board (GitHub Projects or Linear) for "to-recon", "to-validate", "to-report", "submitted", "paid".

Hard rule: no team comms in public channels, no findings in DMs that disappear without backup, no client/program credentials in chat logs older than 24 hours.

## Conflict resolution

Conflicts are inevitable; plan for them upfront.

- Disputed credit: who actually found the root cause? Defer to written notes timestamped before the report. If unclear, default to the team charter's tiebreaker (e.g. coin flip, mentor decides, even split).
- Dupe internal to the team: if two team members hit the same bug independently, file once and credit both.
- Diverging effort: surface in weekly check-ins. Adjust splits prospectively, not retroactively.
- Departures: define what happens to in-flight reports (last 30 days share at full rate; older bugs at 50%). Define what happens to recon assets and tooling.
- Disagreement on report quality: the partner doing the report-writing has final say on phrasing; the finder has final say on technical accuracy. See [[report-writing]] and [[report-writing-step-by-step]].

Write the charter once; revisit quarterly.

## Knowledge transfer between team members

Collaboration is a force multiplier on learning when done well.

- Pair-hacking sessions: one drives, one navigates. Rotate every 25 minutes. Excellent for absorbing methodology.
- Weekly debrief: each member presents one new technique they used. Recorded for the team notes.
- Shared reading list: rotate who summarizes a piece from [[keeping-up-with-research-feeds]] or a public disclosure ([[h1-disclosed-report-reading-method]], [[reading-public-pocs-effectively]]).
- Joint case-study reviews: [[case-study-h1-top-disclosed-2024-2025]], [[case-study-portswigger-top-10-pattern]], [[case-study-orange-tsai-research-pattern]].
- Cross-train on tools: the web specialist learns the basics of Frida; the mobile specialist learns Burp macros.

The team that learns together stays together; the team that hoards specialization burns out and dissolves.

## When collaboration beats solo

Choose collab when:

- The chain requires skills outside your stack (mobile -> cloud, cloud -> on-prem).
- The program is large enough that solo coverage is impossible (Fortune-100 horizontal scope; see [[scope-vertical-vs-horizontal]]).
- The bounty multiplier rewards high-impact chains (rather than counting bugs).
- A live event clock is involved.
- You are burning out (see [[burnout-and-pipeline]]) and need accountability.

Choose solo when:

- Programs are small, vertical, and within your wheelhouse.
- The platform forbids collaboration explicitly.
- Bounties are small enough that split overhead exceeds value.
- You are early-career and the priority is depth over breadth ([[target-selection-heuristics]], [[program-selection-tactics]]).

## Workflow to study

A two-week duo sprint on a single program:

1. Day 1: review program scope together; build the [[testing-methodology-checklists]] specific to this target; assign verticals.
2. Day 2-3: parallel recon ([[continuous-recon-automation]]) and [[getting-feel-for-target]] manual triage.
3. Day 4-7: each hunter works their vertical; daily 30-minute syncs to share findings and discuss chains.
4. Day 8: chaining session. Bring all single findings to the table; look for chains that no solo bug could produce.
5. Day 9-11: report-writing sprint. The reporter seat drafts; the finder reviews.
6. Day 12-14: triage support, follow-up Qs, retest. Weekly retro covering effort, split fairness, and process improvements.

## Defensive baseline (program-side perspective)

If you run a program and want healthy collaboration:

- Allow native collaboration in your platform settings.
- Publish a clear policy on third-party involvement.
- Pay the same for chained bugs whether from solo or team; do not penalize collaboration.
- Track team submitters in your CRM so you understand who works together.

## References

- [https://docs.hackerone.com/en/articles/8410545-collaboration](https://docs.hackerone.com/en/articles/8410545-collaboration) — HackerOne collaboration documentation.
- [https://www.bugcrowd.com/blog/](https://www.bugcrowd.com/blog/) — Bugcrowd blog with periodic posts on duo and team submissions.
- [https://portswigger.net/research](https://portswigger.net/research) — PortSwigger research; many published chains were team efforts even when authored by one byline.
- [https://www.intigriti.com/blog](https://www.intigriti.com/blog) — Intigriti blog with collaboration case studies.
- [https://hackerone.com/hacktivity](https://hackerone.com/hacktivity) — Public disclosed reports; filter by multi-collaborator submissions for real-world examples.
- [https://yeswehack.com/learn-bug-bounty](https://yeswehack.com/learn-bug-bounty) — YesWeHack learning resources, including team workflow guides.

## Related

- [[burnout-and-pipeline]]
- [[live-hacking-event-playbook]]
- [[testing-methodology-checklists]]
- [[continuous-recon-automation]]
- [[scope-vertical-vs-horizontal]]
- [[program-selection-tactics]]
- [[target-selection-heuristics]]
- [[report-writing]]
- [[report-writing-step-by-step]]
- [[disclosure-and-comms]]
- [[ctf-to-bug-bounty-transition]]
- [[hacker-mindset-questioning]]
- [[demonstrating-impact]]
- [[dupe-mental-model]]
