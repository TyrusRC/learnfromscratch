---
title: JSON Web Tokens (JWT)
slug: jwt
---

> **TL;DR:** Signed/encrypted tokens carrying claims. Bug surface: algorithm confusion, weak keys, kid injection, jku, jwk.

## What it is
A JWT is `base64url(header).base64url(payload).base64url(signature)` where the header announces the signing/encryption alg and the payload carries claims (`sub`, `exp`, `aud`, …). Verification depends on the server trusting the header to pick the right key and algorithm — a long-standing source of bugs.

## Preconditions / where it applies
- Service authenticates by JWT (cookie, `Authorization: Bearer`, query param)
- Verification path reads the header alg / kid / jku / jwk before deciding the key — instead of pinning both
- HS256/RS256 confusion possible because libraries accept either

## Technique
1. **`alg: none`** — strip signature, set header alg to `none`/`None`/`nOnE`. Old jjwt/jsonwebtoken accept it.
   ```
   {"alg":"none","typ":"JWT"}.{"sub":"admin","exp":...}.
   ```
2. **HS256/RS256 confusion** — server holds an RSA public key; attacker signs HS256 using the public key as the HMAC secret. Verifier loads "the key" and calls HMAC-verify because header said HS256.
3. **Weak HS256 secret** — crack with `hashcat -m 16500 token.jwt wordlist`. Anything `<` ~10 random chars / dictionary will fall.
4. **`kid` injection** — header `{"kid":"../../../dev/null"}` makes the server load `/dev/null` as the key (empty); sign with empty key. Or SQLi/path traversal in `kid` to choose attacker-controlled bytes as the key.
5. **`jku` / `jwk`** — header points at a JWKS URL or embeds a public key. Some libraries fetch and trust it. Host attacker JWKS at `https://target.tld.attacker.tld/.well-known/jwks.json`, sign with the matching private key.
6. **`x5u` / `x5c`** — same idea with X.509 cert URLs / inline certs.
7. **JWE direct key** — `alg: dir` with `enc: A256GCM` and CEK from a guessable header field.
8. **Audience / issuer confusion** — token issued for service A accepted by service B (no `aud` check). Cross-tenant pivot.
9. **None of these?** Probe `exp`/`nbf` — some libs ignore claims they don't recognise, or compare as strings.
10. Tools: `jwt_tool.py`, Burp `JWT Editor`, `mkjwk`.

## Detection and defence
- Pin algorithm at the verifier; refuse `alg: none`; refuse HS* if the key is meant to be asymmetric (compare key type to header alg).
- Resolve key by trusted, server-controlled lookup — never by `jku`/`jwk`/`x5u` from the token.
- Use ≥256-bit HMAC secrets; rotate; store in KMS.
- Validate `iss`, `aud`, `exp`, `nbf`, `iat` and reject unknown headers.
- Where you only need session lookup, prefer opaque tokens.
- Log unusual headers (`kid` containing path chars, unknown `alg`, mismatched `iss`).
- Related: [[oauth-flows]], [[saml-attacks]], [[sso-attacks]], [[parser-differential-saml-ruby]].

## References
- [PortSwigger — JWT](https://portswigger.net/web-security/jwt) — labs covering alg confusion, jwk/jku, kid
- [Auth0 — JWT handbook](https://auth0.com/resources/ebooks/jwt-handbook) — claim semantics
- [jwt_tool](https://github.com/ticarpi/jwt_tool) — recon and exploit framework
