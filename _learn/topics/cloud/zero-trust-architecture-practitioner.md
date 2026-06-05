---
title: Zero Trust architecture — practitioner playbook
slug: zero-trust-architecture-practitioner
aliases: [zero-trust-architecture, zta-practitioner]
---

> **TL;DR:** Zero Trust Architecture (ZTA) is not a product — it is an operating model that replaces implicit network trust with continuous, explicit, identity-and-context-driven verification. NIST SP 800-207 defines the reference model (policy engine + policy administrator + policy enforcement point), and CISA's Zero Trust Maturity Model (ZTMM) breaks the journey into pillars (identity, device, network, application/workload, data) with traditional → initial → advanced → optimal stages. Real programs take 3–5 years, depend heavily on identity hygiene ([[cloud-identity-mental-model]]) and ZTNA replacing flat VPNs ([[ztna-vs-vpn-migration]] and [[identity-aware-proxy-deep]]), and live or die based on whether you can survive modern AiTM phishing ([[aitm-evilginx-modern-phishing]]) and conditional-access bypasses ([[conditional-access-bypass-modern]]). This note is the practitioner's roadmap, written assuming you have a real org, real legacy, and a real budget — not a Gartner slide.

## Why it matters

The perimeter model assumed: corporate network = trusted, internet = hostile. That model is dead. Users work from coffee shops, workloads run in three clouds, contractors need scoped access, SaaS holds the crown jewels, and attackers who phish one user pivot freely east-west through flat VLANs (see [[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]], [[case-study-lastpass-2022]]).

Zero Trust says: **trust nothing implicitly, verify every request, and assume breach has already happened**. Done well it shrinks blast radius, kills lateral movement, and gives you the telemetry to detect what slipped past prevention. Done badly it is an expensive VPN replacement with a new logo.

Regulators are starting to require it in spirit if not name — US Executive Order 14028 mandates federal ZTA, [[nis2-implementation]] expects strong access control and segmentation, DORA expects continuous verification, and [[pci-dss-4-implementation]] increasingly aligns with ZT principles (per-session auth, MFA everywhere, segmentation as a control rather than a perimeter).

## Core principles

### Never trust, always verify

Every access request is authenticated and authorized based on **all available signals** — identity, device posture, location, behavior, time of day, sensitivity of the resource. No "I'm on the corp network so let me in." Network location is one signal, not a passport.

### Least privilege, per session

Access is granted for the **minimum scope** needed and for the **shortest time** needed. Standing admin is a smell. Just-in-time elevation, scoped tokens, per-app access (not "VPN into the whole flat network") are the patterns. Pair with [[authorization-patterns-rebac-abac]] for fine-grained authorization decisions inside apps.

### Assume breach

Design as if the attacker is already inside. That means micro-segmentation between workloads, encryption in transit and at rest, strong audit logging, and detection content tuned to **east-west** movement — not just north-south. See [[detection-engineering-pyramid-of-pain]] and [[siem-detection-use-case-catalog]].

### Explicit verification with context

Every decision is **dynamic**, based on current signals — not "you logged in at 9am so you're trusted all day." Continuous evaluation, step-up auth on sensitive actions, session revocation when posture degrades.

## NIST SP 800-207 reference architecture

NIST's logical model has three core components:

| Component | Role |
|---|---|
| **Policy Engine (PE)** | Brain. Computes the trust algorithm: given subject + resource + signals, grant / deny / step-up. |
| **Policy Administrator (PA)** | Operator. Establishes/tears down the session, issues tokens, signals PEP. |
| **Policy Enforcement Point (PEP)** | Bouncer. Actually intercepts the request and enforces the PE's decision. |

Supporting telemetry: CDM (continuous diagnostics & mitigation), threat intel ([[cti-collection-management]]), identity store, PKI, SIEM, activity logs, data classification.

The **trust algorithm** can be score-based (sum signals, threshold) or criteria-based (hard rules). Production systems are usually a mix: hard rules first (block jailbroken devices, block known-malicious IPs), then dynamic scoring (anomaly distance from baseline, recent compromise indicators) — see [[ueba-detection-ml-primer]] for the analytics side.

## Identity-centric vs network-centric implementations

NIST recognizes a few flavors:

- **Identity / enhanced governance** — IdP is the brain, every app integrates with SSO, conditional access decides per-request. Works well for SaaS-heavy orgs. This is the Okta/Entra/Ping pattern. See [[cloud-identity-mental-model]].
- **Micro-segmentation** — agent or fabric (NSX, Illumio, Cilium, eBPF) enforces L4–L7 policy between workloads. Strong for data centers and on-prem; harder politically because it touches every team.
- **Software-defined perimeter (SDP) / ZTNA** — broker mediates per-app access; user device connects to broker, broker connects to app. Replaces VPN. See [[ztna-vs-vpn-migration]] and [[identity-aware-proxy-deep]].

Real programs combine all three. There is no single "ZT product."

## Key building blocks

### Strong identity and phishing-resistant MFA

ZT collapses without an authoritative IdP. Consolidate to one (or as few as politics allow), enforce **phishing-resistant** MFA (FIDO2, platform passkeys, smartcards) — not SMS, not push fatigue ([[mfa-fatigue-tradecraft]]). Eliminate legacy auth (basic auth, IMAP, POP, ROPC), and watch for OAuth device-code abuse ([[oauth-device-code-phishing-m365]]) and AiTM kits ([[aitm-evilginx-modern-phishing]], [[tycoon2fa-and-modern-phish-kits]]). Understand [[conditional-access-bypass-modern]] before you trust your CA policies.

### Device posture and trust

Only managed, healthy devices get access to sensitive resources. Posture = OS version, patch level, EDR running, disk encryption, no jailbreak/root. MDM/UEM (Intune, Jamf, Kandji) issues device certificates; conditional access checks them at every session. BYOD gets a more limited slice (browser-only, no token persistence).

### Micro-segmentation

Default-deny between workloads. Allow lists by identity-of-workload (SPIFFE/SVID, service accounts) — not IPs. In Kubernetes, NetworkPolicy + service mesh (Istio, Linkerd, Cilium). On VMs, host firewalls + identity-based agents. Avoid the trap of "we segmented prod from dev" — true micro-seg is per-service.

### Encryption everywhere

mTLS between services, TLS 1.2+ for everything user-facing, encryption at rest with managed keys (KMS, HSM-backed). Stop carving exceptions for "internal" traffic.

### Continuous verification

Sessions are re-evaluated continuously. Token lifetimes are short. Step-up on sensitive actions (export data, change config, access PHI). Revoke on posture change. CAEP (Continuous Access Evaluation Protocol) and OpenID Shared Signals push this further.

### Data-centric controls

Classify data, tag it, enforce policy on access regardless of where it lives (DLP, IRM, CASB). The data pillar is the hardest and most often skipped.

## CISA Zero Trust Maturity Model (ZTMM)

Five pillars × four stages (traditional → initial → advanced → optimal), with three cross-cutting capabilities (visibility & analytics, automation & orchestration, governance).

| Pillar | Traditional | Optimal |
|---|---|---|
| **Identity** | Passwords, per-app local accounts | Phishing-resistant MFA, continuous validation, JIT, risk-based |
| **Device** | Unmanaged, no inventory | Real-time posture, compliance enforced per request |
| **Network** | Flat, VPN | Micro-segmented, ZTNA, encrypted, identity-aware east-west |
| **App / workload** | Monoliths, perimeter auth | Per-API authz, workload identity, runtime protection |
| **Data** | Untagged, shared drives | Classified, tagged, policy-enforced regardless of location |

Use this as a self-assessment tool, not a scorecard for a vendor. Most orgs honestly start at "initial" across the board and aim for "advanced" in 3–5 years.

## Realistic transformation roadmap

### Year 0 — strategy and baseline

- Executive sponsor (CIO/CISO joint), measurable goals, budget reality.
- Inventory: users, devices, apps, data, identities (service accounts especially), network paths.
- Pick a target architecture (identity-centric / ZTNA / micro-seg mix).
- ZTMM self-assessment per pillar.
- Pick 2–3 pilot apps (one SaaS, one internal web, one legacy thick-client).

### Year 1 — identity and access foundation

- IdP consolidation, SSO for top 80% of apps by usage.
- Phishing-resistant MFA rollout starting with admins.
- Conditional access baseline (block legacy auth, require compliant device for sensitive apps).
- Kill long-lived service account passwords; move to workload identity.
- ZTNA pilot replacing VPN for the pilot apps. See [[ztna-vs-vpn-migration]].

### Year 2 — device and network

- Universal MDM/UEM enrollment, posture signals into CA.
- ZTNA expanded; VPN sunset planned.
- Begin micro-segmentation in highest-value zones (PCI, regulated data, crown-jewel apps).
- DNS and egress controls (block C2 categories, log everything).

### Year 3 — application, workload, data

- Workload identity (SPIFFE, cloud IAM) across services.
- Service mesh / sidecar mTLS in modern stacks.
- Data classification, DLP / CASB enforcement on top apps.
- Continuous evaluation (CAEP) where supported.

### Year 4+ — optimization and continuous improvement

- Automated policy generation from behavior baselines.
- Detection coverage tied to ZT signals ([[detection-engineering-pyramid-of-pain]]).
- Purple-team validation that ZT controls actually stop modeled attacks ([[purple-team-feedback-loop]], [[atomic-red-team-emulation-deep]]).

## Common pitfalls (be honest)

- **"We have ZTNA, we are Zero Trust."** No. ZTNA is one PEP. You still need identity, device, segmentation, data.
- **Calling the existing VPN "zero trust."** Slapping MFA on a flat-network VPN is not ZT. If a compromised laptop can scan the /16, you are not there.
- **Buying point tools without a strategy.** Every vendor sells "Zero Trust." Without a target architecture and pillar plan, you collect overlapping tools and an angry CFO.
- **Ignoring legacy.** Mainframes, OT, medical devices, that one app from 2008 — they do not speak modern auth. Plan compensating controls (jump hosts with full session recording, dedicated segments, broker proxies) rather than pretending they will magically integrate.
- **Identity hygiene gap.** ZT amplifies identity. If your IdP is messy (orphan accounts, shared admins, weak service accounts), ZT makes those vulnerabilities load-bearing. Clean first.
- **No detection content for the new model.** East-west traffic now flows through identity-aware brokers; if your SIEM is still grepping firewall logs, you blinded yourself. See [[siem-detection-use-case-catalog]].
- **Politics.** Network team, identity team, app teams, infosec — ZT crosses all four. Without an exec mandate and shared OKRs, it stalls at the org boundary.
- **MFA bypass via AiTM / token theft.** Plan for it. Phishing-resistant factors, token binding, short lifetimes, anomaly detection on token replay. ([[aitm-evilginx-modern-phishing]], [[conditional-access-bypass-modern]]).

## Measurable outcomes

If you cannot measure it, you cannot claim progress. Useful metrics:

- % of apps behind SSO + MFA + CA.
- % of users on phishing-resistant MFA (admins first, target 100%).
- % of devices with real-time posture signal.
- % of east-west traffic covered by micro-segmentation policy in default-deny.
- VPN concurrent users (target: decreasing → zero).
- Time to revoke access on termination (target: minutes).
- Mean blast radius from tabletop / purple-team exercise ([[tabletop-exercise-design-and-execution]]) — measured before vs after.
- Detection coverage mapped to ATT&CK lateral movement and credential access techniques.

## Workflow to study

1. Read NIST SP 800-207 cover to cover — it is short and the only authoritative reference.
2. Read CISA ZTMM v2 and do an honest self-assessment of your org across the five pillars.
3. Read [[cloud-identity-mental-model]] and [[ztna-vs-vpn-migration]] and [[identity-aware-proxy-deep]] — the identity + access layer is where 70% of value comes from.
4. Build a one-page target architecture diagram with PE / PA / PEP labelled for your environment.
5. Pick three pilot apps and write the per-app policy (subject, signals, decision, PEP).
6. Walk an AiTM phishing scenario ([[aitm-evilginx-modern-phishing]]) through your design — does ZT actually stop it, or just slow it down? Add CAEP / token binding if not.
7. Tabletop a ransomware scenario ([[ransomware-affiliate-playbook]]) — measure blast radius with and without segmentation.
8. Read case studies of failures: [[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]], [[case-study-lastpass-2022]]. Identify which ZT control would have prevented or contained each.

## Related

- [[ztna-vs-vpn-migration]]
- [[identity-aware-proxy-deep]]
- [[cloud-identity-mental-model]]
- [[conditional-access-bypass-modern]]
- [[aitm-evilginx-modern-phishing]]
- [[mfa-fatigue-tradecraft]]
- [[oauth-device-code-phishing-m365]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[cloud-iam-misconfig-patterns]]
- [[authorization-patterns-rebac-abac]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[ueba-detection-ml-primer]]
- [[purple-team-feedback-loop]]
- [[atomic-red-team-emulation-deep]]
- [[tabletop-exercise-design-and-execution]]
- [[nis2-implementation]]
- [[pci-dss-4-implementation]]
- [[case-study-snowflake-2024]]
- [[case-study-okta-2023-support-system]]
- [[case-study-lastpass-2022]]
- [[ransomware-affiliate-playbook]]

## References

- NIST SP 800-207, Zero Trust Architecture — https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf
- CISA Zero Trust Maturity Model v2 — https://www.cisa.gov/zero-trust-maturity-model
- NIST NCCoE Implementing a Zero Trust Architecture (SP 1800-35) — https://www.nccoe.nist.gov/projects/implementing-zero-trust-architecture
- US Executive Order 14028 on Improving the Nation's Cybersecurity — https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/
- OMB M-22-09, Federal Zero Trust Strategy — https://www.whitehouse.gov/wp-content/uploads/2022/01/M-22-09.pdf
- DoD Zero Trust Reference Architecture — https://dodcio.defense.gov/Portals/0/Documents/Library/(U)ZT_RA_v2.0(U)_Sep22.pdf
