---
title: GraphQL attacks
slug: graphql-attacks
---

> **TL;DR:** Introspect the schema, then abuse aliasing, batching, depth, and field-level auth gaps to enumerate, brute, and DoS the API.

## What it is
GraphQL exposes a single endpoint (usually `/graphql`) that takes structured queries. Compared to REST it concentrates authorisation decisions to per-field resolvers — and shifts complexity from URL routing to query shape. Bugs cluster around schema exposure, missing per-field auth, the alias/batch mechanisms that let one HTTP request fan out into many logical operations, and resource exhaustion via deeply nested queries.

## Preconditions / where it applies
- A GraphQL endpoint. Common paths: `/graphql`, `/api/graphql`, `/v1/graphql`, `/query`, plus `/graphiql` / `/playground` UIs.
- Apollo, Hasura, Graphene, graphql-java, AWS AppSync, or a custom resolver layer.
- Either anonymous access or a low-priv user account.

## Technique
1. **Detect.** POST `{"query":"{__typename}"}` — a JSON response with `"__typename":"Query"` is conclusive. Look for `errors[].extensions.code` style metadata.
2. **Introspect.** Even when explicit introspection is disabled, field suggestions ("Did you mean `userById`?") leak schema. Tools: `graphql-cop`, `InQL`, `clairvoyance` (suggestion-based schema recovery).

   ```graphql
   query { __schema { types { name fields { name args { name type { name } } } } } }
   ```

3. **Authorisation per field.** Authentication often gates the endpoint but not each resolver. Walk every Query and Mutation field with a low-priv token and see what returns data.
4. **IDOR via arguments.** `user(id: 42)`, `order(id: "...")`. Iterate ids exactly like [[idor]] over REST.
5. **Alias batching for brute force.** One HTTP request, many logical operations — sails past per-request rate limits.

   ```graphql
   mutation {
     a: login(user:"alice", pass:"p1") { token }
     b: login(user:"alice", pass:"p2") { token }
     c: login(user:"alice", pass:"p3") { token }
   }
   ```

6. **Query batching.** Some servers accept arrays of operations: `[{query:"..."},{query:"..."}]`. Same effect as aliasing.
7. **Depth / complexity DoS.** Self-referential types (`user { posts { author { posts { author { ... } } } } }`) generate exponential resolver work. Pair with batching for amplification.
8. **CSRF via GET / form-encoded.** Some servers accept `query=` via `application/x-www-form-urlencoded`, opening [[csrf]] against mutations because there is no JSON content-type preflight.
9. **Field name injection / GraphQL-over-WebSocket.** Subscriptions may expose data not reachable via Query.

## Detection and defence
- Disable introspection in production; disable suggestions when the framework allows it.
- Enforce authorisation in every resolver. Use a directive (`@auth`) or middleware that fails closed.
- Cap query depth, complexity, and aliases per request. Reject query batching if you don't use it.
- Require `Content-Type: application/json` and reject GET for mutations; CORS lock the endpoint.
- Detection: alerts on `__schema`/`__type` queries; spikes in alias counts; clients that submit unusually deep queries.

## References
- [HackTricks — GraphQL pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/graphql.html) — checklist.
- [PortSwigger — GraphQL API vulnerabilities](https://portswigger.net/web-security/graphql) — labs.
- [OWASP — GraphQL Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html) — defensive patterns.
