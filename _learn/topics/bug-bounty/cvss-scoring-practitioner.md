---
title: CVSS scoring — practitioner guide
slug: cvss-scoring-practitioner
aliases: [cvss-practitioner, cvss-scoring]
---

> **TL;DR:** CVSS is the lingua franca of vulnerability severity, but it is a blunt instrument — Base metrics describe an abstract worst-case attacker, not your specific bug, and triage teams routinely down-score reports that mis-apply Scope, Privileges Required, or chained impact. This note walks through CVSS 3.1 and 4.0 metrics from a practitioner's view (what each vector means, where scorers go wrong, how platforms weight it), and pairs with [[demonstrating-impact]], [[hackerone-platform-deep]], and [[bugcrowd-platform-deep]] for translating a score into a payout.

## Why it matters

Severity is the variable that drives bounty amount, SLA, and remediation priority. Get it wrong by one band (High vs Critical, Medium vs High) and you leave money or risk on the table. CVSS is the default scale on H1, Bugcrowd, Intigriti, YesWeHack and most internal VRPs. It is also poorly understood — most reporters memorise a "looks Critical, vector AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H" pattern and never internalise what each letter means. Triagers who do understand it will trim your score and the bounty with it.

CVSS also has structural limitations that bite practitioners: it cannot natively express "reachable only after a chain", it conflates exploitability and impact, and Base scores ignore environment. CVSS 4.0 (Nov 2023) tries to fix some of this with Threat and Environmental metrics and supplemental categories. Knowing both versions matters because programs are mid-migration through 2025–2026.

## Base metrics — what each really means

### Attack Vector (AV)

- **Network (N)** — exploitable across an L3 boundary. The bug is reachable from the public internet or another routable network.
- **Adjacent (A)** — same broadcast/L2 segment, Bluetooth, same VPC. Common scoring mistake: marking same-region cloud control-plane bugs as Adjacent when they are actually Network.
- **Local (L)** — local access required (shell, IPC, USB-as-keyboard). Not "local network" — that's Adjacent.
- **Physical (P)** — physical touch, including evil-maid and JTAG. See [[uart-jtag-debug]] and [[hardware-glitching-deep]].

Practitioner tip: a SSRF that hits AWS IMDS from a public web app is `AV:N` because the entry point is Network. The post-condition (touching `169.254.169.254`) doesn't downgrade it. Pair with [[ssrf-to-cloud]] and [[aws-imds-ssrf-pivot]] when arguing.

### Attack Complexity (AC)

- **Low (L)** — fire and forget. No race, no environment-specific tuning.
- **High (H)** — requires conditions outside attacker control: timing, leaked secrets, victim configuration. Reserve for true races, heap-spray reliability problems, or "only works if admin recently logged in".

Common error: marking `AC:H` because the bug needs a specific endpoint or header. That's not High Complexity — that's just knowing the target. See [[testing-methodology-checklists]] on documenting reproducibility.

### Privileges Required (PR)

- **None (N)** — unauthenticated.
- **Low (L)** — any registered user.
- **High (H)** — admin, tenant-owner, or other elevated role.

Trap: self-registration on a SaaS does NOT make a bug `PR:N` — it's `PR:L` because an attacker had to create the account. The exception is when account creation is the attack (e.g. invite abuse). For [[bola]] and [[idor]] across tenants, `PR:L` is correct even though the attacker is "just a user" — they still need an account.

### User Interaction (UI)

- **None (N)** — server-side or zero-click.
- **Required (R)** — victim clicks a link, visits a page, opens a file. Stored XSS that fires on a profile page admins routinely visit is still `UI:R`, but Environmental can capture the high likelihood.

CVSS 4.0 splits this into **Passive (P)** (victim does normal activity) and **Active (A)** (victim performs unusual action). Use it — a stored XSS in an admin panel is `UI:P` 4.0, which scores higher than 3.1's blanket `UI:R`.

### Scope (S) — the most-abused metric

- **Unchanged (U)** — impact stays within the vulnerable component's security authority.
- **Changed (C)** — impact crosses an authority boundary: hypervisor escape, sandbox break, SSRF that pivots to a different trust zone, XSS in an iframe that touches the parent origin.

Over-scoring `S:C` is the single biggest reason triagers trim scores. SSRF that reads metadata is `S:C` only if you actually pivoted out of the application's authority. A reflected XSS is `S:U`. A subdomain takeover that lets you steal session cookies for the parent is `S:C`. When in doubt, ask: "did I cross an authority boundary the original component was supposed to enforce?"

CVSS 4.0 replaces Scope with **Subsequent System Impact** (`SC/SI/SA`), splitting impact on the vulnerable system (`VC/VI/VA`) from impact on downstream systems. This is more honest and easier to score chains. See [[demonstrating-impact]].

### CIA Impact (C / I / A)

- **High (H)** — total loss. All data, all integrity, full DoS.
- **Low (L)** — partial loss. Some records, some fields, some endpoints.
- **None (N)** — no impact in this dimension.

Practitioner trap: an IDOR exposing one user's email is `C:L`, not `C:H`, because the attacker pulls one record at a time. If it's a list endpoint dumping all users, `C:H`. Triagers will ask for the proof — see [[demonstrating-impact]] and [[report-writing-step-by-step]].

## Temporal metrics (CVSS 3.1) / Threat metrics (CVSS 4.0)

CVSS 3.1 Temporal:

- **Exploit Code Maturity (E)** — Unproven / PoC / Functional / High. Most bug-bounty submissions are `E:F` (you have a working PoC).
- **Remediation Level (RL)** — Unavailable / Workaround / Temporary / Official. Pre-fix bugs are `RL:U`.
- **Report Confidence (RC)** — Unknown / Reasonable / Confirmed.

CVSS 4.0 simplifies this into **Threat metrics**: Exploit Maturity (Attacked / PoC / Unreported / Not Defined). It folds RL and RC into Supplemental.

Programs rarely require Temporal/Threat in submissions but use it internally to drive patch SLAs. Worth filling in honestly — overstating `E` makes you look unserious.

## Environmental metrics

Environmental lets the asset owner re-weight Base for their context: a Confidentiality-critical asset gets `CR:H`, and Modified Base lets them say "in our env the bug is actually `AV:A` because the endpoint isn't internet-facing." This is where programs legitimately lower your score.

You usually can't argue Environmental — only the program owns that context — but you can pre-empt it. If you know an endpoint is internet-facing, screenshot the public reachability in your PoC. See [[program-scope-reading]] and [[scope-vertical-vs-horizontal]].

## Common scoring errors

### Over-scoring Scope

Most "I think this is Critical" reports are actually High because the reporter set `S:C` for an SSRF that didn't pivot, an XSS that didn't cross origins, or an open redirect. Save `S:C` for: sandbox escapes, hypervisor breaks, cross-tenant impact in [[bola]] / [[bfla]], SSO bugs that affect downstream apps, and SSRF that reaches an authority boundary (cloud metadata, internal admin services).

### Under-scoring chained impact

The opposite mistake: a stored XSS in admin panel + CSRF token leak + admin role assignment is reported as three separate Mediums. Chain them in one report with one CVSS reflecting the worst end-state. See [[demonstrating-impact]] and [[account-takeover-modern-chains]].

### Mis-applying PR

Self-registered SaaS bugs are `PR:L`, not `PR:N`. Bugs requiring a paid plan are still `PR:L` — CVSS doesn't model cost. Bugs requiring victim-side privilege (CSRF against an admin) are `PR:N` on the attacker side with `UI:R`.

### Confusing AC with reproducibility

A bug that only fires on Tuesdays during a specific deploy window is `AC:H`. A bug that requires a particular URL parameter format is `AC:L` — you just had to find it.

### Forgetting Availability

Memory-corruption and parser bugs almost always have `A:H` even if you stopped at info-leak. DoS-only bugs are often `A:H, C:N, I:N`. Don't zero out CIA just because you focused on one dimension.

## How platforms weight CVSS vs custom severity

- **HackerOne** — programs can use CVSS or H1's Severity (None/Low/Medium/High/Critical) which maps roughly to CVSS bands. Many enterprise programs require CVSS 3.1; some moved to 4.0 in 2025. See [[hackerone-platform-deep]].
- **Bugcrowd** — uses **VRT** (Vulnerability Rating Taxonomy), an opinionated mapping of bug class → P1–P5. VRT often diverges from CVSS for web bugs (BAC is P1 even when CVSS scores High). See [[bugcrowd-platform-deep]].
- **Intigriti / YesWeHack** — CVSS-first with program-specific overrides.
- **Internal VRPs (Google, Microsoft, Meta)** — proprietary scales (Google's VRP tiers, MSRC Critical/Important/Moderate/Low) only loosely tied to CVSS. See [[case-study-google-vrp-writeup-patterns]].

Practical move: score CVSS honestly, then translate to the program's scale in your report. Don't argue both — pick the scale the program uses and back it with evidence.

## Limitations in practice

- **No native chaining** — CVSS scores a single vector. Document chains narratively.
- **Exploitability vs impact conflation** — a hard-to-reach `C:H` bug can score lower than an easy `C:L` bug. Programs adjust via Environmental or bounty matrices.
- **No business-logic awareness** — a $5M wire-fraud bug and a stored XSS can score similarly. See [[demonstrating-impact]].
- **Version drift** — 3.1 and 4.0 produce different numbers for the same bug. Always state which version.
- **No likelihood / threat-intel input by default** — 4.0's Threat metrics help, EPSS supplements.

## Workflow to study

1. Re-score 10 recent [[h1-disclosed-report-reading-method]] reports yourself before reading the triager's score. Compare.
2. Take a chained ATO you wrote (or one from [[account-takeover-modern-chains]]) and score each link plus the chain. Note where Scope changes.
3. Score the same bug in 3.1 and 4.0. Build intuition for the delta.
4. Build a personal cheat-sheet of edge cases: self-register `PR:L`, SSRF `S:U` unless pivoted, stored XSS in admin = `UI:R`/`UI:P`, DoS = `A:H`.
5. Read FIRST.org's CVSS 4.0 examples document end-to-end.
6. For each program in your rotation, note their scoring scale (CVSS version, VRT, custom) in your [[program-selection-tactics]] notes.

## Related

- [[demonstrating-impact]]
- [[report-writing-step-by-step]]
- [[hackerone-platform-deep]]
- [[bugcrowd-platform-deep]]
- [[account-takeover-modern-chains]]
- [[ssrf-to-cloud]]
- [[bola]]
- [[idor]]
- [[case-study-google-vrp-writeup-patterns]]
- [[program-scope-reading]]
- [[testing-methodology-checklists]]

## References

- FIRST CVSS 4.0 specification — <https://www.first.org/cvss/v4-0/specification-document>
- FIRST CVSS 3.1 specification — <https://www.first.org/cvss/v3.1/specification-document>
- FIRST CVSS 4.0 examples — <https://www.first.org/cvss/v4-0/examples>
- Bugcrowd Vulnerability Rating Taxonomy — <https://bugcrowd.com/vulnerability-rating-taxonomy>
- HackerOne severity guidance — <https://docs.hackerone.com/en/articles/8409812-severity>
- EPSS (Exploit Prediction Scoring System) — <https://www.first.org/epss/>
