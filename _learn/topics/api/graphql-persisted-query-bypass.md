---
title: GraphQL persisted-query bypass
slug: graphql-persisted-query-bypass
aliases: [persisted-query-bypass, apq-bypass, graphql-pq-bypass]
---

> **TL;DR:** Persisted queries (Apollo APQ, Relay PQ, GraphQL HTTP spec PQ) are a performance / security feature: clients send a hash; the server looks up the corresponding query. Servers configured to **only accept persisted queries** (allowlist mode) effectively block introspection, ad-hoc queries, and many bug-bounty test vectors. Common bypasses: extension parameter manipulation, query-string vs body mismatch, double-encoding, and Apollo automatic-persisted-queries (APQ) registration race. Companion to [[graphql-attacks]] and [[graphql-source-review]].

## Why this matters

- Persisted queries are increasingly the default for modern GraphQL deployments.
- Allowlist-only mode is presented as a security control.
- Pentesters and hunters need bypass paths to attack PQ-only endpoints.
- Bug-bounty programs flag PQ-only as in-scope but harder to fuzz.

## Persisted queries recap

Three flavours:

### Apollo APQ (Automatic Persisted Queries)

Client first time: send query body with `extensions.persistedQuery.sha256Hash`. Server stores hash → query. Client next time: send only hash.

In *automatic* mode, anyone can register a new query. In *allowlist* mode, the server only accepts hashes already in a server-side list (uploaded at deploy time).

### Relay persisted queries

Compile-time generation of query IDs; client uses ID; server has a static map.

### GraphQL-over-HTTP spec persisted operations

Standardised version. Same idea: hash or ID lookup.

## Class 1 — APQ registration when expected to be allowlist

Some "allowlist" Apollo configurations still accept new query registration if a specific flag isn't set. If the server allows registration:
- Send your query body with the SHA-256 hash; server registers.
- Now you can send arbitrary queries.

Audit: test by sending a brand-new query with hash; see if it executes.

## Class 2 — Query in `extensions` parameter

Some servers accept the query in both `query` body field and `extensions.persistedQuery` field. If the parser preference order is wrong:
- Send hash for persisted query A.
- Send body `query` for a different query B.
- Server may execute B while looking up A.

Test with conflicting body + extensions.

## Class 3 — Query-string vs body mismatch

GET requests can pass the query in URL. Different parsing of GET vs POST in some servers:
- Hash in URL; body in POST has the actual query.
- Server reads URL for hash, ignores body — or vice versa, depending on implementation.

Test mixed transport.

## Class 4 — Variables-as-query

Some implementations stringify variables and substitute into the query template. If you can pass query-like text in a variable:
- Inject GraphQL syntax that becomes part of the resolved query.
- Effectively unauthorised operation.

Rare but documented in specific implementations.

## Class 5 — Hash collision / wildcard

For SHA-256 hashes, collisions are infeasible. But:
- Some implementations use shorter hashes (MD5, custom truncation).
- Some implementations use `**` style "wildcards" or normalize queries before hashing.

If normalisation strips comments / whitespace, you can inject content that's part of the query but stripped before hash computation:
- `query { x } # actually query { y }` — hashing strips comment; server stores `query { x }` but executes the comment too in some flawed parsers.

Mostly historical; modern implementations harden against.

## Class 6 — Operation name swap

If a persisted document contains multiple operations (`query A`, `query B`, `mutation C`), the request specifies `operationName`. Bypass:
- Allowlist a benign query.
- Request the same allowlisted document but with `operationName: mutation_C` — if document contains mutation, it executes.

Audit document allowlist for unintended operations.

## Class 7 — Custom directives / fragments

Some servers allow fragments to be defined in the persisted doc but spread into the executed query at runtime by client. Crafted spreads can expand to unintended queries.

## Class 8 — Apollo Federation gateway bypass

In a federated GraphQL setup, the gateway enforces allowlist; subgraphs may not. If you can reach a subgraph directly (often on internal port):
- Subgraph executes without allowlist.

Test for unauthenticated subgraph endpoints.

## Class 9 — Introspection via "magic" queries

Introspection is usually blocked in allowlist mode. But:
- Error messages may leak schema info ("field X not found on type Y").
- Fuzz field names against error responses.
- 4xx error message bodies sometimes contain partial schema.

## Class 10 — Cache-key confusion

PQ deployments often add a CDN cache in front. Cache-key confusion ([[cache-poisoning-modern-chains]]):
- Hash in URL; CDN caches by URL.
- Body in POST is different per request, but cache hits return prior cached response.
- Privacy: response intended for one user served to another.

Or the reverse for cache poisoning of authenticated responses.

## Recon approach

Quick checks against a suspected PQ-allowlist endpoint:

1. Send a brand-new query with `extensions.persistedQuery.sha256Hash`. See if accepted.
2. Send hash for a known operation with a different body query. See preference.
3. Send GET with hash in URL and POST body conflicting. See preference.
4. Send a persisted operation name with `operationName` for a different operation in the document.
5. Probe internal / subgraph endpoints.
6. Probe introspection paths.

Tools: Burp + GraphQL extensions (`InQL`, `GraphQL Voyager`), `graphw00f`, custom scripts.

## Defensive baseline

- **Strict allowlist mode** — disable automatic registration.
- **Single operation per persisted document** — no multi-operation documents.
- **Server-side enforcement** at every subgraph, not just gateway.
- **Same parsing precedence** for body, extensions, URL.
- **Block introspection** in production.
- **No GET requests for queries** with side effects.
- **Cache key includes** body hash or operation name + variable hash.
- **Subgraph network isolation** — only reachable from gateway.

## Workflow to study

1. Deploy an Apollo GraphQL server with APQ in allowlist mode.
2. Implement a small client.
3. Test each bypass class above against the deployment.
4. Tighten configuration to defend against each.
5. Repeat against a federated setup.

## Related

- [[graphql-attacks]] — general class.
- [[graphql-source-review]] — source audit.
- [[graphql-batching-aliasing-abuse]] — adjacent.
- [[graphql-field-permissions-introspection]] — adjacent.
- [[cache-poisoning-modern-chains]] — adjacent.
- [[api-fuzzing-wide-vs-deep]] — methodology.

## References
- [Apollo Server — Automatic Persisted Queries](https://www.apollographql.com/docs/apollo-server/performance/apq/)
- [GraphQL over HTTP spec](https://github.com/graphql/graphql-over-http)
- [Relay persisted queries](https://relay.dev/docs/guides/persisted-queries/)
- [graphw00f](https://github.com/dolevf/graphw00f)
- [InQL Burp extension](https://github.com/doyensec/inql)
- See also: [[graphql-attacks]], [[graphql-source-review]], [[graphql-batching-aliasing-abuse]], [[api-fuzzing-wide-vs-deep]]
