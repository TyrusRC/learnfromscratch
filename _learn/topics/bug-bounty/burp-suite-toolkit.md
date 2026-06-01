---
title: Burp Suite toolkit — a methodology view
slug: burp-suite-toolkit
---

> **TL;DR:** Burp is not "one tool" but a workflow: Proxy captures, Repeater iterates, Intruder fuzzes, Sequencer measures randomness, Decoder transforms, Collaborator catches blind callbacks, Turbo Intruder races, Match-and-Replace and session-handling rules keep the rig running unattended.

## What it is
A methodology-level map of the Burp surface area for an engagement, in the order you actually use them. Most bugs are found in Repeater and Intruder; the rest of the suite exists to feed those two with clean, authenticated, scoped traffic and to confirm blind findings via Collaborator. Bambdas (Burp's Java-lambda filter language) replace most custom extensions for HTTP-history triage.

## Preconditions / where it applies
- Burp Suite Professional (Community lacks Intruder throttling, Collaborator, Scanner, Bambdas)
- Browser proxy configured, CA installed for HTTPS interception
- Defined target scope before recording — otherwise history fills with noise

## Technique
**Scope and history hygiene.**
- `Target → Scope`: advanced regex on host + path prefix; tick "in-scope only" everywhere
- HTTP history filter Bambda example (only authenticated 200s with JSON bodies):

```java
return requestResponse.hasResponse()
    && requestResponse.response().statusCode() == 200
    && requestResponse.request().hasHeader("Authorization")
    && requestResponse.response().mimeType() == MimeType.JSON;
```

**Match-and-Replace** (Proxy → Match and replace rules). Force a header on every outbound request (canary user-agent for log correlation, fixed `X-Forwarded-For` to test rate-limit keys, swap `Origin` to probe CORS). Keep rules per-project, disable by default.

**Repeater discipline.** Tab-per-finding, rename tabs (`F2`), use tab groups per chain. `Ctrl+R` to send-from-history, `Ctrl+Space` to switch panes. Inspector panel to edit params without breaking encoding.

**Intruder.**
- Sniper for single-position fuzzing
- Cluster bomb for `username × password`
- Pitchfork for paired wordlists (token + matching CSRF)
- Resource pool: throttle to avoid WAF and lockouts; one pool per target host

**Turbo Intruder** for races and high-volume — single-packet attack via `engine=Engine.BURP2`, gate-based concurrency (see [[race-conditions]]).

**Sequencer.** Pull 10k tokens (session ID, password-reset token, CSRF), measure entropy. Anything below ~64 bits effective is brute-forceable.

**Decoder + Inspector.** URL/Base64/hex/HTML chains; JWT decode in Inspector now built-in.

**Collaborator.** Insert payloads — `Burp → Collaborator client → Copy to clipboard` gives a fresh subdomain per click. Confirms blind SSRF/SQLi/XSS/XXE (see [[oast-out-of-band-testing]]).

**Session handling rules + macros** (the unattended-rig piece). When a token expires mid-Intruder run, define:

1. Macro: `POST /auth/refresh` with the refresh-token, extract `access_token` from response
2. Session-handling rule: "run macro before request" on scope, "update header `Authorization: Bearer $token`"

Now Intruder/Scanner run for hours without a 401 cascade.

**Extensions worth keeping.** Param Miner (hidden params + cache poisoning), Autorize (BOLA/BFLA diff — see [[bola]], [[bfla]]), JWT Editor, Hackvertor, Logger++, HTTP Request Smuggler.

**Bambdas for triage.** Custom columns in HTTP history (e.g., a column showing JWT `sub` claim across requests) make IDOR hunting visual. Stored as `.bambda` files, share across team.

## Detection and defence
- This is offensive tooling — the defensive angle is detection: Burp's default user-agent is fingerprintable, Collaborator domains are public, Intruder traffic has telltale param-position patterns
- Defenders: alert on >N 4xx from one client cert / API key in a short window, on requests with `X-Forwarded-For` set from non-CDN origins, on user-agents matching `Burp|sqlmap|nuclei|ffuf`
- For your own opsec on a real engagement: change Burp's UA in Match-and-Replace, route through a residential proxy, throttle Intruder to human-plausible rates

## References
- [PortSwigger: Burp Suite documentation](https://portswigger.net/burp/documentation) — official tool-by-tool reference
- [PortSwigger: Bambdas](https://portswigger.net/burp/documentation/desktop/tools/proxy/http-history/bambdas) — filter language reference

See also: [[testing-methodology-checklists]], [[oast-out-of-band-testing]], [[automated-fuzzer-vuln-discovery]].
