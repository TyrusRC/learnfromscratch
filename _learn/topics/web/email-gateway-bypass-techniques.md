---
title: Email gateway bypass techniques
slug: email-gateway-bypass-techniques
aliases: [email-bypass, email-filter-bypass]
---

> **TL;DR:** Modern secure email gateways (SEGs) catch the lazy 80% — generic phishing kits, known-bad senders, plain `.exe` attachments, freshly-registered domains. The remaining 20% is where red teams live: HTML/MIME parsing differences, container attachment formats (ISO/IMG/LNK/VHD), URL fronting through trusted SaaS, calendar and Teams side-channels, and AitM-friendly delivery that survives one-time clicks. This note collects the working techniques and pairs them with [[aitm-evilginx-modern-phishing]], [[tycoon2fa-and-modern-phish-kits]] and [[dmarc-spf-dkim-deep]].

## Why it matters

Phishing is still the #1 initial-access vector in nearly every incident report (Verizon DBIR, M-Trends, NCSC annual). Defenders have pushed hard on the email layer: Microsoft Defender for Office 365, Google Workspace security sandbox, Proofpoint TAP, Mimecast, Abnormal, Cisco IronPort. Yet payload-bearing emails still land — and red teams need a working mental model of why, not just a list of tricks that get patched within a quarter.

Understanding gateway bypass is also defensive work: the same logic feeds [[detection-engineering-pyramid-of-pain]], [[siem-detection-use-case-catalog]] entries for mail flow, and the purple-loop in [[purple-team-feedback-loop]]. Real-world relevance: Tycoon 2FA campaigns (see [[tycoon2fa-and-modern-phish-kits]]) used Cloudflare Turnstile and Cloudflare Workers to gate phishing pages from sandbox crawlers — a textbook URL-fronting bypass.

## Classes of bypass

### 1. HTML and MIME parsing tricks

SEGs render or statically analyse HTML to find phishing indicators (brand keywords, login forms, suspicious URLs). The parser is rarely a real browser, so divergence is exploitable.

- Conditional comments (`<!--[if mso]>`) to hide content from Outlook scanners but show it on render.
- CSS `display:none` blocks loaded with the real phishing link, while the visible-to-scanner text looks benign.
- MIME multipart with `text/plain` carrying clean content and `text/html` carrying the lure — some sandboxes only score the plain part.
- Unicode confusables in display names (`Microsoft` with Cyrillic `о`), homoglyph domains.
- `data:` URIs and base64-encoded HTML attachments (`.htm`, `.shtml`) that the SEG opens out-of-context.

### 2. Attachment-format selection

Macro-enabled Office files are dead for most tenants (Microsoft's Mark-of-the-Web enforcement, blocked-by-default macros). Red-team attachment selection in 2024–2026 is dominated by container formats that strip MOTW or smuggle execution.

- **ISO / IMG / VHD / VHDX** — mounting as a virtual disk historically stripped MOTW from inner files; Microsoft patched this for ISO in late-2022 but mileage varies across patched estates, and VHD remained inconsistent.
- **LNK files** inside ZIPs — small, abused heavily by Qakbot/Pikabot lineage. Arguments hidden in the LNK metadata, executing `mshta`, `rundll32`, or `wmic`.
- **OneNote (.one)** — embedded attachments with social-engineering overlays.
- **HTML smuggling** — attached `.html` decodes a Blob in-browser and offers it as a download (avoids the SEG ever seeing the binary).
- **SVG with embedded JS / foreignObject** — recent campaigns (late-2024 onwards) used SVG as a lightweight HTML smuggler.
- **Password-protected archives** — password in the body, contents unscannable. Detection tradeoff: easy to flag the pattern, but legitimate use exists.

### 3. URL fronting and reputation laundering

A naked attacker-controlled domain dies on reputation. The fix is to host the lure or the next hop behind something the SEG trusts.

- **Cloudflare Workers / Pages / R2** subdomains, Vercel, Netlify, Render, fly.dev, AWS Amplify, Azure Static Web Apps — see [[domain-fronting-and-cdn-abuse]], [[cloudflare-workers-audit]], [[vercel-edge-and-middleware-audit]].
- **Open redirects** on trusted brands (Google AMP, YouTube `/redirect`, LinkedIn `/slink`, Microsoft `aka.ms`, Baidu, news sites).
- **SaaS-hosted lures** — Adobe Document Cloud, Dropbox Transfer, Box, OneDrive, Google Drive sharing, Notion public pages, Canva, Zoho, SharePoint anonymous links.
- **Link shorteners and tracking redirectors** — bit.ly, t.co, mailchimp tracking, Constant Contact, Salesforce Marketing Cloud (`mkt.com`), Pardot.
- **Cloudflare Turnstile / Google reCAPTCHA** in front of the phishing page — sandboxes do not solve them, real users do.

### 4. Sender and infrastructure choices

- **Compromised legitimate tenant** — a small business M365 tenant with clean reputation, valid SPF/DKIM/DMARC ([[dmarc-spf-dkim-deep]]). Survives everything except behavioural anomaly detection.
- **Bring-your-own warmed domain** — registered weeks/months in advance, slowly warmed with benign traffic, configured with strict DMARC. Costs time but bypasses age-of-domain heuristics.
- **Lookalike domains** with valid DKIM — typosquats (`micros0ft-support.com`), parked-then-activated.
- **Abused ESPs** — SendGrid, Mailgun, Amazon SES, Mailchimp subaccounts. Defenders rarely block the ESP outright; the ESP's reputation carries you.
- **Reply-thread hijacking** — popular with Qakbot/Emotet lineage: insert into an existing thread from a compromised mailbox so DMARC aligns and recipients trust the context.

### 5. M365 vs Google differences

The two platforms behave very differently and the same lure scores differently on each.

- **M365 (EOP / Defender)** — heavy weight on SafeLinks rewriting, SafeAttachments detonation, Mark-of-the-Web propagation. Defender for O365 sandbox is more aggressive at clicking links, which means time-bombed payloads and Turnstile gating hurt it more. Internal-to-internal mail often skips full inspection (abused by [[m365-admin-attacks]] and [[entra-cross-tenant-sync-abuse]]).
- **Google Workspace** — strong ML classifier on body content, aggressive on attachment hashes via VirusTotal lineage, but historically weaker on novel HTML smuggling. SafeBrowsing on click. Calendar invites land directly in calendar by default (huge social-engineering surface).

### 6. AitM-friendly delivery

Modern phishing increasingly uses adversary-in-the-middle proxies (Evilginx, Tycoon 2FA, Mamba 2FA). Delivery requirements differ:

- The lure URL needs to survive SafeLinks rewriting (some kits detect rewrite and serve a clean page instead).
- The proxy needs to evade sandbox visits — Turnstile, geolocation/ASN filtering, mouse-movement checks, user-agent and TLS-fingerprint allowlists.
- See [[aitm-evilginx-modern-phishing]] for proxy mechanics, [[tycoon2fa-and-modern-phish-kits]] for the kit ecosystem, [[oauth-device-code-phishing-m365]] for the non-AitM alternative.

### 7. Calendar and Teams vectors

- **Calendar invites** — Google Calendar adds events by default for `mailto:` invites; defenders have rolled this back via admin settings but many tenants still auto-add. The invite carries a link in the description, often whitelisted.
- **Microsoft Teams external messages** — abused by Midnight Blizzard (APT29) in 2023–2024 to bypass email entirely. See [[apt-tradecraft-russian-svr-fsb]]. Defaults tightened in 2024 but federated-by-default tenants remain.
- **Shared SharePoint / OneDrive links** — anonymous-link sharing arrives via Microsoft's own infrastructure with perfect DMARC.
- **Distribution list and group abuse** — joining a public Google Group or Teams team to inject messages.

## Defensive baseline

If you are on the blue side, the inverse of every section above is your detection backlog. Concretely:

- Enforce strict DMARC (`p=reject`) and monitor aggregate reports — see [[dmarc-spf-dkim-deep]].
- Block container attachments (ISO, IMG, VHD, VHDX, ONE) at the gateway unless business-justified.
- Strip or sandbox HTML attachments; alert on `.svg` with `<script>` or `<foreignObject>`.
- Disable Office macros from the internet (Microsoft does this by default since 2022 — verify your tenant did not re-enable).
- SafeLinks with "do not allow click-through" for unknown URLs; click-time scanning for SaaS-hosted shares.
- Restrict M365 external Teams chat to allowlist; disable anonymous SharePoint links by default.
- Disable Google Calendar auto-accept from external senders; lock down Google Groups external posting.
- Behavioural detection on first-time-sender + reply-with-link patterns; reply-thread anomaly detection (sudden URL after months of plain text).
- Feed phish reports into a sandbox pipeline and route into [[detection-engineering-pyramid-of-pain]] / [[siem-detection-use-case-catalog]].

## Workflow to study

1. Stand up a lab tenant on M365 E5 trial and a Google Workspace Business Plus trial — see [[building-a-research-home-lab]].
2. Register a clean warmed-style domain, configure SPF/DKIM/DMARC properly, validate with `dmarcian` or `mxtoolbox`.
3. Send increasingly aggressive lures to lab inboxes on both platforms and record what reaches inbox vs junk vs quarantine. Build a matrix.
4. Layer the HTML/attachment tricks above one at a time — change one variable per send so you can attribute the score change.
5. Wire an Evilginx instance behind Cloudflare with Turnstile and observe how each sandbox behaves (browser fingerprint, IP, retry pattern).
6. Read disclosed campaigns (Mandiant, Microsoft Threat Intelligence, Volexity, Proofpoint write-ups) and recreate the delivery layer only — see [[reading-public-pocs-effectively]] and [[h1-disclosed-report-reading-method]].
7. Document findings as both an offensive playbook and a defensive backlog — feed both sides via [[purple-team-feedback-loop]].

## Related

- [[aitm-evilginx-modern-phishing]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[dmarc-spf-dkim-deep]]
- [[oauth-device-code-phishing-m365]]
- [[mfa-fatigue-tradecraft]]
- [[m365-admin-attacks]]
- [[entra-cross-tenant-sync-abuse]]
- [[conditional-access-bypass-modern]]
- [[domain-fronting-and-cdn-abuse]]
- [[cloudflare-workers-audit]]
- [[vercel-edge-and-middleware-audit]]
- [[smtp-injection]]
- [[smtp-enum]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[detection-engineering-pyramid-of-pain]]
- [[purple-team-feedback-loop]]

## References

- Microsoft Threat Intelligence — Storm-1811 and Midnight Blizzard Teams phishing: https://www.microsoft.com/en-us/security/blog/2024/05/15/threat-actors-misusing-quick-assist-in-social-engineering-attacks-leading-to-ransomware/
- Mandiant M-Trends 2024 — initial access trends: https://www.mandiant.com/m-trends
- Proofpoint — Pikabot and LNK smuggling: https://www.proofpoint.com/us/blog/threat-insight
- Microsoft — blocked macros and Mark-of-the-Web for ISO: https://techcommunity.microsoft.com/t5/microsoft-defender-for-office/bg-p/MicrosoftDefenderforOfficeBlog
- NCSC UK — phishing guidance for organisations: https://www.ncsc.gov.uk/guidance/phishing
- Verizon DBIR 2024 social-engineering chapter: https://www.verizon.com/business/resources/reports/dbir/
