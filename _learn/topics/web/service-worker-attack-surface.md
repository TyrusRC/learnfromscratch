---
title: Service Worker as attack surface
slug: service-worker-attack-surface
aliases: [sw-security, service-worker-audit]
---

{% raw %}

> **TL;DR:** Service Workers are persistent client-side scripts that intercept network requests for a registered scope. Once installed, they survive page navigation and live until explicitly unregistered or the browser GCs them. Bugs: XSS that injects/registers a malicious SW gains semi-permanent control of the scope, scope hijacking via overly-broad registration, `respondWith` returning attacker content to legitimate requests, and BroadcastChannel data leakage across tabs. Complement to [[service-worker-persistent-xss]].

## What it is
A Service Worker is registered via `navigator.serviceWorker.register('/sw.js', {scope:'/'})`. Browser caches it, runs it as a separate thread, and routes requests within its scope through its `fetch` event handler. It can:
- Intercept any HTTP request in scope.
- Cache and replay responses (the "offline" use case).
- Receive push notifications.
- Run periodic background sync.
- Communicate with all tabs in scope via `BroadcastChannel`/`postMessage`.

## Bug patterns

### 1. XSS → persistent compromise via SW registration
Vulnerability: XSS on `https://victim.com/anything` lets attacker run `navigator.serviceWorker.register('/sw.js', {scope:'/'})` from a URL they control (uploaded JS, blob URL, or stored payload).
- The SW persists across page reloads.
- Browser-controlled lifecycle; full uninstall requires the user to clear site data.
- Attacker now intercepts every request to the origin — credentials, tokens, responses.
- See [[service-worker-persistent-xss]] for the deep dive.

### 2. Scope hijacking via permissive Service-Worker-Allowed
A SW's max scope is the directory of its script. `/sw.js` → scope `/`. But the response header `Service-Worker-Allowed: /` from the SW script's HTTP response lets a SW under `/uploads/sw.js` claim scope `/`.
- Bug: server returns this header on user-upload paths → user uploads `sw.js` → registers it → full scope.
- **Fix**: never set `Service-Worker-Allowed` from user-content origins.

### 3. SW responding with attacker content
SW's `fetch` handler returns whatever it wants:
```js
self.addEventListener('fetch', (e) => {
  e.respondWith(new Response('<script>alert(1)</script>', {headers:{'Content-Type':'text/html'}}));
});
```
For an XSS-then-installed-SW, every page in scope renders attacker HTML.

### 4. Cache poisoning that persists
SW caches responses (`caches.open('v1')` then `.put(req, res)`). A malicious SW caches a poisoned response permanently — even after the XSS is fixed and the SW is uninstalled, the cache may linger if the user doesn't clear site data.
- **Fix**: cache version naming + cleanup; SW should `caches.delete` outdated versions on `activate`.

### 5. PostMessage from SW to clients
SW can `.postMessage` to every controlled client (tab):
```js
clients.matchAll().then(clients => clients.forEach(c => c.postMessage(data)));
```
Cross-tab data flow without origin check on receive side → see [[postmessage-bugs]].

### 6. Push notification spoofing
- Push subscription tokens stored on app server.
- Compromised app server can spam notifications to all users.
- Compromised SW can show notifications mimicking legitimate ones — phishing surface (`registration.showNotification({title:'Your bank', body:'Login here'})`).

### 7. Background sync
- `registration.sync.register('tag')` queues background sync that runs when network is available.
- Persistent execution surface — survives page close.
- Hostile sync can exfil cached data once network returns.

### 8. SW + COOP/COEP/CORP mismatch
- SW responses are subject to CORS for cross-origin fetches. But same-origin responses set by SW can include arbitrary headers, including disabling COOP for the page.
- Bypass of cross-origin isolation depending on SW response headers.

### 9. `claim()` racing fresh page loads
- `self.clients.claim()` makes a newly-installed SW take control of existing clients immediately, without reload.
- Combined with malicious SW install → instant control without waiting for navigation.

### 10. Update check loophole
- Browser checks for SW updates on navigation (when ≥24hrs since last fetch). Malicious SW that survives 24hrs is effectively permanent until user intervenes.
- `updateViaCache: 'none'` is the safer registration option but not default.

## Audit checklist

### Repo / source review
```bash
# Find every SW script
find . -name 'sw.js' -o -name 'service-worker.js' -o -name 'workbox-*.js'
# Find every registration call
rg -n 'navigator\.serviceWorker\.register' .
# Find Service-Worker-Allowed headers
rg -n 'Service-Worker-Allowed' .
# Find fetch handlers + respondWith
rg -n 'respondWith\(' sw* service-worker* workbox*
```

### Deployment audit
- Confirm SW script served from a trusted origin only (not user upload bucket).
- Confirm CSP allows the SW script source.
- Confirm `Service-Worker-Allowed` header is set explicitly (or not at all) on every origin.
- Confirm SW versioning has cleanup logic.

## Hardening
- Strict CSP, especially `script-src` — SW scripts subject to it.
- Serve SW from a dedicated path with no user content (e.g., `/sw.js` at root, never `/uploads/sw.js`).
- Never set `Service-Worker-Allowed` on user-content origins.
- Periodic cache version migrations in SW; `caches.delete` aggressively.
- Logout flow includes `navigator.serviceWorker.getRegistrations()` + `r.unregister()` to clean up.
- Sentry/Datadog alerts on unexpected SW registration paths.

## References
- [MDN — Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Google Web.dev — SW security](https://web.dev/articles/service-worker-security)
- [PortSwigger — Service worker persistence](https://portswigger.net/research)
- See also: [[service-worker-persistent-xss]], [[postmessage-bugs]], [[mv3-extension-bypass]]

{% endraw %}
