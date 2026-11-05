---
title: Client-Side Path Traversal (CSPT)
slug: client-side-path-traversal
aliases: [CSPT, client-side path traversal, client path traversal, CSPT to XSS, CSPT to CSRF]
---

> **TL;DR:** Client-Side Path Traversal (CSPT) occurs when user-controlled input is used to construct URLs in frontend JavaScript (`fetch`, `XMLHttpRequest`, `window.location`) without sanitisation — letting an attacker inject `../` sequences to redirect API calls to attacker-controlled endpoints, enabling XSS, CSRF, and data exfiltration without any server-side vulnerability.

## What it is
CSPT is the client-side cousin of server-side path traversal. Instead of reading files on the server, the attacker manipulates the path in a URL that client-side JavaScript constructs and fetches. By traversing out of the intended API path, the attacker redirects the request to a different endpoint — one that returns attacker-controlled content that the app trusts and renders unsafely.

The attack chain is typically: **CSPT source** (user input flows into URL path) → **traversal** (`../` to escape the intended directory) → **CSPT sink** (the response is used unsafely: `innerHTML`, `eval`, state mutation, or action execution).

## Preconditions / where it applies
- JavaScript constructs API URLs from user-controllable values (URL path segments, query parameters, fragment, `postMessage` data, storage values)
- The constructed URL is fetched and the response is rendered or acted upon
- Common in SPAs (React, Angular, Vue) that build API calls dynamically from route parameters
- The attacker can influence the URL source (via crafted link, open redirect, or reflected parameter)

## Technique

### 1 — Identifying CSPT sources
Look for patterns where user input is concatenated into fetch URLs:

```javascript
// Vulnerable pattern — route param directly in URL
const userId = window.location.pathname.split('/')[2];
fetch(`/api/users/${userId}/profile`)
  .then(r => r.json())
  .then(data => { document.getElementById('name').innerHTML = data.name; });

// Attack: visit /users/..%2f..%2fattacker-controlled-endpoint/profile
// fetch resolves to /attacker-controlled-endpoint/profile
```

Sources to check:
- URL path segments (`/resource/:id/action`)
- Query parameters (`?callback=`, `?next=`, `?returnTo=`)
- `window.location.hash` (fragment-based routing)
- `postMessage` data from other windows
- `localStorage` / `sessionStorage` values set from URL params

### 2 — CSPT-to-XSS chain
The classic chain: traverse to an endpoint that reflects user input, then the app renders it as HTML:

```
# App fetches /api/widgets/{id}/details and renders response in innerHTML
# Attacker URL:
https://target.com/widgets/..%2f..%2fuser%2fprofile%3fname%3d<img+src=x+onerror=alert(1)>/details

# The fetch resolves to:
/user/profile?name=<img src=x onerror=alert(1)>

# If that endpoint reflects the name param in JSON: {"name":"<img src=x onerror=alert(1)>"}
# And the app renders data.name via innerHTML → XSS
```

Requirements:
- A "gadget" endpoint that reflects attacker-controlled content in its response
- The sink that processes the response uses unsafe rendering (`.innerHTML`, `v-html`, `dangerouslySetInnerHTML`, `document.write`)

### 3 — CSPT-to-CSRF chain
Traverse to a state-changing endpoint to trigger actions on behalf of the victim:

```javascript
// App sends POST to /api/items/{itemId}/share with body from form
// If itemId is attacker-controlled:
// itemId = ../../../account/settings/change-email

// The POST goes to /api/account/settings/change-email
// with whatever body the app was going to send for "share"
```

This bypasses same-origin CSRF protections because the request originates from the app's own JavaScript — SameSite cookies and CORS are satisfied. If the target endpoint ignores unexpected body fields, the action executes.

### 4 — SPA router interaction
SPAs with client-side routing (React Router, Vue Router, Angular Router) often extract path segments and pass them to API calls:

```javascript
// React Router
function UserProfile() {
  const { userId } = useParams();  // from URL path
  useEffect(() => {
    fetch(`/api/v2/users/${userId}`)  // CSPT source → sink
      .then(r => r.json())
      .then(setUser);
  }, [userId]);
  return <div dangerouslySetInnerHTML={{ __html: user.bio }} />;
}
```

Angular's `HttpClient` with interpolated route params, Vue's `$route.params` in `axios` calls — same pattern.

### 5 — Relative URL manipulation
When JavaScript uses relative URLs, the browser resolves them against `document.baseURI` or `window.location`:

```javascript
// If current page is https://target.com/app/dashboard
fetch('api/data')  // resolves to https://target.com/app/api/data

// If attacker tricks victim to https://target.com/app/..%2fevil/dashboard
fetch('api/data')  // resolves to https://target.com/evil/api/data
```

The `<base href>` tag and service worker scope also affect resolution.

### 6 — Hunting methodology
```
1. Map all fetch/XHR calls in the SPA (browser DevTools → Sources → search for
   "fetch(", "axios.", "$.ajax", "XMLHttpRequest")
2. Trace each URL argument back to its source — is any segment user-controlled?
3. Check if the response is used in a dangerous sink (innerHTML, eval, state change)
4. Identify "gadget" endpoints on the same origin that reflect input or perform actions
5. Build the chain: craft URL with ../ to redirect fetch to the gadget endpoint
```

Browser DevTools → Network tab: watch API calls change as you modify URL path segments.

```bash
# Burp Suite: look for API calls where path contains user-reflected values
# Search proxy history for patterns like /api/v1/{reflected_value}/
# Test with: ..%2f..%2f to see if path traversal is normalised or passed through
```

### 7 — Real-world examples
- **Grafana CSPT** (CVE-2023-6152): avatar URL path traversal allowed redirecting API calls
- **Various SPA bug bounties**: React apps using `useParams()` directly in `fetch()` without validation
- **OAuth callback manipulation**: `state` or `redirect_uri` params used in post-auth API calls

## Detection and defence
- **Validate and sanitise path segments** — reject or strip `../`, `..%2f`, `..%5c` from any user input used in URL construction
- **Use allowlists** — map user input to a set of known-good values rather than interpolating directly into paths
- **Avoid dangerous sinks** — use `textContent` instead of `innerHTML`; use React JSX (auto-escapes) instead of `dangerouslySetInnerHTML`
- **URL constructor** — build URLs with the `URL` class and validate the final `pathname` stays within expected prefix:
```javascript
const url = new URL(`/api/users/${userId}/profile`, window.location.origin);
if (!url.pathname.startsWith('/api/users/')) throw new Error('invalid path');
```
- **Content-Type enforcement** — endpoints should return strict `Content-Type` (e.g., `application/json`) and the frontend should reject unexpected types
- **CSP** — `script-src` and `connect-src` directives limit where scripts can fetch from

See also [[xss]], [[csrf]], [[open-redirect]], [[path-traversal]], [[postmessage-vulnerabilities]].

## References
- [Doyensec — CSPT research](https://blog.doyensec.com/2024/10/07/cspt-research.html) — original systematic research
- [Doyensec — CSPT2CSRF](https://blog.doyensec.com/2024/10/07/cspt2csrf.html) — CSRF chain technique
- [PortSwigger — DOM-based vulnerabilities](https://portswigger.net/web-security/dom-based) — related DOM source/sink model
- [HackTricks — Client-side attacks](https://book.hacktricks.wiki/en/pentesting-web/xss-cross-site-scripting/dom-xss.html) — DOM XSS patterns
