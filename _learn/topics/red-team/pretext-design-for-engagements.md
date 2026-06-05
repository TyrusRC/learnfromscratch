---
title: Pretext design for engagements
slug: pretext-design-for-engagements
aliases: [pretext-design, phishing-pretexts]
---

{% raw %}

> **TL;DR:** A pretext is the story the email/call tells. Good pretexts match a real business workflow ("DocuSign — please review"), arrive from a plausible sender, and create just enough urgency without triggering scepticism. Bad pretexts use threats, free money, or grammar errors. This is the "what to write" companion to [[phishing-infrastructure-design]]'s "how to send".

## The four pillars

| Pillar | Question |
|---|---|
| **Plausibility** | Would this email exist in the target's normal workday? |
| **Authority** | Does the sender's identity logically have this ask? |
| **Urgency** | Is there a reason to act now, but not a panicked one? |
| **Action** | Is the requested action specific and easy? |

The classic anti-pattern: "Account locked — click within 1 hour or lose access". Plausible (account-lock alerts exist), authoritative (impersonating IT), urgent (1 hour) — but *too urgent*, triggering recipient scepticism. Replace with "Quarterly access review — your manager will see this list" — slower, peer-pressure-shaped.

## Pretexts that work in 2026

### 1. Workflow extension
- "Your Confluence comment from yesterday has 3 new replies."
- "Action required: complete your annual phishing-awareness training by Friday." (yes, the irony)
- "Calendar invite: Q2 OKR review — please confirm attendance."

These ride existing tools the target uses daily. Brand impersonation is one part; the *workflow* match is the other.

### 2. HR / payroll
- "Your W-2 is ready — view in Workday."
- "Open enrollment closes in 3 days — confirm benefits selections."

Highly effective in late January (W-2s) and during open enrollment windows.

### 3. IT / security
- "Multi-factor authentication device expiring — re-enroll by EOM."
- "Per IT Security: confirm your VPN client version."

Sender impersonation: a real IT person from the target org, ideally one whose name appears in LinkedIn.

### 4. Vendor / supplier
- "DocuSign — please review and sign the renewal."
- "Adobe Sign: 1 document awaiting your signature."

DocuSign and Adobe Sign emails are real-business standard; users click them daily. The landing page imitates the brand.

### 5. Internal events
- "Lunch & Learn — pizza ordered, please RSVP."
- "Volunteer opportunity — Q3 community day signup."

Low-stakes, high-click-through. Pairs well with credential-harvest landing pages.

## Pretexts that fail

- Lottery / Nigerian-prince variants. Filters and users have learned.
- "URGENT: account closure in 1 hour". Too urgent → suspicion.
- Free gift cards to non-employees. Outside business context.
- Anything sent from `noreply@company.tld` to internal users (real `noreply` emails are filtered into Promotions/Spam by default; users don't expect to take action on them).

## Personalisation

The further you personalise, the higher the click rate — and the slower the campaign.

| Tier | Personalisation | Click-rate | Recipients per hour |
|---|---|---|---|
| Tier 1 | None ("Dear user") | 1-3% | 1000 |
| Tier 2 | First name | 5-10% | 200 |
| Tier 3 | First name + role + recent project | 20-40% | 20 |
| Tier 4 | Spear-phish per target (LinkedIn-mined) | 50-80% | 1-5 |

For OSEP-style assumed-breach: tier 3 or 4. For volume external testing: tier 1.

## Authority cues

The sender display name and signature matter more than the email address — recipients glance at the From-name and skim the signature.

- A real-looking sender name + plausible internal title + sender's photo in the auto-fetched contact card.
- Email signature with phone number that rings to a burner (warm number for callback verification).
- Email-trail context: "Per our conversation on Tuesday, here's the doc." (Even if no conversation happened — the recipient assumes they forgot.)

## Trust transfer

Bigger campaigns build trust over weeks:
1. Benign first email (no link) — "Reaching out about Q3 — when are you free?".
2. Reply received → continue conversation.
3. Third or fourth email contains the payload, in context.

A target's mail filter and gut both relax after a few exchanges.

## Urgency calibration

Use a clock that makes sense, not a clock that screams.

- "Closes Friday at 5pm" — fine.
- "Closes in 15 minutes" — flags suspicion.
- "Action required this quarter" — too slow, gets archived.

Pair urgency with a *low-cost* action: "just click to confirm" beats "fill out a 30-field form" every time.

## Quality-of-writing tells

Modern phishing detectors score:
- Spelling (rare today; LLMs solved this).
- Hyperlink display-vs-href mismatch (`<a href="evil">support.microsoft.com</a>`).
- Domain-vs-display mismatch in From line.
- Unusual reply-to (different domain from From).
- Missing standard mail headers (List-Unsubscribe for marketing-style mail).

LLM-assisted phishing is now standard. Defenders score grammar less; they score structure and infrastructure more.

## A/B testing

Run two variants of the pretext on a small fraction of the target list before fully committing. Track:
- Open rate.
- Click rate.
- Credential-submission rate (or beacon-callback rate).
- Report-to-IT rate (the killer metric).

A pretext that beats its sibling on opens but loses on reports-to-IT is the worse choice.

## Ethics and authorisation

Phishing tests work for security only when the engagement letter clearly:
- Names the targeted domains and headcount.
- Specifies whether reports-to-IT count for IR practice.
- Specifies what data may be collected (credentials? sessions? cookies?).
- Names the delivery window and the "stop" channel for the customer.

Going off-scope on phishing pretexts is the fastest way to lose a customer and become unemployable in the sector.

## OSEP relevance

OSEP's "client-side code execution" modules assume a delivery mechanism. The exam gives you the lab target; pretext design is implicit. Real engagements lean heavily on the skill — practise pretexts as much as payloads.

## References
- [SANS — Pretexting analysis](https://www.sans.org/white-papers/)
- [TrustedSec — Pretext research](https://www.trustedsec.com/blog/)
- [SpecterOps — Adversary emulation pretexts](https://posts.specterops.io/)
- [Verizon DBIR — annual breach data, attack vectors](https://www.verizon.com/business/resources/reports/dbir/)
- See also: [[phishing-infrastructure-design]], [[client-side-attacks-primer]], [[office-vba-macros-initial-access]], [[osep-roadmap]]

{% endraw %}
