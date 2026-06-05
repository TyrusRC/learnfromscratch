---
title: Retail / e-commerce defender playbook
slug: retail-ecommerce-defender-playbook
aliases: [retail-defender, ecommerce-defender]
---

> **TL;DR:** Retail and e-commerce security teams live at the intersection of PCI DSS, consumer-privacy law, and a threat landscape dominated by Magecart-style client-side skimmers, credential-stuffing-driven account takeover (ATO), gift-card and loyalty fraud, and POS malware. The defining operational reality is the Q4 change freeze: from roughly mid-October through early January, you cannot deploy anything non-trivial, so the controls that matter are the ones already in place. This note is a practitioner playbook — what to actually do as a defender — and pairs with [[pci-dss-4-implementation]], [[aitm-evilginx-modern-phishing]], [[ueba-detection-ml-primer]], and the breach lessons in [[case-study-equifax-2017]] and [[case-study-lastpass-2022]].

## Why it matters

Retailers sit on three things attackers want simultaneously: live payment card data (PAN + CVV at checkout), large consumer-identity datasets (email, address, DOB, phone, loyalty balances), and stored value (gift cards, loyalty points, store credit). Stored value is particularly attractive because it is liquid, often non-reversible, and frequently outside the fraud team's traditional card-network controls.

The regulatory overlay multiplies the blast radius of any incident:

- **PCI DSS 4.0** — mandatory if you store, process, or transmit cardholder data. As of 31 March 2025, the future-dated requirements (including 6.4.3 and 11.6.1 for client-side script integrity) are in force. See [[pci-dss-4-implementation]] for the control rollout view.
- **GDPR** — any EU customer triggers 72-hour breach notification to the supervisory authority. See [[gdpr-incident-implications]].
- **CCPA / CPRA** — California consumer rights, statutory damages of USD 100-750 per consumer per incident for certain breaches under Cal. Civ. Code 1798.150.
- **US state breach laws** — all 50 states plus DC have notification statutes; thresholds, timelines, and AG-notice requirements vary. Multi-state retailers usually default to the strictest applicable timeline.
- **PSD2 / SCA** in Europe and emerging payment rules elsewhere shape what authentication you can require at checkout.

The combination means a moderate breach is rarely just a security incident — it is simultaneously a PCI forensic investigation (PFI), a privacy-regulator notification project, a class-action defence problem, and a brand crisis.

## Threat landscape

### Magecart and client-side script injection

Magecart is the umbrella name for crews injecting JavaScript skimmers into checkout pages, exfiltrating PAN, CVV, expiry, and billing details to attacker-controlled domains. Injection vectors include:

- Compromised first-party JS (CI/CD breach, S3 bucket misconfig, stolen admin creds).
- Compromised third-party tag (analytics, A/B test, chat widget, payment-page helper).
- Malicious fourth-party — a legitimate third party loading a compromised dependency.

PCI DSS 4.0 codifies the response: **6.4.3** requires an inventory of and integrity assurance for every script loaded on the payment page, and **11.6.1** requires a tamper-detection mechanism that alerts on unauthorised modifications to the payment page received in the consumer browser. See [[pci-dss-4-implementation]] for control mapping. Commercial vendors in this space include Akamai Page Integrity Manager, Imperva Client-Side Protection, Jscrambler, and Source Defense.

### Account takeover via credential stuffing

Attackers replay credentials harvested from third-party breaches against your login endpoints. ATO targets stored gift-card balances, saved payment methods, loyalty points, and order-history (for refund fraud and social engineering). Indicators include:

- Login traffic with unusually high failure rates from residential proxy ranges.
- High velocity from known bot infrastructure (BrightData, Oxylabs, IPRoyal egress).
- Time-of-day distribution that does not match your customer geography.

Mitigations layer: bot management, MFA on high-risk actions (not necessarily login — friction kills conversion), device fingerprinting, and behavioural anomaly scoring. See [[ueba-detection-ml-primer]] for the analytics approach.

### Gift-card and loyalty fraud

Gift-card enumeration (brute-forcing card numbers to find activated, non-zero balances) is rampant. Loyalty fraud includes points theft via ATO, merge-account fraud, and abuse of referral or sign-up bonuses. Fraud teams own much of this, but the security team owns the bot-control plane and the API authorisation logic that enables it.

### POS and store-network attacks

In-store POS remains a target via:

- RAM-scraping malware on Windows-based POS (the classic Target 2013 / Home Depot 2014 pattern).
- Compromise of remote-support tooling (the Target vector — HVAC vendor RMM access into the segmented payment network that was not actually segmented).
- Network-edge device compromise (printers, kiosks, digital signage) as pivot points.

Defensive baseline: segment POS networks ruthlessly, deny outbound internet from POS except to a tightly allowlisted set, enforce application allowlisting on POS endpoints, and log every interactive logon to POS servers.

### Adjacent: phishing of staff and partners

Customer-service and store-manager accounts are high-value targets for fraud-enabling access. Modern AiTM phishing (Evilginx, Tycoon2FA, Mamba2FA) defeats most MFA. See [[aitm-evilginx-modern-phishing]] and [[tycoon2fa-and-modern-phish-kits]]. The [[case-study-lastpass-2022]] writeup is a useful reminder that secondary access (a developer's home machine) can be the way into payment-relevant systems.

## Defensive baseline

### Client-side script protection

- **Inventory**: an authoritative list of every script that can execute on the payment page, with owner and business justification. Auto-discover via crawler and CSP report-uri.
- **Subresource Integrity (SRI)** for any first-party or pinnable third-party script.
- **Content Security Policy** in `Content-Security-Policy-Report-Only` first to catch breakage, then enforce. Use `script-src` allowlisting, `connect-src` to constrain exfil, `report-to` for telemetry.
- **Tamper detection**: a runtime sensor (commercial or homegrown) that compares observed DOM and network behaviour on the payment page against expected baselines and alerts on deviation. PCI 11.6.1.
- **Tag management discipline**: do not let marketing add tags directly to the payment page. The payment page is a regulated surface, not a campaign surface.

### Bot management

Mainstream commercial bot-management options include Akamai Bot Manager, Imperva Advanced Bot Protection, DataDome, Kasada, and HUMAN. Trade-offs:

- **Akamai / Imperva** — strong if you already run them as a CDN/WAF; mature device fingerprinting; can be heavy to tune.
- **DataDome** — strong on residential-proxy detection, JS challenge UX is reasonable.
- **Kasada** — aggressive obfuscation of client SDK, effective against off-the-shelf solvers, harder for attackers to reverse engineer.
- **HUMAN (formerly White Ops)** — strong ad-fraud heritage, useful where ATO bleeds into affiliate / referral fraud.

No vendor stops a well-resourced adversary indefinitely. The goal is to make automation expensive enough that attackers move to softer targets. See [[waf-bypass-research-deep]] for attacker-side context.

### POS and store-network

- Network segmentation with denylist-by-default and explicit egress allowlists.
- Application allowlisting (Microsoft WDAC, Airlock, or vendor-native) on POS.
- Centralised, tamper-evident logging from every POS endpoint and the in-store router.
- Vendor remote access via a jump host with session recording and MFA — never direct RDP/VNC.
- Annual physical inspection of POS terminals for skimmer overlays and shimmers.

### API authorisation for fraud-relevant endpoints

Treat the following as security-critical APIs, not just product APIs:

- Gift-card balance check and redemption.
- Loyalty points transfer and merge.
- Saved-payment-method listing.
- Order-history read (refund-fraud reconnaissance).
- Address-book edit (refund redirection).

Apply per-endpoint rate limits, anomaly scoring, and step-up auth on sensitive actions. Log enough to reconstruct an ATO investigation.

### Third-party / SaaS vendor risk

Retail tech stacks are sprawling — OMS, ERP, CRM, ESP, CDP, review platform, chat, analytics, A/B testing, recommendation engine, search, fraud, payment, tax, shipping. Each one is a potential supply-chain vector. Practical controls:

- Maintain a payment-page-adjacent vendor inventory separate from the general vendor list.
- Require SOC 2 Type II or equivalent ([[soc2-vs-iso27001]]) for vendors touching customer data or scripts.
- Contractually require breach notification within a timeline that lets you meet your own regulatory clock (24-48 hours is reasonable; 72 hours is too late).
- For vendors loading code into the browser, require SRI support, CSP-friendly delivery, and pre-notification of script changes.

## Holiday peak reality

Q4 dominates the retail calendar. Typical change-freeze window runs from around **mid-October through 6 January** (US) — earlier and longer for retailers with significant pre-Black-Friday traffic. During freeze:

- No production deploys except security and stability fixes with executive sign-off.
- On-call coverage scales up; security joins the war-room rotation alongside SRE.
- Incident-response runbooks are exercised in September (tabletop) and frozen in October.
- Detection content authored before freeze is the detection content you have. Plan content investments around the freeze.
- Vendor changes follow the same rules — push back on third parties trying to ship a CDN change on Black Friday.

The implication for planning: anything you want in place for peak must be production-stable by **end of September**, with a buffer for late-October hot-fix cycles. This drives an annual cadence that is unusual relative to other industries.

## Fraud-team and security-team coordination

In many retailers, fraud and security report to different executives (fraud often under finance or CX, security under the CIO or a CISO). Friction points:

- **Signal sharing**: fraud sees the financial impact of ATO; security sees the authentication telemetry that explains it. Neither has the full picture alone.
- **Bot management ownership**: usually security owns the platform, fraud owns the rule-tuning for transaction abuse. This works if both sides actually meet.
- **Customer-friction trade-offs**: security wants step-up auth; fraud wants approval rates; marketing wants conversion. Establish a forum (weekly is fine) where the trade-off is made explicitly, not by whoever shouts loudest.
- **Incident ownership**: a card-data breach is security-led with fraud consulting; a refund-fraud spike is fraud-led with security consulting. Write this down before you need it.

## Workflow to study

1. Read PCI DSS 4.0 in full, paying particular attention to 6.4.3, 11.6.1, 8.x (auth), 10.x (logging), and the customised-approach option. Cross-reference [[pci-dss-4-implementation]].
2. Pull your own production payment page and inventory every script, every network call, and every cookie. Map each to a business owner.
3. Stand up CSP in report-only mode for two weeks; review reports; harden to enforcing.
4. Stand up SRI for every pinnable script. Document what cannot be pinned and why.
5. Pilot a tamper-detection product (commercial or build a thin sensor) on the payment page.
6. Walk the ATO data flow from edge (CDN, WAF, bot manager) through login service to downstream fraud signals. Identify where you cannot reconstruct an attack.
7. Run a tabletop on a Magecart-style breach: detection, containment, PFI engagement, customer notification, regulator notification timelines, board comms.
8. Do the same tabletop for a credential-stuffing-driven gift-card drain.
9. Sit with the fraud team for a day during a normal Tuesday and a day during Cyber Monday simulation.
10. Review the post-mortems from [[case-study-equifax-2017]], [[case-study-capital-one-2019]], and [[case-study-lastpass-2022]] for transferable lessons.

## Related

- [[pci-dss-4-implementation]]
- [[gdpr-incident-implications]]
- [[soc2-vs-iso27001]]
- [[aitm-evilginx-modern-phishing]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[waf-bypass-research-deep]]
- [[ueba-detection-ml-primer]]
- [[siem-detection-use-case-catalog]]
- [[detection-engineering-pyramid-of-pain]]
- [[case-study-equifax-2017]]
- [[case-study-lastpass-2022]]
- [[case-study-capital-one-2019]]
- [[ransomware-affiliate-playbook]]

## References

- PCI Security Standards Council, "PCI DSS v4.0.1" — https://www.pcisecuritystandards.org/document_library/
- OWASP, "Magecart / Client-Side Security" guidance — https://owasp.org/www-project-top-ten/
- MDN, "Content Security Policy (CSP)" — https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
- MDN, "Subresource Integrity" — https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity
- US FTC, "Data Breach Response: A Guide for Business" — https://www.ftc.gov/business-guidance/resources/data-breach-response-guide-business
- ENISA, "Threat Landscape for Supply Chain Attacks" — https://www.enisa.europa.eu/publications/threat-landscape-for-supply-chain-attacks
