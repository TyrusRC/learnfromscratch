---
title: CTF-to-bug-bounty transition playbook
slug: ctf-to-bug-bounty-transition
aliases: [ctf-to-bb, ctf-to-bug-bounty, transitioning-from-ctf]
---

> **TL;DR:** CTF and bug bounty look similar (find vulns, write impact) but have very different feedback loops. CTF tells you the answer is on a single box; bug bounty tells you almost nothing and asks you to prove the bug is in scope, in production, and high-impact. The skills that win CTFs (single-shot exploitation, clever payloads) don't directly map. Skills that win bug bounty: scoped recon, methodical surface coverage, business-impact framing, and dupe-aware testing. Companion to [[hacker-mindset-questioning]] and [[h1-disclosed-report-reading-method]].

## Why the transition is non-trivial

In CTF:
- The bug **exists** by definition.
- The surface is small (one box, one app, one binary).
- You have full visibility.
- Solving = scoring; no follow-up needed.
- Time is bounded; difficulty is curated.

In bug bounty:
- There may be **no bug** in scope.
- The surface is enormous (subdomains, JS, APIs, mobile, third-party integrations).
- You have black-box visibility.
- Solving = report writing, triage, duplicate adjudication, regression battles.
- Time is open-ended; payoff is uncertain.

CTF players often hit the bug bounty world and burn out because the success ratio is so different.

## What transfers directly

- **Vulnerability class knowledge** — SQLi, XSS, deserialisation, kernel UAF — all directly useful.
- **Tooling fluency** — Burp Suite, sqlmap, ffuf, Ghidra, gdb-pwn — directly useful.
- **Exploit creativity** — a player who can chain three techniques will chain them in bounty too.
- **Patience for technical detail** — debugging skill scales.
- **Crypto / cipher analysis** — useful for novel JWT / SAML / OAuth attacks.

## What needs unlearning

- **Single-bug mindset** — bug bounty rewards chains and impact; isolated bugs often get "informative".
- **"Find anything and submit"** — bounty programs filter for in-scope + novel + impactful. Submitting clones / out-of-scope wastes triage cycles and hurts reputation.
- **Quick-win speed** — bug bounty needs sustained focus over days/weeks per target, not sprint-style.
- **Ignoring business context** — CTF doesn't care if the company uses the feature; bounty does.
- **Self-promotion habits** — some CTF / disclosure habits (public PoC, Twitter brags) burn programs and earn bans.

## The new core skills

### 1. Recon

CTF gives you the URL. Bug bounty doesn't. You need to find:
- Every subdomain in scope.
- Every endpoint, JS file, API route.
- Every linked third-party.
- Every staging / dev / preview environment.

See [[subdomain-enumeration]], [[github-recon]], [[js-recon]], [[content-discovery]].

### 2. Scoping discipline

Programs publish scope rules. Reading them carefully avoids hours of out-of-scope work:
- What domains are in scope?
- What types of bug are accepted?
- What's explicitly out of scope?
- What's the bounty tier per severity?

See [[program-scope-reading]], [[scope-vertical-vs-horizontal]].

### 3. Methodical surface coverage

CTF: try every technique on the one box. Bounty: prioritise which endpoints get which techniques to fit available time.

See [[testing-methodology-checklists]], [[expanding-attack-surface]].

### 4. Impact framing

A bug that "could leak emails" pays less than a bug that "leaks emails of 100k users including PII and password reset tokens". Same root cause, different impact framing.

See [[demonstrating-impact]], [[report-writing-step-by-step]].

### 5. Dupe avoidance

Most low-hanging-fruit on mature programs is already reported. Submitting it = dupe + no bounty + lost time. Hunt where dupes are unlikely:
- Newly-launched features.
- Acquisitions.
- Less-tested endpoint types (APIs, gRPC, GraphQL aliasing).
- Business logic, not just OWASP top-10.

See [[dupe-mental-model]].

### 6. Patience and pipeline

CTF rewards 4-hour bursts. Bounty rewards consistent 1–2 hour daily sessions sustained for months. You'll have weeks with no findings. The pipeline matters more than any single hunt.

See [[burnout-and-pipeline]], [[continuous-recon-automation]].

## A realistic first-90-days plan

### Week 1–2

- Pick **one program** with public scope and reasonable bounty range (start mid-tier, not "Google VRP").
- Read **every disclosed report** for that program (some publish via H1 hacktivity).
- Map the program's product yourself — primary flows, account types, API surfaces.

See [[h1-disclosed-report-reading-method]].

### Week 3–6

- Run recon ([[subdomain-enumeration]], etc.) and triage the surface.
- Walk through every disclosed-report pattern on your selected program.
- Build a private notes file.

### Week 7–12

- Focus testing on the **fresh areas** (new acquisitions, new features, less-trafficked endpoints).
- Submit your first reports — even informational ones — to learn the program's triage style.
- Refine your methodology based on triager feedback.

After 90 days, expect:
- Familiarity with the program's surface.
- 1–3 valid submissions (could be more, could be zero — both normal).
- A working methodology for the next program.

## CTF skills that translate especially well

- **Web bugs** (XSS, SQLi, prototype pollution, SSTI) — bug bounty mostly is this.
- **OAuth / SAML / OIDC manipulation** — CTF teaches the protocol; bounty rewards finding implementation bugs.
- **Mobile reverse engineering** — many programs include mobile.
- **Cloud / SaaS understanding** — modern programs are cloud-native.
- **Forensic / IR mindset** — useful for understanding business impact.

## What to skip initially

- **Pwn / heap exploitation** — translates to OS / firmware bounties (a tiny subset of programs); learn web first.
- **Reverse engineering** — useful but not the volume of bounty income unless on specific programs.
- **Crypto-CTF puzzles** — rare in modern bug bounty; useful for niche programs.

## Combining CTF and bounty

Active CTF play *during* bounty hunting maintains skills:
- CTF for **technique acquisition** and **rapid feedback**.
- Bug bounty for **income** and **real-world impact**.
- Reading **bug-bounty writeups** trains new techniques.
- **Open-source** contribution (huntr.dev, Internet Bug Bounty) bridges both.

Many top hunters keep both pipelines active.

## Income / time expectations

Realistic in 2025:
- **First 6 months**: $0–500 total earnings for most.
- **Year 1**: $1k–10k for the median; outliers higher.
- **Year 2+**: top hunters six figures; median hunters supplement income.
- Bug bounty as **sole income** is rare and high-variance.

Treat as supplementary income + technique training initially.

## Related

- [[hacker-mindset-questioning]]
- [[testing-methodology-checklists]]
- [[h1-disclosed-report-reading-method]]
- [[burnout-and-pipeline]]
- [[program-selection-tactics]]
- [[oscp-exam-methodology]]
- [[dupe-mental-model]]

## References
- [Pentesterland — writeups archive](https://pentester.land/list-of-bug-bounty-writeups.html)
- [HackerOne hacktivity](https://hackerone.com/hacktivity)
- [Bug bounty mentor lists — Twitter / Discord communities](https://twitter.com/i/lists)
- [STÖK / NahamSec / JR0ch17 / InsiderPhD — YouTube channels](https://www.youtube.com/)
- See also: [[h1-disclosed-report-reading-method]], [[testing-methodology-checklists]], [[bug-bounty-methodology]], [[burnout-and-pipeline]]
