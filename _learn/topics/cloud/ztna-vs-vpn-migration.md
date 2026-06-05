---
title: ZTNA vs VPN — migration practitioner notes
slug: ztna-vs-vpn-migration
aliases: [ztna-migration, vpn-replacement]
---

> **TL;DR:** Zero Trust Network Access (ZTNA) replaces the legacy "VPN puts you on the LAN" model with per-application brokered access tied to identity, device posture, and policy. The migration is rarely a flip-the-switch event — it is a 12 to 24 month program that runs the VPN in parallel while you broker apps one at a time. Companion reading: [[zero-trust-architecture-practitioner]], [[identity-aware-proxy-deep]], [[conditional-access-bypass-modern]], and the supply-chain horror story in [[case-study-3cx-supply-chain]].

## Why it matters

Legacy SSL VPNs (Fortinet FortiGate / FortiClient, Ivanti Connect Secure formerly Pulse Secure, Citrix NetScaler/ADC, Cisco AnyConnect) have become one of the most reliably exploited initial-access vectors of the 2023 to 2026 era. A non-exhaustive parade:

- Ivanti Connect Secure: CVE-2023-46805 + CVE-2024-21887 (auth bypass + command injection chain, mass exploited Jan 2024), CVE-2025-0282 (stack overflow, pre-auth RCE).
- Fortinet FortiOS SSL VPN: CVE-2022-42475, CVE-2023-27997, CVE-2024-21762, CVE-2024-55591 (auth bypass), CVE-2025-24472.
- Citrix NetScaler: CVE-2023-3519 ("Citrix Bleed" lite — pre-auth RCE), CVE-2023-4966 ("Citrix Bleed" — session token theft), CVE-2025-5777 ("Citrix Bleed 2").
- Cisco ASA / FTD: CVE-2024-20481 (DoS abused for password spray), CVE-2025-20333/20362 (the "ArcaneDoor" follow-ups).

The pattern is consistent: internet-exposed appliance, pre-auth bug, ransomware operator or state actor inside the LAN within days. Even when patched promptly, the architectural model is the problem — once you authenticate to the VPN, you are "on the network" and lateral movement is a routing decision. ZTNA collapses that blast radius: you connect to an identity-aware broker, the broker proxies one app, and the rest of the network is not even reachable.

This note is about the **migration program**, not the marketing brochure. See [[zero-trust-architecture-practitioner]] for the broader Zero Trust mental model and [[cloud-identity-mental-model]] for the IdP plumbing that makes any of this work.

## Architectural differences

### Legacy VPN model

- User authenticates to a concentrator at the network edge.
- Concentrator pushes a route table or assigns an IP from an internal pool.
- User device behaves as if cabled into the corporate LAN — full L3/L4 reachability to whatever the firewall lets through (which, in practice, is usually "most of it").
- Posture checks (if any) happen once at connect time.
- Trust decision is **binary and durable**: you are in, or you are out, for the session lifetime.

### ZTNA model

- User authenticates to an identity-aware broker (cloud-hosted or self-hosted connector).
- Broker evaluates **per-request**: who (IdP claims, MFA, group), what device (managed? EDR healthy? disk encrypted? OS patched?), what app, from where, at what time.
- Only the specific app's traffic is tunnelled. The rest of the corporate network is invisible — there is no route to it.
- The "network" is effectively deleted as a security boundary; identity + device + app become the boundary.
- Connectors live near the app (in the VPC, in the on-prem DC) and dial **outbound** to the broker. No inbound listener on the internet.

This is the same architectural shift discussed in [[identity-aware-proxy-deep]] — Google's BeyondCorp / IAP was the canonical implementation, and most ZTNA vendors are now re-implementations of that idea.

## ZTNA vendor landscape

Honest take, late-2025-ish:

- **Zscaler Private Access (ZPA)** — the enterprise default. Mature, expensive, app-discovery is strong. Operational model is heavy (App Connectors, ZIA pairing, segmentation policies). Best fit if you already have ZIA for SWG.
- **Cloudflare Access (part of Cloudflare One)** — strongest developer ergonomics, fastest to pilot, generous free tier, excellent for browser-based and SSH/RDP apps. Weaker for thick-client legacy apps. WARP client posture is improving but historically lighter than Zscaler.
- **Tailscale** — WireGuard-based mesh, beloved by engineering orgs. Identity-aware ACLs ("tailnet policy"), device posture via integrations. Sells itself as ZTNA but is closer to "modern VPN with identity ACLs" — which for many orgs is exactly the right answer.
- **Twingate** — similar shape to Tailscale, more enterprise-y polish, agentless options.
- **Palo Alto Prisma Access** — SASE play, deep integration with NGFW policy, strong for orgs that are already Panorama-shop. Heavyweight.
- **Netskope Private Access** — strong DLP-and-CASB story bundled; SASE positioning.
- **Cato Networks** — single-vendor SASE, ZTNA + SD-WAN + FWaaS. Good for mid-market that wants one throat to choke.
- **Microsoft Entra Private Access** — the dark horse. If you are already an E5 shop, this is "included" and integrates with Conditional Access (see [[conditional-access-bypass-modern]] for how attackers think about CA). Maturity behind ZPA but catching up fast.

Vendor marketing claim to discount: "agentless ZTNA." It works for HTTP(S) apps via a reverse-proxy mode, but thick-client apps (SMB, SQL, legacy fat clients) still need an agent. Anyone telling you otherwise is selling you a browser isolation product and calling it ZTNA.

## Migration phases (realistic)

### Phase 0 — Inventory and discovery (1 to 3 months)

- Enumerate every app reachable over VPN today. NetFlow / firewall logs / VPN concentrator logs are your friend.
- Classify by protocol (HTTP, SSH, RDP, SMB, thick-client TCP, UDP), criticality, and user population.
- Identify the long tail: vendor remote-support tools, kiosk dial-homes, IoT/OT bridges, the one Access database that runs payroll.
- Map app owners. You will need them.

### Phase 1 — Pilot (1 to 2 months)

- Pick a friendly user group (IT, security, a sympathetic engineering team).
- Pick 3 to 5 apps that are easy wins: internal wikis, Git servers, Jenkins/CI, an HR portal.
- Stand up broker + connectors in parallel with VPN. Both work; users opt in.
- Measure: latency vs VPN, support tickets, login flow friction.

### Phase 2 — App-by-app brokering (6 to 12 months)

- Work through the app inventory in priority order. Each app gets:
  - A connector deployed near it.
  - An access policy (IdP group, MFA strength, device posture requirements).
  - Owner sign-off and a user comms note.
- Track a burn-down chart of "apps still requiring VPN." Show it to the CISO weekly.
- Hard apps go to a parking lot for Phase 4.

### Phase 3 — Contractor and vendor access (parallel with Phase 2)

- This is often where ZTNA pays for itself fastest. VPN access for contractors is a perennial nightmare: provisioning, deprovisioning, over-broad access, shared accounts.
- ZTNA lets you grant scoped, time-bound, app-specific access to an external identity (often via [[third-party-risk-management-practitioner]] vendor onboarding) without ever putting them on your LAN.
- Vendor remote-support tools (BeyondTrust, TeamViewer, ScreenConnect) — broker them or replace them. See [[case-study-3cx-supply-chain]] for why "trusted vendor with persistent network access" is now a board-level risk.

### Phase 4 — Long tail and VPN sunset (3 to 6 months)

- Address the parking lot: legacy fat clients, kiosks, IoT, OT bridges.
- For genuine holdouts, keep a **minimal VPN** as a contained legacy enclave with aggressive egress controls and short-fuse MFA.
- Communicate the VPN shut-off date. Move it once if you must. Do not move it twice.
- Decommission concentrators. Remove them from the internet. Celebrate.

## Gotchas

- **Thick-client legacy apps** — Anything that does dynamic port allocation (old SAP GUI, some Oracle clients, FTP active mode) will fight the broker. Test early.
- **Kiosks and shared devices** — Identity-bound access assumes a user. Kiosks usually need a service identity + device cert + IP allowlist on the connector side.
- **IoT and OT** — Cameras, badge readers, PLCs do not run agents. Use connector-side allowlists, micro-segmentation, and accept that these stay on a segmented VLAN. See [[manufacturing-ot-defender-playbook]].
- **MDM / posture gaps** — If your device posture signal is weak (no MDM, no EDR, BYOD-heavy), ZTNA degrades to "VPN with MFA." Fix the device story first or in parallel.
- **Split DNS and certificate pinning** — Some apps hard-code internal hostnames or pin certs. Brokered access through a different hostname/cert breaks them. Plan for re-issuance or hostname aliasing.
- **VoIP / SIP / real-time** — UDP-heavy real-time protocols are awkward over most ZTNA brokers. Often left on VPN or moved to cloud telephony.
- **Auditors** — Compliance frameworks (PCI, SOC 2, ISO 27001) still talk in terms of "network segmentation." You will need to map ZTNA controls to their language. See [[building-a-pci-dss-program-practitioner]] and [[building-an-iso27001-isms-practitioner]].
- **Break-glass** — Plan how an admin gets in when the broker itself is down. Usually a tiny VPN or out-of-band console access path. Document it.

## Defensive baseline

Even mid-migration, do these now:

- Patch SSL VPN appliances within 48 hours of vendor advisories. Treat any Fortinet/Ivanti/Citrix CVE as critical until proven otherwise.
- Move VPN authentication behind your IdP with **phishing-resistant MFA** (FIDO2 / passkeys, not SMS, not push). See [[mfa-fatigue-tradecraft]] and [[aitm-evilginx-modern-phishing]] for why.
- Enforce device certificates on VPN clients — raises the bar past stolen-credential reuse.
- Log every VPN session to SIEM with user, device, source IP, geo. Hunt for impossible-travel and concentrator-side anomalies. See [[siem-detection-use-case-catalog]].
- Egress filter from VPN client pools — no, your VPN users do not need to SSH to arbitrary internet hosts.
- On the ZTNA side: harden the connectors (they are now your trust boundary), monitor broker admin actions, alert on policy changes.

## Workflow to study

1. Read the BeyondCorp papers (Google, 2014 to 2018) — the canonical ZTNA reference.
2. Read NIST SP 800-207 (Zero Trust Architecture) cover to cover. Map its components to your chosen vendor.
3. Spin up a free tier of Cloudflare Access or Tailscale at home. Broker access to a Raspberry Pi or home NAS. Feel the latency, the policy model, the device posture flow.
4. Read the CISA advisories on Ivanti, Fortinet, Citrix VPN exploitation from 2023 to 2025. Internalize how fast pre-auth-RCE becomes ransomware.
5. Shadow one app migration end-to-end at work: discovery, owner conversation, connector deploy, policy authoring, user comms, cutover, ticket triage.
6. Build the burn-down dashboard. Present it. This is the artifact a CISO actually wants. See [[ciso-vciso-track]].
7. Run a tabletop where the VPN concentrator is the initial-access vector. See [[tabletop-exercise-design-and-execution]].

## CISO talking points

When you pitch this program to a board or exec team:

- "Our VPN is internet-exposed pre-auth attack surface. Every Fortinet/Ivanti/Citrix CVE in the last three years has been mass-exploited within days. We are one missed patch from ransomware initial access."
- "VPN gives any authenticated user network reachability to most internal apps. ZTNA gives one user access to one app, evaluated per request."
- "Contractor and vendor access is currently expensive to provision and dangerous to leave provisioned. ZTNA scopes it and expires it automatically."
- "This is a 12 to 24 month program, parallel-run, not rip-and-replace. Cost is roughly $X/user/year for the broker plus internal engineering effort. ROI is reduced lateral-movement blast radius (insurance lever), reduced helpdesk load for VPN issues, faster contractor onboarding."
- "We will keep a minimal VPN for genuine legacy holdouts and break-glass. The goal is not 'zero VPN' on day one — it is 'VPN is no longer the primary access path.'"

Do **not** promise: "ZTNA eliminates ransomware." It does not. It shrinks the blast radius and removes one of the top initial-access vectors. The phishing/MFA/EDR/patch story still has to work too.

## Measurement

Track and report monthly:

- Apps brokered via ZTNA vs apps still requiring VPN (burn-down).
- Active VPN users / sessions (should trend down).
- p95 login latency for top 10 apps (compare VPN baseline vs ZTNA).
- Helpdesk tickets tagged "remote access" (should trend down after Phase 2).
- Time-to-provision contractor access (should drop from days to minutes).
- Number of internet-exposed remote-access appliances (target: 0 or 1 break-glass).
- Posture compliance rate among ZTNA-connecting devices (encryption on, EDR healthy, OS within N versions of latest).

## Related

- [[zero-trust-architecture-practitioner]]
- [[identity-aware-proxy-deep]]
- [[conditional-access-bypass-modern]]
- [[case-study-3cx-supply-chain]]
- [[cloud-identity-mental-model]]
- [[mfa-fatigue-tradecraft]]
- [[aitm-evilginx-modern-phishing]]
- [[third-party-risk-management-practitioner]]
- [[manufacturing-ot-defender-playbook]]
- [[siem-detection-use-case-catalog]]
- [[ciso-vciso-track]]
- [[tabletop-exercise-design-and-execution]]
- [[building-an-iso27001-isms-practitioner]]
- [[building-a-pci-dss-program-practitioner]]

## References

- NIST SP 800-207, Zero Trust Architecture: https://csrc.nist.gov/publications/detail/sp/800-207/final
- Google BeyondCorp papers: https://research.google/pubs/?area=security-privacy-and-abuse-prevention&team=beyondcorp
- CISA advisory on Ivanti Connect Secure exploitation (CVE-2023-46805 / CVE-2024-21887): https://www.cisa.gov/news-events/cybersecurity-advisories/aa24-060b
- Mandiant on Citrix Bleed (CVE-2023-4966) session hijacking: https://cloud.google.com/blog/topics/threat-intelligence/session-hijacking-citrix-cve-2023-4966
- Cloudflare on ZTNA vs VPN architectural model: https://www.cloudflare.com/learning/access-management/what-is-ztna/
- Gartner Market Guide for Zero Trust Network Access (overview / vendor framing): https://www.gartner.com/en/documents/zero-trust-network-access
