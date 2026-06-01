---
title: OAuth flows and attacks
slug: oauth-flows
---

> **TL;DR:** Redirect_uri abuse, state-less requests, leaky code exchange, implicit-flow token leakage.

## What it is
OAuth 2.0 lets a client (web app) obtain a token from an authorization server (IdP) on behalf of a resource owner (user). The standard flows are Authorization Code (with PKCE), Implicit (deprecated), Client Credentials, Device Code, and Resource Owner Password (deprecated). Most attacks target the redirect step or the code/token exchange — primitives that survived from the very first drafts because real-world client implementations cut corners on validation.

## Preconditions / where it applies
- Any "Sign in with X" integration
- Client that uses `redirect_uri` to receive the authorization code or access token
- IdP whose registered redirect URI list uses loose matching (prefix, wildcard, missing path check)
- Missing or unverified `state` / PKCE `code_verifier`

## Technique
**redirect_uri smuggling.** The IdP allows `https://target.com/cb` and the client also exposes an open redirect at `https://target.com/redirect?next=`. Combine:

```
https://idp.example/authorize
  ?client_id=abc
  &response_type=code
  &redirect_uri=https://target.com/redirect?next=https://attacker
  &scope=email
```

The code is appended to attacker URL. Same idea with path traversal in path-matched URIs, `#` fragment after the registered URI, userinfo `@` smuggling (`https://target.com@attacker`).

**Missing state → CSRF login.** Without `state`, an attacker captures a valid authorization code for *their* account, tricks the victim into completing the IdP redirect with that code — victim's session is now bound to attacker's IdP identity. They unlink it later and have a persistent account on the victim's app.

**Implicit flow token leakage.** Response type `token` puts the access token in the URL fragment. Open redirects, Referer leakage, browser history, and any in-page postMessage-to-`*` (see [[postmessage-bugs]]) all leak it.

**Code interception without PKCE.** Native and SPA apps without `code_challenge` are vulnerable to a malicious app registering the same custom scheme / loopback URI.

**Mix-up attacks.** Client trusts the user's claim about which IdP is responding. Attacker steers the client to issue the code-exchange request to attacker's IdP — accesses the victim's account on attacker's IdP unwittingly.

**`response_mode=form_post` XSS.** IdP renders an auto-submitting HTML form including raw `state` — if `state` is reflected unsanitised, you get XSS on the client origin.

Related: [[oauth-token-theft]], [[sso-attacks]], [[open-redirect]].

## Detection and defence
- Exact-match `redirect_uri` (string-equality after canonicalisation)
- Mandatory PKCE for public clients; mandatory `state` for confidential clients
- Bind the authorization code to the client and to the `code_challenge`
- Drop implicit and ROPC flows entirely
- IdP rejects requests where `response_type=code` paired with `redirect_uri` containing open-redirect markers
- Log code-exchange requests; alert when a code is exchanged from an IP/UA far from the authorize request

## References
- [PortSwigger — OAuth 2.0 authentication](https://portswigger.net/web-security/oauth) — labs, common bugs
- [IETF — OAuth 2.0 Security BCP (RFC 9700)](https://www.rfc-editor.org/rfc/rfc9700.html) — current best practice
- [Daniel Fett — OAuth attacks catalogue](https://danielfett.de/) — formal analysis and mix-up
