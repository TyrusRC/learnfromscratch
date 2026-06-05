---
title: PQC migration — organisational risk
slug: pqc-migration-risk
aliases: [pqc-migration-risk, pqc-program-management]
---

> **TL;DR:** Migrating an organisation to post-quantum crypto is a multi-year programme, not a library upgrade. The risk surface during migration is broader than the eventual end-state: cryptographic agility bugs, partially-migrated chains, vendor-product gaps, and rushed decisions under regulatory pressure. Framework: inventory → prioritise by HNDL exposure → pilot → hybrid → full. Companion to [[post-quantum-crypto-attack-surface]] and [[appsec-maturity-checklist]].

## Why a migration programme, not a project

PQC touches:
- **Every TLS endpoint** — frontend, internal-service, third-party.
- **Every signing key** — code-signing, document-signing, JWT, SAML.
- **Every certificate authority** — private and public.
- **Every secure-storage primitive** — KMS, HSM, vault.
- **Every protocol** — SSH, IPsec, OpenVPN, message queues, gRPC.
- **Embedded devices** that may not be field-upgradeable.

For most enterprises, this is a 3–5 year programme requiring discovery, vendor coordination, and architectural changes.

## Risk axes during migration

### 1. Cryptographic-agility bugs

The application's code path must support multiple algorithms simultaneously. Common bugs:
- Hard-coded algorithm assumption breaks when PQC enabled.
- Negotiation-failure fallback re-enables classical without notice.
- Signature-verification accepts wrong algorithm (algorithm-confusion).
- Hybrid-mode implementations check only one half.

Many bugs match historical patterns ([[jwt-key-confusion]], [[saml-attacks]]).

### 2. Partially-migrated chains

A chain of trust spans multiple components. If half migrate and half don't:
- Cert chain has classical root → PQC intermediate → classical leaf — order matters.
- TLS server supports hybrid; CDN in front strips PQC; client downgraded.
- Mobile app pinned to classical CA fingerprint that's being rotated.

Test end-to-end after each migration step.

### 3. Vendor / product gaps

Many vendor products are slow to support PQC:
- HSM firmware — vendor-by-vendor adoption.
- Network appliances (load balancers, WAFs) — may not parse new TLS extensions.
- Mobile SDKs — embedded libraries lag.
- Industrial control systems — may never support PQC; planning for compensating controls required.

Inventory vendor support; budget replacement for products that won't migrate.

### 4. Regulatory and audit pressure

Several regulatory regimes are setting PQC milestones:
- **NSA CNSA 2.0** — US national-security systems.
- **NIST guidance** — federal civilian.
- **PCI DSS / financial-sector** — guidance evolving.
- **EU NIS2** — implicit through cryptography requirements.

Compliance deadlines force decisions. Rushed decisions = bugs.

### 5. Performance and capacity

PQC has larger keys / signatures / handshakes. At scale:
- TLS handshake size increases ~10x with PQC.
- Latency for handshake increases (depending on transport MTU).
- HSM throughput drops for ML-DSA vs RSA.
- Network capacity may need increases.

Load-test migration scenarios.

### 6. HNDL exposure shape

The migration **priority** depends on what an adversary could harvest *today* that's still valuable when quantum matures.

| Data lifetime | Action priority |
|---------------|-----------------|
| < 5 years (session data, short-lived contracts) | Low — likely safe |
| 5–10 years (typical PII) | Moderate — migrate this decade |
| 10+ years (medical, classified, identity, financial archives) | High — migrate now |
| Permanent (cryptographic identities, certificate authorities) | Critical — migrate first |

## Organisational framework

### Step 1 — Inventory

- Crypto-bill-of-materials (CBOM) — every algorithm in every component.
- Tools: vendor scanning (Wiz, Defender, etc. now have CBOM features), home-grown audit scripts.
- Includes hardware-bound keys, certs in long-lived hardware.

### Step 2 — Prioritise

- HNDL exposure scoring.
- Vendor support landscape.
- Migration cost (engineering, hardware, vendor renewal).

### Step 3 — Pilot

- Low-risk environment.
- Hybrid mode TLS.
- Hybrid signatures where supported.
- Capture metrics: latency, throughput, error rate.

### Step 4 — Crypto-agile architecture

- Refactor code that hard-codes algorithms.
- Wrap crypto calls behind an interface that supports algorithm swapping.
- Implement automated algorithm-rotation in cert issuance.

### Step 5 — Hybrid roll-out

- Hybrid TLS as default.
- Hybrid signature suites for new keys.
- Crypto-policy enforcement (CA-side, client-side).

### Step 6 — Phase out

- Block classical-only handshakes at network edge.
- Refuse to issue new classical certs.
- Vendor sunset for products that won't migrate.

### Step 7 — Re-validate

- Independent crypto audit.
- Penetration testing focused on algorithm-confusion / downgrade.
- HSM key-rotation drill.

## Common migration pitfalls

- **"We support PQC" claims** without specifying which suites / hybrid mode / which products.
- **TLS termination at one layer** but not at internal hops — partially-PQC chain.
- **Cert authority migration** without renewing every dependent system's trust store.
- **Mobile/embedded** ignored because "it's classical and that's fine for now" — HNDL risk.
- **Performance regression** not measured before production roll-out.

## What red teams will look for during migration

- **Negotiation downgrade** — force classical via protocol-level manipulation.
- **Algorithm confusion** in signing / verifying.
- **Implementation bugs** in fresh PQC code — likely targets for fuzzing.
- **Cert pinning to legacy** that prevents PQC adoption — break the pin.
- **Vendor-product PQC gaps** as wedges into the protected environment.

A purple-team exercise during migration is high-value.

## Defensive baseline

- Treat PQC migration as **CISO-level priority** not a crypto-team side project.
- Establish a **migration team** with engineering, compliance, vendor management.
- **Quarterly tracking** of progress against inventory.
- **Vendor pressure** through procurement contracts requiring PQC roadmap.
- **Industry collaboration** — many sectors have migration consortia worth joining.

## Workflow to study

1. Build a CBOM for a small project you control.
2. Identify the highest-HNDL-risk component.
3. Migrate that component to a hybrid PQC suite.
4. Test for downgrade / algorithm-confusion against your own implementation.
5. Document the migration playbook.

## Related

- [[post-quantum-crypto-attack-surface]] — technical class.
- [[appsec-maturity-checklist]] — organisational baseline.
- [[secrets-in-code-detection-patterns]] — adjacent.
- [[secure-sdlc-rollout-playbook]] — adjacent.

## References
- [NIST — migration to PQC project](https://www.nccoe.nist.gov/projects/migration-post-quantum-cryptography)
- [CISA — PQC roadmap](https://www.cisa.gov/quantum)
- [NSA — CNSA 2.0](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/3148990/)
- [ETSI PQC migration guidance](https://www.etsi.org/technologies/quantum-safe-cryptography)
- See also: [[post-quantum-crypto-attack-surface]], [[appsec-maturity-checklist]], [[secure-sdlc-rollout-playbook]]
