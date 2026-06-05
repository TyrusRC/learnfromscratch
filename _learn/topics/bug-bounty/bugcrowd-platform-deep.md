---
title: Bugcrowd — platform deep dive
slug: bugcrowd-platform-deep
aliases: [bugcrowd-deep, bc-platform]
---

> **TL;DR:** Bugcrowd is the second-largest bounty platform alongside HackerOne. It differs in scoring (kudos + priority-based payouts), severity (VRT instead of CVSS-only), program structure (managed triage + Crowdcontrol), and product mix (Bug Bounty, PTaaS, ASM, VDP). This note is the tactical companion to [[hackerone-platform-deep]], [[program-scope-reading]], and [[testing-methodology-checklists]]. If you only know HackerOne, the muscle memory transfers but the rules of engagement and reputation math do not.

## Why it matters

- Many high-paying private programs run exclusively on Bugcrowd (Tesla, Mastercard, ServiceNow historically, several US gov VDPs).
- VRT is one of the **de facto industry standards** for bug severity outside CVSS — knowing it well prevents downgrades.
- Bugcrowd's **trust score + kudos** system gates access to private invites in a different way than H1's signal/impact.
- Researchers who only use H1 miss roughly half the bounty market — see [[program-selection-tactics]].

## Account setup

1. Sign up at `https://bugcrowd.com/user/sign_up` with a dedicated research email.
2. Enable **MFA** (TOTP) — required to receive payouts.
3. Complete the researcher profile: skills, country, tax form (W-8BEN / W-9 via TIPALTI).
4. Configure payout method: PayPal, Payoneer, bank wire, or crypto (USDC) via TIPALTI.
5. Verify identity (KYC) — gates private invites for some programs.
6. Subscribe to **Researcher Inbox** notifications and the public RSS of new programs.
7. Optionally link a GitHub or LinkedIn for additional signal — see [[target-selection-heuristics]].

## VRT — Vulnerability Rating Taxonomy

Bugcrowd's VRT is a tree-structured severity matrix maintained openly at `https://bugcrowd.com/vulnerability-rating-taxonomy`.

### Structure

- **Priority P1 (Critical)** → **P5 (Informational)**.
- Each leaf is a specific bug class with a default priority that can be **upgraded or downgraded** per program.
- Example: `Server-Side Injection > SQL Injection` defaults to P1; `Cross-Site Scripting > Reflected > Non-Self` defaults to P3.

### Why it matters for payout

- Most programs publish a **payout table mapped to P1–P5**, not raw CVSS.
- Triage will quote the VRT path in the comment thread; if you disagree you cite a sibling path with higher priority and justify.
- Some bug classes are **VRT excluded** (out of scope) by default — e.g., `Server Security Misconfiguration > Lack of Password Confirmation`. Verify in the brief.

### Tactical use

- Before submitting, look up the exact VRT node and **quote it in your report title**: `[P2 — Broken Access Control > IDOR > Horizontal]`.
- Pre-empt downgrades by addressing the typical "why this is not P3" question (impact, business context) — see [[demonstrating-impact]].
- For new bug classes not yet in VRT, propose a path via the public GitHub repo `https://github.com/bugcrowd/vulnerability-rating-taxonomy`.

## Reputation: Kudos, Points, Priority, Trust

Bugcrowd tracks four overlapping researcher metrics:

- **Kudos points**: awarded for valid reports even when bounty is zero (VDPs). They drive leaderboard rank.
- **Submission points**: weighted by VRT priority.
- **Accuracy / Signal**: ratio of valid to invalid submissions — affects invitations.
- **Trust score**: identity verification level (0 → fully verified).

Private invites typically require: signal above program threshold, trust verified, country not on program denylist, and matching skill tags. See [[program-selection-tactics]] for how to optimise.

## Program types

### Public Bug Bounty (BB)

Standard paid program, open to all. Equivalent to H1 public programs.

### Private Bug Bounty

Invite-only. Most lucrative; gated by trust score + accuracy + skill.

### Pen Test as a Service (PTaaS / Next Gen Pen Test)

- Time-boxed (1–4 weeks), fixed roster of researchers, hourly + bonus pay model.
- Requires application + interview; you sign per-engagement NDA.
- Heavy methodology focus — see [[testing-methodology-checklists]] and [[oscp-exam-methodology]].

### Attack Surface Management (ASM)

- Bugcrowd offers continuous discovery; some programs reward asset discovery findings.
- Pair with your own recon — [[continuous-recon-automation]], [[expanding-attack-surface]].

### Vulnerability Disclosure Program (VDP)

- No bounty, only kudos and recognition.
- Often the only legal channel for government targets — see [[responsible-disclosure-across-jurisdictions]].

## Rules of Engagement (ROE) comprehension

Each Bugcrowd brief has standard sections you must read top to bottom:

- **Targets in scope**: domain, mobile binary hash, IP range, source repo.
- **Targets out of scope**: subdomains, third-party SaaS, marketing sites.
- **Focus areas**: bug classes the program actively wants — bonus territory.
- **Out-of-scope vulnerabilities**: VRT exclusions, dupe categories, accepted risks.
- **Disclosure terms**: coordinated, private-forever, or restricted.
- **Safe harbour clause**: jurisdictional carve-outs.
- **Reward range table**: P1–P5 with tiered bonuses for focus areas.

Cross-reference with [[program-scope-reading]] and [[scope-vertical-vs-horizontal]] before touching a target.

## Submitting a report

1. Open **Submit Report** on the program's brief page.
2. Pick the **VRT path** from the dropdown — search by keyword.
3. Title: `[VRT-path] — short impactful summary`.
4. Target: select from the dropdown (must match a scoped asset).
5. Description: TL;DR → reproduction steps → impact → remediation. Reuse the template from [[report-writing-step-by-step]].
6. Attach PoC: video (MP4 < 50 MB), Burp request files, screenshots. Store large artifacts in the report, not external links — see [[report-writing]].
7. Add **CVSS** if asked but always also restate the VRT priority.
8. Hit Submit. The state machine moves: `New → Triaged → Resolved → Rewarded`.

### Triage interactions

- Bugcrowd's **Application Security Engineers (ASEs)** triage first, then route to customer.
- Reply via the report thread; tag `@bugcrowd_triage` for escalations.
- You can request a **priority upgrade** by citing VRT siblings and business impact.
- For dupes, ask if you can see the original ID for learning — see [[dupe-mental-model]].

## Payouts

- Currency: USD by default, paid via TIPALTI.
- Frequency: triggered on `Rewarded` state, batched weekly.
- Minimum payout depends on method (PayPal $1, wire $50+).
- **Tax**: W-8BEN or W-9 required; 1099 issued for US residents over $600/year.
- **Retest**: many programs offer a retest workflow — verify the fix and earn a small bonus (often 10–20 percent of original).

## Crowdcontrol — the customer platform

Researchers don't log in to Crowdcontrol directly, but understanding it helps:

- Customers triage, comment, tag, and route findings via Crowdcontrol.
- They can mark a report **dupe of internal finding** (rare on H1) — push back with evidence of timestamp and unique exploitation path.
- Integrations: Jira, ServiceNow, GitHub Issues — your report fields map to those.

## Tactical differences vs HackerOne

| Aspect | Bugcrowd | HackerOne |
|---|---|---|
| Severity model | VRT (P1–P5) | CVSS 3.1 / 4.0 |
| Reputation | Kudos + Accuracy + Trust | Signal + Impact + Reputation |
| Triage | Bugcrowd ASE in-house | H1 Triage in-house |
| Retest | Built-in workflow with bonus | Customer-initiated, optional |
| PTaaS | Next Gen Pen Test product | H1 Pentest |
| Disclosure | Mostly private by default | Coordinated disclosure encouraged |
| Public report DB | Limited disclosure feed | Hacktivity (large public corpus) |
| VDP volume | Heavy US gov presence | Heavy with DoD, EU gov |
| Payment processor | TIPALTI | HackerOne Payments (Coinbase optional) |
| Profile portability | LinkedIn-style profile | Hacktivity portfolio |

Implication: on Bugcrowd you **win on accuracy and VRT mastery**; on H1 you win on volume and disclosure-driven reputation. See [[h1-disclosed-report-reading-method]] for the H1 corpus learning loop.

## Workflow to study

1. Read VRT end-to-end once; bookmark the GitHub repo for diffs.
2. Pick 3 public Bugcrowd programs in your target vertical and read every ROE.
3. Submit two low-risk findings (P4 info disclosure, P3 XSS) to a public program to learn the submission UX and triage cadence.
4. Track your accuracy ratio in a spreadsheet — invalid submissions cost more here than on H1.
5. After 5–10 valid reports, apply to Next Gen Pen Test if PTaaS interests you.
6. Cross-link your H1 profile and CVEs in your Bugcrowd profile to accelerate private invites.
7. Build a recon pipeline that respects Bugcrowd's `*.scope` policy — see [[automation-and-rinse-repeat]] and [[continuous-recon-automation]].

## Defensive baseline (program operator perspective)

If you ever run a Bugcrowd program:

- Pre-publish a VRT exclusion list — researchers respect explicit "no thanks" lists.
- Set realistic SLAs (5 business days triage, 30 days resolution) and meet them.
- Mirror your scope to a machine-readable format if possible — researchers can automate ROE checks.
- Pay on triage where you can; it builds reputation and attracts top researchers.

## Related

- [[hackerone-platform-deep]]
- [[program-scope-reading]]
- [[scope-vertical-vs-horizontal]]
- [[testing-methodology-checklists]]
- [[program-selection-tactics]]
- [[dupe-mental-model]]
- [[report-writing]]
- [[report-writing-step-by-step]]
- [[demonstrating-impact]]
- [[disclosure-and-comms]]
- [[responsible-disclosure-across-jurisdictions]]
- [[continuous-recon-automation]]
- [[expanding-attack-surface]]
- [[h1-disclosed-report-reading-method]]

## References

- Bugcrowd VRT — `https://bugcrowd.com/vulnerability-rating-taxonomy`
- VRT GitHub source — `https://github.com/bugcrowd/vulnerability-rating-taxonomy`
- Bugcrowd Researcher Documentation — `https://docs.bugcrowd.com/researchers/`
- Bugcrowd University free training — `https://www.bugcrowd.com/hackers/bugcrowd-university/`
- Bugcrowd Standard Disclosure Terms — `https://www.bugcrowd.com/resource/standard-disclosure-terms/`
- TIPALTI payee FAQ for researchers — `https://support.tipalti.com/`
