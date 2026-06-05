---
title: React SSR hydration bugs
slug: react-ssr-hydration-bugs
aliases: [react-ssr-security, hydration-mismatch-bugs]
---

{% raw %}

> **TL;DR:** React server-side rendering produces HTML on the server, which React then "hydrates" on the client by attaching event listeners and reconciling. Mismatches between server-render and client-render leak data, enable XSS via `dangerouslySetInnerHTML` reaching server output unsanitised, expose backend-only props in the serialised RSC payload, and let attacker JS race the hydration window. Frameworks: Next.js (App + Pages Router), Remix, RedwoodJS, Gatsby.

## What it is
React SSR cycle:
1. Server renders the React tree to HTML (via `renderToString`, `renderToPipeableStream`, or the framework equivalent).
2. Server includes a serialised version of any props the client component needs (often as JSON in a `<script>` tag).
3. Client downloads HTML + JS, runs React, "hydrates" the existing DOM with event handlers.
4. From there, it's a normal SPA.

Security-relevant boundaries: the server→client serialisation, the hydration race, and the `dangerouslySetInnerHTML` reaching server output.

## Bug patterns

### 1. Props leak via RSC / hydration payload
React Server Components send serialised props to the client as part of the page. Any data passed as props to a client component is visible to the browser.
```tsx
// Server component
async function Profile() {
  const user = await db.user.findUnique({ where: { id: ctx.userId } });
  return <ClientCard user={user} />;
}
```
- `user.passwordHash`, `user.email`, every column is in the HTML payload.
- DevTools "View Source" reveals it.
- **Fix**: strip server-only fields before passing to client components.

### 2. `dangerouslySetInnerHTML` reached by user input
Same risk as XSS — but server-rendered HTML means it's in the initial page, runs before hydration, runs even with JS disabled (sort of), and is in CDN cache.
```tsx
<div dangerouslySetInnerHTML={{ __html: post.body }} />
```
- If `post.body` is unsanitised user input → stored XSS.
- Server render means the XSS payload appears before any React-level sanitisation kicks in.
- **Fix**: sanitise on write OR on read with DOMPurify (server-side `isomorphic-dompurify` or `sanitize-html`).

### 3. Hydration mismatch reveals data
If server renders different HTML than client first-render:
- React warns "hydration mismatch" — production swallows the warning.
- React falls back to client-render, throwing away server output.
- Window after first paint where server-rendered content is visible but inert.
- Attacker exploits: include sensitive data server-side, expect client-render to remove it; victim sees brief flash. Less critical, but PII leak.

### 4. Race window before hydration
- Server-rendered button has `onclick="..."` placeholder; React attaches the handler at hydration.
- Pre-hydration click → no handler → fallback (maybe form submit to `action` URL).
- Attacker may trick users to click during the window for unintended action; rare but possible on slow networks.

### 5. `<Script>` ordering
- Next.js `<Script>` with `strategy="beforeInteractive"` runs before hydration.
- Code injection vulnerability in a `beforeInteractive` script runs without React's safety.

### 6. SSR injection via headers
- Server-side render uses `headers().get('x-forwarded-host')` to render canonical URL.
- Attacker controls header → SSR renders attacker URL into page → cached → propagated.
- See [[host-header-injection]] + [[cache-poisoning]].

### 7. `noscript` content
- React respects `<noscript>` content; server-renders it. If reachable to user-controlled input, XSS that fires for crawlers / non-JS users.

### 8. Static rendering of cookie / session data
- `getServerSideProps` (Pages Router) reads cookies, renders into HTML.
- If page is cached at CDN → next user gets prior user's session-derived content.
- See [[vercel-edge-and-middleware-audit]] section on ISR.

### 9. Frame ancestor bypass for SSR pages
- `Content-Security-Policy: frame-ancestors 'none'` set on the response.
- For SSR JSON endpoints (used by hydration), the header may be missing → click-jackable iframe.

### 10. Serialised function references
- Devs occasionally pass functions as props in RSC — React errors but in some configs falls back silently.
- Function reference + closure may leak.

### 11. Streaming SSR partial flush
- Streaming responses flush HTML chunks early.
- An exception mid-stream may leave half-rendered HTML, with attacker-controlled content already on screen.
- Error boundary must protect; otherwise data leak.

### 12. Hydration errors disclose state
- Dev mode error overlay shows component state + props.
- Production should not, but accidentally-enabled dev mode in prod → full state leak.

## Audit grep
```bash
rg -n 'dangerouslySetInnerHTML' src/
rg -n 'renderToString|renderToPipeableStream' src/
rg -n 'getServerSideProps|getStaticProps' pages/
rg -n 'use server|use client' app/
rg -n 'Script.*beforeInteractive' src/
rg -n 'cookies\(\)|headers\(\)' app/
rg -n 'cache:\s*[\x27"](no-)?store' src/
```

## Hardening
- DTOs at server/client boundary; never spread server objects into client components.
- Sanitise HTML on write (`isomorphic-dompurify`) and verify on read.
- Cache scope explicit: `cache: 'no-store'` for user-specific data; `'force-cache'` only for truly public.
- CSP includes `script-src` strict; verify it applies to hydration scripts.
- Error boundaries on every streaming SSR component.
- Production NODE_ENV strictly enforced in container build.

## References
- [React docs — Server Components](https://react.dev/reference/rsc/server-components)
- [Next.js — App Router data fetching + caching](https://nextjs.org/docs/app/building-your-application/data-fetching)
- [Remix docs — security considerations](https://remix.run/docs/en/main/guides/security)
- [Snyk — React XSS deep dive](https://snyk.io/blog/react-xss/)
- See also: [[nextjs-server-actions-audit]], [[cross-site-scripting]], [[host-header-injection]], [[cache-poisoning]]

{% endraw %}
