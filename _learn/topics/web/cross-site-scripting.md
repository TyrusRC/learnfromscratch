---
title: Cross-site scripting (XSS)
slug: cross-site-scripting
---

> **TL;DR:** Attacker JavaScript runs in the victim's browser, in the origin of the vulnerable app, with full access to that origin's cookies, storage, and APIs.

## What it is
The browser renders attacker data as code because the server or client mixes untrusted input into an HTML, JS, or attribute context without the right encoding. Three families: reflected (input from the current request), stored (persisted server-side and served to other users), and DOM-based (the sink is in client JS — see [[dom-xss]]).

## Preconditions / where it applies
- A sink that emits attacker data into a page in a script-executable position: HTML body, attribute, JS block, URL handler, or via `innerHTML`/`document.write`.
- A browser without an effective Content-Security-Policy ([[content-security-policy-bypass]]), or with one that allows `'unsafe-inline'` or wide allowlists.
- The attacker can deliver the URL (reflected/DOM) or get content rendered to other users (stored).

## Technique
1. **Find the context.** Inject a unique marker (`xss7q`) and look at the rendered HTML. Is it inside a tag, attribute, comment, `<script>`, or URL?
2. **Pick a payload that fits the context.**

   ```html
   <!-- HTML body -->
   <svg onload=alert(1)>
   <!-- Single-quoted attribute -->
   ' autofocus onfocus=alert(1) x='
   <!-- Inside a <script> string -->
   ';alert(1);//
   <!-- javascript: URL -->
   javascript:alert(1)
   ```

3. **Bypass filters.** Mixed case (`<sCrIpT>`), HTML entities, JS escapes, `eval(atob('...'))`, template literal tricks. See [[waf-bypass]] and the cheat sheets below.
4. **Escape sanitiser quirks.** DOMPurify on outdated versions, server-side sanitisers that miss SVG/MathML, mutation-XSS where `innerHTML` re-parses your safe-looking output into something executable.
5. **Weaponise.** Read DOM and exfil sensitive data, mint same-origin requests (`fetch('/api/me',{credentials:'include'})`), pivot to [[csrf]] now that SOP is on your side, inject a key-logger, install a [[service-worker-persistent-xss]] for persistence.
6. **CSP bypass.** Look for JSONP endpoints, `script-src` with a CDN that hosts AngularJS or known gadget files, allowlisted nonceless `'unsafe-eval'`, or `base-uri` not locked → inject a `<base>` tag.

## Detection and defence
- Contextual output encoding by default — template engines that escape based on sink (HTML, attr, JS, URL). Avoid `innerHTML`, prefer `textContent`.
- Strict CSP with a nonce per request; no `'unsafe-inline'`, no broad allowlists, lock `base-uri 'self'`, set `object-src 'none'`. Add [[trusted-types-bypass]] resistance via `require-trusted-types-for 'script'`.
- HttpOnly + Secure + SameSite on session cookies to blunt token theft.
- Detection: server-side reflection scanners in CI; CSP report-uri telemetry; WAF rules for canonical payloads; review for `dangerouslySetInnerHTML` and similar.

## References
- [PortSwigger — Cross-site scripting](https://portswigger.net/web-security/cross-site-scripting) — labs, contexts, cheat sheet.
- [OWASP — XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) — encoding by context.
- [PayloadsAllTheThings — XSS Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/XSS%20Injection) — payload reference.
