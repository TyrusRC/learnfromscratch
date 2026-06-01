---
title: Common issues to start with
slug: common-issues-to-start-with
---

> **TL;DR:** Run the same 60-minute opening checklist on every new target — IDOR, broken access control, auth-flow flaws, misconfigured CORS, and stored XSS pay out repeatedly because they are missed by scanners.

## What it is
A fixed opening playbook beats freelancing every time you land on a new target. The bugs that pay first are rarely novel — they are bread-and-butter classes that automated scanners miss because they require an authenticated session or a second account. Codifying your opening moves prevents tunnel vision on a shiny endpoint while you walk past a low-hanging IDOR.

## Preconditions / where it applies
- Two test accounts (call them A and B); the program permits multi-account testing
- Burp / Caido running before you touch the app, so every request is captured (see [[getting-feel-for-target]])
- A note template ready ([[note-taking-while-hacking]]) — checklist gets stale fast if you don't record what you tested

## Technique
A pragmatic opening order for any web target:
1. **Auth-flow flaws.** Register, log in, reset password, change email, MFA enrol. Watch for: token in URL, no rate limit on reset, password reset link reusable, email-change without re-auth, MFA bypass via missing server-side check.
2. **IDOR / BOLA.** Note every numeric and UUID-like identifier in URLs and JSON bodies. From account A, fetch one of B's resources by ID. Try `PUT/PATCH/DELETE` not just `GET`. Try predictable IDs first, then leak IDs from public endpoints.
3. **Broken function-level authorisation.** Hit admin endpoints discovered in JS ([[js-endpoint-extraction]]) as a normal user. Try `?role=admin`, mass-assignment of `is_admin`, role-spoofing via headers like `X-Forwarded-User`.
4. **Access control on tenant boundaries.** Multi-tenant apps leak across orgs through `org_id` parameters, shared S3 buckets, or webhook URLs.
5. **CORS / postMessage / clickjacking.** `Origin: https://evil.tld` on credentialed endpoints; check `Access-Control-Allow-Credentials: true` with reflected origin.
6. **Stored XSS in low-friction inputs.** Display names, file names, support-ticket bodies, OAuth `redirect_uri`. Try polyglots; remember CSP often blunts but rarely blocks.
7. **SSRF in any URL-accepting field.** Avatar-from-URL, webhook, SSO callback, RSS importer. Test `127.0.0.1`, `169.254.169.254`, `localhost.target.tld`, DNS-rebinding.
8. **Common misconfigs.** `.git`, `.env`, `swagger.json`, `/actuator/**`, `/wp-json/wp/v2/users`. One curl per host.

Time-box: if nothing landed in 60 minutes, you have signal that the target is hardened — move to [[expanding-attack-surface.md]] or rotate program.

## Detection and defence
- These classes are exactly what OWASP Top 10 (A01 broken access control, A07 auth failures) targets; defenders should have automated tests per route
- Modern WAFs catch some XSS/SQLi but miss IDOR entirely — server-side authorisation checks are the only fix
- For hunters: rotate the order occasionally to avoid testing the same well-trodden paths everyone else hits first

## References
- [PortSwigger Web Security Academy](https://portswigger.net/web-security/all-topics) — labs for each class above
- [OWASP WSTG](https://owasp.org/www-project-web-security-testing-guide/) — exhaustive test catalogue you can prune to a personal checklist
- [HackTricks web pentesting methodology](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — comparable opening flow
