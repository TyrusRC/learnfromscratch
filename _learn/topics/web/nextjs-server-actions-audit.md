---
title: Next.js Server Actions — audit
slug: nextjs-server-actions-audit
aliases: [next-server-actions-security, rsc-actions-audit]
---

{% raw %}

> **TL;DR:** Server Actions (`'use server'` functions) are RPC endpoints that look like local function calls — but their visibility, authorization, and input validation are 100% the developer's responsibility. Common bugs: actions referenced from any client component become unauthenticated public endpoints, no built-in CSRF (Next defends via origin check that has bypasses), parameter trust assumed because TypeScript "validates" inputs, and IDOR-by-default since the action runs as whoever called it. Complement to [[nextjs-middleware-cve-2025-29927]].

## What it is
Server Actions are a Next.js (and React) primitive that lets a function on the server be invoked from client code by reference. The framework wires up encrypted IDs, dispatch, and execution. The model is simpler than `app/api/*/route.ts` API routes, but the simplicity hides several footguns.

## Threat-model summary
- **Visibility**: any exported `'use server'` function in a module imported by a client component is exposed as a public RPC endpoint. Even if no UI references it. Removing the UI does not remove the endpoint.
- **Auth**: there is no automatic auth check. Middleware runs but does NOT see Server Action calls' parameters as form fields — it sees a POST to the page URL. Auth enforcement must be inside the action body.
- **Validation**: TypeScript types are compile-time hints, not runtime guards. Untyped or `any` inputs reach the body unchecked.
- **CSRF**: Next compares `Origin` to allowed list (`Host` + `experimental.serverActions.allowedOrigins`). If misconfigured (e.g., `'*'`, missing in dev) → CSRF.

## Bug patterns

### 1. Orphan action exposed as RPC
```ts
// app/actions/admin.ts
'use server';
export async function deleteAllUsers() { await db.user.deleteMany(); }
```
If any client component imports this file (even unused), the function is callable by anyone who can guess the action ID. Action IDs are deterministic from the call site → predictable on rebuild.
- **Fix**: gate with auth inside body; treat actions as public endpoints.

### 2. Missing auth check
```ts
'use server';
export async function updateProfile(id: string, data: ProfileInput) {
  return db.profile.update({ where: { id }, data });
}
```
Anyone can update any profile. `id` is attacker-controlled.
- **Fix**: read auth session inside action, derive `id` from session, never trust client-passed identifier.

### 3. Trusted FormData
```ts
'use server';
export async function newPost(form: FormData) {
  const role = form.get('role');
  await db.user.update({ where: { id: session.userId }, data: { role } });
}
```
Hidden form field `role=admin` works because FormData is just a wire format, not a trust boundary.
- **Fix**: only read fields explicitly granted to the user; ignore extras.

### 4. Mass assignment via spread
```ts
await db.user.update({ where: { id: session.userId }, data: { ...input } });
```
If `input` is typed `Partial<User>` but populated from `form.get` / JSON body, attacker sets any field — including `isAdmin`, `emailVerified`.
- **Fix**: explicit pick / zod schema with `.strict()`.

### 5. Server-side fetch within action (SSRF)
```ts
'use server';
export async function fetchPreview(url: string) {
  return (await fetch(url)).text();
}
```
- **Fix**: IP allowlist, scheme allowlist, no redirect-follow, or proxy via a hardened service.

### 6. RSC props leaking sensitive data
Server Components serialise their props to the client as part of the RSC payload. Anything passed as a prop to a `'use client'` child is visible to the browser. Common bug: passing `user` from server to client component, which includes `passwordHash`.
- **Fix**: strip server-only fields before passing across boundary; use a DTO.

### 7. CSRF via misconfig
`experimental.serverActions.allowedOrigins` accepts wildcards. `['*']` opens cross-origin invocation; `['localhost']` in dev that ships to prod is the classic mistake.
- **Fix**: explicit production origin; reject in dev too.

### 8. Encrypted action ID confusion
Next assigns each action an ID derived from source. Hot-reload or build-time changes can re-issue IDs; if a client has a stale ID, it may map to a different action on the server post-deploy. Audit for "stale tab" UX implications and version skew.

### 9. Open redirect via `redirect()`
```ts
'use server';
export async function login(form: FormData) {
  redirect(form.get('next') as string);
}
```
`redirect()` accepts any URL — open redirect, optional XSS via `javascript:` URI.
- **Fix**: validate `next` against allowlist.

### 10. Revalidate / cache poisoning
`revalidatePath` / `revalidateTag` calls with user-controlled path/tag can be used to evict a critical cached page repeatedly → cache stampede / DoS. Less catastrophic but reportable.

## Audit checklist
1. `rg -n "'use server'" app/ lib/` → enumerate every action file.
2. For each action: does it call `auth()` / `getServerSession()` / equivalent inside the body?
3. For each action: does it pick fields explicitly from input, or spread?
4. For each `redirect(...)` and `fetch(...)`: is the URL validated?
5. `next.config.js`: check `experimental.serverActions.allowedOrigins`.
6. Grep for `dangerouslySetInnerHTML` — XSS via Server Component output is still XSS.

## References
- [Next.js docs — Server Actions security](https://nextjs.org/docs/app/building-your-application/data-fetching/server-actions-and-mutations#security)
- [Vercel blog — Server Actions security model](https://vercel.com/blog/security-best-practices-for-server-side-vercel-functions)
- [Project Discovery — Next.js attack surface](https://blog.projectdiscovery.io/) (search "next.js")
- [Assetnote — Next.js writeups](https://blog.assetnote.io/)
- See also: [[nextjs-middleware-cve-2025-29927]], [[ssrf]], [[open-redirect]], [[mass-assignment]]

{% endraw %}
