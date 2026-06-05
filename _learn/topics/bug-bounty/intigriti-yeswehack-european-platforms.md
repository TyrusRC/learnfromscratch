---
title: Intigriti / YesWeHack — European platforms
slug: intigriti-yeswehack-european-platforms
aliases: [intigriti-deep, yeswehack-deep, eu-bb-platforms]
---

> **TL;DR:** Intigriti (Belgium) and YesWeHack (France) are the two dominant European bug-bounty platforms. They differ from US peers ([[hackerone-platform-deep]], [[bugcrowd-platform-deep]]) on GDPR handling, EUR payouts, multi-lingual programs, and access to European-government VDPs (Belgian federal CCB, French ANSSI/ministerial scopes). For tax and invoicing implications of working across them, pair with [[bug-bounty-income-tax-international]] and the [[program-selection-tactics]] heuristics.

## Why it matters

European platforms are not just "HackerOne in EUR." They operate under a different legal and cultural regime:

- **GDPR-first triage** — researcher PII (passport, IBAN, address) is treated as a data subject record, with retention and DSAR rights baked in.
- **Government VDP density** — Intigriti runs the Belgian federal CCB program; YesWeHack hosts French ministerial scopes, EU institutions, and several national-CERT VDPs.
- **EUR payouts and SEPA** — direct SEPA Credit Transfer is cheaper and faster than the USD wires US platforms still default to.
- **Language diversity** — programs frequently accept reports in English, French, Dutch, German, sometimes Spanish; localized triage staff exist.
- **Different broker culture** — fewer "live-hacking event" theatrics, more long-tail private programs and continuous engagements.

Hunters who only have HackerOne/Bugcrowd accounts are leaving a meaningful chunk of European scope on the table, and EU-resident hunters can simplify their tax life dramatically (see [[bug-bounty-income-tax-international]]) by routing earnings through a SEPA-native platform.

## Platforms, programs, and process

### Intigriti (Belgium)

Founded 2016, headquartered in Antwerp. Owned by a Belgian holding, with a European board. The platform's reputation is built on tight triage SLAs and a strong relationship with Belgian and Dutch enterprises (banks, telcos, government).

Key features:

- **Hacker tiers** — Standard, Silver, Gold, Platinum, and the invite-only **1337UP** tier. Promotion is driven by signal (valid:invalid ratio), severity, and platform engagement, not just bounty totals. 1337UP members get early access to new private programs and live-hacking events.
- **Belgian CCB Safe Harbor VDP** — the only platform with the official `*.belgium.be` and federal-agency umbrella scope. Pure VDP (no bounty) but the legal coverage from Belgian federal law on coordinated disclosure is unusually strong; useful precedent for [[responsible-disclosure-across-jurisdictions]].
- **Private program density** — a large share of Intigriti's bounty volume sits in private invites. Building Silver+ tier is the prerequisite to seeing the real money.
- **Continuous Pen Testing (CPT)** — hybrid managed-testing product. Some hunters get paid hourly + bounty for hand-picked scopes.
- **Triage in EU timezones** — reports filed at 09:00 CET typically get touched the same morning, not 24h later.

### YesWeHack (France)

Founded 2013 in Paris, with offices across Europe, Singapore, and recently the Middle East. Stronger global footprint than Intigriti, and the de-facto platform for French-speaking programs.

Key features:

- **Bug Bounty Plus** — premium tier where YesWeHack staff own primary triage, similar to HackerOne's managed offering. Programs pay a markup; researchers see faster, more consistent responses.
- **Vulnerability Disclosure Programs (VDP)** — explicitly separated from bounty programs. France's `*.gouv.fr` ministerial scopes, EU institutions (some), and CERT-FR coordination all live here. No bounty, but Safe Harbor language is robust.
- **Dojo and YesWeHackEDU** — free training labs and a university program. Useful as a [[ctf-to-bug-bounty-transition]] on-ramp and for warming up an account before requesting private invites.
- **Asset Discovery & Attack-Surface Management** — productized recon (PTaaS-adjacent). Researchers can sometimes feed findings from this into program scopes.
- **Multi-lingual reports** — French is first-class; many programs accept French OR English. Submitting in the program's native language signals seriousness.

### Comparing the two

| Dimension | Intigriti | YesWeHack |
|---|---|---|
| HQ / jurisdiction | Belgium (EU) | France (EU) |
| Primary government access | Belgian federal CCB | French ministries, EU bodies |
| Tiering | Standard → 1337UP | Reputation points + invite system |
| Payout rails | SEPA (EUR), wire (USD), some crypto | SEPA (EUR), wire, PayPal in some regions |
| Triage style | Internal staff, EU hours | Internal + Bug Bounty Plus managed tier |
| Language defaults | English, NL, FR | French, English, some DE |
| Public program count | Smaller but premium-skewed | Larger, more breadth |

### GDPR and data-handling differences

Both platforms are data controllers for hunter PII and processors for program-submitted vulnerability data. Practical consequences:

- **Right to erasure** — you can request deletion of your researcher account and PII; platforms must comply within ~30 days. US platforms technically honor this too but the EU framing is the default.
- **Cross-border transfers** — when a US-based program triages a report filed by an EU hunter, the platform's DPA spells out the SCCs (Standard Contractual Clauses) used. Worth reading once.
- **Triage logs** — internal triage notes about your reports are subject access requestable. Useful if you suspect a wrongful dupe close (rare but documented).
- **PII in PoCs** — both platforms have explicit rules against attaching real personal data of third parties to reports. Use synthetic accounts; this aligns with [[report-writing]] best practice anyway.

### Payments, EUR vs USD, taxes

- **EUR-denominated bounties** — Intigriti programs typically post bounties in EUR; YesWeHack mixes EUR and USD. For EU-resident hunters this kills the FX spread you eat on HackerOne.
- **SEPA Credit Transfer** — both platforms support SEPA. EU/EEA hunters get paid within 1 business day at near-zero cost. Non-EU hunters can request SWIFT (slower, fees apply) or PayPal/crypto where supported.
- **Tax artifacts** — Intigriti issues a yearly earnings summary; YesWeHack provides per-program statements. Neither issues a W-9/W-8BEN equivalent the way HackerOne does, because the legal relationship is hunter-as-independent-contractor under EU contract law. Belgian and French tax authorities have begun specifically naming bug-bounty income in guidance — see [[bug-bounty-income-tax-international]] for the EU treatment.
- **VAT and reverse charge** — EU-business hunters (sole traders with VAT IDs) may need to invoice with the EU reverse-charge mechanism. Both platforms can accept VAT-compliant invoices on request; this is a meaningful workflow difference from US platforms which mostly do not.
- **Non-EU hunters** — payouts work fine but you lose the SEPA cost advantage. Cross-reference with your home-country tax rules.

## Defensive baseline (for program operators)

If you are running a program on either platform, the basics are unchanged from [[program-scope-reading]] but the EU twist matters:

1. **Scope language** — publish scope in English plus at least one local language; reduces dupes and improves report quality.
2. **Safe Harbor wording** — both platforms supply EU-counsel-reviewed templates that survive challenge under the Belgian and French coordinated-disclosure statutes. Use them.
3. **GDPR data-minimization in reports** — instruct hunters to redact third-party PII; provide a synthetic test tenant.
4. **Payout currency** — match the currency to your hunter base. EUR for EU-heavy programs reduces friction; USD only if you specifically want US/global hunters.
5. **Response SLAs in EU hours** — set CET working-hours expectations explicitly; hunters file accordingly.

## Workflow to study

1. **Create accounts on both** with the same identity and SEPA details. Complete KYC on each (national ID + proof of address). Account verification takes 1-3 business days.
2. **Walk the public programs** on both. Note bounty tables in EUR vs USD and compare against equivalent HackerOne scopes for the same companies (some run cross-platform).
3. **Submit one well-scoped report on a public program** on each platform to calibrate triage style. Apply [[report-writing-step-by-step]] and your standard [[testing-methodology-checklists]].
4. **Engage with Dojo / Hacker tier ladders** — YesWeHack Dojo CTFs build reputation; Intigriti's monthly challenge does the same. Visible engagement triggers private invites.
5. **Read the EU government VDP scopes** end-to-end. The Belgian CCB and French government VDPs have unusually broad legal scope and unusually narrow technical scope; learn both.
6. **Set up multi-platform recon hygiene** — keep target inventories from EU programs separate from your US targets so you do not accidentally OOS-test (see [[expanding-attack-surface]] and [[continuous-recon-automation]]).
7. **Track your taxable income per platform** monthly. Both platforms make annual statements available; reconcile against your accounting (per [[bug-bounty-income-tax-international]]).
8. **Build language muscle** — even basic French or Dutch in a report's executive summary signals respect to local triage; English-only is fine but localization wins ties.

## Related

- [[hackerone-platform-deep]] — US platform comparison
- [[bugcrowd-platform-deep]] — US platform comparison
- [[bug-bounty-income-tax-international]] — tax treatment for cross-border earnings
- [[program-selection-tactics]] — choosing where to spend hunting hours
- [[program-scope-reading]] — reading scope across jurisdictions
- [[responsible-disclosure-across-jurisdictions]] — EU vs US legal regimes
- [[report-writing]] / [[report-writing-step-by-step]] — multi-lingual submission craft
- [[ctf-to-bug-bounty-transition]] — using Dojo / 1337UP ladders to ramp
- [[continuous-recon-automation]] — keeping EU vs non-EU scopes separate
- [[disclosure-and-comms]] — handling coordinated disclosure with EU CERTs

## References

- <https://www.intigriti.com/researchers> — Intigriti researcher portal and tier documentation
- <https://www.yeswehack.com/researchers> — YesWeHack researcher overview and Dojo
- <https://ccb.belgium.be/en> — Belgian Centre for Cybersecurity, coordinated-disclosure framework
- <https://www.cert.ssi.gouv.fr/> — CERT-FR (ANSSI) coordinated-disclosure guidance
- <https://edpb.europa.eu/edpb_en> — European Data Protection Board, GDPR guidance relevant to vulnerability data handling
- <https://www.enisa.europa.eu/publications/coordinated-vulnerability-disclosure-policies-in-the-eu> — ENISA report on EU coordinated vulnerability disclosure policies
