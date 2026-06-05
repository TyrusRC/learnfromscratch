---
title: AppSec champions program
slug: appsec-champions-program
aliases: [security-champions, champions-program]
---

> **TL;DR:** A security champions program is the cheapest force multiplier an AppSec team has, and the most commonly bungled. The pattern: embed a part-time (10-20% time) security-curious engineer inside every product team, train them, give them air cover, and use them as the local liaison for threat modeling, code review, and triage. This note is the people/process companion to [[devsecops-platform-engineering]] (the tooling), [[secure-sdlc-rollout-playbook]] (the process), [[security-training-program-building]] (the curriculum), and [[appsec-maturity-checklist]] (the scorecard).

## Why it matters

Central AppSec teams do not scale. A typical ratio in industry is 1 AppSec engineer to 50-200 developers, and even the well-funded shops sit closer to 1:100. You cannot threat-model every sprint, review every PR, or triage every Snyk finding from the center. Three things break first:

- **Threat modeling backlog.** Product teams ship features faster than central AppSec can review them, so threat modeling either gets skipped or becomes a checkbox PDF nobody reads.
- **Finding fatigue.** SAST/SCA noise lands in a Jira queue nobody on the product side feels ownership for, and false-positive rates kill trust.
- **Context loss.** AppSec engineers don't know the business logic of 40 microservices. The local engineers do. Without a bridge, every security review starts from zero.

Champions are the bridge. They are **engineers first, security-adjacent second**. They do not replace AppSec; they are the local sensor and translator. Done well, they turn AppSec from a gatekeeper into a platform team. Done badly, they become unpaid Snyk-ticket-closers who quit within a year.

## Champion role definition

### What a champion is

- An engineer on a product team who spends roughly **10-20% of their time** on security-adjacent work: threat modeling the team's features, triaging tool findings, being the first reviewer for security-relevant PRs, attending the monthly champions sync, and escalating to central AppSec when needed.
- A **liaison and translator**, not a pentester. They explain the team's architecture to AppSec and explain AppSec's asks to the team.
- Reports to their engineering manager, **dotted line to AppSec**. This matters: if they report to AppSec, they're a security engineer with extra steps. If they report only to engineering with no AppSec relationship, they drift.

### What a champion is not

- Not a substitute for a pentest or a code audit. See [[pentest-engagement-execution]] and [[secrets-in-code-detection-patterns]] for the depth work that still belongs to specialists.
- Not on-call for incidents. IR is a separate skill set; see [[ir-from-source-signals]].
- Not unpaid. If you can't budget time or compensation, you don't have a program, you have a wishlist.

### Selection criteria

In order of importance:

1. **Intrinsic curiosity.** They already lurk in security Slack, have done a CTF, read the [[case-study-okta-2023-support-system]] writeup. You cannot manufacture this.
2. **Respected by peers.** A champion whose code reviews get ignored is useless. Pick senior or mid-level engineers, not interns.
3. **Manager buy-in confirmed in writing.** If the manager won't carve the 10-20%, decline the candidate. This is the number one failure mode.
4. **Communication skills.** They translate. They write tickets. They run a 30-minute threat-model session without it devolving.
5. **Tenure of at least 6 months on the team.** They need to know the codebase.

Avoid: the eager junior with no manager support, the disgruntled senior looking for an exit, anyone "voluntold."

## Process: standing up the program

### Phase 0: prerequisites (do not skip)

- A working AppSec function with at least basic tooling: SAST in CI, SCA, secret scanning. See [[sast-dast-ci-integration]] and [[secrets-in-code-detection-patterns]].
- A threat-modeling method the central team actually uses. See [[appsec-threat-modeling]].
- Exec sponsorship in writing — VP Eng or CTO — confirming the 10-20% time allocation is real.
- A baseline of where teams are. See [[appsec-maturity-checklist]] to score it.

Skipping any of these produces a program that looks busy for 6 months and then dies.

### Phase 1: pilot (months 1-3)

- Recruit 3-5 champions across diverse teams (one backend, one frontend, one mobile, one infra, one data).
- Onboard them with a structured **6-week curriculum** (see Training below).
- Run **weekly office hours** between champions and AppSec.
- Pick **one measurable outcome per champion** for the pilot: e.g. complete a threat model for a team service, drive backlog of SAST findings from N to N/2, ship one secure-default in the team's framework.

### Phase 2: scale (months 4-9)

- Roll out to all engineering teams, target one champion per team of 5-15 engineers.
- Move office hours to **monthly all-hands** plus on-demand Slack.
- Introduce a **champion charter** signed by champion, manager, and AppSec lead.
- Publish a public champion directory inside the company.

### Phase 3: maturity (year 2+)

- Champions begin running their own threat-model sessions without AppSec attendance.
- Champions co-author internal standards (see [[policy-and-standards-writing]]).
- A subset graduate into AppSec proper, becoming hiring pipeline.

## Training and curriculum

### External resources to lean on

- **OWASP** projects: Top 10, ASVS, Cheat Sheet Series. Free, high quality, language-agnostic.
- **AppSec University** (formerly SecureFlag / various vendor offerings) for hands-on labs. Honestly, vendor labs vary wildly in quality — pilot before buying seats.
- **PortSwigger Web Security Academy** if your stack is web-heavy. Free, excellent, and the labs are not toy.
- **HackTheBox** or similar for the curious. Optional, but a champion who has popped a box understands attacker mindset.

### Internal curriculum (6-week onboarding)

| Week | Topic | Output |
|------|-------|--------|
| 1 | Org-specific threat model + crown jewels | Read the team's existing TM, identify gaps |
| 2 | Secure SDLC overview, see [[secure-sdlc-rollout-playbook]] | Map team's process to SDLC stages |
| 3 | Tooling: how SAST/DAST/SCA are wired locally, see [[sast-dast-ci-integration]] | Triage 10 existing findings |
| 4 | AuthZ patterns and pitfalls, see [[authorization-patterns-rebac-abac]] | Identify one authz risk in team's code |
| 5 | Supply chain hygiene, see [[npm-postinstall-and-typosquat-audit]] or [[python-pypi-supply-chain-audit]] depending on stack | Audit team's dependencies |
| 6 | Incident response basics, when to escalate | Walk through last public incident as case study |

Each week is roughly 2-4 hours of self-paced study plus a 1-hour sync. If you can't budget that, the program is theatre.

### Ongoing learning

- Monthly **brown bag** where a champion presents a finding, a bug, or an external case study like [[case-study-snowflake-2024]].
- Conference budget: send champions to BSides, OWASP local chapters, DEF CON if budget allows. This is retention spending.
- Internal CTF, ideally quarterly.

## Incentives and recognition

This is where most programs die. "Volunteer" champions burn out in 9-18 months. What works:

- **Recognition in performance reviews.** Champion work must show up in the engineer's promo packet, not as a footnote. Get this in writing with HR.
- **Compensation uplift.** Some orgs add a small stipend (a few thousand dollars annually) or a salary band adjustment. Even small amounts signal that the work is real.
- **Conference attendance.** Real budget, real travel, not "if there's money left over."
- **Public credit.** Quarterly all-hands shoutouts, security wins attributed to the champion.
- **Career path.** Make it explicit that champion experience is a path into AppSec (see [[appsec-maturity-checklist]]) or staff engineering.

What does not work: pizza, t-shirts as the only reward, "exposure," and "looks good on your resume."

## Measurement

Be honest: vanity metrics will sink the program with leadership. Useful metrics:

### Participation metrics

- Number of active champions / number of teams.
- Champion attendance at monthly sync (target 70%+; if it drops below 50%, the program is dying).
- Number of threat models completed by champions vs by central AppSec.

### Outcome metrics

- **Mean time to fix** (MTTF) for high/critical findings, teams **with** champion vs teams **without**. This is the single most defensible metric to leadership.
- Reopened-vulnerability rate per team.
- Number of security stories in the team's sprint backlog per quarter.
- Adoption rate of secure defaults (e.g. percentage of services using the hardened base image).

### Health metrics (run quarterly)

- Anonymous champion satisfaction survey.
- Manager survey: is the 10-20% being honored?
- Time-since-last-promotion for champions. If champions are not getting promoted at the same rate as peers, you have a retention bomb.

## Community building

A program is a community, not a roster.

- **Slack channel** (or Discord, if your eng org uses it): dedicated, active, low-noise. AppSec engineers live there.
- **Monthly sync**, 60 minutes, with a rotating champion presenter. Record it.
- **Private channel** for sensitive discussion (active incidents, findings under embargo).
- **Champion-only swag**: hoodies, stickers. Cheap, surprisingly motivating.
- Cross-pollinate with the broader industry: OWASP chapters, BSides volunteering.

## Defensive baseline

Even without a formal program, you can get 50% of the value with:

1. A single named security contact in each team's `OWNERS` or `CODEOWNERS` file.
2. Mandatory threat model on any new service exposing public endpoints (see [[appsec-threat-modeling]]).
3. SAST/SCA findings auto-routed to the team's existing bug tracker, not a separate "security queue."
4. A monthly "AppSec AMA" open to all engineers.

This is the minimum viable champion program for shops without budget.

## Pitfalls (and how to spot them early)

- **Champions overloaded.** They take on incident response, on-call, audit evidence collection, and pentest scoping on top of their day job. **Mitigation:** hard cap on hours, manager review quarterly.
- **No manager buy-in.** Champion attends syncs but cannot actually do work because their manager assigns 100% of sprint capacity to product. **Mitigation:** charter signed by manager, escalate to VP Eng if violated.
- **Champion becomes the team's security single point of failure.** They leave; institutional knowledge evaporates. **Mitigation:** pair champions, rotate every 18-24 months.
- **Program captured by central AppSec.** Champions become unpaid ticket-closers for the central team's backlog. **Mitigation:** champions set their own team's security priorities, central AppSec advises.
- **Vendor-driven program.** A vendor sells you "champion-in-a-box" training and a leaderboard. The training is generic, the leaderboard gamifies the wrong thing. **Mitigation:** build your own curriculum, use vendor content as raw material only.
- **Churn.** A champion quits or rotates. Without succession planning, the team loses everything. **Mitigation:** document everything in the team's runbook, pair from day one.
- **Promo penalty.** Champion work is invisible at promo time. Champions leave for promotions elsewhere. **Mitigation:** explicit calibration guidance to managers.

## Workflow to study

If you are spinning up a program from zero, work in this order:

1. Score current state with [[appsec-maturity-checklist]].
2. Confirm tooling foundation: [[sast-dast-ci-integration]], [[secrets-in-code-detection-patterns]].
3. Get exec sponsorship in writing.
4. Recruit 3-5 pilot champions, one per team archetype.
5. Run a 6-week onboarding; complete one measurable outcome per champion.
6. Publish results internally; recruit phase 2.
7. Layer in monthly sync, charter, recognition, and stipend.
8. Tie into [[secure-sdlc-rollout-playbook]] so champions own SDLC checkpoints locally.
9. Review program health quarterly; rotate champions every 18-24 months.

## Realistic effort

For a 200-engineer org:

- **Year 1:** 0.5-1.0 FTE of AppSec time to run the program (curriculum, syncs, mentoring). Plus 10-20% of each champion's time. Plus stipend budget (~ low five figures) and conference budget.
- **Year 2:** Self-sustaining, but still 0.25 FTE of program management.

If leadership balks at this cost, the honest answer is: a champions program will not work here; focus on tooling and central AppSec until the org grows up.

## Vendor marketing vs reality

Vendors will sell you "gamified champion platforms" with leaderboards (the leaderboard incentivizes ticket-closing volume, not security outcomes), "champion certifications" (nice-to-have, not the point — the point is local context and trust), and "AI-driven champion assistants" (useful for code suggestions in [[sast-dast-ci-integration]] context, not a substitute for a human liaison). Build the program around people first, tools second. Tools change every three years; the community is what compounds.

## References

- OWASP Security Champions Playbook: <https://owasp.org/www-project-security-champions-guide/>
- OWASP SAMM (Software Assurance Maturity Model): <https://owaspsamm.org/>
- BSIMM (Building Security In Maturity Model): <https://www.blackduck.com/services/security-program/bsimm-maturity-model.html>
- SAFECode practical guidance: <https://safecode.org/>
- PortSwigger Web Security Academy: <https://portswigger.net/web-security>

## Related

- [[devsecops-platform-engineering]]
- [[secure-sdlc-rollout-playbook]]
- [[security-training-program-building]]
- [[appsec-maturity-checklist]]
- [[appsec-threat-modeling]]
- [[sast-dast-ci-integration]]
- [[secrets-in-code-detection-patterns]]
- [[authorization-patterns-rebac-abac]]
- [[policy-and-standards-writing]]
- [[pentest-engagement-execution]]
