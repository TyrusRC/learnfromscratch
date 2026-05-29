---
title: Web application security
slug: web-application-security
aliases: [webapp-sec, web-pentesting]
---

> Zero-to-hero web app pentesting. The goal is to be able to take an
> unfamiliar web app, recon it, find the high-impact classes of bugs, and
> write a report someone will pay for.

## Prereqs

- HTTP request/response, headers, cookies, status codes.
- One scripting language for tooling (Python or Go preferred).
- Comfort with a proxy ([[burp-suite|Burp Suite]] or
  [[caido|Caido]]).

## Stage 1 — fundamentals

Goal: recognise every bug class in the OWASP Top 10 in a single sentence
and exploit a textbook example of each in a lab.

- HTTP and session basics — read the [MDN HTTP
  guide](https://developer.mozilla.org/en-US/docs/Web/HTTP).
- Burp Suite essentials — Proxy, Repeater, Intruder, Decoder.
- Lab through [PortSwigger Web Security
  Academy](https://portswigger.net/web-security) — apprentice tier.
- Bug classes: [[sql-injection]], [[cross-site-scripting]],
  [[csrf]], [[idor]], [[file-upload]], [[lfi-rfi]],
  [[open-redirect]], [[cors-misconfig]].

## Stage 2 — intermediate

Goal: chain bugs, recognise auth-layer flaws, attack real frameworks.

- AuthN/Z deep dives: [[jwt]], [[oauth-flows]], [[saml-attacks]],
  [[session-fixation]], [[2fa-bypass]].
- [[ssrf]] (incl. cloud metadata pivot — see [[ssrf-to-cloud]]).
- [[xxe]] · [[ssti]] · [[command-injection]].
- Modern JS surface: [[prototype-pollution]],
  [[dom-clobbering]], [[postmessage-bugs]].
- PortSwigger Academy practitioner tier.
- Read [*The Web Application Hacker's Handbook* — chapters on
  application logic, encoding, and attack chaining].

## Stage 3 — advanced

Goal: invent new chains, weaponise primitives no scanner catches.

- [[http-request-smuggling]] (CL.TE, TE.CL, TE.TE, H2.CL).
- [[deserialisation]] — Java, .NET, PHP, Python, Node.
- [[race-conditions]] — single-packet attacks.
- [[websocket-attacks]] · [[graphql-attacks]] (see [[api-security]]).
- [[cache-poisoning]] · [[cache-deception]].
- Browser-side: [[content-security-policy-bypass]],
  [[xs-leaks]], [[trusted-types-bypass]].
- Source-code review — pick one stack (PHP, Spring, Rails, Express) and
  audit a real open-source app.
- HackTricks pentesting-web index:
  <https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html>.

## When you're "done"

- You can read a target's tech stack from headers + JS in five minutes
  and predict the three most likely bug classes.
- You routinely find chains that need ≥2 bugs to reach impact.
- You've written ≥10 reports that triaged on first read.
