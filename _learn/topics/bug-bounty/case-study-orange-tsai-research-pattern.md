---
title: Case study — Orange Tsai's research pattern
slug: case-study-orange-tsai-research-pattern
aliases: [orange-tsai-pattern, devcore-research-pattern]
---

> **TL;DR:** Orange Tsai (Cheng-Da Tsai, Devcore) consistently publishes industry-shaping research by attacking *protocol parsing differentials* in mature products everyone assumed were hardened. Pattern: pick a protocol with multiple implementations, find where the implementations disagree, and turn the disagreement into a primitive. Studying his pattern is one of the highest-leverage things a web hacker can do. Companion to [[http-smuggling-modern-variants]] and [[parser-differential-saml-ruby]].

## Why study one researcher's pattern

Top researchers don't get lucky repeatedly. They have a *method* they apply to many products. Reverse-engineering the method is more valuable than memorising the bugs.

Orange's published work spans:
- **Proxylogon / Proxyshell** — Exchange server pre-auth RCE chain.
- **SSRF research** — original "A new era of SSRF" Black Hat work.
- **GitLab pre-auth RCE chain** (multiple years).
- **Request smuggling** — HTTP/1.1 parsing differentials across LB / WAF / origin.
- **JSON parsing differentials**.
- **CGI / FastCGI parsing bugs**.
- **Apache JServ Protocol (Ghostcat)**.

The shape is the same across all of them.

## The method

### 1. Pick a protocol with multiple implementations

Protocols implemented by many independent parties accumulate disagreement over time:
- HTTP/1.1 (every load balancer, CDN, app server, WAF, library).
- SMTP, IMAP, FTP — older protocols, idiosyncratic implementations.
- SAML, OpenID Connect — security-critical and complex.
- gRPC / Protobuf — schema-driven; mismatch in schema interpretation.
- WebSocket — handshake + framing.
- DNS — UDP and TCP, EDNS, parsing variations.

The mature ones with multiple major implementations are the most fertile.

### 2. Read the RFC, then read each implementation's parser

Orange's posts often show side-by-side code from `nginx`, `Apache`, `IIS`, `node:http`, `Go net/http`. The RFC says X; one implementation does X; another does Y. The bug lives in the Y.

Practically:
- Pull source for 4–5 implementations of the protocol.
- Diff the parser functions for handling the same edge case.
- Note every disagreement.

### 3. Construct an input where the disagreement is the vulnerability

If implementation A treats `\n` as a header terminator but implementation B treats only `\r\n` — and A is the proxy, B is the origin — A passes a header that B treats as part of the prior header. That's smuggling.

If implementation A normalises `..` in a path but B doesn't — and A is the access-control layer, B is the file server — that's path traversal.

The vulnerability isn't in A or B alone. It's in the *pipeline*.

### 4. Chain to impact

Parser differentials are usually a primitive (smuggle, bypass, confusion). The chain to impact requires a second bug or a permissive backend:
- Smuggle into an unauthenticated admin endpoint.
- Bypass into an SSRF-enabled internal service.
- Confuse into a cached private response.

The full chain is what shows up in the conference talk.

## Worked example shape — Proxylogon

(High level — read the original.)

- Two Exchange components parse the request differently: a front-end (Outlook Web Access) and a back-end (the actual Exchange service).
- The front-end auth check is bypassed via SSRF-like rewriting.
- A second component (PowerShell endpoint) is reachable internally with a privileged identity.
- Chain: front-end bypass → back-end PowerShell call → file write → RCE.

The lesson isn't the specific bug. It's that "Exchange has two HTTP parsers" was the *seed* the entire chain grew from.

## Worked example shape — HTTP request smuggling (h2 downgrade)

- HTTP/2 framing has explicit length fields; HTTP/1.1 has `Content-Length` and `Transfer-Encoding: chunked`.
- A front-end that speaks HTTP/2 to clients but HTTP/1.1 to the origin re-encodes.
- If the re-encoding doesn't preserve the chunked / content-length agreement, the origin and the front-end disagree about request boundaries.
- Smuggling primitive.

Pattern: **protocol translation introduces parser differential**. See [[http-smuggling-modern-variants]].

## How to apply the pattern yourself

Pick a less-attacked protocol or a newer one:

- **HTTP/3 / QUIC** — multiple implementations, framing differences. See [[http3-quic-attack-surface]].
- **MQTT** — many brokers, small ecosystem.
- **AMQP**, **Kafka protocol** — parsers across language clients.
- **gRPC** — protobuf parsing across languages.
- **PostgreSQL wire protocol** — pgbouncer vs Postgres.
- **OpenID Federation**, **SCIM**.

For each:
1. Get 3–5 implementations.
2. Diff parser code or behaviour with controlled inputs.
3. Note disagreements.
4. Think about pipelines where two of those implementations sit in sequence.

## What's hard about this method

- It's **slow** to get the first bug. You'll spend weeks before the first finding.
- It requires **reading other people's code** in multiple languages.
- It requires **building test harnesses** that produce arbitrary protocol bytes — not all libraries let you.
- The bugs you find are **chain-only impact**; the primitive is usually unimpressive on its own. You need the chain.

Worth it: each bug you find tends to be high-tier and unique.

## Reading list (for studying the pattern)

- "A new era of SSRF" (Black Hat USA 2017).
- "Breaking parser logic" / HTTP request smuggling research.
- Proxylogon / Proxyshell post-mortems.
- "Confusion attacks on Apache" (Black Hat / DEFCON 2024).
- "How I hacked GitLab" series.

After reading three of these, you'll start to see the seed-question Orange asks before every project.

## Related researcher patterns worth studying

- **James Kettle (PortSwigger)** — similar pattern but focused on HTTP semantics: request smuggling, web cache poisoning, single-packet races.
- **Sam Curry** — bug-bounty chain-builder, often combines OAuth + IDOR + SSRF.
- **Frans Rosén (Detectify)** — recon-heavy, OAuth + subdomain takeover focus.
- **Filedescriptor** — postMessage / browser quirks.

Cross-reference: [[case-study-portswigger-top-10-pattern]].

## References
- [Orange Tsai's blog (English mirror)](https://blog.orange.tw/)
- [Devcore research](https://devco.re/blog/)
- [Black Hat USA archive — Orange's talks](https://www.blackhat.com/html/archives.html)
- [PortSwigger research index](https://portswigger.net/research)
- See also: [[http-smuggling-modern-variants]], [[parser-differential-saml-ruby]], [[ssrf]], [[case-study-portswigger-top-10-pattern]]
