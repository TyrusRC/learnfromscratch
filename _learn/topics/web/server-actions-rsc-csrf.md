---
title: Server Actions / RSC CSRF and related patterns
slug: server-actions-rsc-csrf
aliases: [server-actions-csrf, react-server-component-csrf, rsc-csrf]
---

> **TL;DR:** React Server Components (RSC) and Next.js Server Actions introduce a new RPC-shaped surface: client invokes server functions identified by an opaque action ID, with arguments serialised in a framework-specific format. CSRF defences depend on the framework's handling of `Origin`/`Referer` plus the action-ID secrecy. Default protections vary across Next.js versions and other RSC implementations; bug-bounty findings have surfaced in real apps. Companion to [[nextjs-server-actions-audit]] and [[csrf]].

## Why this is its own class

- Server Actions are **not** REST endpoints. The default CSRF mental model (token in form, validated server-side) doesn't directly apply.
- The action **identity** is part of the request payload, not the URL.
- Framework defaults change; what was protected in Next.js 14.0 may not be in 14.1; what's protected in default config may not be with custom server.
- Bug-bounty hunters report this class as a recurring source of findings on Next.js / RSC apps.

## RSC / Server Action recap

In Next.js (App Router):

```jsx
async function MyAction(formData) {
  'use server';
  // runs on server
}

// Component:
<form action={MyAction}>
  <input name="x" />
  <button type="submit">Go</button>
</form>
```

Or programmatic:
```jsx
'use client';
import { MyAction } from './actions';

function Comp() {
  return <button onClick={() => MyAction({...})}>...</button>;
}
```

When invoked, the client POSTs to the same URL with `Next-Action: <action-id>` header, payload in body.

## Default Next.js protection (current versions)

Next.js 14+ implements:
- Check that `Origin` header matches request host.
- Check the action ID matches a registered action.

Versions prior had inconsistent enforcement. Vercel and the Next team document the changes.

## Class 1 — Origin / Referer check missing or weak

If the framework / proxy strips `Origin` header, or accepts requests without it:
- Cross-site form submission can invoke the action with attacker-controlled body.
- Classic CSRF impact.

Audit: send action invocation without `Origin`; observe.

## Class 2 — Action ID leakage

Action IDs are derived from a hash of source file + function name + key. If predictable:
- Attacker enumerates actions.
- Combined with no-CSRF-check, calls arbitrary actions.

Next.js uses a build-time key (`actionEncryptionKey`) to encrypt; attackers can't generate but can replay any ID seen in legitimate traffic.

## Class 3 — CSRF via subdomain

`Origin` checks only equal-origin. If your app has `app.example.com` and `evil.example.com` (subdomain takeover, or attacker-controlled subdomain):
- `evil.example.com` sends action request with `Origin: https://evil.example.com`.
- Equal subdomain to `app.example.com` is *not* same-origin; but...
- ...if check is `endsWith('.example.com')`, bypass.

Audit Origin check shape.

## Class 4 — Server-action exposed via untrusted reverse proxy

Cloudflare Workers / Vercel Edge / Cloudflare Pages can intercept and forward Origin headers differently. Custom proxy:
- Strips Origin.
- Adds Origin: own.
- Returns response to wrong origin.

Audit reverse-proxy header handling.

## Class 5 — Action invocation via GET

Some implementations or custom servers expose actions via GET. CSRF via image / link tag becomes trivial.

Even default Next, certain version configurations allow this for OG image generation or specific routes.

## Class 6 — Header injection enabling Origin bypass

If the app sets `Origin` server-side based on user-controlled header:
- Inject Origin: own.
- Bypass check.

Rare but documented in custom servers.

## Class 7 — Stale CSRF token after deploy

If the action-ID encryption key rotates on deploy, mid-session actions fail; some users get errors. Mitigations sometimes accept old IDs for grace period — replay attack opportunity.

## Class 8 — Mass-assignment-like in form-data

Server actions take serialised arguments. If the action handler doesn't validate arguments:
- Pass extra fields not in the form.
- Backend processes them as if from a trusted form (mass-assignment, [[mass-assignment]]).

Action handlers should validate inputs as if from untrusted user — even when called from "trusted" forms.

## Class 9 — Auth check missing in action

The action runs server-side, but auth is the developer's responsibility. Common omission:
- Action assumes logged-in user (because UI hidden from non-logged-in).
- Attacker calls action directly; runs without auth.

The form / button gating is UX, not security.

## Class 10 — Cross-tab / cross-origin token usage

If session cookies are `SameSite=Lax` (Next default), cross-site POST is *not* sent with cookies. So pure cross-origin CSRF without prior login is limited.

But:
- Top-level navigation followed by form submission (legacy `SameSite=None`) brings cookies.
- New tabs with stolen auth tokens.

Combinations matter.

## Workflow to audit

1. List all `'use server'` functions and their callers.
2. For each, identify intended caller(s) (form, programmatic, route).
3. For each, identify auth / authorization checks within.
4. Test with: missing Origin, cross-origin form, mismatched Referer, GET, mass-assignment of extra args.
5. Compare to framework defaults.

## Defensive baseline

- Use the latest framework version (Next 14+ recommended).
- **Validate auth in every action** — don't rely on form gating.
- **Validate input shape** — Zod / Joi schema per action.
- **Strict Origin checks** — exact match.
- **No GET for state-changing actions.**
- **Action-rate-limiting** at edge / WAF.
- **Audit reverse-proxy header handling.**
- **CSP** preventing common XSS that could invoke actions silently.

## Workflow to study

1. Spin up a Next.js 14 app with a server action.
2. Test default protection — cross-origin POST fails.
3. Test variant scenarios — missing Origin, subdomain, GET, missing auth.
4. Add custom server and test edge cases.

## Related

- [[nextjs-server-actions-audit]] — audit shape.
- [[nextjs-middleware-cve-2025-29927]] — adjacent recent CVE class.
- [[csrf]] — generic class.
- [[onsite-request-forgery]] — adjacent.
- [[mass-assignment]] — adjacent class.
- [[react-ssr-hydration-bugs]] — adjacent.

## References
- [Next.js — Server Actions docs](https://nextjs.org/docs/app/building-your-application/data-fetching/server-actions-and-mutations)
- [Next.js security advisory pages](https://github.com/vercel/next.js/security/advisories)
- [PortSwigger — modern web research](https://portswigger.net/research)
- See also: [[nextjs-server-actions-audit]], [[nextjs-middleware-cve-2025-29927]], [[csrf]], [[mass-assignment]]
