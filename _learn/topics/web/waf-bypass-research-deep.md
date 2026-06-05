---
title: WAF bypass research — deep
slug: waf-bypass-research-deep
aliases: [waf-bypass-deep, waf-research-deep]
---

> **TL;DR:** Modern WAF bypass research is dominated by parser differentials — making the WAF and origin disagree about where a request begins, ends, or what its body contains. This deep dive ties together transport-layer quirks (HTTP/2 and HTTP/3), encoding mismatches, oversize-payload tricks, ML-WAF evasion, and rate-limit rotation. Pair this with [[waf-bypass]] for the primer, [[waf-bypass-advanced-techniques]] for tactical payload patterns, and [[http-request-smuggling]] / [[http-smuggling-modern-variants]] for the smuggling family that underpins much of this research.

## Why it matters

WAFs are the canonical "compensating control" relied on by SOC 2, [[pci-dss-4-implementation]], and most enterprise stacks. When a WAF can be bypassed, every patch lag, every misconfigured app, and every shadow API behind that WAF instantly becomes exploitable. Cloud-managed WAFs (Cloudflare, Akamai, AWS WAF, Imperva, F5 Distributed Cloud) now sit in front of a large fraction of the public web, so a single class of bypass affects thousands of programs at once — which is why bug-bounty researchers and APTs alike treat WAF research as a force multiplier. See [[apt-tradecraft-russian-svr-fsb]] and [[apt-tradecraft-chinese-mss]] for tradecraft that routinely leans on WAF/CDN abuse, and [[domain-fronting-and-cdn-abuse]] for the network-layer twin.

## Classes of modern bypass

### 1. Parser-differential bypass

The single most productive class. The WAF parses the request one way; the origin parses it another. Whatever the origin sees and the WAF doesn't is your bypass.

- **Header parsing differentials.** Duplicate `Content-Length`, conflicting `Transfer-Encoding`, whitespace before colons, line folding, NUL bytes, `\r` without `\n`. James Kettle's smuggling series formalised this; see [[http-request-smuggling]].
- **URL parsing differentials.** `;` parameters, `..;/`, `%2e%2e`, mixed `/` and `\`, double-slash normalisation. Orange Tsai's "Breaking Parser Logic" remains the canonical reference; cross-link [[case-study-orange-tsai-research-pattern]].
- **Body parsing differentials.** WAF inspects `application/json` but origin accepts `application/x-www-form-urlencoded` for the same endpoint (Content-Type confusion). Or WAF parses JSON strictly, origin accepts JSON5/trailing commas/comments.
- **Multipart differentials.** WAF only inspects the first part; origin reassembles all parts. Or boundary parsing differs (LF vs CRLF, quoted vs unquoted boundary).

### 2. Transport-layer quirks (HTTP/2 and HTTP/3)

- **H2.CL / H2.TE downgrades.** When the front door speaks HTTP/2 and the origin speaks HTTP/1.1, headers like `Content-Length` and `Transfer-Encoding` get re-serialised, opening smuggling windows. See [[http-smuggling-modern-variants]].
- **Pseudo-header smuggling.** Injecting `:path` containing CRLF, or `:authority` with embedded host headers. Many WAFs only validate the canonical headers, not the HTTP/2 frames.
- **CONTINUATION frame flooding / HPACK abuse.** Some WAFs cap inspected header bytes; sending a giant HPACK-compressed header set can push malicious headers past the inspection budget.
- **HTTP/3 (QUIC).** Even fewer WAFs deeply parse QUIC streams. Early research (2024-2025) shows Akamai, Cloudflare, and AWS WAF all have differential behaviour between their H2 and H3 ingress paths.

### 3. Encoding chains

- **Unicode normalisation.** NFC vs NFKC vs NFD. `ﹰ` (FE70) collapses to `ً` after NFKC. Full-width `＜script＞` becomes `<script>` after the origin's normalisation pass but is invisible to a WAF doing only ASCII signature matching.
- **Percent-encoding chains.** Double and triple URL-encoding (`%2527` -> `%27` -> `'`). Many WAFs decode once; origins decode multiple times depending on framework.
- **JSON inside form, form inside JSON.** `{"q":"%27 OR 1=1"}` where the app `urldecode`s the value server-side.
- **XML / SOAP entity tricks.** Parameter entities, mixed encodings (`UTF-7`, `UTF-16-LE` with BOM), CDATA sections wrapping payloads. See [[ssrf]] and [[host-header-injection]] adjacency.
- **Brotli / gzip quirks.** PortSwigger's 2024 research on Brotli dictionaries and compression-side bypasses — the WAF inspects the compressed body, the origin sees the decompressed one with different byte boundaries.

### 4. Oversize-payload and budget-exhaustion bypass

- **Inspection ceilings.** Most WAFs have a hard cap on body inspection (commonly 8 KB, 64 KB, or 128 KB). Pad with junk before the malicious token.
- **Header count limits.** Send 100+ headers; the WAF inspects the first N, the origin sees them all.
- **Chunked body with tiny chunks.** Some WAF body parsers give up after a chunk threshold.
- **Slowloris-style send pacing.** Trickle the request so the WAF's inspection timeout fires and the request is forwarded uninspected (fail-open misconfig).

### 5. ML-based WAF evasion (Akamai, Cloudflare, Imperva)

- **Score-tuning.** Cloudflare and Akamai expose an attack-score header internally; researchers infer thresholds via oracle queries (request -> blocked/allowed) and gradient-search payloads.
- **Adversarial mutation.** Tools like `wafw00f` + custom mutators (`AutoSpear`, `WAFAREE`, internal Burp extensions) evolve payloads against the live oracle. Combine with rotated IPs to avoid rate-block.
- **Context dilution.** Wrap the malicious token in many benign tokens so the per-feature contribution to the model score drops below threshold. e.g. SQL keywords sprinkled in product names.
- **Semantic equivalents.** `/**/`, `UNION ALL SELECT` -> `UNION DISTINCT SELECT`, alternate quote characters (`%u2019`), tautologies that don't match `OR 1=1` regex but evaluate the same.

### 6. IP rotation and rate-limit defeat

- **Residential proxy pools** (BrightData, Soax) — WAFs frequently treat residential ASNs as low-risk.
- **Cloud egress via the WAF's own provider.** Sending Akamai-bypass traffic from another Akamai-hosted app sometimes routes through trusted internal IPs.
- **AWS API Gateway and Lambda as rotating egress.** Burp's `IP Rotate` extension automates this — every request from a new AWS edge IP.
- **Header-based identity.** `True-Client-IP`, `X-Forwarded-For`, `CF-Connecting-IP` spoofing when origin trusts them after a misconfigured WAF.

## Defensive baseline

- Treat the WAF as **defence in depth**, never as a primary control. Patch and harden the origin.
- Normalise inputs on the origin in the **same way** the WAF does — or, better, terminate parsing at the WAF and forward a re-serialised, canonical request.
- Disable HTTP/1.1 downgrade on the origin where possible; speak HTTP/2 end-to-end. Track [[http-request-smuggling]].
- Cap header count, body size, and chunk count at both WAF and origin with **matching** limits.
- For ML WAFs, monitor the score distribution per endpoint — sudden drift toward "borderline" scores from a small set of IPs is a strong evasion signal. Feed into [[detection-engineering-pyramid-of-pain]] and [[siem-detection-use-case-catalog]].
- Log raw bytes of blocked and borderline requests for post-hoc analysis; many bypasses are only obvious after the fact. See [[ir-from-source-signals]].
- Enforce strict `Content-Type` allowlists per endpoint.
- Tabletop the failure mode "WAF is bypassed" with [[purple-team-feedback-loop]] and [[atomic-red-team-emulation-deep]].

## Workflow to study WAF bypass research

### Step 1 — fingerprint

Identify the WAF (`wafw00f`, response headers, cookies, block-page fingerprints, JA3/JA4 patterns). Note any CDN in front: Cloudflare, Akamai, Fastly, CloudFront, Vercel — see [[cloudflare-tenant-attacks]], [[cloudflare-workers-audit]], [[vercel-edge-and-middleware-audit]].

### Step 2 — build an oracle

Pick a known-blocked baseline payload (a clear XSS or SQLi). Confirm a stable block response. This is your oracle: each mutation either keeps the block, flips to allowed, or flips to a different status. Automate via Burp Intruder, `ffuf`, or a small Python harness.

### Step 3 — categorise the bypass surface

Walk the classes above in order: parser-diff, transport, encoding, oversize, ML, rate. For each, prepare 5-10 candidate payloads. Don't blend categories yet — you want to know *which* class produced the bypass for the writeup.

### Step 4 — reproduce against a lab

Stand up the same WAF in a lab if possible (Cloudflare free tier, AWS WAF on a test ALB, ModSecurity CRS in Docker). Confirm the bypass is general, not target-specific. See [[building-a-research-home-lab]].

### Step 5 — minimise and document

Shrink the payload to the smallest reproducer. Diagram the parser-differential clearly. Use [[report-writing-step-by-step]] and [[demonstrating-impact]] to write it up; if it's bug-bounty, follow [[h1-disclosed-report-reading-method]] style and [[responsible-disclosure-across-jurisdictions]].

### Step 6 — stay current

Feed your inbox with [[keeping-up-with-research-feeds]], read [[case-study-portswigger-top-10-pattern]] annually, and study [[case-study-orange-tsai-research-pattern]] and [[pwn2own-2024-2025-research-roundup]] for fresh primitives.

## Notable public research to anchor on

- James Kettle, **HTTP Desync Attacks** (2019), **Browser-Powered Desync** (2022), **Smuggling at the Frontier** (2024) — the foundational HTTP smuggling corpus.
- Orange Tsai, **Breaking Parser Logic** (Black Hat USA 2018) and **A New Era of SSRF** — parser-differential canon.
- PortSwigger, **Brotli compression bypass** and **header-mangling** research (2023-2024).
- Akamai/Cloudflare ML-WAF score reverse-engineering writeups on bug-bounty platforms (2024-2025).
- Snyk and Imperva research on JSON-based SQL injection that bypassed CRS-style rules.

Cross-link these with [[case-study-google-vrp-writeup-patterns]] and [[case-study-h1-top-disclosed-2024-2025]] when planning your own research arc.

## Related

- [[waf-bypass]]
- [[waf-bypass-advanced-techniques]]
- [[http-request-smuggling]]
- [[http-smuggling-modern-variants]]
- [[cache-poisoning]]
- [[cache-poisoning-modern-chains]]
- [[cache-deception]]
- [[host-header-injection]]
- [[ssrf]]
- [[domain-fronting-and-cdn-abuse]]
- [[cloudflare-tenant-attacks]]
- [[cloudflare-workers-audit]]
- [[vercel-edge-and-middleware-audit]]
- [[case-study-portswigger-top-10-pattern]]
- [[case-study-orange-tsai-research-pattern]]
- [[pwn2own-2024-2025-research-roundup]]
- [[keeping-up-with-research-feeds]]
- [[building-a-research-home-lab]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]

## References

- https://portswigger.net/research/http-desync-attacks-request-smuggling-reborn
- https://portswigger.net/research/browser-powered-desync-attacks
- https://portswigger.net/research/smashing-the-state-machine
- https://www.blackhat.com/docs/us-18/materials/us-18-Orange-Tsai-Breaking-Parser-Logic-Take-Your-Path-Normalization-Off-And-Pop-0days-Out.pdf
- https://owasp.org/www-project-modsecurity-core-rule-set/
- https://github.com/EnableSecurity/wafw00f
