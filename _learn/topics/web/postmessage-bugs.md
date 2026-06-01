---
title: postMessage flaws
slug: postmessage-bugs
---

> **TL;DR:** `window.addEventListener('message', e => …)` handlers that ignore `e.origin` or `e.source` accept attacker-controlled JSON — XSS, action invocation, and cross-origin data theft follow.

## What it is
`window.postMessage()` is the only sanctioned cross-origin DOM messaging channel. The contract is the receiver must verify `event.origin` (and ideally `event.source`) before acting on `event.data`. Receivers in the wild routinely skip the check, parse `data` as JSON or HTML, and dispatch to `innerHTML`, `eval`, `setAttribute('href', ...)`, or postBack URL fields. Symmetric bug: senders that emit secrets to `'*'` instead of a specific origin leak data to any embedded iframe.

## Preconditions / where it applies
- A target site embeds (or is embedded by) an iframe / opens a popup.
- The handler does any of:
  - No `origin` check at all.
  - A `String.indexOf` or `endsWith` substring check (bypass with `target.com.evil.tld`).
  - Allows `'null'` origin (sandboxed iframe).
- The handler routes the message into a DOM sink, a fetch URL, or a privileged action.

## Technique
Find the listener in DevTools — `getEventListeners(window).message`. Or grep the bundled JS for `addEventListener('message'` and `onmessage`.

Receiver-side XSS sink:

```js
window.addEventListener('message', e => {
  document.getElementById('out').innerHTML = e.data.html;
});
```

Attacker page from any origin:

```html
<iframe src="https://target.com/embed" id="t"></iframe>
<script>
document.getElementById('t').onload = () => {
  t.contentWindow.postMessage({ html: '<img src=x onerror=alert(1)>' }, '*');
};
</script>
```

Action invocation when the handler dispatches by `type`:

```js
window.addEventListener('message', e => {
  if (e.data.type === 'redirect') location = e.data.url;        // → open redirect / XSS
  if (e.data.type === 'auth')     fetch('/api/token', { method: 'POST', body: JSON.stringify(e.data) });
});
```

Sender-side leakage:

```js
parent.postMessage({ token: localStorage.token }, '*');   // any embedder reads it
```

An attacker iframes the secret-bearing page (if X-Frame-Options allows it) and captures the broadcast.

Advanced patterns:

- **Reverse tabnabbing** — `window.opener.postMessage` from a popup reaches the original page.
- **Origin-check string bugs** — `e.origin.indexOf('target.com') > -1` matches `https://evil.com/target.com`.
- **JSON.parse on `e.data`** — prototype-pollution gadget ([[prototype-pollution]]) if pollution affects later code paths.
- **`BroadcastChannel`** has the same model and similar bugs.

## Detection and defence
- Receiver MUST exact-match `event.origin === 'https://trusted.target.com'` before touching `event.data`.
- Optionally verify `event.source` against a known window reference held by the page.
- Sender MUST target a specific origin string (`postMessage(data, 'https://target.com')`); never `'*'` for secrets.
- Treat `event.data` as untrusted: validate shape with a schema, never pass to `innerHTML`, `eval`, `setAttribute('href')`.
- Strict CSP (no `unsafe-inline`) reduces XSS impact, Trusted Types blocks the typical sink.
- Audit: grep the prod bundle for `addEventListener\(.message.` and `postMessage\(.*\*\)`.

See also [[cross-site-scripting]], [[dom-xss]], [[xs-leaks]].

## References
- [PortSwigger – Web Messaging](https://portswigger.net/web-security/dom-based/dom-based-vulnerabilities#web-messaging) — sinks & sources
- [MDN – Window.postMessage](https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage) — normative
- [HackTricks – postMessage vulnerabilities](https://book.hacktricks.wiki/en/pentesting-web/postmessage-vulnerabilities/index.html) — catalogue of patterns
