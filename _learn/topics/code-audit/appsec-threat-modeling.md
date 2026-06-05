---
title: AppSec threat modeling
slug: appsec-threat-modeling
aliases: [threat-model-web-app, stride-pasta-vast]
---

{% raw %}

> **TL;DR:** Threat modeling is the discipline of mapping what the system does, what could go wrong, who would do it, and what the consequence is — before writing tests or audit checklists. The audit yield is much higher when you know what to look for. STRIDE is the most teachable framework; PASTA/VAST are more elaborate. This note is a practical walk-through, not a textbook.

## What it is
Threat modeling produces a structured artefact describing the system's attack surface and how mitigations map to attacker actions. Done early in design, it shapes architecture; done before audit, it focuses the audit; done after incident, it documents what was missed.

## When to do it
- New feature with crossing trust boundaries (auth flow change, payment integration, multi-tenancy).
- Pre-audit scoping for a non-trivial app.
- Post-incident retro.
- Quarterly review of critical systems.

## STRIDE (the workhorse)
For each component / data flow, ask:
- **S**poofing — can someone pretend to be someone they're not? (auth, identity)
- **T**ampering — can data be modified in unauthorised way? (integrity)
- **R**epudiation — can an actor deny they did it? (logging, auditability)
- **I**nformation disclosure — can sensitive data leak? (confidentiality)
- **D**enial of service — can the system be made unavailable? (availability)
- **E**levation of privilege — can a low-priv actor reach high-priv state? (authorization)

For each yes: what's the impact, what's the existing mitigation, what's the residual risk?

## Step-by-step workflow

### Step 1 — Map the system
- Draw a data-flow diagram: external entities, processes, data stores, data flows, trust boundaries (dashed lines).
- Two layers: high-level (services) and low-level (one feature).
- Tools: pen + paper, draw.io, [Threagile](https://threagile.io/), Microsoft Threat Modeling Tool.

### Step 2 — Identify assets
- What are you protecting? User data, money, intellectual property, system integrity, reputation.
- For each: who would target it, what's the worst case.

### Step 3 — Identify actors
- Anonymous internet user.
- Authenticated user.
- Premium user.
- Admin.
- Another tenant.
- Insider (employee, contractor).
- Compromised third-party (npm dep, OAuth provider).
- Network attacker (MitM).
- Physical attacker (lost device).

### Step 4 — Walk trust boundaries
- Each crossing is a checkpoint. What does crossing imply?
- Internet → DMZ: WAF, rate limit, DDoS protection.
- DMZ → app: auth check, authz check, input validation.
- App → DB: parameterised queries, least-priv DB user.
- App → external API: TLS, cert validation, key handling.
- App → user (response): output encoding, PII redaction.

### Step 5 — Apply STRIDE per component
For each component:
- Spoofing → how is the actor authenticated coming in?
- Tampering → what guarantees integrity on data in flight / at rest?
- Repudiation → what's logged?
- Information disclosure → what data leaves this component? Encrypted? Filtered?
- Denial of service → resource limits? Backpressure? Circuit breaker?
- Elevation of privilege → can an actor in this component reach a higher-priv component?

### Step 6 — Rank threats
- DREAD or simpler: impact (high/med/low) × likelihood (high/med/low).
- Or just: which would be a P0 if exploited? Those first.

### Step 7 — Mitigations
- For each top threat: what's the control? Is it implemented? Tested?
- Output: a backlog of "implement", "verify", "document".

## Common findings from threat modeling

### 1. Trust boundary not visible
- Service-to-service calls assumed authenticated by network position; service mesh missing.
- Fix: mTLS, signed JWTs between services.

### 2. Data exit without redaction
- Logs include user PII; analytics export raw events.
- Fix: filter at egress, not at log source.

### 3. Privilege chains
- User → admin via password reset that emails to attacker-controlled address (host-header injection).
- Internal API trusts gateway, gateway trusts auth proxy, auth proxy has a misconfig.

### 4. Missing repudiation logs
- Sensitive actions (refund, deletion, permission change) not logged with actor identity.
- Fix: append-only audit log for security-relevant events.

### 5. DoS via amplification
- Single endpoint triggers chain of N DB queries / M API calls.
- Fix: complexity caps, rate limit.

## Outputs

### Threat model document
- System overview.
- Diagrams.
- Asset inventory.
- Actor list.
- Per-component STRIDE table.
- Risk ranking.
- Mitigation backlog with owners + dates.

### Test plans
- For each top threat: a test that demonstrates the mitigation works.
- Integration / E2E tests; not unit.

### Audit scope
- Pass the threat model to the audit team. They know where to dig.

## Frameworks beyond STRIDE

### PASTA (Process for Attack Simulation and Threat Analysis)
- 7-stage process: define objectives, define tech scope, decompose app, analyse threats, identify weaknesses, model attacks, risk analysis.
- More elaborate; better for high-stakes systems (finance, healthcare).

### VAST (Visual, Agile, Simple Threat modeling)
- Designed for DevOps / many small models, scaling with team.
- ThreatModeler tool support.

### LINDDUN
- Privacy-focused (similar to STRIDE but for privacy threats).

### Attack trees
- Root: attacker goal. Branches: alternative methods. Leaves: concrete attacks.
- Good for one-off analysis of a specific high-value attack.

### MITRE ATT&CK (mapping, not modeling)
- Post-hoc framework. Useful to label threats: "this is T1566 Phishing." Helps coverage gap analysis vs detection.

## Anti-patterns

### "We're a small startup, we don't need this"
- Threat modeling is more important when small (fewer security people, scarce resources). One half-day exercise pays back tenfold.

### "We do STRIDE on every PR"
- Overkill. Reserve threat modeling for design-level decisions, not code-level. PR review handles code-level.

### "We have OWASP Top 10"
- Top 10 is a bug-class list. Threat model is the system-level view that determines which bug classes matter for your system.

### Output document never read
- Keep it short (10-30 pages). Update on major changes. Cross-reference from architecture docs.

## References
- [Microsoft Threat Modeling — STRIDE](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [Adam Shostack — *Threat Modeling: Designing for Security*](https://shostack.org/books/threat-modeling-book)
- [OWASP Threat Modeling cheatsheet](https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html)
- [Threagile (open-source tool)](https://threagile.io/)
- [LINDDUN — Privacy threat modeling](https://www.linddun.org/)
- See also: [[whitebox-to-exploit-methodology]], [[appsec-maturity-checklist]], [[api-threat-modeling]]

{% endraw %}
