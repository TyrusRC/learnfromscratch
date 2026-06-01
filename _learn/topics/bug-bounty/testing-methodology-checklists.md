---
title: Per-class testing checklists
slug: testing-methodology-checklists
---

> **TL;DR:** Maintain a one-page checklist per bug class — every endpoint gets walked through the relevant lists, ticked off as tested, and any gaps become hunting leads.

## What it is
A personal, evolving set of tightly-scoped checklists — one per bug class (IDOR, SSRF, XSS, SQLi, SSTI, deserialisation, CORS, OAuth, race condition, etc.). Each checklist enumerates the variants worth trying, the prerequisites, and a quick negative test. Applied per endpoint, they prevent the "I think I tested that" failure mode and surface coverage gaps you would otherwise miss. The checklists are a hunter's flight-check, not a course curriculum.

## Preconditions / where it applies
- An endpoint inventory ([[endpoint-spidering]], [[js-endpoint-extraction]])
- A target dossier ([[getting-feel-for-target]]) so you know which classes are even applicable
- A note system ([[note-taking-while-hacking]]) to record what was tested where

## Technique
1. **Build per-class lists, not per-OWASP-category lists.** Granularity matters — "XSS" is too broad; split into reflected/stored/DOM/template-injection, each with its own prerequisites and payload variants.
2. **Each checklist line is one concrete test.** Bad: "test for SSRF". Good: "submit `http://169.254.169.254/latest/meta-data/iam/` as `url` param; check for AWS metadata response". Triagers love specificity; so does your future self at midnight.
3. **Keep the checklists short and orthogonal.** If two items always pass/fail together, merge them. A 10-line list applied 50 times beats a 200-line list applied twice.
4. **Run checklists per endpoint, not per app.** For each new endpoint:
   - Classify the endpoint (auth/anon, GET/POST, JSON/form, returns HTML/JSON)
   - Match to applicable checklists
   - Walk each list, mark `OK / VULN / N/A / SKIP-reason`
   - The unticked items are next-session work
5. **Refine per program.** After each engagement, fold in the new classes / variants you saw. Programs running custom GraphQL get GraphQL-specific lines; programs running Rails get mass-assignment lines.
6. **Pair with seeded payload files.** A checklist line should reference the payload file you use, not embed payloads — keeps the list short and lets you iterate payloads centrally. PayloadsAllTheThings is the standard seed.

Example IDOR checklist (10 lines, applies to any authenticated endpoint with an identifier):
- Numeric ID — increment/decrement
- UUID — replace with another known UUID (account B)
- Email/username as ID — substitute
- Try `PUT/PATCH/DELETE` not just `GET`
- Try HTTP method override (`X-HTTP-Method-Override: DELETE`)
- Wrap ID in array `[1, 2]` (mass enumeration)
- IDOR via secondary parameter (`org_id` while spoofing main ID)
- IDOR via path traversal in non-path parameters
- Try ID in stale OAuth tokens
- Re-test after role change

## Detection and defence
- Defenders should ship per-class internal test catalogues that mirror these — pre-commit and CI checks
- WAFs catch a small fraction of these tests; server-side authorisation, parameterised queries, and contextual encoding are the actual fixes
- For the hunter: do not let checklists replace curiosity. The list keeps you thorough; novelty comes from off-list intuition

## References
- [OWASP WSTG](https://owasp.org/www-project-web-security-testing-guide/) — exhaustive test catalogue to prune from
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — payload corpus per class
- [HackTricks pentesting web](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — class-by-class technique index
