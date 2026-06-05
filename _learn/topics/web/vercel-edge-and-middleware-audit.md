---
title: Vercel Edge and Middleware audit
slug: vercel-edge-and-middleware-audit
aliases: [vercel-middleware-audit, edge-functions-audit]
---

{% raw %}

> **TL;DR:** Vercel splits compute into Node serverless functions, Edge Functions (V8 isolates), and Middleware (runs before every request to a Next.js / framework deployment). Audit surface: middleware that fails-open on errors, header trust (`x-forwarded-*`), the CVE-2025-29927 middleware-bypass shape (see [[nextjs-middleware-cve-2025-29927]]), env var exposure via build leak, ISR cache poisoning, and the per-region cold-start race.

## What it is
Vercel deployments include multiple compute layers:
- **Static** — pre-rendered HTML.
- **ISR** — periodically regenerated static.
- **Edge** — V8 isolate, web platform APIs.
- **Serverless** — Node.js Lambda-style, full Node APIs.
- **Middleware** — Edge runtime function intercepting all requests before they reach a handler.

Each layer has different trust assumptions. Middleware in particular runs first — bugs there bypass everything else.

## Bug patterns

### 1. Middleware bypass (CVE-2025-29927 family)
- Header `x-middleware-subrequest` was honoured by Next.js to skip middleware on internal subrequests. Attacker sent the header on external requests → middleware (often the only authz check) skipped → unauthenticated access to gated pages.
- See [[nextjs-middleware-cve-2025-29927]] for the canonical exploit; this is a pattern worth checking across other "internal subrequest" header conventions.

### 2. Middleware fails open on exception
```ts
export async function middleware(req) {
  try {
    const user = await verifyJWT(req.cookies.get('token'));
    if (!user) return NextResponse.redirect('/login');
  } catch (e) {
    // log and let through
  }
  return NextResponse.next();
}
```
JWT verification throws → catch swallows → request proceeds unauthenticated.
- **Fix**: fail-closed; any auth check exception is a denial.

### 3. Header trust (`x-forwarded-*`)
- `req.headers.get('x-forwarded-for')` is set by Vercel proxy from the connecting IP.
- BUT if your middleware also runs in `wrangler dev` / local Next dev, the header is attacker-controlled.
- And attacker can include multiple comma-separated IPs; the "client IP" is the first one — but Vercel guarantees only that the last is the connecting IP. Picking the wrong index spoofs origin.

### 4. ISR / Data cache poisoning
- `revalidateTag('user-' + userId)` called with attacker-controlled tag can invalidate caches for any user.
- `next/cache` data cache keyed by URL + headers; if the cache key doesn't include auth context, one user's cached data serves to another.
- See [[cache-poisoning]].

### 5. Environment variable exposure
- Build-time env vars prefixed `NEXT_PUBLIC_*` are inlined into client bundles. Devs accidentally mark sensitive vars public.
- `process.env.API_KEY` in a client component (Next.js will warn but not block in all configs) inlines the secret.
- **Fix**: never `NEXT_PUBLIC_*` for secrets; `next build` output audit.

### 6. Edge runtime API mismatches
- Edge runtime is V8 only — no `fs`, no most Node APIs. Devs sometimes use `Buffer`, `crypto.createHash`, `node:fs` thinking they work; Vercel polyfills some, fails on others.
- Polyfill bugs occasionally introduce subtle differences (timing, randomness quality).

### 7. Geographic / IP rate limit at edge
- Vercel built-in `geolocation()` returns claimed country from connecting IP. Trustworthy.
- But edge functions in different regions may see different DNS for the same upstream → SSRF target varies by deploy region.

### 8. ISR on-demand revalidate
- `app/api/revalidate/route.ts` typically requires a secret. If the secret is leaked (env in client bundle) or weak (no entropy), attacker forces revalidation → DoS or cache poisoning if they can also trigger a render with attacker input.

### 9. Middleware matcher misconfig
- `export const config = { matcher: ['/dashboard/:path*'] }` — typo or pattern bug excludes a gated path. Audit every `matcher` against your route list.
- Negative patterns (`!/api/...`) had historical bugs around regex anchoring.

### 10. Preview deploys exposed
- Every PR gets a preview URL on `*.vercel.app`. Indexed by Google sometimes.
- Preview deploys often have looser auth (testing creds, debug flags) → auth bypass against the same code that's locked down in prod.
- **Fix**: Vercel Password Protection or SSO on previews; remove debug flags from `process.env` defaults.

### 11. Image Optimization SSRF
- `<Image src="https://victim/...">` with `next.config.js` `images.domains = ['*']` lets the Vercel image optimizer fetch any URL → SSRF from Vercel's image worker to internal services.
- **Fix**: restrict `images.domains` / `images.remotePatterns` strictly.

### 12. Server Actions specifics
- See [[nextjs-server-actions-audit]] — also relevant on Vercel.

## Audit checklist
```bash
# Middleware
rg -n 'export (async )?function middleware' app/ src/
# Matcher patterns
rg -n 'matcher:\s*\[' app/ src/ next.config.*
# Public env prefix
grep -nE 'NEXT_PUBLIC_' .env* next.config.*
# Revalidate routes
rg -n 'revalidateTag|revalidatePath|res\.revalidate' app/ pages/
# Image domain wildcards
grep -nE 'domains|remotePatterns' next.config.*
```

## Hardening
- Fail-closed in middleware; no error swallow.
- Restrict `NEXT_PUBLIC_*` to truly public values; lint in CI.
- Preview deploys behind auth (Vercel Password Protection or SSO).
- Pin Next.js to a version past the middleware-bypass fix.
- `images.remotePatterns` with explicit `protocol/hostname/pathname`.

## References
- [Vercel security docs](https://vercel.com/docs/security)
- [Next.js security advisories](https://github.com/vercel/next.js/security/advisories)
- [Assetnote — Next.js writeups](https://blog.assetnote.io/)
- See also: [[nextjs-middleware-cve-2025-29927]], [[nextjs-server-actions-audit]], [[cache-poisoning]], [[cloudflare-workers-audit]]

{% endraw %}
