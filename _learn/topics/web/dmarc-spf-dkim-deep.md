---
title: DMARC / SPF / DKIM — practitioner deep dive
slug: dmarc-spf-dkim-deep
aliases: [email-authentication-deep, dmarc-deep]
---

> **TL;DR:** SPF, DKIM and DMARC are three independent mechanisms that together let receivers decide whether to trust the `From:` header on an inbound email. SPF authorises sending IPs, DKIM signs headers and body with a public key in DNS, and DMARC ties them to the visible `From:` domain via alignment plus a published policy (`p=none|quarantine|reject`). Misconfiguration is rampant — too-many-lookups in SPF, neglected DKIM rotation, and `p=none` left forever — and forwarders quietly break SPF/DKIM, which is why [[arc-and-mail-forwarding]] exists. This note is the practitioner companion to [[arc-and-mail-forwarding]] and [[email-gateway-bypass-techniques]].

## Why it matters

Email remains the primary phishing vector tracked across [[case-study-h1-top-disclosed-2024-2025]], [[apt-tradecraft-dprk-lazarus]] and the modern AiTM kits in [[aitm-evilginx-modern-phishing]] and [[tycoon2fa-and-modern-phish-kits]]. When DMARC is misconfigured, attackers spoof the exact brand domain and bypass user training entirely. When DMARC is correctly enforced, attackers fall back to lookalike domains, display-name spoofing, or compromised third-party senders — a very different (and noisier) game.

For defenders, DMARC aggregate (`rua`) reports are also one of the cheapest sources of "who is sending mail as us" intelligence, feeding directly into [[cti-collection-management]] and [[expanding-attack-surface]] for owned brands. For offensive testers, mapping a target's email-auth posture is a free reconnaissance step that often unlocks high-impact phishing scenarios in scope ([[program-scope-reading]], [[demonstrating-impact]]).

## How each mechanism works

### SPF — Sender Policy Framework

SPF is a TXT record at the envelope-sender (`MAIL FROM` / `Return-Path`) domain listing authorised sending sources. Receivers fetch `_spf` style records, evaluate mechanisms (`ip4`, `ip6`, `a`, `mx`, `include`, `redirect`) left-to-right, and stop at the first match. The result is one of `pass`, `fail`, `softfail`, `neutral`, `none`, `permerror`, `temperror`.

Key practitioner points:

- SPF authenticates the envelope sender, not the header `From:` users see. On its own it does nothing against display-spoofing.
- RFC 7208 caps DNS lookups at 10 (mechanisms + `include` + `redirect`); exceeding the cap yields `permerror`, which many receivers treat as "fail open". This is the single most common SPF break in the wild.
- `~all` (softfail) is advisory; `-all` (hardfail) is the only posture DMARC treats as a definitive SPF fail in the absence of DKIM.

### DKIM — DomainKeys Identified Mail

DKIM signs a canonicalised subset of headers and (optionally) the body with an RSA or Ed25519 key, publishing the public key at `selector._domainkey.example.com`. The signature lives in the `DKIM-Signature:` header and references the signing domain in the `d=` tag.

Key practitioner points:

- The `d=` domain is what DMARC aligns against, not the selector. A vendor signing with `d=mailgun.org` will not align for `example.com` unless they also sign with `d=example.com` (often via a CNAME-delegated selector).
- 1024-bit RSA keys are widely considered weak; 2048-bit is the baseline. Old short keys are still everywhere — Zach Harris famously cracked 512-bit DKIM keys at Google in 2012.
- DKIM key rotation is rarely automated. Operators publish a selector, point a vendor at it, and forget. Compromise of any historical private key forever undermines forensic non-repudiation.
- The `l=` body-length tag allows partial body signing — appending content after the signed prefix preserves the DKIM pass and is a known phishing primitive.

### DMARC — Domain-based Message Authentication, Reporting and Conformance

DMARC is a TXT record at `_dmarc.example.com` that ties SPF and DKIM results to the header `From:` domain via *alignment*, declares a policy, and requests reports.

Minimum useful policy:

```text
v=DMARC1; p=reject; rua=mailto:dmarc-rua@example.com;
ruf=mailto:dmarc-ruf@example.com; fo=1; adkim=s; aspf=s; pct=100
```

Tag highlights:

- `p=` — policy for the organisational domain (`none`, `quarantine`, `reject`).
- `sp=` — policy for subdomains; defaults to `p=` if omitted. Forgetting `sp=reject` while parent is `p=reject` is a classic gap that lets attackers spoof `noreply.example.com`.
- `adkim` / `aspf` — alignment mode: `r` (relaxed, organisational domain match) or `s` (strict, exact match).
- `pct=` — percentage of mail to which policy is applied; useful for gradual rollout, but attackers will keep retrying until they hit the unenforced slice.
- `rua` / `ruf` — aggregate (XML, daily) and forensic (per-message) reporting endpoints. External `rua` destinations require a confirming `_report._dmarc` record on the receiver side.

## Alignment in practice

DMARC passes if *either* SPF or DKIM passes *and* aligns. Relaxed alignment compares the organisational domain (eTLD+1) — useful when third parties send from `mail.example.com`. Strict alignment requires an exact FQDN match.

| Scenario | SPF result | SPF aligned? | DKIM result | DKIM aligned? | DMARC |
| --- | --- | --- | --- | --- | --- |
| Direct send from owned MTA | pass | yes | pass (`d=example.com`) | yes | pass |
| SaaS sender, SPF include, no DKIM CNAME | pass | no (`d=vendor.com`) | n/a | n/a | fail |
| SaaS sender, DKIM CNAMEd to vendor | softfail | n/a | pass (`d=example.com`) | yes | pass |
| Mailing list rewrite | pass for list | no | DKIM body broken | no | fail (see [[arc-and-mail-forwarding]]) |

## Common misconfigurations

- **SPF >10 lookups.** Especially common with Microsoft 365 + Google Workspace + Mailchimp + Salesforce + a CRM. Flatten with a managed service or split sending domains.
- **Multiple SPF records.** RFC 7208 requires exactly one; multiples yield `permerror`. Easy to introduce when two teams add records.
- **`+all` or extremely wide `ip4:0.0.0.0/0`.** Effectively disables SPF.
- **DMARC `p=none` forever.** "Monitoring mode" without a deadline becomes "spoof us at will" mode.
- **No `sp=` set with mixed subdomain sending.** Attackers pivot to obscure subdomains.
- **`rua` mailbox unmonitored or quota-full.** Receivers stop sending reports after bounces.
- **DKIM key kept for years.** Vendor offboarding never includes selector decommission.
- **Selector with weak key length** (1024-bit or smaller, missing `t=y` removed from test mode).
- **MTA-STS / TLS-RPT absent.** Not DMARC, but commonly grouped — downgrade attacks remain feasible without them.

## Forwarder and mailing-list breakage

- Plain forwarding (`.forward`, Sieve `redirect`) preserves headers — SPF fails because the forwarder IP is not in the original domain's SPF, but DKIM usually still passes if the body is untouched.
- Mailing lists typically modify the `Subject:` (adding `[list]`), append unsubscribe footers, and rewrite `From:` or add `Sender:`. This breaks DKIM body hashes. SPF was never going to pass for the new envelope. Result: DMARC fail for any list participant whose domain enforces.
- The fix is ARC ([[arc-and-mail-forwarding]]), which lets intermediaries vouch for the original auth state. Receivers can use ARC to override DMARC failures from trusted forwarders.
- Tactically, lists either (a) require members on `p=reject` domains to use a list-friendly address, or (b) rewrite `From:` to a list-owned domain (`user via list <list@list.example>`), losing identity in the process.

## Defensive baseline

- Move every primary and parking domain through monitor (`p=none`) -> `quarantine; pct=10` -> `quarantine; pct=100` -> `reject` over weeks, watching `rua`.
- Set `sp=reject` once subdomains are inventoried.
- Use strict alignment (`adkim=s; aspf=s`) for high-value brand domains.
- Rotate DKIM keys at least annually, automate selector swap, retire old selectors after sufficient drain time.
- Publish DKIM at >=2048-bit RSA or Ed25519 where supported.
- Add MTA-STS (`_mta-sts` TXT + HTTPS policy file) and TLS-RPT to harden transport.
- Parking domains and never-send domains need explicit "null" records: `v=spf1 -all`, an empty DKIM, and `v=DMARC1; p=reject;` to block spoofing of dormant brands.
- Pipe `rua` XML into a parser (dmarcian, Postmark, internal ELK) and feed anomalies into [[siem-detection-use-case-catalog]] and [[detection-engineering-pyramid-of-pain]].
- Pair with phishing controls from [[aitm-evilginx-modern-phishing]], [[conditional-access-bypass-modern]] and [[m365-admin-attacks]] — DMARC alone does not stop lookalike domains.

## Spoofing-test methodology

Treat this as a checklist when testing in scope (see [[program-scope-reading]] and [[testing-methodology-checklists]]):

1. Enumerate sending sources: `dig TXT example.com`, `dig TXT _dmarc.example.com`, walk `include:` chains, look for vendor CNAMEs on `*._domainkey.example.com`.
2. Count SPF DNS lookups; flag any `permerror` risk.
3. Identify subdomains with no `sp=` coverage or with their own permissive `_dmarc` records.
4. Check DKIM selectors discoverable from past mail you legitimately received — look for short keys, missing keys (selector removed), or `t=y` test flags.
5. Send authenticated test mail through any third-party sender you can sign up for; see whether their default `d=` aligns with target.
6. Probe `MAIL FROM` vs `From:` mismatches in lab to confirm receiver behaviour — many filters only check one.
7. Validate ARC handling by routing through known intermediaries (mailing lists you control) to a target mailbox you control.
8. Document outcomes per receiver (Google, Microsoft 365, Proofpoint, Mimecast) — gateways differ wildly. See [[email-gateway-bypass-techniques]].
9. Report findings with concrete spoof evidence and remediation in the language of [[report-writing-for-pentesters]] and [[demonstrating-impact]].

## Workflow to study

- Stand up a lab domain in [[building-a-research-home-lab]] with a real MX, an SPF record, two DKIM selectors and a `_dmarc` endpoint pointing `rua` at a mailbox you control.
- Send mail through Postfix, then Gmail SMTP relay, then a transactional vendor (Postmark/SES) and observe header diffs.
- Break things deliberately: drop the DKIM selector, switch to `~all`, add an 11th SPF lookup; watch the `rua` next morning.
- Subscribe the lab address to a mailing list, then to a forwarding rule; compare ARC behaviour.
- Re-run the spoofing checklist against your own lab to internalise receiver quirks before testing customer domains.
- Track DMARC ecosystem changes in [[keeping-up-with-research-feeds]] — Google and Yahoo's 2024 bulk-sender enforcement changed posture for thousands of brands overnight.

## Related

- [[arc-and-mail-forwarding]]
- [[email-gateway-bypass-techniques]]
- [[smtp-injection]]
- [[smtp-enum]]
- [[aitm-evilginx-modern-phishing]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[oauth-device-code-phishing-m365]]
- [[m365-admin-attacks]]
- [[dnssec-misconfig-attacks]]
- [[siem-detection-use-case-catalog]]
- [[detection-engineering-pyramid-of-pain]]
- [[report-writing-for-pentesters]]

## References

- <https://datatracker.ietf.org/doc/html/rfc7208> — SPF (RFC 7208).
- <https://datatracker.ietf.org/doc/html/rfc6376> — DKIM Signatures (RFC 6376).
- <https://datatracker.ietf.org/doc/html/rfc7489> — DMARC (RFC 7489).
- <https://datatracker.ietf.org/doc/html/rfc8617> — ARC (RFC 8617).
- <https://dmarc.org/overview/> — DMARC.org overview and deployment guidance.
- <https://support.google.com/a/answer/81126> — Google Workspace 2024 bulk-sender requirements.
