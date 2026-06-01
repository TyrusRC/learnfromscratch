---
title: Getting a feel for the target
slug: getting-feel-for-target
---

> **TL;DR:** Before touching a single payload, click through every feature as a real user with Burp recording — you cannot exploit a flow you do not understand.

## What it is
The pre-test exploration phase. The goal is not to find a bug; it is to map roles, trust boundaries, identifier shapes, and state transitions so that later testing is targeted instead of blind. Hunters who skip this step throw payloads at random forms and miss the lateral / vertical access-control bugs that pay best.

## Preconditions / where it applies
- Proxy of choice running (Burp / Caido) with the target's CA installed in the browser
- Two test accounts, ideally in two tenants/orgs if multi-tenant
- A blank note ([[note-taking-while-hacking]]) and roughly 60-90 minutes of uninterrupted time

## Technique
1. **Walk the product like a paying customer.** Sign up, verify email, log in, do the primary user journey end-to-end, log out. Repeat as account B. Do not try to break anything yet — you are recording the happy path.
2. **Annotate as you go.** For each feature note: which roles can access it, what identifiers it exposes (numeric vs UUID vs slug), what state it mutates, what notifications it sends. A simple table in your notes is enough.
3. **Spot the trust boundaries.** Where does anonymous → authenticated happen? Where does user → admin? Where does tenant A → tenant B? Each crossing is a candidate for [[common-issues-to-start-with]] checks later.
4. **Tech stack and framework.** Cross-reference Wappalyzer / favicon / response headers ([[tech-stack-fingerprinting]]). Knowing it is a Rails app changes what you fuzz; knowing it is GraphQL changes the entire methodology.
5. **Read every JS bundle the browser loads.** Even five minutes scanning chunked JS for `/api/v1/admin/*` strings often surfaces endpoints the UI does not expose ([[js-endpoint-extraction]]).
6. **Catalogue authentication artefacts.** Cookie names, JWT structure (decode with `jwt.io` mentally — don't paste tokens), CSRF token placement, refresh-token flow. These dictate which auth-bypass classes are even applicable.
7. **End with a target dossier** — a one-page summary of roles, endpoints, identifiers, and "things that look interesting." That dossier drives the rest of the engagement.

## Detection and defence
- The walk-through is indistinguishable from normal browsing; this phase generates almost no defender signal
- That stealth is the point — every "what does this button do?" you answer now you do not need to answer mid-exploit when WAF is watching
- For the hunter: resist the urge to fuzz during the walk-through. Once you start payload-testing your brain stops mapping

## References
- [PortSwigger — recon basics](https://portswigger.net/web-security/information-disclosure) — application-level recon mindset
- [OWASP WSTG — Information Gathering](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/01-Information_Gathering/) — structured pre-test checklist
- [HackTricks web pentesting methodology](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — wider methodology this opens
