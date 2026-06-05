---
title: Bug bounty platform payouts and currency
slug: bug-bounty-platform-payouts-and-currency
aliases: [bb-payouts, bb-currency]
---

> **TL;DR:** Bug-bounty payouts look simple ("we paid you $5,000") but the path from program triage to money in your bank involves payout rails (PayPal, Hyperwallet, wire, Coinbase, crypto), FX conversion, withdrawal minimums, fees, and tax/sanctions compliance. Each platform has different defaults: HackerOne uses PayPal/Coinbase/Hyperwallet, Bugcrowd uses Payoneer/Hyperwallet/PayPal, web3 platforms ([[code4rena-sherlock-cantina-web3]]) pay in USDC on-chain. Hunters in non-USD jurisdictions can lose 3-7% to FX spread and fees alone, and OFAC-restricted countries cannot legally receive payouts at all. Companion to [[bug-bounty-income-tax-international]], [[hackerone-platform-deep]], [[bugcrowd-platform-deep]], and [[burnout-and-pipeline]].

## Why it matters

Hunters obsess over CVSS and bounty tables but underestimate the **effective take-home rate**. A $10,000 bounty paid via international wire with a 2.5% FX spread, $25 intermediary fee, and a country with 30% income tax nets closer to $6,800 — and you may wait 30-60 days for the money. Worse, a hunter unaware of OFAC/sanctions rules can have payouts permanently frozen, or trigger KYC failures that lock their account during a high-earning month.

Treating payouts as an engineering problem — choosing rails, batching withdrawals, tracking FX, planning taxes — is part of running a sustainable hunting practice. See [[burnout-and-pipeline]] for the broader sustainability angle and [[program-selection-tactics]] for choosing programs that actually pay.

## Per-platform payout methods

### HackerOne

Documented rails (as of 2024-2025):

- **PayPal** — fastest, available in most countries, but PayPal's FX conversion is ~3-4% worse than mid-market. Withdrawal to local bank adds another fee.
- **Coinbase** — receive in USDC/BTC/ETH. Useful for hunters in countries with capital controls or weak local banking, but creates a crypto tax event in many jurisdictions.
- **Hyperwallet** (PayPal-owned) — bank transfer rails to ~170 countries. Lower FX spread than PayPal-direct, but onboarding KYC is heavier.
- **Bank wire** — used for very large bounties or corporate payouts. Fees of $15-50 plus intermediary bank deductions.
- **Local bank transfer** — in some markets HackerOne supports ACH (US) or SEPA (EU).

See [[hackerone-platform-deep]] for triage and program selection on H1.

### Bugcrowd

- **Payoneer** — historically the primary rail; reasonable spreads, debit-card option.
- **Hyperwallet** — added later as alternative.
- **PayPal** — supported in select regions.
- **Bank transfer** — direct deposit in some countries.

See [[bugcrowd-platform-deep]] for VRT and platform specifics.

### Intigriti, YesWeHack, Synack

- **Intigriti** — SEPA-friendly (EU-based), supports bank transfer and PayPal; usually quotes bounties in EUR.
- **YesWeHack** — French platform, EUR-denominated, bank transfer common.
- **Synack** — private, treats researchers as 1099 contractors (US) or equivalent; pays via direct deposit or wire.

### Web3 platforms (Code4rena, Sherlock, Cantina, Immunefi)

- **USDC on-chain** is the default. Hunters provide an Ethereum/Arbitrum/Optimism address; payouts arrive in days, not weeks.
- No FX spread (stablecoin), but on-ramp/off-ramp to fiat costs 1-2% and creates a taxable event.
- **Immunefi** pays in the protocol's native token sometimes (e.g., partial in project token) — this is a price-risk decision.

See [[code4rena-sherlock-cantina-web3]] for contest mechanics.

### Vendor-direct programs

Apple, Google, Microsoft, Meta, etc. pay directly:

- Apple — wire transfer after W-8BEN/W-9 paperwork.
- Google — Bill.com or wire; Google VRP is famously slow on payout cycles.
- Microsoft — bank wire after MSRC validates bank details.

## Currency: USD vs EUR vs native

### USD-denominated programs

Most US-platforms (H1, Bugcrowd) quote in USD. If your local currency is volatile (TRY, ARS, NGN), USD payouts are effectively a hedge against local inflation — many hunters prefer to **hold USDC** rather than convert.

### EUR-denominated programs

Intigriti, YesWeHack, and many European corporate programs quote EUR. Watch for **double FX**: program pays EUR → PayPal converts to USD → bank converts to local currency, each leg taking 1-3%.

### Native-currency programs

Rare but exists (e.g., Japanese programs in JPY, some Indian programs in INR). Usually paired with local bank transfer to avoid FX entirely.

## Withdrawal minimums and processing time

| Rail | Typical minimum | Processing time |
|---|---|---|
| PayPal | $1 (varies by country) | 1-3 days to bank |
| Hyperwallet bank transfer | $10-50 | 3-7 business days |
| Coinbase USDC | None (gas only) | Minutes to hours |
| International wire | $100-1000 | 3-5 business days |
| Payoneer | $50 | 2-5 business days |
| On-chain USDC (web3) | None (gas) | Minutes |

Platforms often **batch payouts weekly or biweekly** even after the program marks the report "rewarded" — read the platform's payout schedule docs.

## Fees breakdown

### Hyperwallet

- Bank transfer to local account: often free or $1-3 flat.
- FX spread: ~1.5-2.5% above mid-market.
- Better than PayPal for amounts above ~$500.

### PayPal

- Receiving: usually free within platform.
- Withdraw to bank: free in many countries, but FX spread 3-4%.
- Cross-border: extra 1-2%.

### Wire

- Sending bank: $0-25 (platform usually absorbs).
- Intermediary bank: $10-30 (silently deducted).
- Receiving bank: $5-25.
- Total bite on a $1000 wire can be 5-6%.

### Crypto on/off-ramp

- Exchange fee: 0.1-1.5%.
- Network gas: $1-20 depending on chain.
- Off-ramp to fiat: 0.5-2% plus local bank fee.

## Tax-reporting implications

- US hunters typically receive **1099-NEC** for $600+ from a platform; treat as self-employment income. See [[bug-bounty-income-tax-international]] for cross-border specifics.
- Non-US hunters file **W-8BEN** to claim treaty rates and avoid 30% US withholding. Without W-8BEN, HackerOne/others may withhold 30% on certain payments.
- EU hunters may need to register as **freelancers/sole traders** to legally invoice platforms; some platforms require this for payout.
- Crypto payouts trigger capital-gains events on every conversion in most jurisdictions — track cost basis at receipt time.
- VAT/GST: in some EU countries bug-bounty income above a threshold requires VAT registration.

## Sanctions and OFAC

US-based platforms cannot legally pay hunters in OFAC-sanctioned jurisdictions (Iran, North Korea, Cuba, Syria, Crimea/Donetsk/Luhansk, and partial restrictions on Russia/Belarus as of 2024-2025). This matters in practice:

- Hunters in sanctioned countries have had accounts frozen mid-program.
- Hunters in **adjacent countries** (UAE, Turkey, Armenia, Georgia) sometimes hold accounts under those jurisdictions, but platforms increasingly KYC-verify residence.
- Web3 platforms with on-chain payouts use **OFAC sanctions screening** on wallet addresses (Chainalysis lists), and some explicitly block known sanctioned addresses.

Do not lie on KYC — it's fraud and will get all payouts permanently frozen.

## Currency hedging for high-volume hunters

Hunters earning $50k+/year develop hedging habits:

- **Hold a USD or USDC buffer** equal to 1-3 months of expenses to avoid FX-converting during dips.
- **Batch withdrawals** monthly instead of per-bounty to reduce per-tx fees.
- **Spread across rails** — having both PayPal and Hyperwallet means a platform-side outage on one doesn't block income.
- **Maintain a multi-currency account** (Wise, Revolut, Mercury) to hold USD/EUR/GBP and convert at near-mid rates.
- **Track effective take-home rate** per program: net received / nominal bounty.

## Payment delays during program issues

Things that delay payment:

- **Program runs out of budget** mid-quarter — bounty validated but queued for next budget cycle.
- **Customer dispute on severity** — payment held until resolved.
- **Platform KYC re-verification** triggered by a large payout.
- **Bank rejected the transfer** (sanctioned country routing, name mismatch).
- **Tax form expired** — W-8BEN expires every 3 years; expired form blocks payment.

Hunters should keep KYC docs and tax forms current proactively, not reactively.

## Defensive baseline (financial)

- Maintain 3-6 months of expenses in a stable currency or USDC; bug-bounty income is lumpy.
- Use a dedicated business bank account (LLC, sole-prop, or equivalent) — easier for taxes and audits.
- Keep written records of every bounty: program, date validated, date paid, gross, fees, net, FX rate at receipt.
- Renew W-8BEN/W-9 forms before they expire.
- Diversify across 2+ platforms so a single platform issue doesn't zero your month.

## Workflow to study

1. Pick one platform you've earned on (or plan to). Read its **payout policy page** end-to-end.
2. Calculate your **effective take-home rate** on the last 3 payouts: net into bank / nominal bounty.
3. Compare two rails (e.g., PayPal vs Hyperwallet) on a $1000 hypothetical: list every fee and FX spread.
4. Read your country's **freelance/self-employment tax rules** for foreign income; identify the form you must file.
5. Verify your **W-8BEN** (or equivalent) is on file and not expired.
6. Set up a spreadsheet: program, date, gross, currency, rail, fees, FX, net, tax-reserved.
7. For web3 hunters: pick a chain for receiving USDC and a trustworthy off-ramp; document the cost-basis at receipt.

## Related

- [[bug-bounty-income-tax-international]]
- [[hackerone-platform-deep]]
- [[bugcrowd-platform-deep]]
- [[code4rena-sherlock-cantina-web3]]
- [[program-selection-tactics]]
- [[burnout-and-pipeline]]
- [[report-writing]]
- [[disclosure-and-comms]]

## References

- HackerOne payout documentation: https://docs.hackerone.com/en/articles/8410812-receiving-bounty-payments
- Bugcrowd payment methods: https://docs.bugcrowd.com/researchers/receiving-rewards/payment-methods/
- Hyperwallet fee schedule (PayPal): https://www.hyperwallet.com/
- IRS guidance on Form W-8BEN (foreign individuals): https://www.irs.gov/forms-pubs/about-form-w-8-ben
- OFAC sanctions program list: https://ofac.treasury.gov/sanctions-programs-and-country-information
- Immunefi payment FAQ: https://immunefi.com/faq/
