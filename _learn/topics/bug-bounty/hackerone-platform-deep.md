---
title: HackerOne — platform deep dive
slug: hackerone-platform-deep
aliases: [h1-platform, hackerone-deep]
---

> **TL;DR:** HackerOne (H1) is more than a submission portal — it is a structured reputation economy with signal, impact, retest workflows, Clear vetting, and program-specific scope semantics that materially affect what you should hunt and how you report. This note is the operator-level companion to [[h1-disclosed-report-reading-method]], [[case-study-h1-top-disclosed-2024-2025]], [[report-writing-step-by-step]], and [[program-scope-reading]]. Read it before you fire your first request at a public program; the platform's mechanics shape ROI as much as the targets themselves.

## Why it matters

Most newcomers treat H1 as a glorified bug tracker. In reality, the platform encodes years of triage economics into Signal, Impact, reputation, program tiers, and disclosure controls. Misunderstand them and you will:

- Burn reputation on N/A and Informative closures that haunt your stats for months.
- Submit to programs whose scope language quietly excludes your finding.
- Miss bonus pools by reporting through the wrong asset or with the wrong severity.
- Fail Clear or private invite criteria because your Signal slipped below thresholds.

Hunters who internalize the platform — see [[program-selection-tactics]] and [[dupe-mental-model]] — out-earn equally skilled hunters who don't, simply because they spend their hours where the platform pays them back.

## Account setup and the reputation economy

### Identity, payouts, taxes

- Sign up with a stable handle. Renaming is possible but costs you brand equity in disclosed reports.
- Add your tax forms (W-8BEN/W-9) early; many programs hold bounty payouts until tax info is on file.
- Payout rails: PayPal, Coinbase, HackerOne wallet (held balance), and direct bank in some regions. The wallet incurs no per-transaction fee but ties your money to H1.
- Currency: bounties are denominated in USD; conversion happens at the payout provider. Track the FX hit if you live outside USD.

### Profile signal

Your public profile shows reputation, Signal, Impact, and recent activity. Programs and private-invite algorithms read these continuously. Keep your profile clean: a single visible "Spam" closure can deter conservative triagers.

### Reputation, Signal, Impact

H1 uses three intertwined scores:

- **Reputation** — points awarded per resolved report, scaled by severity. Lifetime and 90-day windows both matter.
- **Signal** — average reputation per report. Submitting low-quality or duplicate reports drags this down; Spam and N/A closures penalize heavily.
- **Impact** — average bounty per resolved report on a program. High-impact hunters get pulled into private programs first.

Practical rules:

- Do not submit speculative findings. A negative Signal hit takes ~20+ resolved reports to wash out.
- If you suspect a duplicate, search the program's disclosed reports first (see [[h1-disclosed-report-reading-method]]).
- Withdraw a report yourself if you realize it is invalid before triage — withdrawn reports do not affect Signal as harshly as N/A closures.

## Program types

### Public programs

Visible to anyone; listed in the directory. Higher noise, higher dup rate, lower average bounty per finding. Good for building Signal once you can identify under-tested surface (see [[target-selection-heuristics]] and [[expanding-attack-surface]]).

### Private programs

Invite-only. Allocation is partly algorithmic (your Signal/Impact, prior performance on similar programs) and partly manual (program managers handpick). They typically have:

- Less dup pressure.
- Higher bounty tables.
- Stricter NDA: do not screenshot the inbox, do not discuss findings publicly, do not mention scope to non-participants.

### Vulnerability Disclosure Programs (VDPs)

No bounty, but reputation only. Useful for new hunters to build Signal on real assets, and for hunting CVEs in government or open-source assets (e.g., the US DoD VDP).

### Bounty programs vs. pentest engagements

H1 also runs structured pentests (time-boxed, fixed roster). These are separate from open bounty programs and require Clear plus invitation.

## Triage SLAs and lifecycle

Each program publishes target response times for:

- **First response** (typically 1–3 business days).
- **Time to triage** (typically 3–10 business days).
- **Time to bounty** and **time to resolution** (highly variable).

The lifecycle states you will see: `New` → `Triaged` → `Resolved` (or `N/A`, `Informative`, `Duplicate`, `Spam`, `Not Applicable`). A report in `Needs more info` pauses the SLA — answer fast.

Triage on top programs is often outsourced to H1's internal triage team ("H1 Triage"). They are skilled but volume-throttled; concise, reproducible reports get to the customer fastest. See [[report-writing-step-by-step]].

## Disclosure controls

After resolution, disclosure can happen if both reporter and program request it. Options:

- **Public disclosure** — full report published, contributing to the disclosed corpus you should be mining ([[h1-disclosed-report-reading-method]]).
- **Limited disclosure** — title and summary only.
- **No disclosure** — common on private programs; the report stays sealed.

Never disclose unilaterally. Off-platform disclosure violates the platform ToS and can permanently ban you. Coordinated disclosure best practices: see [[disclosure-and-comms]] and [[responsible-disclosure-across-jurisdictions]].

## Hacker101 and the CTF

H1 runs Hacker101 — free training content and a CTF that mirrors realistic web bug classes. Completing CTF flags can yield private program invitations, which is the cheapest way to bootstrap a serious program inventory if you are new. See [[ctf-to-bug-bounty-transition]] for how to translate CTF skills into bounty workflow.

## Clear (background-checked tier)

Clear is H1's vetted hunter program. Requirements include:

- Identity verification (government ID).
- Background check via a third party.
- Often a code-of-conduct attestation.

Benefits:

- Access to programs that legally require vetted researchers (financial, healthcare, government-adjacent).
- Higher trust posture in triage.
- Often a higher initial bounty range.

Trade-offs: your identity is on file; some hunters prefer pseudonymity and skip Clear deliberately.

## Pro features and program-side mechanics

While Pro is a customer-side offering, knowing it exists explains hunter-side behavior:

- Customers can opt into **Bounty Tables** with structured severity → payout mappings.
- **Retest** allows the customer to ask the reporter to verify a fix; the reporter is paid a small fee per retest. Treat retests seriously — they are easy money and build Impact with the program.
- **Asset management** lets customers categorize scope; you may need to pick the exact asset when filing.

## Submitting a report — mechanics

When you click `Submit Report`, you are choosing many things at once:

- **Title** — concise, asset-prefixed (e.g., `[api.example.com] BOLA in /v2/orders/{id} allows arbitrary order read`). See [[report-writing]].
- **Asset selection** — pick the exact asset from the program's structured list. Wrong asset can route the report to the wrong team or out of scope entirely.
- **Weakness (CWE)** — choose the closest CWE; triagers rely on this.
- **Severity** — H1 uses CVSSv3 by default. Be honest; over-rating gets you demoted in triage trust.
- **Attachments** — videos for chained exploits (see [[demonstrating-impact]]), HAR files for HTTP races, never include third-party PII.
- **Markdown body** — H1 supports a subset; preview before submit.

### Severity disputes

If you and the customer disagree on severity, you can request a re-rating. Bring evidence (real impact, business consequence). Avoid arguing over a 0.5 CVSS bump for a sub-Medium — it costs more in goodwill than it earns in cash.

## Bonuses, currency, payouts

- **Bonus structures** — customers can add ad-hoc bonuses on top of the base bounty for exceptional impact, first-bug-on-a-new-asset, or rapid retest. Read program policy pages for declared bonus rules.
- **Promotion bonuses** — H1 occasionally runs platform-wide events with bonus pools on specific programs. Worth tracking.
- **Currency** — payouts are USD. Some programs publish bounties in EUR/GBP; H1 converts at platform rate.
- **Leaderboards** — quarterly and lifetime leaderboards drive both pride and stress. Decide early whether you optimize for leaderboard rank or sustainable income; see [[burnout-and-pipeline]].

## Reading a program scope page

Every program policy page has the same structural skeleton. Speed-read it in this order:

1. **In scope** — exact domains, mobile apps, APIs. Treat anything not listed as out of scope unless explicitly wildcarded.
2. **Out of scope** — common exclusions: marketing sites, third-party SaaS, rate-limit bugs, SPF/DMARC misconfigs.
3. **Eligible vulnerabilities** — sometimes a positive list; if so, anything not listed needs prior approval.
4. **Ineligible vulnerabilities** — the boilerplate list (self-XSS, missing security headers without impact, etc.). Memorize.
5. **Bounty table** — severity → range. Note the *range*, not just the minimum.
6. **Testing requirements** — e.g., user accounts you must create, dummy data prefixes, header tagging.
7. **Disclosure policy** — disclosure-by-default vs. customer-approved.

Detailed methodology in [[program-scope-reading]] and [[scope-vertical-vs-horizontal]].

## Defensive baseline (for program owners)

If you run a program:

- Publish unambiguous scope and bounty tables; ambiguity costs you in dispute time.
- Honor your SLAs publicly — H1 displays response medians on your profile.
- Use retests routinely; researchers reward fast-paying programs with more attention.
- Calibrate severity using business impact, not raw CVSS.

## Workflow to study the platform

1. Create your profile, complete Hacker101 fundamentals, and grab CTF flags for an initial private invite pool.
2. Pick one VDP (e.g., government) and one small public program; submit two real findings to learn the lifecycle without leaderboard pressure.
3. Mine 30 disclosed reports per target program before submitting — apply [[h1-disclosed-report-reading-method]] and [[reading-public-pocs-effectively]].
4. Audit your Signal weekly; withdraw weak drafts rather than submitting.
5. After three resolved reports on the same program, ask the program for a retest queue and bonus eligibility clarification.
6. Apply for Clear once you have stable Signal and need access to vetted-only programs.
7. Build a personal scope cache: structured notes per program (assets, exclusions, prior dupes) so re-engagement is instant. Tie into [[continuous-recon-automation]] and [[automation-and-rinse-repeat]].

## Related

- [[h1-disclosed-report-reading-method]]
- [[case-study-h1-top-disclosed-2024-2025]]
- [[report-writing-step-by-step]]
- [[program-scope-reading]]
- [[program-selection-tactics]]
- [[dupe-mental-model]]
- [[demonstrating-impact]]
- [[disclosure-and-comms]]
- [[burnout-and-pipeline]]
- [[ctf-to-bug-bounty-transition]]

## References

- HackerOne docs — Hacker portal: https://docs.hackerone.com/hackers/hacker-portal.html
- HackerOne — Signal and Impact explained: https://docs.hackerone.com/hackers/reputation.html
- Hacker101 training and CTF: https://www.hacker101.com/
- HackerOne Clear program overview: https://www.hackerone.com/product/clear
- HackerOne disclosure guidelines: https://docs.hackerone.com/hackers/disclosure-guidelines.html
- HackerOne bounty payouts and currency FAQ: https://docs.hackerone.com/hackers/bounties.html
