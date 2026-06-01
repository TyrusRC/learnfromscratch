---
title: Chrome Manifest V3 extension abuse
slug: mv3-extension-bypass
---

> **TL;DR:** MV3 extensions still siphon Meet/Zoom streams, hijack OAuth flows, and mutate pages via Declarative Net Request rules.

## What it is
Manifest V3 was sold as a hardening step (no remote code, no `webRequest` blocking for non-enterprise, service workers instead of background pages). But the trust model — an installed extension runs with broad host permissions and access to `chrome.*` APIs — is unchanged. Malicious or compromised MV3 extensions still achieve credential theft, session takeover, OAuth abuse, and silent page modification; recent research shows several MV3 APIs are effectively equivalent to the V2 primitives they were supposed to replace.

## Preconditions / where it applies
- Victim installs a malicious / supply-chain-compromised extension (sideload, store takeover, dev-account hijack)
- Or an extension with broad host permissions (`<all_urls>`, `*://*.google.com/*`) trusted at install time
- Enterprise managed-extension policies allowing arbitrary extensions

## Technique
1. **Content-script DOM scraping** — register a content script at `document_start`; read forms, cookies (via background SW), and DOM tokens. MV3 doesn't reduce this.
2. **Declarative Net Request (DNR) rule injection** — at runtime, the SW updates the dynamic rule set to redirect, modify headers, or block. Used to swap OAuth `redirect_uri`, strip CSP headers, route traffic through attacker proxies.
   ```js
   chrome.declarativeNetRequest.updateDynamicRules({
     addRules: [{
       id: 1, priority: 1,
       action: { type: "modifyHeaders",
         responseHeaders: [{ header: "content-security-policy", operation: "remove" }] },
       condition: { urlFilter: "|https://*", resourceTypes: ["main_frame"] }
     }]
   });
   ```
3. **`chrome.tabCapture` / `chrome.desktopCapture`** — capture Meet/Zoom audio/video from inside the user session.
4. **OAuth interception** — extension content script reads the authorization code from `chrome-extension://…/oauth-cb` or sniffs the navigation; or rewrites `client_id`/`redirect_uri` via DNR.
5. **Cookie theft via `chrome.cookies`** — host-permission extensions still read HttpOnly cookies through the API.
6. **Silent persistence** — service worker re-registers itself, fetches command-and-control config; "no remote code" rule is sidestepped by interpreting JSON config as logic (eval-like state machines).
7. **Side-loading via "Developer mode"** — phishing instructs user to enable dev mode and load unpacked.
8. **Update-channel hijack** — buy/take-over a popular legit extension and ship a malicious update.

## Detection and defence
- EDR: monitor extension installs, watch for dynamic DNR rules touching auth/CSP headers, watch `chrome.tabCapture` calls.
- Enterprise policy: `ExtensionInstallAllowlist` + block sideload; review `host_permissions` at allow-time.
- Users: scrutinise extension permissions at install; remove broad-host extensions that don't need them.
- For developers: minimise host permissions; declare `activeTab` only; use optional permissions requested at point of use.
- Related: [[postmessage-bugs]], [[oauth-token-theft]], [[webauthn-api-hijacking-downgrade]].

## References
- [Chrome — DNR docs](https://developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest) — capability surface
- [SquareX — MV3 bypasses](https://securityboulevard.com/2024/10/millions-of-enterprises-at-risk-squarex-shows-how-malicious-extensions-bypass-googles-mv3-restrictions/) — capture, OAuth, DNR abuse
- [Google — MV3 migration](https://developer.chrome.com/docs/extensions/develop/migrate) — official model
