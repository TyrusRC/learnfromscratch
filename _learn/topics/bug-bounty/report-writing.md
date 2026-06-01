---
title: Report writing
slug: report-writing
---

> **TL;DR:** Five fixed sections — Title, Summary, Repro, Impact, Recommendation. Short, complete, copy-pasteable. Triagers reward clarity faster than they reward severity.

## What it is
The artefact that converts a finding into a payout. A bounty submission's job is to let an unfamiliar engineer reproduce the bug in under five minutes and a triager assign severity in under one. Everything else — narrative, screenshots, CVSS — is in service of those two goals. See also [[report-writing-step-by-step]] for the longer methodology.

## Preconditions / where it applies
- A confirmed bug with a stable repro
- The program's preferred submission template (HackerOne, Bugcrowd, Intigriti differ slightly)
- Cleaned-up evidence: screenshots cropped, tokens redacted, video under 3 minutes if used

## Technique
The five-section structure:

1. **Title.** `[Asset] Class — One-line impact`. Example: `[api.target.tld] IDOR in /v2/invoices/{id} allows reading any tenant's invoices`. Triagers route by title; vague titles get back-of-queue.

2. **Summary.** Two to four sentences. What is broken, on which asset, what an attacker achieves. No tool names, no exploration narrative.

3. **Repro.** Numbered, copy-pasteable. Include:
   - Account setup ("Register two accounts A and B")
   - Exact requests as curl or Burp-export blocks
   - Expected vs actual behaviour at each step
   ```
   curl -sk -H "Authorization: Bearer $A_TOKEN" \
     https://api.target.tld/v2/invoices/$B_INVOICE_ID
   # Expected: 403/404. Actual: 200 with B's invoice JSON.
   ```

4. **Impact.** What does this give an attacker? Tie to a business consequence, not a technical one. "Any authenticated user can enumerate IDs and read every tenant's invoices, including PII and amounts." See [[demonstrating-impact]] — vague impact loses severity.

5. **Recommendation.** One short paragraph. Server-side authorisation check on the resource owner; reference the broken control rather than prescribing implementation detail.

Style rules:
- Plain prose, no marketing tone, no emojis
- Code blocks for every request and response
- Screenshots only when text cannot convey the bug (UI XSS, visual artefacts)
- CVSS vector if the program uses it; skip the numeric score if it disagrees with the program's own severity guide
- Redact session tokens and PII before submitting

## Detection and defence
- Programs grade hunter quality on signal/noise of submissions; clean writeups earn private invites
- A triager closing a "needs more info" thread is the worst outcome — your follow-up clarifications take days. Pre-empt every "but how does this matter?" question in the first draft.
- For the hunter: keep a personal template file; iterating on the same template builds compounding speed

## References
- [HackerOne — writing a great submission](https://docs.hackerone.com/en/articles/8410848-quality-reports) — platform-side scoring criteria
- [Bugcrowd VRT](https://bugcrowd.com/vulnerability-rating-taxonomy) — severity vocabulary triagers actually use
- [disclose.io templates](https://disclose.io/) — boilerplate scope/disclosure language
