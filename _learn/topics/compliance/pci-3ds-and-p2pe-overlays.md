---
title: PCI 3DS and P2PE — specialised compliance overlays
slug: pci-3ds-and-p2pe-overlays
---

> **TL;DR:** Beyond PCI DSS, two specialised programs handle high-value payment scenarios: **3DS (Three Domain Secure)** for e-commerce strong customer authentication and **P2PE (Point-to-Point Encryption)** for card-present encryption. Each has its own standard, validation lab, and AoC. Practitioners managing card programs encounter both; understanding their interplay with PCI DSS is the differentiator.

## PCI 3DS

### What it is
3D Secure (3DS) is the EMVCo authentication protocol for card-not-present transactions (Visa Secure, Mastercard Identity Check, Amex SafeKey, Discover ProtectBuy, JCB J/Secure). 3DS 2.x (mandatory since 2022; 1.x deprecated) adds frictionless authentication via risk-based analysis, biometrics, SCA compliance for EU PSD2.

PCI 3DS standard validates entities operating 3DS infrastructure: the **3DS Server (3DSS)**, the **Access Control Server (ACS)** (issuer side), and the **Directory Server (DS)** (operated by card brand).

### PCI 3DS Core Security Standard
For 3DSS and ACS operators. Two complementary standards:
- **PCI 3DS Core Security Standard** — security requirements for 3DS infrastructure
- **PCI 3DS Supporting Document** — physical, logical, network requirements

3DS infrastructure handles cardholder authentication data (3DS authentication value, AAV/CAVV/UCAF), challenge data, device fingerprints, risk-based authentication signals — all sensitive even when PAN isn't directly handled.

### Who needs it
- Issuers operating their own ACS (most outsource to Cardinal, ETS, PXP)
- 3DS Server operators (typically merchants of size or payment processors)
- Entities outsourcing 3DS to a third party fall back on that third party's compliance

### What's in scope
- 3DS-specific application + data flows
- Cryptographic key management for 3DS messages
- 3DS message log retention
- Integration points with PSP / gateway

3DS doesn't replace PCI DSS — entities handling 3DS often also handle PAN and need both.

## PCI P2PE

### What it is
PCI Point-to-Point Encryption is a validated standard for end-to-end encryption of card data from POI device to decryption environment (typically at the processor). When a P2PE solution is correctly deployed, cardholder data is encrypted within the POI before being released to the merchant's environment — meaning the merchant never sees cleartext PAN.

### Why it matters
- **Massive scope reduction** — SAQ P2PE has ~33 questions vs SAQ D's 300+
- **Liability shift** — encrypted PAN no longer attractive to attackers in your environment
- **Compliance velocity** — merchants in the SAQ P2PE path drastically reduce assessment cost

### Roles
- **P2PE Solution Provider** — designs, validates, distributes the P2PE solution; gets a PCI P2PE listing
- **POI device** — must be PCI PTS POI approved; cryptographically configured by the Solution Provider
- **Merchant** — installs and operates the validated solution per the P2PE Instruction Manual (PIM)

A solution becomes PCI listed only when validated by a P2PE QSA against the P2PE Security Standard. Merchants check the PCI SSC P2PE listing before claiming SAQ P2PE.

### P2PE Standards
- **P2PE Solution Standard** — for solution providers
- **P2PE Component Standard** — for component providers (KIF, KLF, decryption services)
- **P2PE Instruction Manual (PIM)** — solution-specific deployment guide merchant must follow

### What merchant must do under P2PE
- Use ONLY P2PE-listed solution
- Follow PIM exactly (device handling, configuration, network)
- Annual chip/sign-in/sign-out asset management of POI devices
- Verify device integrity (look for tampering)
- Maintain documentation per PIM
- Pass annual SAQ P2PE attestation

If you stray from the PIM (e.g., write your own integration that decrypts data) — you've stepped out of P2PE scope and the entire CDE is back in play.

### What P2PE is NOT
- Not full PCI DSS compliance — merchant still has SOME requirements
- Not applicable to e-commerce (CHD encryption happens at browser, not a POI device — different model)
- Not the same as End-to-End Encryption (E2EE) generally — P2PE requires PCI SSC validation
- Not the same as Tokenisation — tokenisation replaces PAN with a token; P2PE encrypts PAN end-to-end

Both can be used together: encrypt PAN with P2PE in flight, tokenise for storage post-decryption at processor.

## Decision matrix — when to use what

| Scenario | Recommended approach |
|---|---|
| In-person card-present, low PCI overhead desired | Validated P2PE + SAQ P2PE |
| E-commerce, no PAN on premises | SAQ A / A-EP + tokenisation |
| E-commerce, PSD2 / SCA required | 3DS 2.x + tokenisation |
| Issuer wanting own ACS | PCI 3DS validation + DSS |
| MOTO call centre | DTMF masking + tokenisation |
| Mobile POS for SMB merchants | P2PE-validated mobile solution (Square, Stripe Terminal, Adyen) |

## Interaction with PCI DSS

3DS and P2PE supplement, don't replace, PCI DSS:
- Merchant with 3DS still needs PCI DSS for other payment channels
- Merchant with P2PE still needs SAQ P2PE (a flavor of PCI DSS)
- Service provider running 3DS infrastructure needs BOTH PCI DSS AND PCI 3DS

## Tradecraft — implementing 3DS

### Step 1 — Determine your role
- Are you the 3DS Server operator (your gateway/PSP handles it for you in most cases)?
- Are you integrating 3DS into your checkout flow (frontend SDK calls)?
- Are you bypassing 3DS through risk-based exemptions (low value, low risk)?

### Step 2 — SDK integration
Major payment providers (Stripe, Adyen, Worldpay, Braintree) abstract 3DS through SDKs. Frontend triggers a challenge flow when issuer requests it; backend handles the authentication response and passes to authorisation.

### Step 3 — Exemption strategy
PSD2 exempts certain transactions from SCA:
- Low value (€30 cumulative limits)
- Recurring payments (after first SCA)
- MIT (Merchant Initiated Transactions)
- TRA (Transaction Risk Analysis) exemption — issuer-driven risk score

Exemption strategy reduces friction but tracking is on the merchant — exemption claims must be documented.

### Step 4 — Liability
3DS-authenticated transactions shift fraud liability from merchant to issuer (under most card brand rules). Soft liability shift even for frictionless authentication.

## Tradecraft — implementing P2PE

### Step 1 — Choose validated solution
Check the PCI SSC P2PE Listing. Major providers:
- Worldpay (Vantiv)
- Adyen
- Square
- Stripe Terminal
- Bluefin
- Verifone Verifone (Verisign integration)
- Many regional banks

### Step 2 — Procure POI devices
Solution provider ships pre-configured POI devices with embedded keys (Key Injection Facility process). Merchant cannot configure cryptographic settings.

### Step 3 — Asset management
PIM mandates:
- Device serial number tracking
- Visual inspection before use, after rotation
- Sign-in / sign-out logs for shared devices
- Tamper-evident packaging tracking
- Disposal procedures (return to provider, not discard)

### Step 4 — Operations
Merchant operates devices ONLY per PIM. Custom integrations (touching plain PAN) take you out of P2PE scope. Annual SAQ P2PE attestation; periodic re-validation as PIM changes.

## Common implementation pitfalls

- **3DS without exemption strategy** — high friction (every transaction challenged) loses sales
- **3DS 1.x persistence** — deprecated; ensure SDK upgraded to 2.x flows
- **P2PE without solution validation** — using "encrypted POI" that isn't PCI-listed doesn't qualify for SAQ P2PE
- **PIM deviation** — common: merchant writes integration that briefly handles cleartext PAN, breaking P2PE scope
- **Mixed POI fleet** — P2PE devices alongside non-P2PE devices means non-P2PE devices remain in scope; segmentation harder than expected
- **Encryption vs tokenisation confusion** — different mechanisms, different scope effects; combine carefully

## OPSEC for compliance team

- Validated P2PE solution lists are public; don't expose internal device serials
- 3DS infrastructure compromise = mass authentication-data exposure; treat ACS / 3DSS as Tier-0
- PIM compliance must be operationalised, not just documented; SOC monitors device tampering alerts
- P2PE encryption key compromise = full cleartext exposure; key custody documented and audited

## References
- [PCI 3DS Core Security Standard](https://www.pcisecuritystandards.org/document_library?category=3ds)
- [PCI P2PE Standards](https://www.pcisecuritystandards.org/document_library?category=p2pe)
- [PCI SSC P2PE Validated Solution Listing](https://www.pcisecuritystandards.org/assessors_and_solutions/point_to_point_encryption_solutions)
- [EMVCo 3DS specification](https://www.emvco.com/emv-technologies/3d-secure/)
- [EU PSD2 SCA Regulatory Technical Standards](https://www.eba.europa.eu/regulation-and-policy/payment-services-and-electronic-money/regulatory-technical-standards-on-strong-customer-authentication-and-secure-communication-under-psd2)

See also: [[building-a-pci-dss-program-practitioner]], [[pci-dss-4-implementation]], [[pci-dss-4-customised-approach]], [[pci-saq-selection-and-scoping]], [[pci-cardholder-data-flow-mapping]], [[pci-qsa-career-track]], [[oauth-modern-attacks]], [[fraud-and-payment-security]]
