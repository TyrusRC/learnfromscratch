---
title: DOM XSS
slug: dom-xss
---

> **TL;DR:** XSS through client-side JS sinks (innerHTML, eval, document.write) rather than the server response.

## What it is
Reflected/stored XSS is a server-side bug — server emits attacker input into HTML. DOM XSS is a client-side bug — server's HTML is fine, but a JavaScript snippet on the page reads attacker-controlled state (URL fragment, `postMessage` data, `localStorage`) and writes it into a dangerous sink. The malicious string never appears in the server's response, so server-side WAFs and grep-the-response scanners miss it.

## Preconditions / where it applies
- Page JS reads from a *source*: `location.hash`, `location.search`, `document.referrer`, `window.name`, `localStorage`, `postMessage` event data
- Then passes that value (often unsanitised) into a *sink*: `innerHTML`, `outerHTML`, `document.write`, `eval`, `setTimeout(string)`, `Function()`, `.src=` of script tag, `location=`, jQuery `$()` on a string starting with `<`
- No Trusted Types policy enforces sink safety (see [[trusted-types-bypass]])

## Technique
Identify sources and sinks. Burp DOM Invader or Chrome DevTools "Sources → Search" for `innerHTML`, `eval`, `document.write`, `location.hash`. Trace each sink backward to a source.

```javascript
// vulnerable
document.getElementById('main').innerHTML = decodeURIComponent(location.hash.slice(1));
// payload (in URL fragment — never sent to server)
// https://target/#<img src=x onerror=alert(document.domain)>
```

Fragment-based payloads bypass server logging entirely (browsers do not send `#...` to the server). Useful for stealth.

Common patterns:

```javascript
// jQuery sink
$(location.hash)                          // hash="<img src=x onerror=...>"
// template
element.innerHTML = `<a href="${userInput}">`  // break out: ">"><img src=x …
// JSON-derived
eval('(' + queryParam + ')')              // straight RCE in page context
// postMessage
window.addEventListener('message', e => document.body.innerHTML = e.data)
```

postMessage chain — see [[postmessage-bugs]]. For client-side template engines see [[client-side-template-injection]].

Bypass CSP that allows `script-src 'self'` by reusing the host's own JSONP endpoints or trusted-types-less sinks; see [[content-security-policy-bypass]].

## Detection and defence
- Static analysis: ESLint with `no-unsanitized` rules, semgrep DOM sink rules
- Runtime: enforce Trusted Types (`Content-Security-Policy: require-trusted-types-for 'script'`) — sinks throw unless input is a `TrustedHTML` / `TrustedScript`
- Sanitise before writing: DOMPurify on any user-derived string
- Avoid `innerHTML` entirely; prefer `textContent` and DOM construction
- Lock down `postMessage` handlers (origin check + schema)

## References
- [PortSwigger — DOM-based XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based) — sinks and labs
- [OWASP — DOM-based XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html) — cheatsheet
- [Google — Trusted Types](https://web.dev/articles/trusted-types) — the structural fix
