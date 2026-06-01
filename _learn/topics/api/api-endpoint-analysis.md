---
title: API Endpoint Analysis and Parameter Mining
slug: api-endpoint-analysis
---

> **TL;DR:** Before attacking an API you map its shape — protocol family, hidden verbs, schema, and undocumented parameters — by mixing spec scraping, HATEOAS walking, and brute-force parameter discovery.

## What it is
Endpoint analysis is the reconnaissance layer that turns an opaque API into a labelled attack surface. It covers protocol fingerprinting (REST vs GraphQL vs SOAP vs gRPC-Web), inferring resource schemas from JSON shape and error messages, walking HATEOAS link relations, and mining parameters that the documentation does not list. The goal is a per-endpoint inventory with methods, content types, expected params, and trust boundaries.

## Preconditions / where it applies
- Black-box or grey-box engagement against an HTTP API
- Target exposes a browsable surface, an SPA, or any client that talks to the backend
- You have a baseline authenticated session (helps reveal more routes)

## Technique
Fingerprint the family first, then enumerate verbs and parameters.

```bash
# Protocol family hints
curl -s -i https://api.target.tld/ | grep -iE 'content-type|x-powered|server'
curl -s https://api.target.tld/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__typename}"}'
curl -s https://api.target.tld/v1/ -H 'Accept: application/hal+json'   # HATEOAS

# Hidden verbs — many WAFs only filter GET/POST
for m in GET POST PUT PATCH DELETE OPTIONS PROPFIND; do
  printf '%s -> ' "$m"
  curl -s -o /dev/null -w '%{http_code}\n' -X "$m" https://api.target.tld/v1/users/1
done

# Spec scraping before guessing
for p in openapi.json swagger.json api-docs v2/api-docs .well-known/openapi; do
  curl -s -o "spec-$p.json" -w "$p %{http_code}\n" "https://api.target.tld/$p"
done

# Parameter mining on a known endpoint
arjun -u https://api.target.tld/v1/search -m GET -w params-big.txt -t 20
paramspider -d target.tld --exclude woff,css,js,png --output ps.txt
x8 -u https://api.target.tld/v1/users/1 -w params.txt -X GET,POST --body '{"$1":"x"}'
```

For GraphQL, run a typename probe then introspection; if disabled, fall back to field suggestion fuzzing (`clairvoyance`). For SOAP, fetch `?wsdl` and generate stubs.

## Detection and defence
- Defender signals: bursts of 404/405, OPTIONS storms, identical paths probed with rotating verbs, repeated requests to `swagger.json` / `openapi.json` / `.well-known/*`
- Hardening: serve specs only behind auth, disable GraphQL introspection in prod, return uniform 404 for unknown verbs (not 405), strip verbose stack traces, normalise error envelopes so schema inference is harder
- Rate-limit and alert per route+verb tuple, not just per IP

## References
- [OWASP API Security Top 10](https://owasp.org/API-Security/) — taxonomy used to scope per-endpoint risk
- [Arjun parameter discovery](https://github.com/s0md3v/Arjun) — wordlist-driven param mining
- [Clairvoyance for GraphQL](https://github.com/nikitastupin/clairvoyance) — schema recovery when introspection is off

See also: [[swagger-discovery]], [[graphql-attacks]], [[api-content-discovery]], [[tech-stack-fingerprinting]].
