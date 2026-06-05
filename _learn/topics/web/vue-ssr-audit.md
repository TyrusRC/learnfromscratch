---
title: Vue SSR / Nuxt audit
slug: vue-ssr-audit
aliases: [nuxt-security-audit, vue-server-render-audit]
---

{% raw %}

> **TL;DR:** Vue SSR (typically via Nuxt 3) generates HTML server-side, hydrates client-side. Audit surface: `v-html` reaching server-rendered content with user data, Nuxt server routes / Nitro endpoints exposed without auth, `useState` / `useFetch` payload leaks, runtime config exposure, `<NuxtLink external>` open-redirect, and the Nitro request body parser quirks. Bug families are similar to React SSR ([[react-ssr-hydration-bugs]]) but the API surface differs.

## What it is
Nuxt 3 (current major) runs on Nitro server engine, deployable to Node, Vercel, Cloudflare, Netlify, AWS, etc. Architecture:
- `pages/*.vue` — page components with `<script setup>` that runs on both server and client.
- `server/api/*.ts` — server-only routes.
- `server/routes/*.ts` — custom server routes.
- `server/middleware/*.ts` — runs on every request.
- `nuxt.config.ts` — runtime config, modules, build settings.

## Bug patterns

### 1. `v-html` with server data
```vue
<div v-html="post.body" />
```
- Vue does NOT sanitise `v-html`. Identical risk to React `dangerouslySetInnerHTML`.
- SSR renders the raw HTML on server → XSS in initial page + post-hydration.
- **Fix**: sanitise on write or via `DOMPurify` / `vue-sanitize`.

### 2. Server-only data reaching client via `useState` / `useFetch`
```ts
const { data: user } = await useFetch('/api/user');
```
- Returns the full API response, serialised into HTML payload for hydration.
- If `/api/user` returns secrets, they're in the page HTML.
- **Fix**: API returns only client-needed fields; trim server-side.

### 3. Runtime config leak
```ts
// nuxt.config.ts
runtimeConfig: {
  apiSecret: '',         // server-only
  public: {
    apiBase: '',          // sent to client
  }
}
```
- `useRuntimeConfig()` returns `{ apiSecret, public: {...} }` on server, only `{ public: {...} }` on client.
- Bug: secret moved to `public` accidentally → ships to client.

### 4. Server routes exposed
- `server/api/admin.ts` is publicly reachable by default.
- Middleware authentication must explicitly cover; per-route auth in handler is the usual approach.
- Audit: every `server/api/*` and `server/routes/*` for auth check.

### 5. Server middleware order
- `server/middleware/*.ts` runs on every request, in filename-alphabetical order.
- `auth.ts` after `01-logger.ts` (filename order) — logger sees unauth requests with PII.

### 6. Nitro body parser
- Default body parser handles JSON, form, multipart.
- Body size limit configurable; default high.
- Large body DoS unless cap set.
- Audit: `nitro.experimental` config + per-route body size.

### 7. `<NuxtLink>` to external URL
- `<NuxtLink to="...">` with user-controlled `to` → open redirect.
- `<NuxtLink external>` for external; if `to` user-controlled, attacker URL allowed.
- **Fix**: validate URLs in template; use allowlist for external links.

### 8. SSR cache
- Nitro has built-in route caching (`defineCachedHandler`).
- If cache key doesn't include user identity, cross-user data leak.

### 9. Server-only composables called in client context
- `useRequestHeaders` / `useRequestEvent` are server-only.
- If called in `<script setup>` that runs both, the client version returns nothing — but the server version returns headers including cookies. Composable correctness matters.

### 10. SQL via Nuxt-DB modules
- Several community modules wrap raw DB. Audit per-module for parameterisation.
- Direct `mysql2`/`pg` usage same shape as [[nodejs-code-auditing]].

### 11. Module CVE history
- Nuxt modules ecosystem is large; some have RCE / SSRF CVEs.
- `npm audit` + Snyk catch most.

### 12. Static-generation leak
- `nuxt generate` produces static HTML. If pages SSR'd with user-specific data and then statically generated, the static file leaks.
- Common in misuse: developer uses `useFetch` with user cookie on page meant to be static.

## Audit grep
```bash
rg -n 'v-html' pages/ components/
rg -n 'useFetch\(|useAsyncData\(' pages/ components/
rg -n 'runtimeConfig|useRuntimeConfig' src/ nuxt.config.*
rg -n 'server/api|server/routes' --files
rg -n 'defineEventHandler' server/ -A5 | grep -v 'auth'
rg -n 'defineCachedHandler|cachedFunction' server/
rg -n '<NuxtLink' --type=vue
```

## Hardening
- Move all secrets to non-`public` runtimeConfig.
- Wrap every `server/api/*` handler in auth check OR add a covering middleware first in alphabetical order.
- DTOs for API responses; never return raw DB rows.
- Cap body size in `nitro` config.
- Cache keys include user identity for any authed data.
- DOMPurify for `v-html` consumers.
- Static generate audit: which pages are truly static?

## References
- [Nuxt 3 docs](https://nuxt.com/docs)
- [Nitro engine](https://nitro.unjs.io/)
- [Vue security best practices](https://vuejs.org/guide/best-practices/security)
- [Nuxt security module](https://nuxt-security.vercel.app/)
- See also: [[react-ssr-hydration-bugs]], [[nextjs-server-actions-audit]], [[cross-site-scripting]], [[open-redirect]]

{% endraw %}
