---
title: Bug bounty income — tax / international considerations
slug: bug-bounty-income-tax-international
aliases: [bb-tax, bb-international-tax, bb-income-tax]
---

> **TL;DR:** Bug-bounty payouts are taxable income in almost every jurisdiction, but the *characterisation* (self-employment, hobby, prize, miscellaneous income) and the *withholding mechanics* (W8-BEN, W9, VAT, 1099, 1042-S) vary wildly by where you live and which platform pays you. This practitioner note collects the recurring questions hunters ask once cheques start arriving — companion to [[hackerone-platform-deep]], [[bug-bounty-as-career-track]], and [[bug-bounty-platform-payouts-and-currency]]. **This is informational only; consult a licensed tax professional in your country of residence before filing.**

## Why it matters

Hunters who treat bounties as "side money" routinely run into avoidable problems:

- **Surprise tax bills** at the end of the year because no withholding occurred on a US-platform payout to a non-US resident.
- **Frozen payouts** because a W8-BEN or W9 was never filed, and the platform is legally required to withhold 24-30% until it is.
- **Audit exposure** when payouts cross local thresholds for mandatory business registration or VAT.
- **Double taxation** when the platform's country and the hunter's country both claim taxing rights and no treaty is invoked.
- **Crypto-payout confusion** where the disposal of the received token at a later date triggers a *second* taxable event (capital gains) on top of the income event.

Getting the structure right early — entity, paperwork, recordkeeping — is far cheaper than unwinding it after three years of unreported income. See also [[bug-bounty-as-career-track]] for the broader career framing and [[burnout-and-pipeline]] for why structure reduces stress.

## Classes / patterns / process

### How payouts are characterised

Different tax authorities slot bounty income into different buckets:

- **Self-employment / business income** — most common treatment for regular hunters. Triggers self-employment tax (US SE tax ~15.3%), national insurance (UK), URSSAF (France), etc. Allows deduction of expenses (VPNs, Burp licence, hardware, see [[building-a-research-home-lab]]).
- **Miscellaneous / "other" income** — used for occasional hunters in many EU jurisdictions. Lower compliance burden but no expense deductions.
- **Hobby income** — IRS specifically removed the hobby-expense deduction in 2018; hobby income is taxed at ordinary rates with *no* offsetting deductions. Usually the worst outcome.
- **Prize / lottery winnings** — rare but some jurisdictions (older interpretations in DE, NL) initially classified bounties this way. Generally superseded.
- **Capital income** — only relevant for the *subsequent* disposal of a crypto payout, not the bounty itself.

The line between hobby and business in the US is roughly: profit motive, regularity, books and records, time invested, and whether you depend on the income. Most active hunters cross into business territory by year two.

### US platform paperwork (HackerOne, Bugcrowd, Intigriti-US, Synack)

- **W9** — required for US persons (citizens, residents, US LLCs). No withholding if filed; you receive a 1099-NEC or 1099-MISC if payouts cross USD 600/year.
- **W8-BEN** — required for non-US individuals. Claims treaty benefits to reduce US withholding (often to 0% on "other income" under most treaties). Without it: 30% US withholding on every payout.
- **W8-BEN-E** — same idea but for non-US entities (your LLC, Ltd, GmbH).
- **1042-S** — the form the platform sends non-US filers showing US-source income and withholding. Keep it; your home country may want it for foreign-tax-credit claims.

The treaty article you cite on the W8-BEN matters. "Independent personal services" and "business profits" articles usually zero-out US withholding for non-US hunters with no US permanent establishment.

### EU VAT considerations

If you are an EU-resident sole trader or company invoicing a non-EU platform (HackerOne US, Bugcrowd US):

- The supply is typically **B2B services to a non-EU customer** — outside the scope of EU VAT (reverse-charge or zero-rated depending on member state).
- You still need to register for VAT once domestic turnover crosses the threshold (varies: DE ~22k EUR small-business cap, FR ~36.8k for services, NL no minimum, UK 90k GBP).
- Intra-EU platforms (Intigriti BE, YesWeHack FR) usually issue a **reverse-charge invoice** under Article 44 of the VAT Directive — you self-account but typically owe nothing if you have full input-VAT recovery.
- Keep the platform's VAT number; tax authorities ask.

### Country-of-residence taxation and double-taxation treaties

Most countries tax their **residents on worldwide income**. The platform's country may also withhold at source. The fix is the bilateral double-taxation treaty (DTT):

1. Establish residence under domestic rules (typically 183-day test + center of vital interests tie-breaker).
2. File the platform's withholding-reduction form (W8-BEN, equivalent).
3. Claim a **foreign tax credit** at home for any tax actually withheld abroad.
4. Keep the 1042-S or equivalent as evidence.

Hunters who relocate mid-year (digital-nomad pattern) need to watch the **split-year** rules and avoid accidentally becoming dual-resident.

### Cryptocurrency payouts

Increasingly common on permissionless platforms (Immunefi, Code4rena, Sherlock) — see [[bug-bounty-platform-payouts-and-currency]] and [[blockchain-security]].

Two taxable events in most jurisdictions:

1. **Receipt** — income at the FMV (fair market value) of the token at the moment of receipt. Record the timestamp and the USD/EUR price.
2. **Disposal** — when you later swap, sell, or spend the token, the difference between disposal value and the receipt-day basis is a capital gain or loss.

This means a hunter paid in ETH who holds for 18 months has *two* tax line items per payout. Tools like Koinly, CoinTracker, or Rotki automate this if you import wallet addresses early. Do *not* try to reconstruct three years of swaps from memory at filing time.

### Business-entity choices

- **Sole proprietor / self-employed** — simplest, lowest setup cost, full personal liability. Suits hunters earning under ~50-80k local currency/year.
- **US LLC (single-member, disregarded)** — pass-through for tax but separates legal liability. Useful for non-US hunters who want a US-payable entity, but creates US-filing obligations (Form 5472, 1120 pro forma).
- **UK Ltd / DE GmbH / FR SASU / similar** — corporate veil + lower effective tax rates on retained profits, but compliance overhead (accounts filing, corporation tax returns, director's salary structuring).
- **Estonian e-Residency OÜ** — popular among EU/non-EU nomads; only taxes distributed profits. Watch out: your country of residence still taxes you personally, and may treat the OÜ as a CFC (controlled foreign company).

Entity choice interacts with [[bug-bounty-as-career-track]] decisions and burnout management ([[burnout-and-pipeline]]).

### Platform-specific tax behaviour

- **HackerOne** — W9/W8-BEN flow in the payment-preferences pane. Issues 1099-NEC (US) and 1042-S (non-US). PayPal, Coinbase, wire, and Payoneer options.
- **Bugcrowd** — similar W9/W8-BEN flow. Historically slower to issue 1042-S.
- **Intigriti** — EU-headquartered (Belgium); invoices flow as B2B services. No US withholding. Issues platform statements but not US-style 1099.
- **YesWeHack** — France-based; similar EU invoicing model.
- **Immunefi** — sponsor-direct payouts (the protocol pays you, not Immunefi). Tax paperwork varies per program; some pay in stablecoin with no withholding, others issue 1099-equivalents.
- **Synack** — treats SRT members closer to contractors; W9/1099-NEC is standard for US members.

## Defensive baseline

Even before talking to an accountant:

- Open a **separate bank account** and (if crypto) a **separate hot wallet** for bounty income. Mixing personal and business funds is the single biggest cause of bad recordkeeping.
- Set aside **30-40% of every payout** into a tax-reserve account on receipt. You will need it.
- File the platform tax form **before your first payout clears**, not after. Backdating is messy.
- Keep a per-payout log: date, platform, program, payout amount in payout currency, FX rate or token FMV at receipt, equivalent in your home currency, and a link to the report (see [[report-writing]]).
- For crypto, snapshot the wallet balance and price feed at end-of-year for inventory valuation.
- If you work with a corporate entity, **document the IP assignment**: the entity, not you personally, owns the bug report.
- Track expenses: VPS, Burp Pro, Caido, recon infrastructure ([[continuous-recon-automation]]), home-lab hardware ([[building-a-research-home-lab]]), training, conference travel.

## Workflow to study

1. Identify your **tax residence** under domestic rules and confirm with a local accountant.
2. Read the DTT between your residence country and the US (most platforms route through US entities). Note the article that covers "other income" or "business profits".
3. Decide on **entity structure** before crossing local registration thresholds.
4. Choose **payout method**: bank wire (cleanest paper trail), PayPal (convenient, FX cost), crypto (only if you can track basis).
5. Set up **bookkeeping** — even a Google Sheet works for the first year. Move to Xero/QuickBooks/Pennylane once revenue stabilises.
6. File the platform tax forms (W9/W8-BEN/W8-BEN-E) and confirm withholding is correctly zeroed.
7. Each January: download platform tax statements, reconcile to your log, hand to accountant.
8. Quarterly: pay estimated taxes if your jurisdiction requires (US estimated taxes, UK payments on account, FR acomptes).

## Related

- [[hackerone-platform-deep]]
- [[bug-bounty-as-career-track]]
- [[bug-bounty-platform-payouts-and-currency]]
- [[program-selection-tactics]]
- [[burnout-and-pipeline]]
- [[report-writing]]
- [[continuous-recon-automation]]
- [[building-a-research-home-lab]]
- [[blockchain-security]]

## References

- IRS, *Hobby or Business?* — <https://www.irs.gov/newsroom/heres-how-to-tell-the-difference-between-a-hobby-and-a-business-for-tax-purposes>
- IRS, *W-8BEN instructions* — <https://www.irs.gov/forms-pubs/about-form-w-8-ben>
- HMRC, *Self-employment manual* — <https://www.gov.uk/hmrc-internal-manuals/business-income-manual>
- European Commission, *VAT rules on cross-border services* — <https://taxation-customs.ec.europa.eu/taxation/vat/eu-vat-rules-topic/vat-services_en>
- OECD, *Model Tax Convention* — <https://www.oecd.org/tax/treaties/model-tax-convention-on-income-and-on-capital-condensed-version-20745419.htm>
- HackerOne docs, *Tax information for hackers* — <https://docs.hackerone.com/en/articles/8403648-tax-information>
