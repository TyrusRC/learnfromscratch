---
title: SvelteKit form actions audit
slug: sveltekit-form-actions-audit
aliases: [sveltekit-security, svelte-form-audit]
---

{% raw %}

> **TL;DR:** SvelteKit form actions are RPC-style server functions invoked by HTML form submission, with progressive enhancement. Audit: actions exposed by route discovery, CSRF protection scope, mass-assignment via `FormData`, hooks ordering (auth must be in `handle`, not later), session cookie handling, and `load` function data leakage to client. Less footgun than Next.js Server Actions but the same shape of bugs.

## What it is
A SvelteKit route can export an `actions` object from `+page.server.ts`:
```ts
export const actions = {
  default: async ({ request, locals }) => {
    const data = await request.formData();
    return { success: true };
  },
  rename: async ({ request, locals, params }) => { ... }
};
```
Forms invoke them: `<form method="POST" action="?/rename">`. The framework wires dispatch.

Auth, session, and global concerns live in `hooks.server.ts`:
```ts
export const handle = async ({ event, resolve }) => {
  event.locals.user = await getUser(event.cookies);
  return resolve(event);
};
```

## Bug patterns

### 1. Actions exposed by route discovery
Every `+page.server.ts` exporting `actions` is a callable endpoint at the route URL. There's no "register" step.
- Bug: route created for internal-use form, but the route is publicly reachable. No `+page.svelte` rendered, but action still callable via POST.
- Audit: enumerate every `+page.server.ts` with `actions`; verify each has appropriate auth in the action body OR in `hooks.server.ts`.

### 2. Auth in `load` but not in actions
`load` runs to fetch page data; commonly does `if (!locals.user) throw redirect(303, '/login')`. But actions are a separate code path — same route's action may not redirect.
- **Fix**: auth check in each action OR centralise in `hooks.server.ts`.

### 3. Mass assignment via `FormData`
```ts
default: async ({ request, locals }) => {
  const data = Object.fromEntries(await request.formData());
  await db.user.update({ where: { id: locals.user.id }, data });
}
```
- `data` contains every form field including `<input type="hidden" name="role" value="admin">` that attacker injected.
- **Fix**: explicit field pick; reject extras.

### 4. CSRF
SvelteKit has built-in CSRF protection: rejects cross-origin POST with `application/x-www-form-urlencoded`, `multipart/form-data`, or `text/plain` if `csrf.checkOrigin` is on (default).
- Bug: `csrf: { checkOrigin: false }` in `svelte.config.js` for some integration → CSRF possible.
- Bug: JSON POST (which doesn't trigger preflight) accepted by an action that meant to be form-only.

### 5. Cookie handling
- `event.cookies.set('session', token, { httpOnly: true, secure: true, sameSite: 'lax', path: '/' })` — proper.
- Bug: missing `httpOnly` (JS-readable cookie), missing `secure` over HTTP dev that ships to prod, `path: '/admin'` scoping breaks broadly.
- See [[cookie-prefix-and-attribute-attacks]].

### 6. `load` function returns sensitive data
`+page.server.ts` `load` returns data to the page; in SvelteKit, that data is sent to the client (for hydration).
- Sensitive fields (password hash, internal flags) returned in `load` end up in the page HTML / JSON.
- **Fix**: strip server-only fields before returning.

### 7. Server-only modules
SvelteKit ensures `$lib/server/*` and `*.server.ts` modules are server-only. Importing them in client code = build error.
- Bug: secret in `$env/static/private` accessed from a `+page.svelte` directly — build catches.
- Bug: secret in `$env/dynamic/private` works at runtime; if used in `+page.ts` (universal load), runs on client too → leak. Use `+page.server.ts` only.

### 8. Hooks order
`handle` runs before any route logic; sets up `locals`. Multiple hooks compose via `sequence(...)`.
- Bug: auth hook after logging hook → logs include unauth requests with PII.
- Bug: error-handler hook before auth → errors fired by anon requests handled differently than authed.
- Audit: hook order; auth first, logging after auth-context is set.

### 9. Invalidation race
`invalidate` / `invalidateAll` triggers data reload. Cross-request race window where stale data renders briefly. Not a security issue per se, but for sensitive data (e.g., logout flow), stale render between server logout + client invalidation can briefly show authed content.

### 10. WebSocket / SSE in adapter
SvelteKit supports streaming via `+server.ts` endpoints. Same SSE/WebSocket risks as [[server-sent-events-injection]] / [[websocket-state-sync-bugs]].

### 11. `$page.url.searchParams` direct reflection
- `<p>Hello {$page.url.searchParams.get('name')}</p>` — Svelte escapes by default. Safe.
- `{@html $page.url.searchParams.get('name')}` — XSS.
- Audit: every `{@html ...}` for source.

### 12. Adapter-specific
- `@sveltejs/adapter-node` exposes `HOST`, `PORT`, `BODY_SIZE_LIMIT` env. Misconfig → DoS via large body or wrong bind.
- `@sveltejs/adapter-vercel` uses Vercel functions; see [[vercel-edge-and-middleware-audit]].
- `@sveltejs/adapter-cloudflare` uses Workers; see [[cloudflare-workers-audit]].

## Audit grep
```bash
rg -n 'export const actions\s*=' src/routes/
rg -n 'export const handle\s*=' src/hooks.server.ts
rg -n 'Object\.fromEntries\(.*formData' src/      # mass assign candidate
rg -n '\{@html\s' src/                            # XSS surface
rg -n 'csrf:|checkOrigin' svelte.config.js
rg -n '\$env/dynamic/private' src/                 # dynamic env access
rg -n 'locals\.user|event\.locals' src/
rg -n 'cookies\.set' src/
```

## Hardening
- Auth as a `handle` hook; `locals.user` populated for downstream.
- Every action checks `locals.user`; redirect/401 if missing.
- Form fields explicitly picked; never `Object.fromEntries(formData)` to update body.
- `load` returns minimal data; strip server-only fields.
- `$env/static/private` for secrets where possible; `$env/dynamic/private` only in `*.server.ts`.
- `{@html}` audited for input source.
- CSP set in adapter or response headers.

## References
- [SvelteKit form actions docs](https://kit.svelte.dev/docs/form-actions)
- [SvelteKit hooks docs](https://kit.svelte.dev/docs/hooks)
- [SvelteKit security topic](https://kit.svelte.dev/docs/glossary#csrf)
- See also: [[nextjs-server-actions-audit]], [[cross-site-scripting]], [[mass-assignment]], [[cookie-prefix-and-attribute-attacks]]

{% endraw %}
