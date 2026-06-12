---
title: Browser-in-the-Browser (BitB) phishing
slug: browser-in-the-browser-phish
---

> **TL;DR:** Render a pixel-perfect fake OAuth popup INSIDE the attacker's phishing page — complete with fake address bar, lock icon, and TLD. Victim sees `accounts.google.com` but it's a `<div>` on `attacker.tld`. Bypasses URL inspection for users trained to "check the address bar."

## What it is
BitB was published by `mr.d0x` in March 2022 and folded into Evilginx, Modlishka, Muraena phishlets shortly after. The technique builds a faithful HTML/CSS replica of the OS-native browser window — Chrome on macOS, Edge on Windows, Safari on iOS — and overlays it on the phishing page. The "popup" cannot be dragged outside the parent window (it's a `position:absolute` div), but most users don't try.

## Preconditions / where it applies
- Phishing landing page where the victim is expected to click "Sign in with Google/Microsoft/Apple"
- Victim browser/OS combo matches one of the included templates (Chrome/Edge/Safari, Win/Mac/Linux/iOS)
- Target SSO uses popup-style consent (the legitimate flow IS a popup in many configurations)

## Tradecraft

**Templates available from the original repo:**

```bash
git clone https://github.com/mrd0x/BITB
ls BITB/
# chrome-mac-dark/  chrome-mac-light/  chrome-windows-dark/  chrome-windows-light/
# Each contains index.html with the OS-themed chrome (titlebar, address bar, body iframe)
```

**Integration with Evilginx:**

```yaml
# phishlet sub_filters add a script that triggers the BitB modal
sub_filters:
  - {triggers_on: 'accounts.google.com',
     orig_sub: 'accounts.google.com',
     domain: 'accounts.google.com',
     search: '<head>',
     replace: '<head><script src="/bitb.js"></script>',
     mimes: ['text/html']}
```

**Modern variant — Iframe-in-the-iframe:** the fake popup contains a real iframe to the attacker's reverse proxy (Evilginx) so the actual auth flow happens inside the cosmetic browser frame. Credentials + session cookie are captured by the proxy; the victim sees correct redirect chain inside the fake popup.

**Detecting victims:**

```javascript
// Server-side: only fire BitB if the user-agent matches templates you have
if (/Chrome.*Mac OS X/.test(navigator.userAgent)) showBitB('chrome-mac-light');
else if (/Edg.*Windows/.test(navigator.userAgent)) showBitB('edge-windows');
else fallback();
```

**FIDO2 / passkey bypass:** BitB does NOT bypass WebAuthn — the origin check still applies. If the target enforces FIDO2 with `accounts.google.com` as the relying party, BitB fails. BitB is effective against TOTP / push / SMS MFA but not against phish-resistant.

**Tycoon2FA / EvilProxy as a service** ship BitB templates pre-configured; see [[tycoon2fa-and-modern-phish-kits]].

## Detection and defence
- WebAuthn / FIDO2 / Passkey for all SSO — closes the BitB path entirely
- Conditional Access "Authentication Strength = Phishing-resistant" — see [[conditional-access-bypass-modern]]
- User awareness: "real OAuth popups can be DRAGGED outside the browser window — fake ones cannot"
- Email gateway: block newly registered domains hosting Microsoft / Google branding (lookalike detection — see [[bimi-and-mail-authenticity-ux]])
- Browser extensions like uBlock + Brave Shields can break BitB CSS rendering, but enterprise-managed extensions are inconsistent
- Look for outbound DNS to lookalike domains right before authentication anomalies in M365 sign-in logs

## OPSEC pitfalls
- Address-bar text in BitB is hardcoded into the HTML — if the operator forgets to swap the example URL, victims see `https://accounts.google.com/signin/oauth/...` even though they're on `attacker.tld` — but inspector still shows `attacker.tld` in the real bar
- Hovering the fake "back/forward/refresh" buttons exposes no tooltip; legitimate browser chrome shows native tooltips
- BitB doesn't survive browser zoom — pixel ratios shift, alignment breaks
- Right-click → "View page source" reveals the trick; some users do this

## References
- [mr.d0x — Browser In The Browser (BITB) Attack](https://mrd0x.com/browser-in-the-browser-phishing-attack/) — original publication
- [BitB templates](https://github.com/mrd0x/BITB)
- [Microsoft — Phish-resistant MFA](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths)
- [Evilginx3](https://github.com/kgretzky/evilginx2) — reverse proxy that pairs with BitB

See also: [[aitm-evilginx-modern-phishing]], [[tycoon2fa-and-modern-phish-kits]], [[oauth-device-code-phishing-m365]], [[conditional-access-bypass-modern]], [[passkey-mobile-ble-phish]], [[mfa-fatigue-tradecraft]], [[phishing-infrastructure-design]]
