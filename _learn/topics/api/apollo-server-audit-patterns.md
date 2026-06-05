---
title: Apollo Server audit patterns
slug: apollo-server-audit-patterns
aliases: [apollo-graphql-audit, apollo-v4-security]
---

{% raw %}

> **TL;DR:** Apollo Server-specific bugs cluster around: `context` builder leaking secrets, plugins running after auth, federated subgraph trust, Apollo Studio reporting leaking data, persisted query allowlist bypasses, cache directives leaking across users, and CSRF prevention disabled. Newer Apollo (v4+) has saner defaults; legacy v2/v3 deployments often retain risky configs.

## What it is
Apollo Server is the dominant Node GraphQL implementation. Setup varies (express middleware, standalone, lambda, Cloudflare Workers). Audit knobs:
- `context` function builds per-request context (auth, db handles).
- `plugins` run lifecycle hooks (request received, parse, validate, execute, response).
- `formatError` shapes error responses.
- `csrfPrevention`, `introspection`, `cache` options.

## Bug patterns

### 1. Context builder leaks secrets / cross-tenant
```ts
context: async ({ req }) => ({
  user: await getUser(req),
  db,                               // shared
  internalApiKey: process.env.KEY,  // leaks if any resolver echoes context
})
```
Context fields reachable from any resolver. If a resolver mistakenly returns context (debug code, error handler), secrets exposed.
- **Fix**: minimum-viable context; never put secrets in fields a resolver could return.

### 2. Auth check in wrong layer
- Express middleware checks auth before Apollo. But Apollo runs the OPERATIONS regardless if reached. Middleware that fail-opens or only checks Cookie presence (not validity) → unauth queries.
- Apollo plugin `requestDidStart` can be auth — but runs *after* parse. Errors there have already revealed schema info via parse-error messages.

### 3. Plugin order leaks
- Logging plugin first → logs request body including secrets.
- Apollo Tracing plugin enabled in prod → returns performance data including resolver names and execution times (timing oracle).

### 4. `formatError` doesn't redact
- Default behaviour returns the raw error object.
- Production should redact stack, message specifics, error codes that leak schema.
- Audit: production `NODE_ENV` actually set; `formatError` function present.

### 5. Federated subgraph trust
- Apollo Federation: gateway routes parts of a query to multiple subgraphs.
- Trust assumption: gateway has authoritative auth; subgraphs trust gateway-supplied user context via `_entities`.
- Bug: subgraph also exposed publicly → attacker hits it directly, bypassing gateway auth.
- **Fix**: subgraphs network-isolated to gateway only; or each enforces own auth.

### 6. Apollo Studio / usage reporting
- `APOLLO_KEY` enables sending operations + variables to Apollo Studio.
- Variables can contain PII, secrets.
- Off by default if no key; on by default in tutorials/examples.
- Audit: `APOLLO_KEY` env presence; `sendVariableValues` config (mask sensitive).

### 7. Persisted query allowlist bypass
- Persisted queries (PQ): client sends `extensions.persistedQuery.sha256Hash` only; server looks up cached query.
- Common as anti-DoS. Some deployments allow arbitrary queries when hash unknown (fallback). Attacker sends arbitrary query with random hash → bypasses allowlist.
- **Fix**: `persistedQueries.ttl: 0` or no fallback; allowlist mode strict.

### 8. `@cacheControl` directive cross-tenant
- Apollo's `@cacheControl(maxAge: 300)` integrated with response-cache plugin.
- Cache key by default does NOT include user identity. Authed query result cached → next user sees it.
- **Fix**: `cacheKeyArgs` plugin override, or `scope: PRIVATE` on user-specific fields.

### 9. Introspection in prod
- `introspection: true` default in dev, false in prod for v4. Older configs may flip.
- Audit: explicit `introspection: process.env.NODE_ENV !== 'production'`.

### 10. CSRF prevention
- v4 default ON. v3 / v2 deployments often disabled or absent.
- Without it, simple POST forms can submit GraphQL queries → CSRF on mutations from any origin.

### 11. Subscription transport
- Apollo Subscriptions over WebSocket. Older `subscriptions-transport-ws` had auth-on-connect-only model. New `graphql-ws` is current.
- Audit: which lib is used; per-message auth.

### 12. Schema directives without resolver wiring
- `@auth(role:"admin")` declared in SDL but `schemaTransformers` not applied → directive is metadata only, no actual check.

## Apollo Server v4 config audit
```ts
new ApolloServer({
  schema,
  introspection: false,            // ✓ in prod
  csrfPrevention: true,             // ✓ default v4
  formatError: (err) => ({ message: err.message }),  // ✓ redact
  plugins: [
    ApolloServerPluginCacheControl({ defaultMaxAge: 0 }),  // ✓ default
    ApolloServerPluginUsageReporting({ sendVariableValues: { none: true } }),  // ✓ no PII
  ],
});
```

## Grep starter
```bash
rg -n 'new ApolloServer\(' src/
rg -n 'introspection:\s*true' src/
rg -n 'csrfPrevention' src/
rg -n 'formatError' src/
rg -n 'ApolloServerPluginUsageReporting' src/
rg -n 'context:\s*\(\s*\{' src/                 # context builder
rg -n '@cacheControl' src/                       # cache directive scope
rg -n 'persistedQueries' src/
```

## References
- [Apollo Server v4 security](https://www.apollographql.com/docs/apollo-server/security/authentication/)
- [Apollo Federation security](https://www.apollographql.com/docs/federation/security)
- [GraphQL-WS](https://github.com/enisdenjo/graphql-ws)
- See also: [[graphql-source-review]], [[graphql-attacks]], [[graphql-batching-aliasing-abuse]]

{% endraw %}
