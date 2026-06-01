---
title: Relative Path Overwrite (RPO)
slug: relative-path-overwrite
---

> **TL;DR:** A page references its CSS/JS with a relative path; an attacker tricks the URL parser into resolving that path against an injection-controlled segment, loading attacker content as same-origin CSS or JS.

## What it is
Browsers resolve relative resource URLs (`<link rel=stylesheet href="theme.css">`) against the current document URL. If the server treats `target.com/users/me/` and `target.com/users/me/anything` as the same resource (suffixed path is ignored), the browser thinks the document is at the deeper URL and resolves `theme.css` to `target.com/users/me/anything/theme.css`. If "anything" is attacker-controlled and the server also reflects content somewhere reachable by that resolved path, the attacker injects same-origin CSS or JS without classic XSS sinks. RPO is a niche but elegant primitive — it bypasses CSP that allows `'self'` styles or scripts.

## Preconditions / where it applies
- Server normalises or ignores the path after a known prefix (PHP `PATH_INFO`, Java servlets, ASP.NET routing with `{*catchAll}`, IIS classic, AEM Dispatcher with selectors).
- Page emits relative URLs (no `<base>` tag, no leading `/`).
- A reflection sink exists where the attacker's injected CSS / JS / HTML appears in the response body — most commonly a 404 page or an echoed `PATH_INFO`.
- Browser quirks: legacy IE used to do permissive CSS parsing (`Content-Type` ignored). Modern browsers still permit a same-origin CSS load if the response *parses* as CSS, regardless of content-type, when in quirks mode.

## Technique
The classic IE-era payload (`{}*{xss:expression(...)}`) is dead. The modern RPO is more about navigation tricks and CSS-injection chains.

Suppose `https://target.com/profile/me` returns HTML that includes `<link rel="stylesheet" href="theme.css">` and the server ignores extra path segments.

1. Browse to `https://target.com/profile/me/?x=`. The browser resolves `theme.css` to `https://target.com/profile/me/theme.css`.
2. If the server treats that as `/profile/me` (same as before), it returns the original HTML. The HTML contains attacker-injected content (e.g. an `<h1>` echoing the path). With `Content-Type: text/html`, modern browsers refuse to parse as CSS (strict MIME). So the modern RPO needs either:
   - **Quirks-mode document** — page lacks doctype, browser is more lenient.
   - **CSS reflection via a separate endpoint** — `/echo?css=` reflects raw CSS with `text/css`.
   - **Self-XSS to RPO** — the attacker controls `/profile/me/anything` so that response body itself is parseable CSS (an injection in `theme` user setting).

3. Combine with CSS-injection exfil ([[css-injection-exfiltration]]) — the loaded "stylesheet" contains attribute selectors that leak CSRF tokens from the same page.

PHP-specific path-info variant:

```
target.com/index.php/foo/theme.css   →  served as index.php, but relative URL resolves under /index.php/foo/
```

Apache `MultiViews` and IIS extensionless routing produce similar patterns.

## Detection and defence
- Always use absolute (`/static/theme.css`) or scheme-relative resource paths. Or set `<base href="/">`.
- Send a strict doctype (`<!doctype html>`) so the browser stays out of quirks mode.
- Send `X-Content-Type-Options: nosniff` on every response so browsers refuse to parse `text/html` as CSS/JS.
- Server-side: do not silently swallow extra path segments; 404 on unknown trailing.
- CSP: `style-src 'self' 'nonce-xyz'` raises the bar even when RPO works.
- Detection: spikes of 200s on URLs with unusual extra segments ending in `.css` / `.js`.

See also [[css-injection-exfiltration]], [[cross-site-scripting]], [[content-security-policy-bypass]].

## References
- [innerht.ml – RPO gadgets](https://blog.innerht.ml/rpo-gadgets/) — modern RPO walkthrough
- [Heyes – Sea Surf RPO](https://portswigger.net/research/detecting-and-exploiting-path-relative-stylesheet-import-prssi-vulnerabilities) — PRSSI variant
- [HackTricks – RPO](https://book.hacktricks.wiki/en/pentesting-web/relative-path-overwrite.html) — concise reference
