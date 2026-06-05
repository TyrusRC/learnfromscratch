---
title: Tycoon2FA and the modern phish-kit landscape
slug: tycoon2fa-and-modern-phish-kits
aliases: [phish-kit-landscape, tycoon2fa, evilproxy-as-a-service]
---

> **TL;DR:** Modern phishing-as-a-service (PhaaS) kits — Tycoon2FA (high-volume 2024–2025 against Microsoft 365), EvilProxy, Caffeine, NakedPages, ONNX Store, Sneaky 2FA, Strox — package AitM reverse-proxy infrastructure, captcha bypass, geo-IP filtering, and bot-detection evasion as turnkey services. Knowing the landscape helps you correlate detections to the kit and predict TTP evolution. Companion to [[aitm-evilginx-modern-phishing]] and [[phishing-infrastructure-design]].

## Why a kit landscape matters to defenders

- Attribution at "kit" level is easier than at "actor" level — many actors use the same kit.
- Defender detections become **kit-specific** — block the kit's URL patterns, JavaScript signatures, captcha challenges.
- Kits update on a predictable cadence — knowing a kit got a new release tells you to refresh detections.
- Kit operators are sometimes traceable through their advertising channels (Telegram, dark-web markets).

## Tycoon2FA

- Surfaced publicly in 2023; dominated 2024 telemetry.
- Targets primarily Microsoft 365.
- Operates as a hosted service — operator pays per-target.
- Notable features:
  - Cloudflare-fronted infrastructure for resilience.
  - Captcha bypass for automated targets (rotates between hCaptcha, reCAPTCHA, Cloudflare Turnstile).
  - Geo-IP and ASN filtering to evade security researchers (won't serve phishing to scanners or VPN IPs).
  - JavaScript anti-debugging.
  - Updated phishlets after Microsoft login UI changes.
- Phishlets supported: Microsoft 365, Outlook on the web, Adobe, DocuSign, Yahoo, AOL.

Sekoia, Proofpoint, and Trustwave have published detailed analyses.

## EvilProxy

- Sold openly on dark-web markets since 2022.
- Built on customised Evilginx.
- Targets Google Workspace, Microsoft 365, Apple, Facebook, GitHub.
- Pricing tiered by target service.
- Known for **fingerprinting and lying** — different content served to security researcher IPs vs end-user IPs.

Resecurity wrote the original disclosure.

## Sneaky 2FA / ONNX Store

- 2024-disclosed kits.
- Sneaky 2FA: distinct from Tycoon, sold to a different operator group.
- ONNX Store: targets corporate accounts; sold via Telegram.
- Use blob:// URLs and HTML attachments to evade email filters.

## Caffeine

- 2022-discovered PhaaS by Mandiant.
- Self-service signup model (unlike most kits which require vetting).
- Phished M365 credentials at scale.

## NakedPages

- 2023-disclosed.
- Targets primarily Microsoft 365 + Cloudflare-fronted.

## Strox

- 2024.
- Distinct command-and-control infrastructure.

## Common kit characteristics

- **AitM core** — see [[aitm-evilginx-modern-phishing]].
- **Captcha relay** — proxies the IdP's captcha so the user sees a legitimate-looking challenge.
- **MFA prompt forwarding** — push, number-matching, TOTP.
- **Cookie capture** — primary trophy; exfil to operator panel.
- **Multi-target phishlets** — one infrastructure serves several brand templates.
- **Cloudflare / CloudFront fronting** — content-delivery for performance + obfuscation.
- **Telegram bot panel** — operator interface.
- **Subscription pricing** — typically $200–$1000 / month.

## Detecting kit traffic

Some signals are kit-specific; many are class-shared.

**Network signals:**
- Newly registered domain on Cloudflare with content proxying `login.microsoftonline.com`-shaped HTML.
- TLS fingerprint (JA3 / JA4) matching kit infrastructure.
- HTTP header sequence atypical for legitimate Microsoft endpoints.

**Content signals:**
- JavaScript with known kit-specific anti-debug strings.
- HTML structure with kit-specific class names or comments.
- Inline scripts that POST to non-Microsoft endpoints.

**User-side signals:**
- URL is not `login.microsoftonline.com` or a documented internal AD FS endpoint.
- Browser warning (rare; kits use valid certs).

## Defensive playbook

1. **Phish-resistant MFA** — FIDO2 / passkeys defeat every kit listed.
2. **Email + URL filtering** — Microsoft Defender, Proofpoint, Mimecast, etc. updated for kit URL patterns.
3. **DNS filtering** — Quad9 / Cloudflare Gateway / Cisco Umbrella block known-kit infrastructure.
4. **Block newly-registered domains** at email gateway for first 30 days.
5. **Conditional Access** — see [[conditional-access-bypass-modern]].
6. **Defender for Cloud Apps** — token theft alerts.
7. **Continuous Access Evaluation** — invalidate captured tokens on risk events.
8. **Internal phishing simulation** to train users.

## Threat-intel sources for tracking kits

- **Sekoia.io blog** — Tycoon2FA tracking.
- **Trustwave SpiderLabs blog**.
- **Microsoft Security blog** — frequent AitM kit posts.
- **Mandiant blog**.
- **Proofpoint** — operational telemetry-driven reports.
- **Group-IB** — kit attribution.
- **PhishTank**, **OpenPhish** — URL feeds.
- **DNSTwist** alerts on lookalike registrations.

## Operational notes for red teams

If contracted to test AitM susceptibility:
- Build infrastructure to match a known kit profile (so detections you tune actually catch the analogous adversary).
- Don't reuse a kit's panel — operate your own.
- Limit exfil — proof-of-concept token capture, immediately revoke.

## Workflow to study (defender lab)

1. Collect URL samples from PhishTank for the past 30 days.
2. Categorise by phishing-kit signature (Tycoon, EvilProxy, etc.).
3. For each kit, fingerprint network and content patterns.
4. Author detection rules (Suricata / Zeek + email gateway).
5. Test rules against a benign clone of the kit in lab.

## Related

- [[aitm-evilginx-modern-phishing]] — underlying technique.
- [[phishing-infrastructure-design]] — your own infrastructure.
- [[mfa-fatigue-tradecraft]] — alternative MFA-defeat.
- [[oauth-device-code-phishing-m365]] — non-kit alternative.
- [[domain-fronting-and-cdn-abuse]] — Cloudflare-fronting technique.

## References
- [Sekoia.io — Tycoon2FA technical analysis](https://blog.sekoia.io/)
- [Resecurity — EvilProxy disclosure](https://www.resecurity.com/blog/article/evilproxy-phishing-as-a-service-with-mfa-bypass)
- [Mandiant — Caffeine PhaaS](https://cloud.google.com/blog/topics/threat-intelligence)
- [Microsoft Security blog — AitM kits](https://www.microsoft.com/en-us/security/blog/)
- See also: [[aitm-evilginx-modern-phishing]], [[phishing-infrastructure-design]], [[mfa-fatigue-tradecraft]], [[conditional-access-bypass-modern]]
