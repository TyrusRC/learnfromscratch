---
title: PKCE downgrade and bypass
slug: pkce-downgrade-and-bypass
aliases: [pkce-attacks, oauth-pkce-bypass]
---

{% raw %}

> **TL;DR:** PKCE (Proof Key for Code Exchange, RFC 7636) was added to OAuth to defend public clients against authorization code interception. Bypasses come from: server not enforcing PKCE when client doesn't send it, `plain` method accepted, code-verifier reuse, verifier guessability, and confused-deputy attacks where attacker uses a legitimate but unrelated client. OAuth 2.1 mandates PKCE for all clients — but enforcement is server-side and often optional.

## What it is
PKCE adds two values to the auth code flow:
1. **`code_verifier`**: a random secret created by the client and kept private.
2. **`code_challenge`**: a transform of `code_verifier` (SHA256 + base64url by default, called `S256`; `plain` echoes the verifier).

Authorization request includes `code_challenge` and `code_challenge_method`. Token exchange request includes `code_verifier`. Authorization server verifies that `SHA256(code_verifier) == code_challenge` before issuing tokens.

Goal: even if attacker intercepts the auth code in transit (e.g., browser history, IPC hijack on mobile), they can't redeem it without the verifier.

## Bypasses

### 1. Server doesn't enforce PKCE when challenge missing
Spec says: if client *sent* a challenge, server MUST verify a matching verifier. But it doesn't *force* clients to send a challenge. Misconfig: client omits PKCE, server accepts. Now interception is fatal again.
- Test: send authorization request with no `code_challenge`. If server proceeds, PKCE not enforced.
- Fix (server): require `code_challenge` for all public clients (OAuth 2.1 default).

### 2. `plain` method accepted
`code_challenge_method=plain` means `code_challenge = code_verifier`. Interception of either yields both. Equivalent to no PKCE.
- Test: send `code_challenge_method=plain` with a fixed value. Token exchange with same value succeeds.
- Fix: server only accepts `S256` per OAuth 2.1.

### 3. Downgrade via metadata
Some servers honour client metadata declaring "no PKCE required" or "plain OK". Attacker who can register/modify a client (or compromise registration endpoint) downgrades.
- Fix: organization-level policy override; ignore client metadata that lowers security.

### 4. Verifier guessability
RFC requires 43–128 chars random. Some libs use weak RNG (`Math.random`, `time` seed). Predictable verifier → attacker brute-forces / predicts.
- Test: capture multiple verifiers from a client app; check for randomness.
- Fix: use CSPRNG, RFC-minimum 43 chars.

### 5. Verifier reuse
PKCE assumes one verifier per code. Some implementations cache verifier across multiple flows. Attacker reuses captured verifier on a fresh code.
- Test: complete a flow, capture verifier; start a new flow on same client, try the old verifier.
- Fix: bind verifier to a specific challenge in a single-use cache; invalidate on any code redemption attempt.

### 6. Confused deputy via shared verifier storage
Mobile app shares verifier storage across components (e.g., custom URL scheme, Intent extras). Another app or web view reads it.
- Fix: hardware-backed keystore for verifier; OS-level same-app isolation.

### 7. `code_challenge` not bound to redirect target
Some servers verify the challenge but not its binding to the redirect URL. Attacker initiates flow with their own `redirect_uri` and challenge, victim somehow ends up with the code, attacker redeems.
- Fix: server stores `(code, redirect_uri, code_challenge, client_id)` tuple atomically; all four must match on token exchange.

### 8. Authorization server caches challenge by code_id only
Same as above but at storage layer. Two flows with the same code prefix collide.

### 9. PKCE missing for confidential clients
Spec originally exempted confidential clients (server-side apps with client secret). OAuth 2.1 still recommends PKCE for them, but many servers don't enforce. If client secret leaks (env file in repo, CI logs), no PKCE = no second factor.
- Fix: PKCE required everywhere per OAuth 2.1.

### 10. Implementation bugs
- Server compares `code_verifier` instead of `SHA256(code_verifier)` to `code_challenge` (i.e., implements `plain` mode internally even when `S256` was requested).
- Base64url vs base64 confusion — padding bytes accepted, allowing similar verifiers to validate.
- Constant-time compare missing — timing-based discovery of verifier.

## Testing methodology

### Black-box / dynamic
1. Enumerate every client (web app, mobile app, SPA).
2. Capture an authorization request → check `code_challenge`/`code_challenge_method` presence and value.
3. Try removing challenge → does server proceed?
4. Try `plain` method → does server accept?
5. Try short or fixed-value verifier on token exchange.
6. Try reusing a verifier across flows.

### Source review
1. Find the authorization server's PKCE verifier comparison — must be constant-time, must check method, must reject `plain`.
2. Find the storage record format — must bind `(code, redirect_uri, code_challenge, client_id)`.
3. Find the challenge required-or-optional gate.

## References
- [RFC 7636 — PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [OAuth 2.1 draft](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1)
- [OAuth 2.0 Security BCP (RFC 9700)](https://datatracker.ietf.org/doc/html/rfc9700)
- [PortSwigger — OAuth attacks](https://portswigger.net/web-security/oauth)
- See also: [[oauth-flows]], [[oauth-authorization-code-injection]], [[auth-bypass-from-source-review]]

{% endraw %}
