---
title: Serverless cold-start side channels
slug: serverless-cold-start-side-channels
aliases: [serverless-side-channels, lambda-warm-cold]
---

{% raw %}

> **TL;DR:** Serverless platforms (Lambda, Cloud Functions, Vercel Functions, Cloudflare Workers) reuse warm instances for performance. State that persists between invocations — module globals, in-memory caches, file descriptors, /tmp — can leak data across requests when one user's invocation warms the runtime and another user's invocation hits the same instance. Audit: any non-request-scoped state, any /tmp write, any module-level data structure, and any "lazy init" pattern.

## What it is
A serverless function lifecycle:
1. **Cold start**: container/isolate spawned, module loaded, top-level code runs.
2. **Warm**: same container reused for subsequent requests until the platform evicts.
3. **Eviction**: container killed; next request cold-starts again.

The trust model implicit in serverless is "one invocation per request". But warm reuse means *the same process state* services multiple user requests — and platforms don't guarantee user isolation between warm invocations on the same instance.

## Bug patterns

### 1. Module-globals as cache
```ts
let cachedUser = null;
export async function handler(event) {
  if (!cachedUser) cachedUser = await db.user.findById(event.userId);
  return cachedUser;
}
```
First user's data cached; second user's request hits warm instance → gets first user's data.
- **Fix**: never module-level state for per-request data.

### 2. Logger / metrics with request context bleed
```ts
let currentRequest = null;
log.setContext = (r) => currentRequest = r;
export async function handler(event) {
  log.setContext(event);
  await doWork();
  log.info('done');  // attaches event to log
}
```
If `doWork` is async and returns to event loop, a concurrent invocation in the same warm runtime overwrites `currentRequest`. Logs cross-contaminate. Cloudflare Workers, Vercel Edge, Lambda Node all run multiple requests in one isolate when concurrency allowed.
- **Fix**: use `AsyncLocalStorage` (Node) or per-request context object passed explicitly.

### 3. `/tmp` write persisted across invocations
Lambda's `/tmp` is per-container (warm-reuse). File written during one invocation visible in next.
- Vulnerable: user uploads file to `/tmp/in.jpg`, handler processes it. Next user's invocation reads `/tmp/in.jpg` (or shells out and globs `/tmp/*`).
- Cross-user data leak.
- **Fix**: namespace `/tmp` writes by request ID; clean up before return.

### 4. Lazy-init secret in module global
```ts
let stripeClient;
async function getStripe() {
  if (!stripeClient) stripeClient = new Stripe(await getSecret('STRIPE_KEY'));
  return stripeClient;
}
```
Stripe client is fine to cache — but if the secret fetch is per-tenant, you've cached the wrong tenant's client.
- **Fix**: keys for caches must include tenant/user discriminator; or no caching of per-tenant resources.

### 5. Database connection pool leak
- ORM connection pool initialised at module load → connects on cold start → reused.
- One request's transaction may bleed isolation level / search_path into the next (Postgres `SET LOCAL` vs `SET`).
- Fix: explicit per-request `BEGIN`/`COMMIT`; reset session state at end.

### 6. Tenant cache poisoning
- Cache layer (memcached, Redis) shared across tenants.
- Key without tenant ID → cross-tenant leak.
- **Fix**: tenant prefix on every cache key; assertion in cache wrapper.

### 7. Cold-start timing oracle
- Cold start takes 100ms-2s; warm is 1-50ms.
- Differential timing leaks "have you seen this user before?" info.
- Theoretical for most apps; real for high-precision auth bypass tests.

### 8. Race window in lazy init
- Two requests arrive on a freshly-warm instance simultaneously.
- Both hit `if (!cache) cache = await load()` — both load → second's load may overwrite first's partial state.
- Pre-init in `process.env`-driven startup avoids this.

### 9. Cross-invocation timer / setInterval
- `setInterval(..., 60_000)` started in one invocation continues firing in the warm container.
- Reads stale request context; may call APIs outside any user's session.
- **Fix**: never long-lived timers in handler bodies; use platform's scheduled-event primitives.

### 10. Cold-start error masking
- First invocation after cold start can fail differently than warm (e.g., DB not yet connected).
- Error-handling paths often less audited.
- Attacker can force cold starts via rate-throttle + retry to exercise edge cases.

### 11. Provisioned concurrency edge cases
- AWS Lambda provisioned concurrency = pre-warmed instances. Init code runs N times in parallel during scale-up.
- Race conditions in initialisation (writing to S3 or DB during init) replicate.

### 12. Tenant context in observability
- DataDog / OpenTelemetry trace context propagated via module globals → cross-trace leak.
- Use `AsyncLocalStorage` properly or a request-scoped context object.

## Audit checklist
```bash
# Module-globals likely leaking state
rg -n 'let \w+\s*=\s*(null|undefined|\[\]|\{\})\s*$' src/handlers
rg -n 'const \w+ = new \w+\(' src/handlers   # client/pool created at module scope
# /tmp usage
rg -n '/tmp/' src/
# AsyncLocalStorage usage (if absent, suspicion increases)
rg -n 'AsyncLocalStorage' src/
# Lazy init patterns
rg -n 'if\s*\(\s*!\w+\s*\)\s*\w+\s*=' src/
# Timers / intervals
rg -n 'setInterval|setTimeout' src/
```

## Hardening
- Per-request context via `AsyncLocalStorage` (Node) / `requestContext` (Edge runtimes).
- No module-level mutable state outside framework / SDK clients.
- `/tmp` writes namespaced by request ID; cleanup in `finally`.
- Cache keys include tenant/user.
- DB sessions reset to defaults at handler end.
- Avoid `setInterval` / long-running timers; use platform scheduled events.

## References
- [AWS Lambda execution environment](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html)
- [Node.js AsyncLocalStorage](https://nodejs.org/api/async_context.html)
- [Vercel — function instance reuse](https://vercel.com/docs/functions/runtimes)
- [Marc Brooker — serverless concurrency model](https://brooker.co.za/)
- See also: [[race-conditions]], [[cloudflare-workers-audit]], [[vercel-edge-and-middleware-audit]]

{% endraw %}
