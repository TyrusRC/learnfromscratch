---
title: AitM phishing — Evilginx and modern reverse-proxy kits
slug: aitm-evilginx-modern-phishing
aliases: [adversary-in-the-middle, evilginx, evilproxy, reverse-proxy-phishing]
---

> **TL;DR:** Adversary-in-the-middle (AitM) phishing uses a reverse proxy between victim and the real authentication endpoint. The proxy relays login + MFA challenge + response, then captures the post-auth session cookie. Result: full MFA bypass on most flows except FIDO2/WebAuthn. Evilginx is the open-source baseline; Tycoon2FA, EvilProxy, Caffeine, NakedPages are commercial kits. Pattern is the dominant 2024–2025 phish kit family. Companion to [[phishing-infrastructure-design]] and [[oauth-device-code-phishing-m365]].

## Why AitM matters

- **Most MFA is bypassed** — TOTP, SMS, push, even number-matching push.
- **Session cookies are the trophy**, not the password — token validity often days to weeks.
- **Detection is hard** — login looks legitimate from the IdP's perspective (correct password, correct MFA, valid client).
- **Default-enabled MFA** is no longer sufficient guarantee against credential phishing.

## The mechanic

1. Victim clicks lookalike link (`outl00k-microsoft-online.com`).
2. DNS resolves to attacker's reverse proxy.
3. Proxy fetches the real Microsoft / Google / Okta login page and serves it to victim, with URL rewriting (replace `login.microsoftonline.com` references with proxy host).
4. Victim enters credentials → proxy forwards to real IdP → IdP returns MFA challenge.
5. Proxy displays MFA challenge to victim.
6. Victim completes MFA → proxy forwards to IdP → IdP issues session cookie.
7. Proxy captures cookie before redirecting victim to a benign page.
8. Attacker replays cookie from their own browser; they're logged in as the victim.

## Why FIDO2 / WebAuthn defeats AitM

FIDO2 binds the authenticator to the **origin** of the page presenting the challenge. The browser's `navigator.credentials.get()` reports the actual origin (`evilginx.com`, not `login.microsoftonline.com`). The authenticator computes the signature over the wrong origin; the IdP rejects it.

This is the **only widely-deployed authentication** AitM doesn't bypass. Push, TOTP, SMS, number-matching, voice — all rely on the user looking at a screen and approving; the screen lies during AitM.

## Tooling

### Open-source

- **Evilginx 3.x / Evilginx-NG** — Phishlet-based, supports Microsoft, Google, Okta, GitHub, dozens of others. Used by attackers and red teams.
- **Modlishka** — older project, similar capability.
- **Muraena** — Italian project, similar.

### Commercial (criminal market)

- **EvilProxy** — sold as a service.
- **Tycoon2FA** — 2024 high-volume kit targeting Microsoft 365.
- **Caffeine** — older but still active.
- **NakedPages** — newer.

These ship pre-configured phishlets for current IdP flows and update as IdPs change their login pages.

## Phishlet structure

An Evilginx phishlet describes:
- The **target domain** to proxy.
- Which **subdomains / paths** to handle.
- **Cookie names** to capture (e.g., `ESTSAUTHPERSISTENT`, `SimpleSAMLSessionID`).
- **JavaScript injection** to rewrite client-side links and forms.
- **Form fields** to log.
- **Redirect target** after capture.

Maintaining phishlets is the main operational cost; IdPs update their login pages quarterly.

## Detection signals

Defenders see:
- **Login from unusual ASN / geo** for the user.
- **Session cookie reuse across IPs** — captured cookie used from attacker IP while victim still uses their normal one.
- **Token age > expected** — attacker may keep using a cookie long after the victim ends their session.
- **User-agent / TLS fingerprint** differs between victim's normal traffic and replayed cookie traffic.
- **Conditional Access risk events** — for Entra ID, Microsoft's Identity Protection flags this class as risky.
- **Token theft alerts** — Microsoft Defender for Cloud Apps now flags some AitM patterns.

The defender's most reliable signal is **session cookie use from new IP combined with no MFA event recently** — the cookie was captured from a different login.

## Defensive baseline

For users:
- **Use FIDO2 / passkeys** wherever possible.
- **Verify URL** before entering credentials. Punycode and lookalike domains catch the unwary.
- **Bookmark** important login pages and use the bookmark, not links from emails.

For organisations:
- **Enforce FIDO2 / passkeys** for high-risk roles (administrators, finance, IT).
- **Conditional Access** policies: require compliant device, restrict by IP, require Phish-resistant authentication strength.
- **Token protection / Continuous Access Evaluation** (CAE) — invalidate sessions when device or risk changes.
- **Domain anti-abuse**: register typo variants of your own domain, monitor for new lookalikes.
- **Email security**: DMARC enforce, SPF + DKIM strict.
- **User training**: focus on URL inspection and "we don't ask for MFA in email" messaging.

## Red team usage and ethics

AitM is a powerful capability that must be used within scope:
- Always within an authorised engagement.
- Coordinate with the client's IT / security team.
- Plan for token revocation post-engagement.
- Limit blast radius — don't capture cookies you don't need.

## Workflow to study in a lab

1. Set up Evilginx in a lab VM.
2. Configure a phishlet for a test Microsoft 365 / Google Workspace test tenant.
3. Stand up a test victim account; complete the AitM flow.
4. Observe captured cookies and the IdP's auditing of the login.
5. Practice the defender's view — Entra sign-in logs, Defender for Cloud Apps alerts.
6. Then enable FIDO2 for the test account and observe the attack failing.

## Related

- [[oauth-device-code-phishing-m365]] — alternative phishing path.
- [[conditional-access-bypass-modern]] — what attackers do post-cookie.
- [[mfa-fatigue-tradecraft]] — different MFA-defeating class.
- [[tycoon2fa-and-modern-phish-kits]] — kit landscape.
- [[phishing-infrastructure-design]] — infrastructure side.

## References
- [Evilginx project](https://github.com/kgretzky/evilginx2)
- [Microsoft — AitM attacks blog](https://www.microsoft.com/en-us/security/blog/2022/07/12/from-cookie-theft-to-bec-attackers-use-aitm-phishing-sites/)
- [Mandiant — AitM threat actor patterns](https://cloud.google.com/blog/topics/threat-intelligence)
- [TrustedSec — AitM operational notes](https://www.trustedsec.com/blog)
- See also: [[phishing-infrastructure-design]], [[oauth-device-code-phishing-m365]], [[conditional-access-bypass-modern]], [[passkey-mobile-ble-phish]], [[browser-in-the-browser-phish]], [[tycoon2fa-and-modern-phish-kits]]
