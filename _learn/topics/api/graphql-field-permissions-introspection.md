---
title: GraphQL field permissions and introspection control
slug: graphql-field-permissions-introspection
aliases: [graphql-field-authz, graphql-introspection-leak]
---

{% raw %}

> **TL;DR:** GraphQL's per-field execution means authorization must be applied at the field level, not just the operation level. The introspection system (`__schema`, `__type`) lets clients see the entire type system — useful for tooling, dangerous in production for reconnaissance, error-based schema discovery, and dependency confusion. This note focuses on the practical defence pattern.

## What it is
A GraphQL query traverses the schema tree. Each field has a resolver. Authorization is correctly applied:
- At the operation root (operation-level — coarse).
- At each field (field-level — fine-grained).
- Often via directives, schema transformers, or middleware.

Introspection is the meta-API: clients can query `__schema { types { name fields { name } } }` to enumerate the entire schema.

## Authorization patterns

### 1. Resolver-level inline
```ts
const resolvers = {
  Query: {
    user: async (parent, args, ctx) => {
      if (!ctx.user) throw new ForbiddenError();
      return ctx.db.user.findById(args.id);
    }
  }
};
```
- **Pro**: explicit, easy to audit per resolver.
- **Con**: scattered; easy to forget on a new resolver.

### 2. Directive-based
```graphql
type Query {
  user(id: ID!): User @auth(role: "user")
  adminPanel: AdminData @auth(role: "admin")
}

type User {
  email: String @auth(role: "self_or_admin")
  publicName: String
}
```
- Schema transformer (Apollo `mapSchema`, GraphQL Tools `directives`) wraps resolvers to enforce.
- **Pro**: declarative, visible in schema.
- **Con**: requires correct wiring; absent transformer = no enforcement.

### 3. Middleware chain (Apollo plugins)
- Plugin's `willSendResponse` strips fields based on role.
- **Pro**: centralised.
- **Con**: runs after execute; fields are resolved before filter — performance + side-effect concerns.

### 4. Library helper
- `graphql-shield` (npm) — rule-based middleware over schema.
- Rules attach per type / field / operation.
- **Pro**: declarative, composable.
- **Con**: another dep; can be misconfigured to fail-open.

### 5. Code-first decorators
- `@Authorized('admin')` decorator on TypeGraphQL field resolvers.
- Compile-time visible.

## Bug patterns

### 1. Auth at root but not on nested fields
- `Query.user(id)` gated; `User.email` not.
- Attacker queries via `Query.viewer { friends { email } }` — reaches email via different path.
- **Fix**: auth applied at field level for any sensitive data.

### 2. Field-level auth bypassed by alias
- `{ a: secretField b: secretField c: secretField }` — three aliases of same field.
- If middleware counts queries by name (not resolver), it sees 3 different fields and applies separately. Bug if middleware caches "already checked" by alias.

### 3. Per-row authz on list returns
- `Query.posts(filter)` returns list. Filter applied at DB level — but no per-row authz check.
- Attacker filters to match private posts (`filter: {title_contains: 'company-secret'}`) → leak.
- **Fix**: row-level predicate in DB query joins on user/tenant.

### 4. Introspection-aware error messages
- "Cannot query field 'isAdmin' on type 'User'" — leaks that `isAdmin` doesn't exist on User; absence of error confirms existence.
- Differential responses → schema reconstruction even with introspection disabled.

### 5. Persisted query allowlist bypass at field level
- PQ allowlist verifies query string hash. New field added to allowed query → new hash. But sometimes the allowlist mechanism evaluates per-operation, not per-field; field-level changes blur.

### 6. Directives stripped by gateway
- Apollo Federation gateway composes subgraph schemas. Some directives are subgraph-local; gateway doesn't propagate to clients.
- Auth directive defined on subgraph type; gateway evaluates the query; subgraph directive enforced. But if gateway *delegates* a query directly and bypasses parse-time auth, depends on implementation.

### 7. Cache + field-level authz
- Response-cache plugin keys by query + variables.
- If user A's authorised result is cached, user B (with different role) hitting same query gets cached result.
- **Fix**: include role / user ID in cache key.

## Introspection control

### Disabling
- `ApolloServer({ introspection: false })` for prod.
- Code-first: `buildSchema({ introspection: false })`.
- This blocks `__schema` and `__type` queries.

### Beyond disabling
- Even disabled, schema can be inferred via:
  - Error messages on unknown fields (turn on `validationRules` to reject lookups for `__*` and respond uniformly).
  - Field suggestions in errors (`Did you mean "email"?`) — turn off (`formatError` redact).
  - Type-based responses (timing, length).
- Defence in depth: also disable verbose errors.

### Persisted-only mode
- If the server only accepts persisted queries from a known allowlist, introspection is moot — `__schema` not in the allowlist → blocked.
- Requires client cooperation.

### Trusted documents (PQ + Sig)
- Apollo's "trusted documents" model: each query signed by client at build time; server verifies signature before parse.
- Even stronger than allowlist; works at scale.

## Audit grep
```bash
# Find auth decorators / directives in schema and code
rg -n '@auth|@Authorized|@hasRole' .
# Find resolvers with no auth call
rg -n 'Query:\s*{|Mutation:\s*{' src/ -A20 | grep -B5 'ctx\.user'
# Find introspection config
rg -n 'introspection:' src/
# Find error formatting
rg -n 'formatError|maskErrors' src/
# Find persisted query config
rg -n 'persistedQueries|automatedPersisted' src/
```

## Hardening checklist
- Field-level authz via directive or library (graphql-shield); audit every sensitive field.
- Introspection off in prod; schema endpoint not exposed.
- `formatError` redacts message details; no "did you mean" suggestions.
- Persisted query allowlist + (if scale permits) trusted documents.
- Cache keys include user/role.
- Per-row authz in list resolvers (DB-level join, not post-filter).
- Validation rule blocks `__*` field names beyond introspection-off (defense in depth).

## References
- [GraphQL.org — Authorization patterns](https://graphql.org/learn/authorization/)
- [Apollo — Trusted documents](https://www.apollographql.com/docs/router/configuration/persisted-queries/)
- [Walls of Shame — GraphQL CVE history](https://github.com/dolevf/Damn-Vulnerable-GraphQL-Application)
- [InQL Burp extension](https://github.com/doyensec/inql)
- See also: [[graphql-source-review]], [[graphql-attacks]], [[graphql-batching-aliasing-abuse]]

{% endraw %}
