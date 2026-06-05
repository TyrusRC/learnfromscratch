---
title: Bounty triage — from the hunter's view
slug: bounty-triage-from-hunters-view
aliases: [triage-mindset, hunter-side-triage]
---

> **TL;DR:** Triage is the human bottleneck between your submission and a bounty. Understanding how triagers work — what they read first, what makes them close a report as Informative, and how they decide severity — lets you write submissions that get paid faster and disputed less often. Pair this with [[report-writing-step-by-step]], [[demonstrating-impact]], and [[dupe-mental-model]] for an end-to-end workflow.

## Why it matters

A bug-bounty report is not read by the engineer who will fix the bug. It is first read by a platform triager (HackerOne, Bugcrowd, Intigriti, YesWeHack) or an in-house security engineer at a self-hosted program. That person reads dozens to hundreds of reports a day. Their job is to filter signal from noise quickly and route real findings to the customer.

If you write for the engineer who will patch the bug, you lose. If you write for the triager — and make their job easy — you win, regardless of the bug's technical depth. This is the inverse of what most hunters assume after their first paid bug: technical depth is necessary but not sufficient; clarity and triage-empathy are what actually convert findings into bounties.

This note dissects what triagers actually do, what trips them up, and how to game (legitimately) the triage process. It is companion reading to [[disclosure-and-comms]] and [[program-selection-tactics]].

## The triager workflow

### Initial review (the 30-second skim)

Triagers open a report and skim:

1. **Title** — does it describe a class of bug they recognize?
2. **Asset / endpoint** — is it in scope?
3. **Impact statement** — one sentence: what can an attacker do?
4. **PoC** — is there a reproducible artifact (request, video, code)?

If any of these are missing or unclear, the report enters a queue of "needs more info" that may sit for days. Reports that pass the 30-second skim are read in full immediately.

### Dupe check

Triagers search the program's internal report database for the same endpoint, vulnerability class, and root cause. Dupes are common and frustrating. See [[dupe-mental-model]] for how to avoid them on the hunter side. From the triage side, dupes are closed quickly because the triager has a template.

Importantly: a dupe is judged on **root cause**, not symptom. Two reports hitting the same endpoint with different payloads may both be valid if they exploit different sinks. Triagers sometimes mis-dupe; this is a fair fight to challenge politely.

### Severity validation

The triager runs your PoC, confirms the impact, and assigns CVSS (or platform-specific) severity. They often downgrade because:

- The bug requires unrealistic preconditions.
- The endpoint is behind authentication that you did not demonstrate is trivially obtainable.
- The "impact" you claimed is theoretical rather than demonstrated.

This is where [[demonstrating-impact]] pays off. A report that shows real impact (data exfil, account takeover, financial loss) cannot be downgraded by hand-waving.

### Customer communication

Triagers translate your report into customer-friendly language and may strip technical jargon. They also field customer pushback ("is this really critical?"). A triager who understands your report deeply will defend the severity. A triager who is confused will accept downgrades.

## What makes a report easy to triage

### Clear, single-sentence impact

> "An unauthenticated attacker can read any user's private messages by abusing the `/api/v2/conversations/{id}` endpoint, which does not enforce membership checks."

That is one sentence. Triager knows the asset, the auth state, the bug class ([[bola]] / [[idor]]), and the impact. No further reading needed to decide severity.

### Clean PoC

- **HTTP requests** as raw text in code blocks, not screenshots of Burp.
- **Step-by-step reproduction** with two accounts (Attacker, Victim) clearly labeled.
- **A video** for anything involving UI state, race conditions, or multi-step flows. Keep it under 90 seconds. No music, no commentary, no zoom-and-enhance. Just the bug.

### Screenshots that prove impact, not effort

One screenshot of the attacker reading the victim's email = critical bug. Ten screenshots of your recon process = noise. Triagers do not award points for effort.

### Reproducibility verified from a clean session

Open an incognito window, follow your own report, reproduce the bug. If you cannot, the triager cannot either. This single step rejects more bad reports than any other.

## Common triage delay reasons

| Symptom | Root cause | Fix |
|---|---|---|
| "Needs more info" after 3 days | Missing PoC artifact or unclear repro | Re-submit with raw HTTP + video |
| Sat in queue 2 weeks | Low-severity bug, triager backlog | Politely bump after 14 days |
| Downgraded to Low | Impact not demonstrated, only claimed | Add data exfil PoC, escalation chain |
| Closed as Informative | Triager could not reproduce or thinks accepted risk | Request reproduction help, cite policy |
| Closed as N/A | Out of scope, missed in your reading | See [[program-scope-reading]] |

## Outcome taxonomy

### Resolved

Patch shipped, bounty paid. The goal. Sometimes patch takes months — bounty is usually paid on triage acceptance, not on patch.

### Informative

"We acknowledge this but it's not a security issue we'll pay for." Common reasons:

- Accepted risk (program has decided this is fine).
- Defense-in-depth issue (no exploitable impact).
- Best-practice recommendation (e.g., missing security header without demonstrated exploitation).

Informative reports do not pay but build reputation on platforms that track signal (HackerOne Signal). Some informatives are wrong and worth challenging.

### Duplicate

Someone reported it first. You get no bounty but get credit for "first responder" reputation. Some programs pay partial bounties for high-quality dupes — rare but exists.

### Not Applicable (N/A)

Out of scope, on a third-party asset, or not a vulnerability. N/A hurts platform reputation. Always verify scope ([[program-scope-reading]]) before submitting.

### Spam

Reserved for clearly malicious or low-effort submissions (scanner output, "I found a CVE on your nginx version"). Spam hurts reputation badly and can lead to bans.

## Challenging unjust triage

Sometimes triagers are wrong. They mis-dupe, mis-classify as Informative, or downgrade severity unfairly. How to push back without burning the relationship:

### The polite escalation pattern

1. **Acknowledge** the triager's read: "I understand you closed this as Informative because the endpoint requires authentication."
2. **Add context** that may have been missed: "However, the auth token is leaked via the `/api/v1/share` endpoint to any user, which means any attacker can obtain it."
3. **Link the chain**: "Combining these two issues, the impact is unauthenticated read of all conversations."
4. **Request re-review**: "Could you reopen this and consider the chained impact?"

Do not say "you are wrong." Do not threaten to go public. Do not name-drop senior staff. Triagers talk to each other across programs.

### When to mediate

If polite escalation fails twice, request platform mediation (HackerOne has a mediation team, Bugcrowd has program escalation). This is a real option that exists. Use it sparingly — once or twice a year, not once a month.

### When to walk away

Some programs are genuinely bad-faith. You will not change that with one report. Document the interaction privately, drop the program, and move on. See [[program-selection-tactics]] for picking programs that triage well.

## Building reputation with triagers

Across years, you submit reports to the same triagers. They remember you. Two things to optimize:

### Signal ratio

Submit only what you are confident in. A 90% acceptance rate beats a 30% acceptance rate even if you submit fewer reports. Triagers fast-track hunters with high signal.

### Tone

Be brief, professional, and helpful. Do not flame. Do not chase. Do not name-drop. When a triager helps you, thank them. When they get it wrong, escalate politely. Build a reputation as someone they want to read.

## Defensive baseline (program-side)

If you run a program (or advise one), think about what makes triage cheap on your side:

- **Public, versioned scope** — see [[program-scope-reading]].
- **Severity rubric** with worked examples published publicly.
- **Templates** for common Informative responses (XSS in admin-only context, missing headers without exploitation, etc.).
- **SLA** for first response (3 business days is industry baseline; 24 hours is excellent).
- **Triager training** on your asset — generic triagers miss business-logic bugs in complex products.

Good programs invest in triage. Bad programs treat it as overhead and then wonder why hunters dry up.

## Workflow to study

1. Submit a report this week using [[report-writing-step-by-step]].
2. After triage, copy the triager's message into a personal log.
3. Tag the outcome (Resolved / Informative / Dupe / N/A) and the root cause of any friction.
4. After 20 reports across 5 programs, review the log. Which programs triage fast? Which triagers downgrade aggressively? Which of your report patterns get fast-tracked?
5. Adjust your submission template and your program targeting.

This feedback loop, run for a year, is what separates hobbyists from professional hunters. See [[burnout-and-pipeline]] for the longer-arc view.

## Related

- [[report-writing-step-by-step]]
- [[demonstrating-impact]]
- [[dupe-mental-model]]
- [[disclosure-and-comms]]
- [[program-selection-tactics]]
- [[program-scope-reading]]
- [[responsible-disclosure-across-jurisdictions]]
- [[burnout-and-pipeline]]
- [[h1-disclosed-report-reading-method]]

## References

- HackerOne, "Triage Services" — https://www.hackerone.com/product/triage
- Bugcrowd, "Vulnerability Rating Taxonomy (VRT)" — https://bugcrowd.com/vulnerability-rating-taxonomy
- Intigriti, "What happens after you submit a report" — https://www.intigriti.com/researchers/blog
- HackerOne, "Mediation" policy — https://docs.hackerone.com/en/articles/8430873-mediation
- FIRST, "CVSS v3.1 Specification" — https://www.first.org/cvss/v3-1/specification-document
- Disclose.io, "Safe harbor and triage norms" — https://disclose.io/
