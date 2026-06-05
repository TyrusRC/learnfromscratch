---
title: Identity-aware proxy — deep
slug: identity-aware-proxy-deep
aliases: [iap-deep, identity-aware-proxy, beyondcorp-pattern]
---

> **TL;DR:** An identity-aware proxy (IAP) is a reverse proxy that sits in front of internal apps, authenticates and authorises every single request against an identity provider plus device/context signals, and forwards only approved traffic to the backend. It is the concrete implementation pattern behind most "BeyondCorp / zero trust" rollouts and is the main mechanism people use to retire application-layer VPN. Companion notes: [[zero-trust-architecture-practitioner]], [[ztna-vs-vpn-migration]], [[oauth-modern-attacks]], [[conditional-access-bypass-modern]].

## Why it matters

VPN gives you a flat network tunnel and trusts whoever lands on the inside. IAP inverts that: there is no "inside". Every HTTP request to an internal tool — Jenkins, Grafana, internal Django admin, Jira data centre, Kubernetes dashboard — passes through a proxy that re-checks: who is the user, what device, what posture, what geo, what risk score, do they have the right group, and is this URL allowed for that group right now.

For defenders this matters because:

- Lateral movement off a single compromised endpoint stops being "free". A stolen laptop on the corp LAN no longer auto-reaches `jenkins.internal`.
- You get per-request audit logs at L7, not just "VPN tunnel up from IP x.x.x.x for 9 hours" (see [[siem-detection-use-case-catalog]]).
- Conditional Access / device posture finally apply to legacy internal apps, not just SaaS (see [[conditional-access-bypass-modern]]).
- It is the mechanism most "zero trust" auditors are actually asking about under frameworks like NIS2, DORA, and modern SOC 2 controls ([[nis2-implementation]], [[soc2-vs-iso27001]]).

It also matters because the IAP itself becomes a single, very tasty choke point. Compromising the IAP, or the IdP feeding it, is equivalent to compromising every app behind it. See [[case-study-okta-2023-support-system]] for the genre.

## Pattern architecture

At its simplest:

```
Browser / CLI client
   |
   v
+--------------------+      +------------------+
| IAP edge (TLS)     | <--> | IdP (Entra/Okta) |
| - authn per request|      +------------------+
| - authz per request|              ^
| - device posture   |              |
| - policy engine    |      +------------------+
+--------------------+      | Device posture   |
   |                        | (Intune/Jamf...) |
   v                        +------------------+
Backend app (HTTP)
no public ingress
```

Key properties:

- The backend has **no public ingress**. It is reachable only from the IAP, usually via a private link, a connector tunnel (Cloudflare Tunnel, Pomerium connector, Teleport agent, Azure App Proxy connector), or a private VPC peering.
- The IAP terminates TLS, runs the policy, and re-originates the request, often injecting a signed header (JWT) or mTLS cert that the backend can optionally verify.
- Authentication happens via OIDC / SAML against the IdP — see [[oauth-modern-attacks]] for what can go wrong here.
- Authorisation is per-request, evaluated against a policy that can include user identity, group, device ID, posture claim, geo, time, risk score, and target URL/method.

## Classes of IAP

Practitioner-relevant vendors and what they actually are:

### Google Cloud IAP / BeyondCorp Enterprise
The original. Sits in front of GCP Load Balancers and App Engine, and via connector in front of on-prem. Tight integration with Google Workspace identity and Chrome Enterprise device posture. Less useful if you are not already a Google shop.

### Cloudflare Access (part of Cloudflare One)
Operates at Cloudflare's edge. You expose apps either via a public hostname behind Access policies, or via `cloudflared` tunnel from a private network. Cheap, fast to deploy, integrates with most IdPs. The big gotcha: your internal app traffic now traverses Cloudflare's edge, which is a trust and compliance decision.

### Pomerium
Open-source, self-hosted. You run it in your own cluster. Good fit when you cannot send traffic to a third-party SaaS edge (regulated environments, see [[financial-sector-defender-playbook]]). Higher operational cost.

### Teleport
Strongest fit for infrastructure access — SSH, Kubernetes, databases, RDP — not just HTTP. Issues short-lived certs, records sessions. Often deployed alongside an HTTP-only IAP, not instead of one.

### AWS Verified Access
AWS-native. Integrates with IAM Identity Center and third-party trust providers (Jamf, CrowdStrike, Jumpcloud). Good if you are already deep in AWS and want the policy evaluated at the AWS edge ([[cloud-ir-aws-cloudtrail]]).

### Microsoft Entra Application Proxy / Global Secure Access
Publishes on-prem web apps through Entra ID with Conditional Access applied. The natural choice if you are an Entra shop and want a single policy surface across SaaS + internal apps ([[conditional-access-bypass-modern]]).

## Per-request authentication and authorisation

The "per request" part is the heart of the pattern.

1. Browser hits `jenkins.corp.example.com`.
2. IAP sees no valid session cookie/JWT — redirects to IdP.
3. User authenticates (password + MFA + device cert + Conditional Access).
4. IdP returns an OIDC token, IAP issues its own session token (signed cookie or JWT).
5. Every subsequent request includes that token. IAP validates signature, expiry, and re-evaluates policy: is the user still in group `eng-jenkins`? Is the device still compliant? Is the geo still allowed?
6. IAP forwards the request to backend with a signed identity header (e.g. `X-Goog-IAP-JWT-Assertion`, `Cf-Access-Jwt-Assertion`).
7. Backend optionally re-verifies that header so a direct hit bypassing the IAP would fail.

The last step is the one most teams skip. If the backend trusts any request that reaches it, an attacker who finds the private origin bypasses the entire IAP. Mandatory backend JWT verification or mTLS is the only safe pattern.

## Context-aware policy

Modern IAP policies are not just "is user in group X". A realistic policy:

- User must be in group `prod-readonly`.
- Device must report `compliant=true` from Intune or Jamf in the last 24 hours.
- Device disk must be encrypted, screen lock enabled, OS within N versions of latest.
- Geo must be one of approved countries; impossible-travel triggers step-up.
- Risk score from IdP (Entra Identity Protection, Okta ThreatInsight) must be below threshold.
- For write methods (POST/PUT/DELETE), require fresh MFA within the last 15 minutes.

This is where IAP genuinely beats VPN: VPN cannot express "POST allowed only if MFA was within 15 minutes from a compliant device in an approved geo".

## Encrypted tunnel vs token-based

Two integration styles for connecting backends:

- **Connector tunnel** (Cloudflare Tunnel, Azure App Proxy connector, Pomerium connector). An outbound-only daemon dials the IAP edge. No inbound firewall rules. Easiest to deploy. Trust model: you trust the IAP vendor with cleartext app traffic after TLS termination.
- **Token-based forwarding to publicly reachable origin**. Backend has a public hostname but enforces a signed JWT from the IAP at the app layer (or via a sidecar / WAF rule). More flexible, but the origin is technically reachable, so origin lockdown (mTLS, IP allowlist of IAP edge ranges, JWT verification) is mandatory.

Most production deployments mix both.

## How IAP replaces VPN at the application layer

Important phrasing: **at the application layer**. IAP does not replace VPN for raw TCP/UDP services that are not HTTP. For SSH, Kubernetes API, databases, RDP, you either:

- Use a Teleport-style protocol-aware proxy, or
- Keep a much smaller VPN / ZTNA agent for non-HTTP traffic (Cloudflare WARP, Tailscale, Zscaler Private Access), or
- Front the service with a web UI that is itself behind IAP (e.g. a database web console).

See [[ztna-vs-vpn-migration]] for the staged retirement plan.

## Integration with SSO and device posture

- **SSO / IdP**: OIDC or SAML to Entra ID, Okta, Google Workspace, Ping. The IAP is "just another SP" from the IdP's point of view. Group claims drive authorisation.
- **Device posture**: integration usually flows via either (a) a device cert issued by MDM that the IAP validates, (b) a posture claim pushed into the OIDC token by Conditional Access, or (c) a direct API check to Jamf/Intune/Kandji/CrowdStrike at session start.
- **Risk signals**: Entra Identity Protection, Okta ThreatInsight, CrowdStrike Zero Trust Assessment scores can be consumed as policy inputs.

## Audit logging benefits

Per-request L7 logs are the underrated win. You get, for every internal app request: user, device ID, source IP, geo, method, URL, response status, policy decision, and the rule that matched. This is night-and-day better than VPN logs and feeds directly into:

- Detection use cases ([[siem-detection-use-case-catalog]], [[detection-engineering-pyramid-of-pain]]).
- UEBA baselining ([[ueba-detection-ml-primer]]).
- Insider-threat and lateral-movement hunts ([[ir-from-source-signals]]).
- Audit evidence under SOC 2 / ISO 27001 / PCI ([[audit-evidence-sampling-and-scoring]], [[building-an-iso27001-isms-practitioner]]).

## Defensive baseline

- Backend **must** verify the signed identity header / mTLS from the IAP. No exceptions.
- Backend origin must not be reachable from anywhere but the IAP. Verify with external scans, not just firewall rules.
- IdP integration uses OIDC with PKCE or SAML with signed assertions and short token lifetimes; refresh tokens rotated. See [[oauth-modern-attacks]].
- Conditional Access / posture rules apply to the IAP exactly as they apply to SaaS — no special "internal" carve-outs ([[conditional-access-bypass-modern]]).
- Admin access to the IAP control plane requires its own break-glass path, hardware MFA, and separate IdP tenant where possible.
- Per-app policies, not one mega-policy. Reviewable in code (policy-as-code), version-controlled, peer-reviewed.
- Egress from the connector hosts is restricted — they should only talk to the IAP edge and the backend.
- Session lifetimes short enough that revoking a user in the IdP actually kicks them within minutes, not 8 hours.
- Backup access path (break-glass) for IAP outage, with heavy logging and alerting.

## Attack surface of the IAP itself

- **The IdP is now the keys to everything internal.** Phishing-resistant MFA (FIDO2) for all users, hardware keys for admins. See [[aitm-evilginx-modern-phishing]] and [[mfa-fatigue-tradecraft]].
- **AiTM proxies** can defeat non-phishing-resistant MFA and harvest the IAP session cookie directly. Token binding / device-bound sessions help.
- **OAuth device-code phishing** against the IdP can grant tokens that the IAP will honour ([[oauth-device-code-phishing-m365]]).
- **Support-desk social engineering** to reset MFA on a privileged account — see [[case-study-okta-2023-support-system]].
- **Connector host compromise** lets an attacker pivot to the backend without going through the IAP at all.
- **Vendor compromise**: if the IAP edge is SaaS, a vendor breach is your breach. Threat-model accordingly ([[third-party-risk-management-practitioner]]).

## Failure modes

- **IAP outage = no access to any internal app.** This is the most important operational risk. You need a documented, tested break-glass path, and you need to decide whether that path goes through a secondary IAP, a tightly scoped VPN, or direct console access via cloud provider IAM ([[tabletop-exercise-design-and-execution]]).
- **IdP outage = same thing.** Multi-IdP or cached sessions help but add complexity.
- **Posture provider outage** (Intune, Jamf) — decide if policy fails open or closed. Failing closed is correct but painful; document it.
- **Cert rotation breakage** on connector tunnels — automate or it will bite you.

## Cost considerations

- SaaS IAP (Cloudflare Access, Verified Access, Entra App Proxy) is usually per-user per-month, often $3-$10. Cheap at small scale, expensive at 50k seats.
- Self-hosted (Pomerium, Teleport, oauth2-proxy) is "free" in licence but real cost is engineering — HA deployment, upgrades, policy authoring, posture integration.
- Hidden costs: re-architecting apps to verify identity headers, MDM rollout to all devices, retiring the existing VPN cleanly.

## Vendor marketing vs reality

- "Zero trust in 30 days" — no. Realistic IAP rollout for a mid-size org is 6-18 months with a dedicated team.
- "Replaces your VPN" — only at the HTTP layer, and only after you have catalogued every internal app and protocol.
- "Just turn on Conditional Access" — useless if half your apps still trust network position. The app-side changes are the hard part.
- "It's just a reverse proxy" — yes, but the policy engine, posture integration, audit pipeline, and break-glass design are 90% of the work.

## Workflow to study

1. Read the original BeyondCorp papers (research.google).
2. Stand up Pomerium or oauth2-proxy locally in front of a toy Flask app; wire it to a free-tier Okta or Entra ID dev tenant.
3. Add a second app and write per-app policy.
4. Add device posture: issue a client cert via your laptop's keychain, require it.
5. Break it on purpose: hit the backend directly bypassing the proxy. Fix it by enforcing JWT verification on the backend.
6. Repeat with Cloudflare Access or AWS Verified Access to feel the SaaS variant.
7. Map the audit log fields and write three detection use cases (impossible travel, posture downgrade, anomalous URL access).

## Related

- [[zero-trust-architecture-practitioner]]
- [[ztna-vs-vpn-migration]]
- [[cloud-identity-mental-model]]
- [[conditional-access-bypass-modern]]
- [[oauth-modern-attacks]]
- [[oauth-device-code-phishing-m365]]
- [[aitm-evilginx-modern-phishing]]
- [[case-study-okta-2023-support-system]]
- [[siem-detection-use-case-catalog]]
- [[third-party-risk-management-practitioner]]
- [[nis2-implementation]]

## References

- https://cloud.google.com/beyondcorp-enterprise/docs/concepts-overview
- https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/
- https://www.pomerium.com/docs/concepts/zero-trust
- https://goteleport.com/docs/access-controls/introduction/
- https://docs.aws.amazon.com/verified-access/latest/ug/what-is-verified-access.html
- https://learn.microsoft.com/en-us/entra/global-secure-access/concept-private-access
