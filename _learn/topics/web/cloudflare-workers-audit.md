---
title: Cloudflare Workers audit
slug: cloudflare-workers-audit
aliases: [cf-workers-security, workerd-audit]
---

{% raw %}

> **TL;DR:** Workers run on V8 isolates at Cloudflare edge with a non-Node runtime. Audit surface: KV/D1/R2/Durable Object permissions, `fetch` with attacker-controlled URLs (SSRF to internal Cloudflare services like the metadata-like `cf-int`), unbound `env` access in handlers, secret leak via `wrangler.toml`, `cf.connectingIp` trust, and cache API poisoning. The lack of a filesystem closes many classic bugs but opens edge-specific ones.

## What it is
Cloudflare Workers is V8-isolate edge compute: each request gets a fresh handler `fetch(request, env, ctx)`. `env` carries bindings to KV namespaces, D1 databases, R2 buckets, Durable Objects, queues, and secrets. No Node APIs; web-platform-ish (`fetch`, `Request`, `Response`, `crypto.subtle`, `caches`). Local dev via `wrangler dev` (which uses workerd).

## Threat-model summary
- Each Worker is publicly callable on `*.workers.dev` and any configured route.
- Bindings have no per-request scoping — the entire `env` is available to every handler.
- Edge runs in multiple data centres; eventual consistency for KV.
- `cf.connectingIp` reflects Cloudflare's view of the source IP — trustworthy only if the request transited Cloudflare.

## Bug patterns

### 1. Open Worker routes
Worker deployed to `worker.example.com` but also `worker.workers.dev` is left enabled (default). Attacker hits the latter, bypassing custom auth that lives on the WAF-protected zone.
- **Fix**: `wrangler.toml` `workers_dev = false`; route-based deployment only.

### 2. SSRF via `fetch`
```js
export default {
  async fetch(req, env) {
    const url = new URL(req.url).searchParams.get('u');
    return fetch(url);
  }
};
```
Worker fetch can reach the public internet AND specific Cloudflare-internal endpoints when bindings are configured. No IP-based allowlist by default.
- **Fix**: scheme + hostname allowlist; reject local/RFC1918/metadata patterns; cap redirect follow.

### 3. KV / D1 / R2 IDOR
Bindings are unscoped. Handler does `env.KV.get(req.params.id)` — attacker reads any key. Same shape for D1 (`SELECT * FROM ... WHERE id = ?` with attacker-supplied id, no ownership filter) and R2 (`env.R2.get(key)`).
- **Fix**: bind ownership check before any binding access; consider per-tenant prefixed keys.

### 4. Secret leak via `wrangler.toml`
Devs sometimes commit `wrangler.toml` with `vars.API_KEY = "..."` instead of using `wrangler secret put`. Secrets visible in repo.
- **Fix**: never put secrets in `vars`; always `wrangler secret put`; CI lint.

### 5. `cf.connectingIp` blind trust
Worker reads `req.cf.connectingIp` for rate-limit / authz. Inside Cloudflare network this is reliable. But:
- `wrangler dev` (local) has no real CF, so the value is spoofable on dev endpoints.
- Cross-Worker invocation via service bindings may not refresh the value as expected.
- **Fix**: pair with cookie/JWT auth, never the sole authz primitive.

### 6. Cache API poisoning
`caches.default.put(req, res)` stores responses keyed by request URL. Attacker primes the cache with a malicious response for a path the next victim hits.
- Combined with `Vary` header omission → cross-user contamination.
- See [[cache-poisoning]].

### 7. Durable Object lock contention / race
Durable Objects single-thread per-object — but Worker code that holds state in module-level `let` is NOT a DO; that state is shared across handlers in one isolate, lost across isolates. Auditors confuse module-globals for DO storage.
- **Fix**: store mutable state in DO storage API only; module-globals are immutable runtime config.

### 8. Service bindings exposing internal Workers
`wrangler.toml` `services = [{ binding="INTERNAL", service="internal-only" }]` lets your Worker invoke another. The internal Worker may have weaker public-route auth assuming it's only called from siblings. Misconfig → attacker hits the internal one directly via `workers.dev`.
- **Fix**: internal Workers should still enforce auth; default-deny.

### 9. Subdomain takeover via `workers.dev`
Old `<name>.workers.dev` subdomain abandoned. Cloudflare may release the name → attacker claims it → hosts a Worker that looks legitimate.
- See [[subdomain-takeover]]; rarer for `workers.dev` than custom CNAMEs but conceivable.

### 10. CPU/wall-clock budget bypass
Workers have CPU time limits (50ms paid plan default). Attacker can:
- Trigger CPU-heavy crypto loops to exhaust per-request budget → DoS.
- Use `ctx.waitUntil` to schedule expensive background work that survives response.
- **Fix**: rate-limit per IP/account; audit `waitUntil` callers; pin `compatibility_flags` for predictable behaviour.

### 11. Headers from `request.headers.get('cf-connecting-ip')`
If your Worker is behind another proxy (uncommon but possible), the cf-* headers may be spoofable.
- **Fix**: use the `request.cf` object (typed) not headers; never read cf-* from `request.headers` for security decisions.

### 12. R2 presigned URL scope
`env.R2.createMultipartUpload(key)` + presigned URLs with long expiry leak to attacker → permanent write access to a prefix.
- **Fix**: short TTL; per-upload key; verify content via worker after upload.

## Audit grep
```bash
rg -n 'env\.\w+\.(get|put|delete|list)' src/      # binding access
rg -n 'fetch\(\s*[a-zA-Z]' src/                   # potential SSRF
rg -n 'connectingIp|cf\.' src/                    # IP trust
rg -n 'caches\.default' src/                      # cache writes
rg -n 'waitUntil\(' src/
# wrangler.toml checks
grep -n '^\[vars\]\|^\[\[d1\|^routes\|workers_dev' wrangler.toml
```

## Hardening
- `compatibility_date` pinned; `compatibility_flags` reviewed.
- `wrangler.toml` reviewed in PRs; secrets only via `wrangler secret`.
- WAF rules in front of Workers for blanket protections (rate limit, geo block).
- D1 prepared statements only (`stmt.bind(...)` not template literals).
- R2 access via signed URLs with short TTL.

## References
- [Cloudflare Workers security docs](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Workerd runtime](https://github.com/cloudflare/workerd)
- [Trail of Bits — edge runtime analysis](https://blog.trailofbits.com/)
- [HackTricks — Cloudflare](https://book.hacktricks.wiki/) (Cloudflare-specific surfaces)
- See also: [[ssrf]], [[cache-poisoning]], [[subdomain-takeover]], [[vercel-edge-and-middleware-audit]]

{% endraw %}
