---
title: JWT key confusion (alg)
slug: jwt-key-confusion
---

> **TL;DR:** Switch the token's `alg` from `RS256` to `HS256` so the verifier treats the RSA public key as an HMAC secret. Sign with that public key and the token validates.

## What it is
Asymmetric algorithms (RS256, ES256) verify with a public key; symmetric algorithms (HS256) verify with a shared secret. Libraries that look up the verification key by `kid` and then dispatch on the header-supplied `alg` will hand the public key to the HMAC verifier when `alg: HS256` is set. Because public keys are not secret, the attacker also knows them — and HMAC works with any byte string.

## Preconditions / where it applies
- Verifier accepts the `alg` value from the token header instead of pinning it server-side
- The RSA/EC public key is recoverable: published in JWKS, embedded in OIDC discovery, fetchable from `/.well-known/jwks.json`, or extractable from token signatures with `jwt-pubkey-recover`
- Library does not type-check that the configured key matches the requested algorithm

## Technique
1. Grab the public key:

   ```bash
   curl -s https://target.example/.well-known/jwks.json | jq .keys[0]
   # convert JWK to PEM if needed
   ```

2. Forge a token. Change the header `alg` to `HS256`, set claims, sign with the public key as the HMAC secret:

   ```python
   import jwt
   with open("pub.pem","rb") as f: pub = f.read()
   tok = jwt.encode({"sub":"admin","role":"admin","exp":9999999999}, pub, algorithm="HS256")
   ```

   Important: use the exact byte representation the server uses (PEM with or without trailing newline, DER, JWK JSON). Trial both PEM variants — most failures here are formatting, not crypto.

3. Submit and check whether claims are accepted.

4. **`alg: none` variant.** Some legacy libraries accept `{"alg":"none"}` and skip verification entirely. Send a header-only token with no signature segment.

5. **Mixed-algorithm key store.** If the server holds both an HMAC secret and an RSA pubkey indexed by `kid`, switching `kid` plus `alg` may pick a different key class than intended.

## Detection and defence
- Pin the algorithm server-side; never trust the header. APIs should call `verify(token, key, algorithms=["RS256"])` and reject anything else
- Use libraries that type-check key material against the algorithm (`PyJWT >=2`, `jose` with explicit algs)
- Store HMAC keys and RSA keys in separate keystores with non-overlapping `kid` namespaces
- Reject `alg: none` at the gateway
- Log alg mismatches between issuance and verification — a forged HS256 against an RS256 issuer is a high-signal alert
- Related: [[jwt-jku-jwk-injection]] for header-injected key material

## References
- [PortSwigger: algorithm confusion](https://portswigger.net/web-security/jwt/algorithm-confusion) — labs and recovery technique
- [CVE-2015-9235 jsonwebtoken](https://nvd.nist.gov/vuln/detail/CVE-2015-9235) — original public disclosure of the class
- [jwt_tool](https://github.com/ticarpi/jwt_tool) — automation for this and other JWT attacks
