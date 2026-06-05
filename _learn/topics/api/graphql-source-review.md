---
title: GraphQL source review
slug: graphql-source-review
aliases: [graphql-code-audit, graphql-whitebox]
---

{% raw %}

> **TL;DR:** GraphQL audits invert the REST workflow: every "endpoint" is a resolver, every field is a permission boundary, and the entire schema is callable from one URL. Source review focuses on resolver-level authz (often missing on nested types), N+1 / depth / complexity caps, introspection in prod, query-level mutation gaps, and the per-resolver auth-context propagation. Complement to [[graphql-attacks]] (which is the blackbox angle).

## What it is
A GraphQL server registers types, fields, and resolvers. A single POST endpoint accepts queries that traverse arbitrarily. Each resolver runs independently; authorization is enforced per-resolver or via middleware over the request. Misconfigurations cluster at resolver boundaries.

## Audit workflow

### 1. Map the schema
- Find the schema definition (`*.graphql` SDL, code-first via `Type-GraphQL` / `Nexus` / `Pothos`).
- Enumerate every type and every field; flag which are gated.
- Generate a "schema graph" — root types, what each query returns, what mutations exist.

### 2. Per-resolver authz
- Find the auth middleware / context builder. What does it produce?
- For each resolver: does it consume the auth context? Where? How?
- Common bug: `Query.me` is gated but `Query.user(id)` is not, and `User.email` field resolver has no auth check.
- "Nested authz gap" — `Query.post(id)` checks post-ownership; `Post.author` resolver returns `User` without rechecking; attacker reads any user via any post they can see.

### 3. Field-level authorization
- A type has 30 fields. Five are admin-only. Are they tagged with directive (`@auth(role:"admin")`) or guard? Where's enforcement?
- Code-first with decorators (`@FieldResolver`, `@Authorized`) makes this auditable. SDL-first requires checking every field's mapped resolver.

### 4. Mutation gaps
- Mutations often inherit class-level authz but lose it on derived methods.
- `updatePost(id, data)` — does it check that requester owns post? Does it check that `data.authorId` isn't being switched to attacker?
- Mass-assignment via input types (`UpdatePostInput { title, content, authorId, isPublished, isAdmin }`) — every field reaches a setter.

### 5. Depth and complexity caps
- A 20-level deep query (`{user{posts{comments{author{posts{comments{...}}}}}}}`) hits N+1 cascade.
- `graphql-depth-limit` / `graphql-query-complexity` libs apply caps. Missing → DoS.
- Audit: is a depth / complexity calculator installed and applied?

### 6. Batching and aliasing
- One HTTP request can carry N queries with aliases. Auth checks per-request fire once; per-query may not.
- See [[graphql-batching-aliasing-abuse]].

### 7. Introspection in prod
- `__schema` / `__type` queries dump the full type system → attacker recon.
- `ApolloServer({introspection: false})` in prod. Often forgotten.
- Even without introspection, schema can be inferred via field-not-found error messages; full disable via `validationRules` to reject `__*` fields.

### 8. Error message leak
- Default Apollo Server returns stack traces in errors with `NODE_ENV=development`. Production should `formatError` to redact.
- Validation errors leak field names from typos → schema reconstruction.

### 9. CSRF protection
- POST GraphQL endpoint with content-type `application/json` is normally CSRF-safe (preflighted). But Apollo Server CSRF prevention (`csrfPrevention: true`) is opt-in; older versions accept `application/x-www-form-urlencoded` GraphQL queries → CSRF possible.
- Audit: Apollo version + `csrfPrevention` flag.

### 10. SSRF via resolvers
- Resolver fetches external URL (`http.get(args.url)`) → SSRF. Same as REST [[ssrf]].

### 11. Subscription auth
- WebSocket subscription connection auth (`onConnect`) checked once at connect.
- Per-message authz often skipped.
- See [[websocket-state-sync-bugs]].

### 12. DataLoader cache poisoning
- DataLoader caches results per-request to fix N+1. Cache key is the loader arg (usually ID).
- If a loader is shared across requests (incorrectly created at app scope), cross-request data leak.
- Audit: `new DataLoader(...)` instantiation — must be per-request.

### 13. Custom directives
- `@auth(role: ...)` is a common SDL pattern that's wired via schema transformer.
- Bug: directive defined but transformer not installed → directive is a no-op decoration.
- Audit: directive's transformer wired in `makeExecutableSchema`.

## Per-framework specifics

### Apollo Server
- `csrfPrevention: true` for v4+; default ON for new installs.
- `formatError` redacts production errors.
- `cache` directive on resolvers — can leak across users if key insufficient.

### NestJS GraphQL
- `@UseGuards` on `@Query`/`@Mutation` only; field-level needs `@ResolveField` + guard.
- `@GraphQLArgs` reaches binders; same mass-assign risk as `@Body`.

### Hasura
- Permission model is declarative per-role per-table. See [[hasura-audit-patterns]].

### Relay-style
- `Node` interface allows `{ node(id) { ... } }` polymorphism. Audit which types implement it; the union is callable from a single root.

## Audit grep
```bash
# Schema files
rg -n 'type \w+\s*{' --type=graphql .
# Resolvers (Apollo style)
rg -n 'resolvers\s*=|Query:\s*{|Mutation:\s*{' src/
# Field resolvers
rg -n '@ResolveField|@FieldResolver' src/
# Auth context build
rg -n 'context:\s*\(' src/  # context builder
rg -n 'context\.user|context\.req\.user' src/
# DataLoader instantiation
rg -n 'new DataLoader' src/
# Introspection / playground
rg -n 'introspection:|playground:' src/
# CSRF
rg -n 'csrfPrevention' src/
```

## References
- [Apollo Server security guide](https://www.apollographql.com/docs/apollo-server/security/authentication/)
- [GraphQL.org — Authorization](https://graphql.org/learn/authorization/)
- [Doyensec — GraphQL audit methodology](https://blog.doyensec.com/)
- [PortSwigger — GraphQL Academy](https://portswigger.net/web-security/graphql)
- See also: [[graphql-attacks]], [[graphql-batching-aliasing-abuse]], [[apollo-server-audit-patterns]], [[hasura-audit-patterns]]

{% endraw %}
