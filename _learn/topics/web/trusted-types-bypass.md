---
title: Trusted Types bypass
slug: trusted-types-bypass
---

> **TL;DR:** Trusted Types force every DOM-XSS sink to consume a typed object, not a string — bypasses come from default policies that pass values through, sanitiser disagreements, or DOM-clobbering gadgets that produce typed objects from attacker input.

## What it is
Trusted Types is a browser feature (Chromium since v83, partially Firefox, in WebKit drafts) declared via CSP: `Content-Security-Policy: require-trusted-types-for 'script'; trusted-types policy1 policy2`. Once enabled, sinks like `Element.innerHTML`, `Element.outerHTML`, `Document.write`, `eval`, `setTimeout(string)`, and `script.src` reject plain strings and require an instance of `TrustedHTML`, `TrustedScript`, or `TrustedScriptURL` minted by an allowed policy. The defence relies on the assumption that policies are few, audited, and never return attacker-controlled strings as-is.

## Preconditions / where it applies
- A target page running with Trusted Types enforcement (`require-trusted-types-for 'script'`).
- An exploitable DOM-XSS sink exists, but the string can't be assigned directly.
- Bypass requires one of: a permissive `default` policy, an allowed policy whose `createHTML` echoes input, DOM clobbering ([[dom-clobbering]]) to produce a typed object, or an HTML mutation gadget post-sanitisation.

## Technique

**Default-policy bypass.** Frameworks often register a `default` policy that delegates to DOMPurify or a custom sanitiser. If the sanitiser allows the attacker's HTML through, TT did not help:

```js
trustedTypes.createPolicy('default', {
  createHTML: s => DOMPurify.sanitize(s, { RETURN_TRUSTED_TYPE: true }),
});
// any innerHTML = "<img onerror=...>" runs through DOMPurify; if DOMPurify has a known bypass (e.g. nested templates, namespace confusion), the result is still TrustedHTML.
```

DOMPurify has shipped multiple bypasses (CVE-2024-45801, 2024-47875, 2021-46708, 2020-26870) — match the deployed version and the corresponding payload.

**Mutation XSS gadget chains.** Even sanitised HTML can re-parse differently when inserted. `<style><a id="<img src=x onerror=alert(1)>">` survives DOMPurify and mutates on `innerHTML` in some configurations.

**Policy-name allowlist bypass.** If `trusted-types policy-name 'allow-duplicates'` lets pages register the same name, an injected script can create a permissive policy:

```js
trustedTypes.createPolicy('policy-name', { createHTML: s => s }).createHTML('<img onerror=...>')
```

**Sink rediscovery.** Old sinks (`<a href="javascript:...">`, `srcdoc`, SVG `<use>` href, MathML `xlink:href`) are sometimes missed by TT enforcement implementations or by polyfills.

**DOM clobbering to satisfy a type check.** Code like `if (x instanceof TrustedHTML) sink.innerHTML = x` can be tricked by `<form id=TrustedHTML>` plus `instanceof` returning truthy for clobbered globals on older engines (mostly closed but historical).

**Same-origin script injection (`TrustedScriptURL`).** If any policy mints `TrustedScriptURL` from a string, an open redirect ([[open-redirect]]) on the trusted origin chains to attacker JS.

## Detection and defence
- No `default` policy, or a default that throws. Force callers to be explicit.
- Use `tt-policy-allow-duplicates` only when necessary; uniquely name policies.
- Run with `Content-Security-Policy-Report-Only: require-trusted-types-for 'script'` in staging; collect violation reports.
- Pair TT with strict CSP (`script-src 'self' 'nonce-...' 'strict-dynamic'`) — TT raises the bar but is not a complete XSS solution.
- Keep DOMPurify pinned and patched; subscribe to its advisories.
- Audit: search the bundle for `createPolicy(`, identify every policy's `createHTML`/`createScript`/`createScriptURL`, ensure none returns the input verbatim.

See also [[cross-site-scripting]], [[dom-xss]], [[content-security-policy-bypass]].

## References
- [web.dev – Trusted Types](https://web.dev/articles/trusted-types) — primer
- [W3C – Trusted Types](https://w3c.github.io/trusted-types/dist/spec/) — normative
- [Google Security Blog – Trusted Types at scale](https://security.googleblog.com/2020/03/securing-web-with-trusted-types.html) — deployment lessons
