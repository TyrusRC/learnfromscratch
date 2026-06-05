---
title: HTTP smuggling — modern variants
slug: http-smuggling-modern-variants
aliases: [http-smuggling-modern, modern-desync-attacks]
---

{% raw %}

> **TL;DR:** Classic CL/TE/TE.CL smuggling (HTTP/1.1) is mostly mitigated at major CDNs; newer variants ride (1) HTTP/2 frame parsing mismatches, (2) HTTP/2 to HTTP/1.1 downgrade desync, (3) header-value injection through whitespace/CR-LF, (4) browser-based client-side desync, (5) HTTP/3's QPACK state. James Kettle's "HTTP/2 The Sequel is Always Worse" and "Browser-Powered Desync" research is the canonical reference. Companion to [[http-request-smuggling]] and [[http3-quic-attack-surface]].

## Classic recap

In HTTP/1.1, both `Content-Length` (CL) and `Transfer-Encoding: chunked` (TE) declare body framing. A proxy parsing one and origin parsing the other = desync. Three variants:
- **CL.TE** — proxy uses CL, origin uses TE.
- **TE.CL** — proxy uses TE, origin uses CL.
- **TE.TE** — both speak TE but disagree on one slightly malformed.

See [[http-request-smuggling]].

## Modern variant 1 — HTTP/2 downgrade

The classic next-gen vector. CDN speaks HTTP/2 to clients; sends HTTP/1.1 to origin. CDN re-serialises the request — and bug shapes appear in the re-serialisation.

```
Client → CDN:        HTTP/2 frame { :method=GET, :path=/, ... }
CDN → Origin:        GET / HTTP/1.1\r\nHost: ...\r\n...
```

If CDN copies attacker-controlled header values into the HTTP/1.1 line, CR/LF injection in the value smuggles a *second* request to origin:

```
Content-Length: 0
Transfer-Encoding: chunked
Host: example.com\r\nSmuggled-Header: x
```

becomes when re-serialised:

```
...
Host: example.com
Smuggled-Header: x
```

Splitting via CRLF in HTTP/2 value (forbidden by spec but accepted by some CDNs).

## Modern variant 2 — HTTP/2 :path or :scheme injection

Pseudo-headers in HTTP/2 (`:method`, `:path`, `:authority`, `:scheme`) are normalised by some intermediaries but not others.

```
:path = /api/users\r\nX-Admin: yes
```

CDN treats as one URL; origin (after downgrade) sees two headers.

## Modern variant 3 — header value normalisation gaps

Whitespace and case folding differ across proxies. A header like:
```
Transfer-Encoding: chunked
Transfer-encoding: ⁠identity
```

(Unicode invisible character before "identity"). Some proxies treat as one header (one wins); others as two.

## Modern variant 4 — client-side desync ("Browser-Powered Desync")

Browser sends a sequence of requests on a connection it keep-alives. If you can inject content into the response body that *the browser misinterprets as the start of a new response*, subsequent requests get poisoned with that misinterpreted boundary.

Example: a same-origin request returns:
```
HTTP/1.1 200 OK
Content-Length: 7

ABCDEFG
```

But what if the response body contains:
```
ABCDEFG
HTTP/1.1 200 OK
Content-Length: 50
```

The browser closes the response after 7 bytes; the trailing content waits on the socket. Next request: the in-flight bytes get prepended to the next response — that next response is now the attacker's chosen content.

Real bugs require precise framing — but James Kettle's research demonstrates it works against major sites.

## Modern variant 5 — HTTP/3 frame smuggling

HTTP/3 frames inside QUIC streams. Smuggling primitives:
- QPACK dynamic table reuse across requests.
- Frame ordering differences between CDN and origin.
- Stream multiplexing — one stream's framing affects another in some implementations.

Research is younger; expect more findings in 2026-2027.

## Modern variant 6 — header / body mismatch via WebSocket upgrade

Sending a WebSocket upgrade request that the CDN forwards but origin rejects (or vice versa) can leave a half-open state where subsequent requests are smuggled into the upgrade body.

## Modern variant 7 — extended CONNECT method

CONNECT in HTTP/2 (extended via `:protocol` for WebSocket-over-h2) creates tunnel semantics. CDN treats as tunnel-passthrough; origin treats as proxy request. Headers and body interpretation diverge.

## Detection tools

- **Burp Suite — HTTP Request Smuggler** — automated probes (CL.TE, TE.CL, h2->h1 downgrade).
- **smuggler.py** (defparam) — CLI tool.
- Manual: send specific test frames; compare timing of front-end vs back-end response.

## Tests every modern smuggling assessment includes

1. Basic CL.TE and TE.CL probes.
2. h2 → h1 downgrade with CR-LF in value.
3. h2 :path injection.
4. Header case folding fuzz.
5. Header dup (`Content-Length: 5\r\nContent-Length: 7`).
6. Pseudo-header injection (`:authority` with newline).
7. Cache poisoning via smuggled request.

## Impact

- Cache poisoning of arbitrary URLs.
- Credential capture by smuggling a request that the *next* victim's session gets responded to.
- WAF bypass (origin sees a request the WAF didn't filter).
- Internal endpoint reach (smuggled request bypasses front-end auth).

## Defence

- **One HTTP version end-to-end** (h2 to origin if h2 to client).
- **Reject ambiguous framing** — `Content-Length` AND `Transfer-Encoding` together → 400.
- **Don't copy headers verbatim** during h2→h1 downgrade; re-canonicalise.
- **Connection: close** between front-end and back-end when uncertain.
- **WAF that parses with the same library as origin.**
- **Continuous probing** — run smuggler.py in production CI to detect regressions.

## OSCP/OSEP/OSWE relevance

OSWE: an HTTP smuggling chain can be the "auth bypass" stage in a source-audited app.
Bug bounty: smuggling found in major SaaS pays well — PortSwigger's annual research updates.

## References
- [PortSwigger — HTTP Request Smuggling research index](https://portswigger.net/research/http-request-smuggling)
- [James Kettle — "HTTP/2: The Sequel is Always Worse"](https://portswigger.net/research/http2)
- [James Kettle — "Browser-Powered Desync Attacks"](https://portswigger.net/research/browser-powered-desync-attacks)
- [smuggler.py](https://github.com/defparam/smuggler)
- See also: [[http-request-smuggling]], [[cache-poisoning-modern-chains]], [[http3-quic-attack-surface]], [[http2-h2-downgrade-desync-v3]]

{% endraw %}
