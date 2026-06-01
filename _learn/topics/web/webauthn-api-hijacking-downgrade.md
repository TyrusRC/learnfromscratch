---
title: WebAuthn API hijacking + passkey downgrade
slug: webauthn-api-hijacking-downgrade
---

> **TL;DR:** Browser-extension or XSS hijack of navigator.credentials.* plus UA-spoofed AiTM forces a passkey login to fall back to OTP/SMS.

## What it is
Passkeys (WebAuthn / FIDO2) bind a credential to (RP id, origin, authenticator). They are phishing-resistant *because the browser enforces the origin check*. Two attack avenues remain: hijack the API surface inside the page (extension or DOM XSS overriding `navigator.credentials.get`), or trigger the RP's **fallback authenticator** (TOTP/SMS/email) by faking client conditions so the user is steered off passkeys and into a phishable factor that an adversary-in-the-middle proxy can capture.

## Preconditions / where it applies
- RP supports passkeys but also retains a phishable fallback (OTP, SMS, email magic link)
- Either: a malicious browser extension with host permissions on the RP, a stored/reflected DOM XSS, or an AiTM proxy
- Client UA / capability signal influences which factor the RP presents

## Technique
1. **API hijack via extension or XSS** — override `navigator.credentials.get` / `.create` before the page calls them:
   ```js
   const orig = navigator.credentials.get.bind(navigator.credentials);
   navigator.credentials.get = async (opts) => {
     // forward to attacker server which calls a legitimate WebAuthn endpoint
     // OR cancel and force fallback by throwing NotAllowedError
     throw new DOMException('cancelled','NotAllowedError');
   };
   ```
   Throwing `NotAllowedError` makes the page believe the authenticator declined — most RPs render "Use a different method", revealing OTP/SMS.
2. **Conditional UI manipulation** — block `PublicKeyCredential.isConditionalMediationAvailable()` to return false; the autofill passkey prompt never shows.
3. **AiTM with UA spoof** — Evilginx-style proxy forwards traffic but rewrites UA / client hints to a browser without WebAuthn support, so the RP serves the OTP screen; capture OTP and replay.
4. **`isUserVerifyingPlatformAuthenticatorAvailable` lie** — set it to false in the proxied page; RP downgrades to roaming auth methods or password+OTP.
5. **Origin spoof not possible (browser enforces)** — but if RP exposes `/passkey/register` to authenticated session without re-auth, attacker uses ambient session ([[csrf]] / hijacked tab) to enrol attacker's passkey on victim's account → silent persistent ATO.
6. **Cross-device sync abuse** — passkey synced to attacker-controlled Apple ID / Google Account if cloud account compromised; lateral move from cloud takeover to per-RP takeover.
7. **Recovery-flow downgrade** — "Lost your passkey?" path issues SMS reset; capture via SIM swap or AiTM. See [[account-recovery-attacks]].

## Detection and defence
- Remove phishable fallbacks for high-value accounts; "passkey only" mode after enrolment.
- Require step-up (existing passkey ceremony) to add a new passkey; never allow add-passkey on a session not freshly authenticated by an existing passkey.
- Server-side: log `clientExtensionResults`, RP id, attestation, authenticator AAGUID; alert on new AAGUIDs.
- Detect `NotAllowedError` spikes per user / per session.
- Use Trusted Types / strict CSP to reduce XSS surface that could override `navigator.credentials`. See [[trusted-types-bypass]] for limits.
- Restrict extension host permissions on critical RPs; enterprise-managed extension allowlists.
- Related: [[2fa-bypass]], [[account-recovery-attacks]], [[mv3-extension-bypass]], [[sso-attacks]].

## References
- [SquareX Labs — passkeys pwned](https://labs.sqrx.com/passkeys-pwned-turning-webauth-against-itself-0dbddb7ade1a) — API-hijack + downgrade research
- [W3C — WebAuthn L3](https://www.w3.org/TR/webauthn-3/) — spec and ceremony details
- [Yubico — phishing-resistant fallback guidance](https://developers.yubico.com/WebAuthn/) — RP hardening
