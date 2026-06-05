---
title: Case study — Google VRP writeup patterns
slug: case-study-google-vrp-writeup-patterns
aliases: [google-vrp-patterns, google-bug-bounty-patterns]
---

> **TL;DR:** Google's Vulnerability Reward Program is one of the longest-running and highest-paying programs. Public writeups from external hunters and from Google Bug Hunters posts cluster around: (1) OAuth / SSO scope misuse on Google products, (2) IDOR through internal-ID exposure in third-party Workspace add-ons, (3) Chromium renderer-to-browser sandbox bugs, (4) Android OS / Pixel firmware bugs, (5) GCP product-feature abuse. Patterns to copy: target the seam between two Google products. Companion to [[case-study-h1-top-disclosed-2024-2025]] and [[h1-disclosed-report-reading-method]].

## The Google scope landscape

Google's VRP is in fact several programs:

- **Google VRP (apps)** — google.com, maps, gmail, docs, drive, calendar, photos, classroom, etc.
- **Chrome VRP** — Chromium browser bugs.
- **Android VRP** — AOSP and Pixel.
- **GCP VRP** — Google Cloud Platform products.
- **OSS VRP** — Google-maintained open source.
- **Patch Rewards** — for upstream OSS patches.

Each has its own scope, payout table, and "bonus" categories.

Reading the bonus table carefully before testing is the difference between $5k and $30k.

## Pattern 1 — Seam between two Google products

Repeating shape:

- Product A grants identity X.
- Product B trusts identity X but interprets a property of X differently.
- Hunter finds an input where B is more permissive than A intends.

Examples in public writeups: app-to-app share permissions across Drive / Docs / Sheets; Workspace marketplace add-ons over-trusting Drive scopes; Calendar invites embedding OAuth-relevant context.

Method: pick two Google products you use; map the data flow; find the trust assertion in each.

## Pattern 2 — Internal-ID exposure

Repeating shape:

- A Google product exposes an internal ID (numeric, opaque-looking) in a URL or JSON response.
- A separate Google product accepts the same ID via a public-ish endpoint and reveals more about the object.
- Together: enumeration / IDOR / cross-product info disclosure.

Internal IDs are a goldmine because they survive across product UI changes.

## Pattern 3 — Chromium renderer-to-browser bugs

Chrome VRP pays heavily for chains:
- Renderer RCE (V8 / Blink / WebRTC / WebGPU bug).
- Sandbox escape (Mojo IPC, GPU process, kernel).
- Persistence.

These are mostly the realm of full-time browser researchers. See [[browser-exploitation-primer]].

For a learner: read disclosed Chrome bug reports (after the 90-day delay). Each has a complete root cause + reproducer + patch.

## Pattern 4 — Android / Pixel firmware

Android VRP pays for AOSP and Pixel-specific bugs:
- Privileged system_server flaws.
- Permission model bugs (cross-app permission leak).
- Kernel bugs reachable from app context.
- Firmware (modem, GPU, bootloader).

Pixel-specific bugs pay multipliers. Trinity baseband and Mali GPU bugs have generated large payouts in recent years.

## Pattern 5 — GCP product abuse

GCP VRP pays for:
- IAM bugs (cross-tenant privilege escalation, service account confusion).
- Workload Identity Federation misuse — see [[gcp-workload-identity-federation-abuse]].
- API surface bugs (gRPC parsing, REST mass-assignment).
- Project-to-project breakouts.

Method: enumerate every GCP product's REST API and look for delete / update endpoints that miss IAM checks.

## Pattern 6 — Mass-assignment in Workspace APIs

Repeating shape:
- A Workspace API accepts an object update.
- Update body includes a field the user shouldn't be able to set (owner, sharing flags, OAuth scope).
- Backend doesn't filter.

Workspace APIs are large and evolved over time; field allowlists are often partial. See [[mass-assignment]] and [[graphql-source-review]] (similar pattern shape).

## Pattern 7 — Auth-flow CSRF / login-as-victim

Despite years of hardening, Google has paid out on:
- OAuth login CSRF.
- Account-link CSRF (binding attacker identity to victim account).
- Recovery-flow CSRF.

See [[account-takeover-modern-chains]], [[onsite-request-forgery]].

## What pays a lot vs what pays a little

High-pay categories (public writeups):
- Pre-auth RCE on a Google service ($100k+).
- Account takeover without user interaction ($30k+).
- Internal-tool RCE ($30k+ with bonuses).
- Chrome renderer + sandbox escape chain ($100k+).
- Pixel firmware kernel chain ($1M+ in special tiers).

Low or no pay:
- Self-XSS on consumer products.
- Open redirects without scope.
- Subdomain takeovers on retired surfaces.
- Reports on products marked out-of-scope.

Read the rules. Several hours of testing on out-of-scope assets pay zero.

## Tools

Public Google Bug Hunters writeups mention:
- Burp Suite (standard).
- `gcloud` CLI for GCP enumeration.
- `androguard`, `apktool`, `frida` for Android.
- Chromium source tree + DevTools for Chrome research.
- `gsuiteddl`-style scripts for Workspace API enumeration.

## Reading sources

- **Google Bug Hunters blog** — `bughunters.google.com/blog/`. Often includes detailed writeups by researchers.
- **External writeups** indexed on pentester.land — search "Google" or "Workspace".
- **Disclosed Chromium bugs** — `crbug.com` with the security label, after the disclosure window.
- **Project Zero** posts on Chrome / Android — high signal.

## How to start

1. Pick one Google product you use daily.
2. Read all disclosed reports on it (mostly via external blogs).
3. Map its endpoint surface (proxy through Burp during a real session).
4. List the *identities* the endpoint trusts (cookie, OAuth, Workspace ACL, internal ID).
5. Look for endpoints that take identity-derived parameters in the body.

Even before finding a bug, the mapping is your future audit baseline.

## References
- [Google Bug Hunters](https://bughunters.google.com/)
- [Chrome VRP](https://g.co/chrome/vrp/)
- [Android Rewards](https://bughunters.google.com/about/rules/android-friends)
- [GCP VRP](https://bughunters.google.com/about/rules/google-friends/6625378258649088/google-and-alphabet-vulnerability-reward-program-rules)
- [Project Zero](https://googleprojectzero.blogspot.com/)
- See also: [[case-study-h1-top-disclosed-2024-2025]], [[case-study-orange-tsai-research-pattern]], [[browser-exploitation-primer]]
