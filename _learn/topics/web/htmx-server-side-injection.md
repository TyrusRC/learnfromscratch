---
title: HTMX server-side injection
slug: htmx-server-side-injection
aliases: [htmx-bug-patterns, htmx-security]
---

{% raw %}

> **TL;DR:** HTMX moves UI state to the server: every interaction is an HTTP request, the server returns HTML fragments, htmx swaps them into the DOM. Security surface: every fragment is unescaped HTML by default (no React-style auto-escape), `hx-target` and `hx-swap` accept attacker-controlled CSS selectors via headers, `hx-headers` JSON gives second-order risk, and the server has to enforce CSRF/auth on what looks like a "partial" request. The model is closer to old jQuery + server templates than to React.

## What it is
htmx is a small JS library (~14KB) that adds HTML attributes (`hx-get`, `hx-post`, `hx-target`, `hx-swap`) to trigger requests and patch the DOM. There's no client-side framework state — UI is regenerated server-side and sent as HTML. Auth/CSRF/escaping become server-template concerns.

## Bug patterns

### 1. XSS via server templates that emit user data without escaping
The biggest single risk. htmx swaps server response directly into DOM. If the server template emits `<div>{{ comment }}</div>` and `comment` is `<script>alert(1)</script>`, that's stored XSS. Server template engine must auto-escape (Jinja2 default, Go html/template, Razor) — confirm it does, then audit for `|safe` / `Html.Raw` overrides.
- Confirmed by source review of every fragment template.

### 2. `hx-target` manipulation
The client can include `HX-Target` header in the request, which the server is encouraged to use for content negotiation. If the server echoes `HX-Target` into the response without sanitisation (e.g., for logging or for setting `hx-swap-oob`), it's XSS / DOM injection.

### 3. Out-of-band swap (`hx-swap-oob`) injection
Server can return `<div id="elsewhere" hx-swap-oob="true">…</div>` to swap a target *other than* the requesting element. If a server template includes user input in an OOB swap that targets a privileged element (e.g., the auth status indicator), attacker controls the swap content. Audit every OOB swap for trust boundary.

### 4. CSRF on every action
htmx requests are normal POST/PUT/DELETE. Server must enforce CSRF as it would for any form. Common mistake: developer treats htmx requests as "internal" because they originate from the same site, and disables CSRF. Anything that triggers a request from `hx-trigger="every Xs"` or a third-party tab still needs CSRF tokens.
- Hook: htmx supports `hx-headers='{"X-CSRF-Token": "..."}'` — config in `htmx.config.includeIndicatorStyles` or a wrapper script.

### 5. `hx-headers` second-order injection
`hx-headers` is a JSON attribute on an element. If server templates emit `hx-headers='{"X-Token": "{{ token }}"}'` without escaping, attacker who controls `token` injects arbitrary headers — host header attacks, SSRF preconditions, log poisoning.

### 6. Open swap target via URL
`hx-target` can be a CSS selector. If a developer renders `<button hx-target="{{ target }}" hx-get="/foo">`, attacker controls the target — they can swap into `body` or any privileged element.

### 7. Server-side template injection
htmx amplifies SSTI risk: every interaction renders a template. A template-injection bug in any fragment route reaches all htmx-driven UI. Same defence as [[ssti]].

### 8. Out-of-context HTML
htmx swaps don't preserve the surrounding context. A fragment that's safe inside `<div>` may be unsafe inside `<script>` or `<style>` if attacker tricks the target. Audit `hx-swap` settings for any non-`innerHTML` swap; `outerHTML`, `beforebegin`, `afterend` can poison sibling elements.

### 9. `HX-Redirect` and `HX-Refresh` headers
Server can issue these response headers to trigger client navigation. `HX-Redirect: javascript:alert(1)` was a CVE in older htmx; current versions sanitise. Pin to a recent htmx (≥ 2.0.4 — earlier had OOB sanitisation gaps; check release notes for current CVEs).

### 10. Auth check per fragment
Every fragment route is a separate endpoint. Every one needs an auth check. Common bug: main page is auth-gated, but `/fragment/comments` (called by htmx) isn't, returning private content unauthenticated.

## Audit workflow
1. Enumerate every endpoint that returns an HTML fragment (response Content-Type often `text/html` with no full `<html>` envelope).
2. For each: verify auth/authz, verify CSRF, verify all interpolations are escaped.
3. Grep for `hx-swap-oob` in templates — every one is a privileged write.
4. Grep for `|safe` / `Html.Raw` / `dangerouslySetInnerHTML` / `mark_safe` in fragment templates.
5. Check `htmx.config` overrides for security-relevant flags (`includeIndicatorStyles`, `allowEval`, `allowScriptTags`, `selfRequestsOnly`).
6. Audit `htmx.config.allowEval` — if true, server can return `<script>` and it executes; combined with any XSS surface this is direct code exec.

## Hardening checklist
- Set `htmx.config.allowEval = false`, `htmx.config.allowScriptTags = false` in production config.
- `htmx.config.selfRequestsOnly = true` to block cross-origin htmx requests.
- CSP that disallows `unsafe-inline` and uses nonces.
- Server-side: escape by default; audit `safe` overrides as if they were dangerous-sink calls.
- Treat every fragment endpoint as a full endpoint for auth/CSRF/rate-limit purposes.

## References
- [htmx docs — security](https://htmx.org/docs/#security)
- [htmx essays — Hypermedia Systems book](https://hypermedia.systems/)
- [Wesley Aptekar-Cassels — htmx security](https://blog.wesleyac.com/posts/htmx-security)
- See also: [[cross-site-scripting]], [[ssti]], [[csrf]], [[content-security-policy-bypass]]

{% endraw %}
