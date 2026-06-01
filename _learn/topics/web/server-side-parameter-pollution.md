---
title: Server-side parameter pollution (SSPP)
slug: server-side-parameter-pollution
---

> **TL;DR:** The front-end takes your input and stitches it into a *second* request it sends to an internal API or partner. Smuggle a delimiter (`&`, `;`, `#`, newline, `?`) and you override or inject params the inner service trusts.

## What it is
Distinct from classic HTTP Parameter Pollution (which targets parsing of duplicate keys on a single request, see [[http-parameter-pollution]]), Server-Side Parameter Pollution attacks the *re-emission* of user input into a server-to-server call. The outer endpoint reads `?q=…` from you, builds something like `internalGet("/users?search=" + q)`, and sends it onward. If you put `&admin=true` (or `;`, `%26`, `#`, `\r\n` depending on the inner parser) into `q`, the inner service sees a parameter you were never supposed to set. The PortSwigger SSPP labs frame this as truncating with `#`, injecting `&` for new params, or using body-vs-query confusion where the outer takes a query param but forwards it as a JSON body field that the inner parser maps loosely.

## Preconditions / where it applies
- A user-facing endpoint that wraps an internal API, SOAP service, GraphQL gateway, or partner integration
- The internal service has parameters the outer one doesn't document (admin, role, debug, limit override, internal flags)
- The forwarding code uses string concatenation or naive `URLSearchParams` without re-encoding
- For body-vs-query confusion: the inner parser accepts the same key from either source and one overrides the other

## Technique
**Inject a new param via `&`.** Outer:

```http
GET /api/search?q=cats HTTP/1.1
```

becomes internally:

```http
GET /internal/search?q=cats&fields=name,email HTTP/1.1
```

You send:

```http
GET /api/search?q=cats%26admin%3dtrue%26fields%3d* HTTP/1.1
```

Internal service now sees `admin=true&fields=*` — last-wins semantics give you everything.

**Truncate trailing controls with `#`.** Outer appends `&apikey=xxx` after your input. Send `q=cats%23` to make the internal URL `/internal/search?q=cats#&apikey=xxx` — the fragment is dropped server-side, severing the API key entirely (the inner service falls into a debug branch when no key is sent).

**Override an existing param.** Outer builds `?id=42&action=read`, you send `id=42%26action%3ddelete` — depending on whether parser takes first or last duplicate, action becomes delete.

**Body-vs-query confusion.** Outer reads `?role=user`, forwards as `{"role":"user"}` in JSON body. You also include `role=admin` in the query string, expecting one parser to merge both:

```http
POST /api/createUser?role=admin HTTP/1.1
Content-Type: application/json

{"role":"user","email":"x@y.tld"}
```

Spring's `@RequestParam`+`@RequestBody` mixes, Express with body-parser-and-query, etc. — `role` resolution depends on which annotation wins.

**Discovery.** Wordlist the inner parameter namespace (`debug`, `admin`, `_method`, `proxy`, `redirect_uri`, `format`, `output`, `callback`, `fields`, `embed`, `expand`, `internal`, `role`, `tenant`). Burp Param Miner runs against the *outer* endpoint with `&{guess}={canary}` and watches for behavioural diff.

## Detection and defence
- Re-encode params before stitching into the inner request: use a URL builder API, never `+` concatenation
- Allowlist forwarded params explicitly — drop everything else before the internal call
- Internal services authenticate with mTLS and ignore client-set sensitive params (re-derive `role` from the verified JWT, not from the inner query string)
- Logging on the inner service flagging unexpected params seen from the gateway
- Disable mixed-source parameter binding in the framework (Spring `@RequestParam` should not fall through to body)

## References
- [PortSwigger: server-side parameter pollution](https://portswigger.net/web-security/api-testing/server-side-parameter-pollution) — lab series
- [PortSwigger: API testing](https://portswigger.net/web-security/api-testing) — broader API methodology

See also: [[http-parameter-pollution]], [[ssrf]], [[api-endpoint-analysis]].
