---
title: PCI DSS — cardholder data flow mapping and scoping
slug: pci-cardholder-data-flow-mapping
---

> **TL;DR:** Cardholder Data Flow Diagrams (CHDFDs) are the foundation of PCI DSS scope — every system, network segment, person, or process touching cardholder data is "in scope". Incomplete CHDFD = wrong scope = invalid compliance. PCI DSS 4.0 makes this explicit: Requirement 12.5.2 demands documented data flows reviewed at least annually + on change.

## What it is
A CHDFD traces cardholder data through your environment: every touchpoint, every component, every storage location, every transmission path. Output: a diagram (Visio, draw.io, Lucidchart) + an inventory + a narrative description.

CHD = Primary Account Number (PAN), Cardholder Name, Expiration Date, Service Code. Sensitive Authentication Data (SAD) = full track data, CVV/CVC, PIN/PIN block — never stored post-authorisation.

## Preconditions / where it applies
- Any entity subject to PCI DSS (merchants, service providers, software vendors with cardholder data exposure)
- Required for both SAQ and ROC paths
- Update trigger: any change to payment flow, new payment channel, system upgrade, new vendor

## Tradecraft — building a CHDFD

### Step 1 — Identify all payment channels
- E-commerce (web site, mobile app, in-app)
- POS terminals (in-person, mobile, MOTO)
- Telephone orders (call centre, IVR)
- Mail order
- Recurring billing
- Refunds / chargebacks workflow
- B2B invoicing with card-on-file
- Affiliate / partner channels

Each channel = potential CHD flow.

### Step 2 — Interview every channel owner
Have business owners walk you through the customer journey. Watch for:
- Where the customer enters card details (browser form, terminal keypad, phone read-out)
- What happens BEFORE submission (validation, formatting)
- What happens AFTER submission (transmission to processor, tokenisation, receipt)
- Any failure / retry paths (re-entry, manual entry by staff)
- Any storage (token, last-4, full PAN, customer record)
- Any access (logs, support tickets, audit records)

### Step 3 — Map the technical path
For each channel, document:
- Customer device → first server / device
- Internal hops (load balancer, WAF, app server, database, queue)
- Outbound to processor / gateway
- Return path (auth response, token, receipt)
- Storage destinations (database, log files, backups)
- Personnel access (devs, ops, support, finance)

### Step 4 — Document the data elements
Per touchpoint, specify which data elements appear:
- PAN — full, masked, tokenised, hashed?
- CVV — present in memory? Logs? Never stored post-auth.
- Track data — never stored.
- Expiry / cardholder name — frequently stored with PAN
- Encryption status at rest / in transit

### Step 5 — Identify scope boundary
The CDE (Cardholder Data Environment) is everything that stores, processes, transmits CHD, PLUS:
- Connected systems (could route, switch, or otherwise affect CDE security)
- Systems that share authentication, share networks, share trust
- Out-of-band management interfaces

Anything NOT meeting CDE criteria can be "out of scope" — but you must DEFEND that classification.

### Step 6 — Validate by walking it
Don't trust the diagram. Validate:
- Run a test transaction; trace packets through the network
- Tap each system; confirm CHD presence or absence with `grep`-style searches
- Check logs across the path for CHD leakage
- Penetration test segmentation between CDE and out-of-scope

## CHDFD inventory components

| Item | Examples |
|---|---|
| Payment channels | Web, mobile, terminal, MOTO, IVR |
| Network zones | Internet, DMZ, app tier, DB tier, mgmt VLAN |
| Devices | Customer browser, POI, load balancer, server, database, backup, archive |
| Applications | Web app, payment service, fraud check, accounting, CRM |
| Storage | Database, file share, log aggregator, backup, archive, message queue |
| Transmission | TLS endpoints, IPSec tunnels, API calls, async queues |
| People | Customer, customer service rep, dev, ops, finance, third-party auditor |
| Third parties | Acquirer, processor, gateway, tokenisation vendor, fraud service, hosting |
| Authentication boundary | SSO, vault, jump host |

## Hidden CHD locations (common audit findings)

- Debug logs catching cleartext PAN
- Database backups copied unencrypted to lower environments
- Email containing customer-emailed credit card screenshots
- Call recordings (customer reads card aloud)
- Chat transcripts and bot training data
- Screen recordings for QA
- Customer support tickets with attached redacted-but-not-really screenshots
- Browser memory dumps for crash analysis
- Network captures collected during incident response
- Old code branches with hardcoded test cards (live PANs sometimes appear in legacy tests)
- Salesforce / CRM custom fields used as "notes" with PAN inside
- Spreadsheets emailed between teams

PCI DSS Requirement 3.5 (cleartext PAN protection) + 12.5.1 (secure deletion when CHD no longer needed) cover these. Discovery during scoping = remediation BEFORE assessment.

## Tokenisation and scope reduction

If you replace PAN with a token at the earliest possible touchpoint and never see the real PAN again:
- Token storage is potentially out of scope (depending on tokenisation provider's PCI validation)
- Systems downstream of tokenisation deal only with the token
- Original PAN passes through a narrow "token boundary" to the vault

This is the most powerful scope reduction technique. Critical:
- Tokenisation must occur BEFORE storage, not after
- Tokens must be irreversibly disconnected from PAN within your environment
- Token vault provider must be PCI DSS validated (their AoC required)

## P2PE — even stronger reduction

PCI SSC Validated P2PE solutions encrypt CHD at the Point-of-Interaction (POI) device using approved key management. Decryption only at the processor. Your environment never sees cleartext PAN. SAQ P2PE drops requirements ~80%.

Caveat: P2PE works for in-person card-present transactions; less applicable to e-commerce.

## Annual review

PCI DSS 4.0 Requirement 12.5.2 requires CHDFD review at least annually + on significant change:
- New payment channel added
- New third party integrated
- Major application change
- Network re-architecture
- Acquisition / divestiture

Document review activities and findings. Auditors check the version history.

## Common implementation pitfalls

- **CHDFD created once, never updated** — stale within a year, useless within two
- **Missing call centre / refund / customer support paths** — these channels handle CHD in unobvious ways
- **Mobile app flow not mapped** — modern wallet payments (Apple Pay, Google Pay) have token flows; mapping them ensures correct scoping
- **Tokenisation flow not mapped through return path** — refunds via token may invoke detokenisation requiring scope expansion
- **Third party CHD touch not documented** — your service provider lifts the audit boundary into theirs; their PCI status matters
- **Network discovery vs CHDFD discrepancy** — automated scanners find systems on the network; CHDFD must explain each

## Tooling

- **draw.io / Lucidchart / Visio** — diagram authoring
- **DiagramSquared / Excalidraw** — collaborative real-time
- **Data discovery tools** — Spirion, DataSunrise, Macie, BigID find CHD in storage; useful for validating CHDFD completeness
- **Network discovery** — nmap, Lansweeper, ServiceNow CMDB inventory
- **DLP tools** — Symantec, Microsoft Purview, Forcepoint identify CHD in transit/at rest
- **Custom scripts** — `rg -P '\b(?:4\d{12}(?:\d{3})?|5[1-5]\d{14}|3[47]\d{13}|6(?:011|5\d{2})\d{12})\b'` to find PAN-format strings in code/logs (Luhn-check post-grep)

## OPSEC for compliance team

- CHDFD is sensitive: describes attack paths to data — TLP:AMBER internal
- Diagrams shared externally (e.g., with QSA) sanitised of internal IPs / hostnames where possible
- Inventory lists: maintain in version control; assessor reviews diffs
- CHD discovery results: remediate BEFORE documenting in audit-facing artifacts

## References
- [PCI DSS v4.0 Standard — Requirement 12.5.2](https://www.pcisecuritystandards.org/)
- [PCI SSC Scope and Segmentation Information Supplement](https://www.pcisecuritystandards.org/)
- [PCI SSC Tokenisation Product Security Guidelines](https://www.pcisecuritystandards.org/)
- [PCI P2PE program](https://www.pcisecuritystandards.org/document_library?category=p2pe)
- [Quentin Carlier — practical CHDFD diagramming](https://quentin-carlier.medium.com/) — community walkthroughs

See also: [[building-a-pci-dss-program-practitioner]], [[pci-dss-4-implementation]], [[pci-dss-4-customised-approach]], [[pci-saq-selection-and-scoping]], [[pci-3ds-and-p2pe-overlays]], [[iso-27002-2022-controls-catalog]], [[asset-management-easm-cmdb]]
