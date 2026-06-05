---
title: Phishing infrastructure design
slug: phishing-infrastructure-design
aliases: [phishing-infra, phishing-infrastructure]
---

{% raw %}

> **TL;DR:** A defensible phishing infrastructure has separated domains and IPs (recon, sending, landing, C2), warmed-up sender reputation with SPF/DKIM/DMARC properly aligned, and CDN-fronted callback URLs that don't burn the rest of the chain. The goal isn't to send "good emails"; it's to send emails that *survive* mail-gateway filtering and that, when reported, don't take down your other operations. Companion to [[pretext-design-for-engagements]] and [[c2-protocol-design]].

## Why the separation matters

A single domain doing everything (recon, sending, landing, beacon) burns instantly. The minute one target reports the phish, that domain is in every mail-gateway and EDR feed within hours. Separated tiers limit blast radius.

```
Tier 1 — Recon          recon.example.tld          (Google dorks, DNS lookups)
Tier 2 — Pretext infra  status-update.example.tld  (delivery)
Tier 3 — Landing/cred   accounts-portal.example    (credential harvest pages)
Tier 4 — Implant C2     api.cdn-front-name.tld     (beacons; CDN-fronted)
```

Each tier has independent domains, ASNs, and ideally accounts. When tier 2 burns, tiers 1/3/4 continue.

## Domain selection

For a high-trust pretext, age and reputation matter.

- **Newly-registered** (< 30 days) — automatic suspicion from many filters.
- **Aged** (≥ 6 months, ideally > 1 year, with passive DNS history of legitimate use) — best signal.
- **Expired domain re-registration** — buy a lapsed domain previously used by a small business; carries some residual reputation.

Patterns:
- **Typo-squat** — `mlcrosoft-support.com`. Easy to register, easy to detect.
- **Homoglyph** — `microsоft.com` (Cyrillic 'о'). High filter detection now.
- **Semantic** — `m365-accounts-help.com`. Plausible-looking, low semantic-suspicion. Best for high-value targets.

DNS records:
- A records pointing at your IP (or CDN edge).
- MX record so the domain can receive bounces (helps reputation).
- SPF + DKIM + DMARC — *must* be aligned, not just present.

## SPF, DKIM, DMARC

These three together determine "is this email allowed to claim it's from this domain?"

```
example.tld.  IN TXT  "v=spf1 ip4:1.2.3.4 -all"        ; only this IP may send
selector._domainkey.example.tld.  IN TXT  "v=DKIM1; k=rsa; p=...public key..."
_dmarc.example.tld.  IN TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.tld"
```

Mail-gateway scoring:
- SPF pass + DKIM pass + DMARC pass = strong "this domain owns this mail".
- Any fail → spam-folder or rejection in well-tuned gateways.

For your phishing domain, set up clean SPF/DKIM/DMARC on the sending domain. If you're impersonating a real brand (with permission, on a contracted engagement), you cannot fix SPF for *their* domain — but you can pick a lookalike for which you control DNS.

## Sender reputation warmup

A brand-new IP/domain that bursts a phishing campaign on day one gets filtered. Warm slowly:

1. Week 1: 5 emails/day from the domain to friendly inboxes (your team, GMail, Outlook).
2. Week 2: 20/day; add Microsoft 365 SCL feedback if you can.
3. Week 3: 100/day with two-way conversations (replies from the friendly inboxes).
4. Week 4+: campaign-scale.

The activity needs to look organic — diverse subjects, replies, normal "engagement" patterns. This is the slow part of phishing operations.

## Sending infrastructure

- Self-hosted Postfix on a VPS — full control, but the VPS provider's reputation is on you.
- SendGrid / Mailgun / Mailjet — turnkey deliverability, but their abuse desk acts fast on phishing reports.
- AWS SES / Google Workspace — strong reputation, very strict abuse policies.

For sanctioned engagements: pick a provider whose ToS *permits* security testing (some do, with paperwork). Don't lie to abuse desks; you'll burn the account.

## Landing pages

The credential-harvest page is the highest-value artefact of the campaign.

- Use a CDN (Cloudflare, Cloudfront) for the landing page so the egress IP is shared and the page can scale.
- Path-randomise the landing URL: `https://accounts-portal.example/r/4f2a-1b3c` — per-target.
- Per-target unique URL → tracking + attribution.
- HTTPS via Let's Encrypt or the CDN's automated TLS.
- Don't render to non-targets — if a researcher visits, serve a 404 or a benign page. Track by User-Agent, IP, time window.

## Tracking and OPSEC

- Per-recipient unique URL.
- Pixel beacons in the email (renders confirm delivery).
- Click counter via JS for the landing page.
- All metadata stored on a *separate* tier from the C2.
- No personal accounts, no personal credit cards, no personal IPs touching any tier. Burner everything.

## Reporting your activity (engagement letter)

For sanctioned pentests:
- Engagement letter lists the targeted domain(s) and the time window.
- A separate channel notifies the customer's IR team when you start sending.
- An "abuse" inbox forwards reports from outside parties to you, not the customer.
- Daily debrief with the customer's lead.

Reading the engagement letter carefully and confirming scope is the difference between "they paid you" and "they call the police".

## Tools

- **GoPhish** — open-source phishing framework with tracking.
- **King Phisher** — older, still useful, scriptable.
- **EvilGinx2** — modern reverse-proxy for MFA-phishing (intercepts session cookies in real time).
- **Modlishka** — similar to EvilGinx, alternative implementation.
- **Mailoney** — when you need a believable sending stack on day one.

## Detection (so you know what defenders see)

- SPF/DKIM/DMARC alignment.
- Domain age via WHOIS / passive DNS (PassiveTotal, RiskIQ).
- TLS cert transparency logs — `crt.sh` for `*.your-pretext-domain`.
- Email content scanning (links to known-bad TLDs, HTML obfuscation patterns).
- User reporting → SOC analyses → blocks domain.
- Sandbox detonation of links — bounce off "user-agent or IP we recognise" to avoid burning landing pages.

## OSEP relevance

OSEP's "client-side code execution" modules assume you can land a payload on a target's workstation via email. The exam's lab gives you a target email; you provide the chain. Infra design isn't graded explicitly — but the more you understand how mail filters score, the better your delivery looks.

## References
- [SpecterOps — Pretext infrastructure design](https://posts.specterops.io/)
- [Microsoft — DMARC, DKIM, SPF documentation](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/email-authentication-about?view=o365-worldwide)
- [GoPhish documentation](https://docs.getgophish.com/)
- [EvilGinx2](https://github.com/kgretzky/evilginx2)
- See also: [[pretext-design-for-engagements]], [[client-side-attacks-primer]], [[office-vba-macros-initial-access]], [[domain-fronting-and-cdn-abuse]], [[infrastructure-design]]

{% endraw %}
