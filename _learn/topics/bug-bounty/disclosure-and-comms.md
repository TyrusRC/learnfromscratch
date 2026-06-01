---
title: Disclosure and comms
slug: disclosure-and-comms
---

> **TL;DR:** Keep tone professional, facts tight, and escalation polite — your reputation across programs compounds faster than any single bounty payout.

## What it is
Disclosure is the part of the job where the technical work meets a human triager who has read a thousand reports this week. How you communicate — initial report tone, response to triage questions, push-back on duplicates or severity downgrades — directly affects payout speed, bounty amount, and whether you stay on the program's preferred-hunter list. It is also where new hunters most often torpedo themselves.

## Preconditions / where it applies
- A finding that has cleared your own quality gate ([[report-writing]], [[demonstrating-impact]])
- A submitted report on a platform (HackerOne / Bugcrowd / Intigriti / YesWeHack) or via a private channel
- A program that follows ISO 29147-style coordinated disclosure (most do)

## Technique
1. **Opening report.** Lead with impact in one sentence, then the minimal repro. No emojis, no "hope you are well", no boasting. A triager skims the first 200 characters.
2. **Reply cadence.** Within 24h of any triager message — even just "ack, investigating". Silence reads as abandonment and slows payouts.
3. **Duplicate disputes.** If you suspect a duplicate is incorrect, ask one specific question: "could you confirm the parent report covers the exact endpoint `POST /api/v2/x` rather than `POST /api/v1/x`?" Never argue policy; argue facts. Accept the dupe gracefully if confirmed — the next bug from the same target is easier when the program likes you (see [[dupe-mental-model]]).
4. **Severity disputes.** Quote the program's stated severity guide back at them; attach a fresh PoC artefact if they downgraded for lack of impact. Two messages max — past that, request mediation.
5. **Mediation.** Every major platform has a mediation team. Use it sparingly and only when you have evidence of platform-policy violation (silent close, ignored CVSS guidance, time-to-bounty SLA breach). Tone in mediation requests is what gets them taken seriously.
6. **Public disclosure.** Default to opt-in only after the program agrees and the fix is deployed. Public disclosure that embarrasses the program closes doors industry-wide.
7. **Boundaries to enforce.** No scope expansion mid-thread, no "free retests" without explicit ask, no informal payments outside the platform — those expose both sides.

## Detection and defence
- Programs track per-hunter signal: report quality, dispute rate, dupe rate. Low-noise hunters get private invites and higher bounty bands.
- Defenders use comms tone as a proxy for hunter seniority when triaging; professional reports get faster triage.
- For the hunter: keep a personal log of every comm to detect platform-side patterns (which programs always downgrade SSRF, which underpay, which mediate fairly) — informs future [[program-selection-tactics]].

## References
- [ISO/IEC 29147 — Vulnerability disclosure](https://www.iso.org/standard/72311.html) — the coordinated-disclosure standard most programs reference
- [HackerOne policy & disclosure guidelines](https://docs.hackerone.com/en/articles/8410870-disclosure-guidelines) — platform-specific norms
- [disclose.io](https://disclose.io/) — open framework for safe-harbor language and disclosure expectations
