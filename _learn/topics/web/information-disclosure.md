---
title: Information disclosure
slug: information-disclosure
---

> **TL;DR:** Verbose errors, debug endpoints, source backups, and exposed VCS metadata feed every later step of the attack chain; rarely critical alone, decisive in combination.

## What it is
Information disclosure is the unintentional exposure of details the application or operators would not knowingly publish: stack traces, internal hostnames, software versions, source code, configuration, credentials, customer PII, or developer-only endpoints. The category is broad on purpose — almost any later exploit benefits from it (CVE-mapping the framework version, harvesting class names for [[deserialisation]], pulling AWS keys out of a .git pack).

## Preconditions / where it applies
- Any HTTP-reachable service. Common sources: misconfigured proxies, default frameworks running in dev mode, public CI artefacts, leaked .git / .svn / .hg / .DS_Store, source-map files, swagger / actuator endpoints, debug toolbars.

## Technique
Triage in this order — each step takes minutes, all combine into a profile.

**Banner + framework fingerprint.** Headers (`Server`, `X-Powered-By`, `Set-Cookie` name like `JSESSIONID`), error pages, favicon hash (`shodan favicon-hash`), and HTML comments. Trigger an error path (`/?id=invalid'` , `/notfound`) to see if stack traces leak the framework.

**Verbose error / debug.** Try `?debug=1`, `?XDEBUG_SESSION_START=1`, `/__debug__/`, `/console`, Django dev `/debug/`, Flask Werkzeug console, ASP.NET YSOD, Spring `/actuator/env`, Rails `/rails/info/properties`. A working Werkzeug or Spring console is effectively RCE.

**Source-leak primitives.**

```
curl -s https://target/.git/HEAD
curl -s https://target/.git/config
curl -s https://target/.env
curl -s https://target/.aws/credentials
curl -s https://target/server-status
curl -s https://target/sitemap.xml
curl -s https://target/composer.lock
curl -s https://target/package-lock.json
```

Use `git-dumper` to clone an exposed `.git/`, `wpscan` for WordPress, `nuclei -t exposures/` for hundreds of templated checks.

**Source maps.** `Application.js.map` reveals original TypeScript with comments, secret API keys, and internal endpoints — fetch and run `npx source-map-explorer` or just `cat`.

**API spec leaks.** `/swagger.json`, `/openapi.json`, `/v2/api-docs`, `/graphql` introspection — instant endpoint catalogue, often including internal-only routes.

**Cloud metadata + secret leaks.** `/.well-known/openid-configuration`, `/api/_internal/health`, Kubernetes `/metrics` (Prometheus) leaks env vars in some setups.

**Web-archive + secondary sources.** `gau`, `waybackurls`, `urlhunter`, GitHub code search (`org:target shhh`) for tokens. Public dorks and `trufflehog` on the org's repos.

## Detection and defence
- Strip framework banners (`server_tokens off;`, `ServerSignature Off`).
- Custom error pages; no stack traces on prod. Centralised structured logging.
- Web root must not contain `.git`, `.svn`, `.DS_Store`, `.env`, `*.bak`, `*.swp`, source maps; block via the front-end (`location ~ /\. { deny all; }`).
- Disable actuator-style endpoints or bind them to localhost; require auth on Swagger.
- Secret scanning in CI (gitleaks, trufflehog) and rotation playbooks for leaked tokens.
- DLP and pre-publish audit on docs/sitemap; SSO-only access to admin/debug subdomains.

See also [[subdomain-takeover]], [[ssrf]], [[oauth-token-theft]].

## References
- [OWASP – Improper Error Handling](https://owasp.org/www-community/Improper_Error_Handling) — verbose-error class
- [PortSwigger – Information disclosure](https://portswigger.net/web-security/information-disclosure) — categories and labs
- [HackTricks – Sensitive data exposure](https://book.hacktricks.wiki/en/pentesting-web/sensitive-data-exposure.html) — checklist
