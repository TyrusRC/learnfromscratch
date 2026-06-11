---
title: Web — topics
slug: web-index
aliases: [web-topics]
---

Atomic web-app vulnerability and primitive notes. Pair with the
[[web-application-security]] learning path for ordering.

## Zero-knowledge primer
- [[http-and-web-primer]]

## Tooling primers
- [[burp-suite]]

## Injection
- [[sql-injection]] · [[sql-injection-by-database]]
- [[nosql-injection]] · [[command-injection]]
- [[ssti]] · [[python-ssti-jinja]] · [[client-side-template-injection]]
- [[xxe]] · [[ldap-injection]] · [[xpath-injection]]
- [[crlf-injection]] · [[smtp-injection]]
- [[http-parameter-pollution]] · [[server-side-parameter-pollution]]

## Cross-site / client
- [[cross-site-scripting]] · [[dom-xss]] · [[html-injection]]
- [[csrf]] · [[onsite-request-forgery]] · [[clickjacking]]
- [[cors-misconfig]] · [[cors-acam-credential-bypass-patterns]] · [[postmessage-bugs]]
- [[dom-clobbering]] · [[prototype-pollution]]
- [[content-security-policy-bypass]] · [[trusted-types-bypass]]
- [[xs-leaks]] · [[javascript-hijacking]]
- [[css-injection-exfiltration]]
- [[relative-path-overwrite]]
- [[dns-rebinding]]
- [[same-origin-policy-bypasses]]
- [[dompurify-bypass-techniques]]
- [[service-worker-persistent-xss]] · [[mv3-extension-bypass]]

## Auth / session
- [[jwt]] · [[oauth-flows]] · [[oauth-token-theft]] · [[oauth-token-leak-vectors]]
- [[pkce-downgrade-and-bypass]] · [[oauth-authorization-code-injection]]
- [[saml-attacks]] · [[parser-differential-saml-ruby]]
- [[sso-attacks]]
- [[session-fixation]] · [[session-token-analysis]]
- [[2fa-bypass]] · [[account-recovery-attacks]] · [[remember-me-flaws]]
- [[captcha-bypass]]
- [[webauthn-api-hijacking-downgrade]] · [[passkey-mobile-ble-phish]]
- [[fedcm-attacks]] · [[cred-management-api-attacks]]
- [[cookie-prefix-and-attribute-attacks]]
- [[server-actions-rsc-csrf]]

## Authorisation and logic
- [[broken-access-control]] · [[idor]]
- [[application-logic-flaws]]

## Request-layer
- [[http-request-smuggling]] · [[cache-poisoning]] · [[cache-deception]]
- [[http2-h2-downgrade-desync-v3]] · [[request-tunnelling-desync]]
- [[host-header-injection]]
- [[websocket-attacks]]
- [[race-conditions]]

## File and path
- [[file-upload]] · [[lfi-rfi]] · [[path-traversal]]
- [[open-redirect]]
- [[webdav-attacks]]

## Indirect access
- [[ssrf]] · [[ssrf-to-cloud]]

## Server-side application
- [[deserialisation]] · [[viewstate-attacks]]
- [[python-deserialization]]
- [[python-format-string]] · [[python-sandbox-escape]] · [[python-sys-audit-bypass]]
- [[prototype-pollution-server-side]]
- [[web-memory-vulnerabilities]]
- [[rce-class]]
- [[graphql-attacks]] · [[graphql-batching-aliasing-abuse]] (see [[api-security]])
- [[information-disclosure]]

## Recon and methodology
- [[banner-and-fingerprinting]]
- [[git-source-leakage]] · [[backup-and-config-leakage]]
- [[oast-out-of-band-testing]]

## Framework CVEs
- [[nextjs-middleware-cve-2025-29927]]

## Modern stack appsec
- [[nextjs-server-actions-audit]]
- [[htmx-server-side-injection]]
- [[websocket-state-sync-bugs]]
- [[server-sent-events-injection]]

## Modern protocol attack surface
- [[http3-quic-attack-surface]]
- [[tls-1-3-attacks-and-misuse]]
- [[cache-poisoning-modern-chains]]
- [[http-smuggling-modern-variants]]
- [[oauth-modern-attacks]]
- [[2fa-bypass-deep]]
- [[ssrf-to-cloud-advanced-chains]]

## CTF and CVE reference
- [[ctf-web-modern-tricks]]
- [[recent-cve-class-overview]]

## SSR / hydration audit
- [[react-ssr-hydration-bugs]]
- [[sveltekit-form-actions-audit]]
- [[vue-ssr-audit]]
- [[astro-server-islands-audit]]

## Edge runtime appsec
- [[cloudflare-workers-audit]]
- [[vercel-edge-and-middleware-audit]]
- [[deno-and-bun-audit]]
- [[service-worker-attack-surface]]
- [[serverless-cold-start-side-channels]]

## Advanced bug-class deepening
- [[unicode-normalization-bypasses]]
- [[waf-bypass-advanced-techniques]]
- [[esi-injection]]
- [[http-pipelining-keepalive-abuse]]

## WAF / CDN bypass research
- [[waf-bypass-research-deep]]
- [[cdn-trust-chain-bypass]]
- [[cloudflare-and-akamai-research]]

## Email authentication / anti-phishing
- [[dmarc-spf-dkim-deep]]
- [[arc-and-mail-forwarding]]
- [[bimi-and-mail-authenticity-ux]]
- [[email-gateway-bypass-techniques]]

## Client-side storage
- [[client-side-storage-attacks]]

## Subdomain / DNS takeover
- [[subdomain-takeover]] · [[dangling-dns-takeover]]

## Exposed services and misconfigurations
- [[firebase-misconfig]] · [[elasticsearch-exposed]] · [[mongodb-exposed]]
- [[shared-hosting-attacks]]
- [[waf-bypass]] · [[canonicalization-attacks]]

## CMS / framework attack surface
- [[wordpress-attacks]] · [[drupal-attacks]]
- [[joomla-attacks]] · [[adobe-aem-attacks]]
