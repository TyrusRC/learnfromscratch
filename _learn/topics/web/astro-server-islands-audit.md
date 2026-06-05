---
title: Astro server islands audit
slug: astro-server-islands-audit
aliases: [astro-security-audit, astro-islands]
---

{% raw %}

> **TL;DR:** Astro's island architecture mixes static HTML with interactive components on demand. Server Islands (4.x feature) defer some component rendering to per-request server calls. Audit: server endpoints under `pages/api/`, `Astro.request` / `Astro.url` trust, partial-prerender cache keys, server-island secret leak via response, and the `client:*` directive surface that determines what JS ships. The static-first model eliminates many SSR bugs but introduces new ones around partial hydration.

## What it is
Astro renders HTML at build time (or request time in SSR mode). Interactive pieces ("islands") opt into client JS via `client:*` directives. Server Islands (Astro 4+) render server-side on each request, embedded inside otherwise-static pages.

```astro
---
// Top of .astro file — runs at build / request
const data = await fetch('https://api/...');
---
<html>
  <body>
    <StaticComponent />
    <InteractiveCard client:load data={data} />     <!-- island, ships JS -->
    <Greeting server:defer />                        <!-- server island -->
  </body>
</html>
```

## Bug patterns

### 1. Server endpoints (`pages/api/*`)
- Astro pages with `.ts`/`.js` extension + `export function GET/POST/...` become API endpoints.
- Public by default; auth check required in handler.
```ts
// src/pages/api/admin.ts
export async function GET({ request, locals }) {
  if (!locals.user?.isAdmin) return new Response('Forbidden', { status: 403 });
  return new Response(JSON.stringify(adminData));
}
```
- Audit: every `src/pages/api/*` for auth.

### 2. Server island response leak
- Server island returns rendered HTML per request, embedded via response stream.
- If the island returns props from a closure that contains secrets → secrets in response.
- **Fix**: minimum-viable props; sanitise.

### 3. `set:html` directive (Astro's equivalent of v-html)
```astro
<div set:html={post.body} />
```
- No auto-sanitisation. Stored XSS if `post.body` is user content.
- **Fix**: `astro-set-html-with-purify` or pre-sanitise.

### 4. `client:*` directive choice
- `client:load` — hydrates immediately on page load.
- `client:idle` — hydrates when idle.
- `client:visible` — hydrates on intersection.
- `client:only="react"` — never SSR'd; client-only.
- `client:only` islands receive props from the page via JSON serialisation → same data-leak risk as React/Vue SSR.

### 5. View Transitions API attack
- Astro 3+ supports view transitions across pages.
- Transition handler can run arbitrary JS during navigation.
- If transition data is user-controlled, XSS-equivalent surface.

### 6. Content Collections schema bypass
- Astro Content Collections enforce Zod schemas on markdown frontmatter.
- Bug: schema for `blog` collection allows arbitrary `bodyHtml` field that's later rendered with `set:html`.
- **Fix**: strict schema; `bodyHtml` not allowed; markdown rendered through Astro's renderer (which escapes).

### 7. SSR adapter trust
- Adapters (`@astrojs/node`, `@astrojs/vercel`, `@astrojs/cloudflare`, `@astrojs/netlify`) implement the request handler.
- Each has its own request body parsing, header handling.
- Audit: adapter-specific quirks; some have body-size, timeout defaults.

### 8. `Astro.request.headers` trust
- Behind a proxy, `x-forwarded-*` headers needed for client IP / scheme.
- Astro doesn't normalize; app code must.
- Same risk as [[host-header-injection]] if used for canonical URL generation in SSR.

### 9. Middleware
- `src/middleware.ts` runs per-request.
- Setup `Astro.locals` for downstream pages.
- Auth here; per-page checks redundant but safer.

### 10. Image optimisation
- `<Image>` component fetches and processes images at build or request time.
- User-controlled `src` → SSRF (server fetches arbitrary URL).
- Configure `image.domains` / `image.remotePatterns` strictly.

### 11. Partial prerender / hybrid mode
- Astro hybrid mode: some pages static, some SSR.
- `export const prerender = false` per page.
- Bug: page meant SSR but `prerender = true` accidentally → cached version contains user data.

### 12. Markdown frontmatter execution
- MDX components execute on render. User-supplied MDX = RCE on render server.
- Astro Content Collections accept MDX; if a collection ingests user-submitted MDX → never. Restrict to admin or pre-rendered.

## Audit grep
```bash
rg -n 'set:html=' src/
rg -n 'export (async )?function (GET|POST|PUT|DELETE|PATCH)' src/pages/api/
rg -n 'client:(only|load|idle|visible)' src/
rg -n 'server:defer' src/
rg -n 'astro:env|getSecret' src/
rg -n 'Astro\.request\.headers' src/
rg -n 'export const prerender' src/pages/
rg -n 'image\.domains|image\.remotePatterns' astro.config.*
```

## Hardening
- Auth in `src/middleware.ts` covering all routes that need it; redundant per-route checks.
- API endpoints explicit auth; never default-allow.
- DTOs for component props that ship to client.
- Pre-sanitise any data reaching `set:html`.
- Content Collections strict schemas; no raw HTML fields.
- `image.remotePatterns` allowlist.
- Production env: `NODE_ENV=production`; verify SSR enabled where expected.

## References
- [Astro docs — Endpoints](https://docs.astro.build/en/guides/endpoints/)
- [Astro Server Islands RFC](https://astro.build/blog/future-of-astro-server-islands/)
- [Astro security topic](https://docs.astro.build/en/recipes/security/)
- [Content Collections](https://docs.astro.build/en/guides/content-collections/)
- See also: [[react-ssr-hydration-bugs]], [[vue-ssr-audit]], [[sveltekit-form-actions-audit]], [[cross-site-scripting]], [[ssrf]]

{% endraw %}
