---
title: Web — topics
slug: web-index
aliases: [web-topics]
---

Atomic web-app vulnerability and primitive notes. Pair with the
[[web-application-security]] learning path for ordering.

## Injection
- [[sql-injection]] · [[sql-injection-by-database]]
- [[nosql-injection]] · [[command-injection]]
- [[ssti]] · [[client-side-template-injection]]
- [[xxe]] · [[ldap-injection]]
- [[crlf-injection]] · [[http-parameter-pollution]]

## Cross-site / client
- [[cross-site-scripting]] · [[dom-xss]] · [[html-injection]]
- [[csrf]] · [[onsite-request-forgery]] · [[clickjacking]]
- [[cors-misconfig]] · [[postmessage-bugs]]
- [[dom-clobbering]] · [[prototype-pollution]]
- [[content-security-policy-bypass]] · [[trusted-types-bypass]]
- [[xs-leaks]] · [[relative-path-overwrite]]

## Auth / session
- [[jwt]] · [[oauth-flows]] · [[oauth-token-theft]]
- [[saml-attacks]] · [[sso-attacks]]
- [[session-fixation]] · [[2fa-bypass]]

## Authorisation and logic
- [[broken-access-control]] · [[idor]]
- [[application-logic-flaws]]

## Request-layer
- [[http-request-smuggling]] · [[cache-poisoning]] · [[cache-deception]]
- [[websocket-attacks]]
- [[race-conditions]]

## File and path
- [[file-upload]] · [[lfi-rfi]] · [[path-traversal]]
- [[open-redirect]]

## Indirect access
- [[ssrf]] · [[ssrf-to-cloud]]

## Server-side application
- [[deserialisation]] · [[rce-class]]
- [[graphql-attacks]] (see [[api-security]])
- [[information-disclosure]]

## Subdomain / DNS takeover
- [[subdomain-takeover]] · [[dangling-dns-takeover]]

## Exposed services and misconfigurations
- [[firebase-misconfig]] · [[elasticsearch-exposed]] · [[mongodb-exposed]]

## CMS / framework attack surface
- [[wordpress-attacks]] · [[drupal-attacks]]
- [[joomla-attacks]] · [[adobe-aem-attacks]]
