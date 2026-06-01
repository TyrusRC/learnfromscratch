---
title: Session token analysis
slug: session-token-analysis
---

> **TL;DR:** Statistically (and structurally) test session tokens for predictability, decode meaningful fields, and look for weak crypto so you can forge or guess them.

## What it is
A session token is supposed to be unguessable, opaque, and bound to the server-side session state. In practice tokens often encode meaningful data (user id, timestamp, role), are generated from weak PRNGs, are HMAC'd with a guessable key, or are simply too short. Analysis is part black-box (collect, decode, test) and part bug-hunting around the lifecycle (rotation, invalidation, [[session-fixation]]).

## Preconditions / where it applies
- The token is visible to you (cookie, `Authorization` header, URL parameter, hidden field).
- You can request many tokens in quick succession — register accounts, log in repeatedly, or trigger anonymous sessions.
- You have an oracle to test forgeries — typically the login or session-validate endpoint.

## Technique
1. **Collect.** 500-20 000 tokens by scripting login or anonymous session creation. Keep timestamps of issuance.
2. **Decode.** Try base64/base64url, hex, URL-decoding, double-encoding. Many "opaque" tokens are JSON or protobuf inside base64 — see also [[jwt]]. Look for separators (`.`, `:`, `-`) that hint at concatenated fields.
3. **Structural read.** Pick out fields that increment, fields that follow timestamps, fields that look like an HMAC tail. Diff two tokens from accounts you control.
4. **Statistical testing.** Feed raw tokens to Burp Sequencer or NIST SP 800-22 / dieharder for randomness. Look for bit-level bias, period, low entropy. Tokens that pass a chi-square test still may be predictable if generated from a non-CSPRNG seeded by time.
5. **Predictable generators.** PHP `mt_rand` seeded by a known timestamp, Java `Random` used instead of `SecureRandom`, JavaScript `Math.random()`. Reverse the state from a few observed tokens (php_mt_seed, untwister).
6. **HMAC-tail forging.** If the token is `payload | HMAC(key, payload)` and you find the key (hard-coded, leaked via env, default), forge arbitrary payloads.
7. **Lifecycle bugs.** Token does not rotate on login (fixation), does not invalidate on logout, does not invalidate on password change, lives in `localStorage` (steal via [[cross-site-scripting]]). See [[remember-me-flaws]].

   ```bash
   # quick entropy probe — should be high for good tokens
   for i in $(seq 1 100); do
     curl -si https://target/login -d 'u=guest&p=guest' | grep -oP 'session=\K[^;]+'
   done | sort -u | wc -l
   ```

## Detection and defence
- Generate tokens from a CSPRNG (`/dev/urandom`, `crypto.randomBytes`, `SecureRandom`). At least 128 bits of entropy.
- Store session state server-side; the cookie is just an opaque pointer. If you must self-encode (stateless JWT), use a strong signing key, rotate it, and pin algorithms.
- Rotate on privilege transitions (login, role change). Invalidate on logout, password change, and 2FA enrolment.
- Detection: monitoring for high-cardinality cookie reuse, fixation attempts (one cookie value used by many user ids), low-entropy token alarms from Sequencer-style checks in CI.

## References
- [OWASP WSTG — Testing for Session Management](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/06-Session_Management_Testing/) — methodology.
- [OWASP — Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — defensive patterns.
- [PortSwigger — Burp Sequencer](https://portswigger.net/burp/documentation/desktop/tools/sequencer) — token randomness tooling.
