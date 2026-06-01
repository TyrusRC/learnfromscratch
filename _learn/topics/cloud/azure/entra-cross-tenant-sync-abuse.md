---
title: Entra cross-tenant sync abuse
slug: entra-cross-tenant-sync-abuse
---

> **TL;DR:** Cross-Tenant Synchronisation (CTS) lets one tenant create B2B guest objects in a partner tenant automatically; abuse the source-tenant config to push attacker-controlled identities into the target, where they inherit guest permissions and any group-based role assignments.

## What it is
CTS is an Entra ID feature that synchronises selected users from a source tenant into a target tenant as B2B collaboration guests. The target tenant configures a "cross-tenant access policy" trusting the source, and the source runs a provisioning job that creates/updates guest objects in the target via the SCIM-like sync API. An attacker who compromises the source tenant — or who tricks a target admin into trusting an attacker-owned tenant — can use CTS to materialise arbitrary guest accounts in the target, then sign in as those guests, bypassing the usual B2B invitation flow and any auditing tied to it. Vasil Michev, Tenable, and Invictus IR have all published abuse research on this.

## Preconditions / where it applies
- Compromise of (or admin role in) a source tenant that the target trusts via inbound CTS.
- Or: ability to socially engineer a target admin into creating a trust to an attacker tenant.
- Target tenant has inbound CTS enabled and "automatic redemption" turned on (so guests can sign in without invitation acceptance).

## Technique
**Push a malicious guest from the source tenant:**

1. From the source tenant, configure a provisioning app for CTS targeting the victim tenant.
2. Add the attacker-controlled user to the scope of the sync (filter or group).
3. Run the sync job; the user is created as a guest in the target with `userType: Guest` and a `mail` matching the source UPN.
4. Sign in to the target tenant as that guest. If automatic redemption is enabled, no email click is required.

**Persistence after detection:** even if the target removes the inbound trust, the already-provisioned guest objects remain until explicitly deleted. Attacker can keep using them.

**Pivot inside target:** guests by default can read directory data, enumerate groups, and may be members of dynamic groups whose rules match attacker-set attributes (`department=Engineering`). If group-based role assignment exists, guest can inherit roles.

**Defender pain points:**
- CTS provisioning logs live in the source tenant — the target sees finished objects, not the act of creation.
- Sign-ins look like normal guest sign-ins; the cross-tenant nature is buried in the audit log.

Chain with [[entra-id-enum]] to map the target post-pivot, [[app-registration-abuse]] for persistence as a service principal, and [[entra-actor-token-cross-tenant]] for related cross-tenant primitives.

## Detection and defence
- Inventory inbound CTS trusts: `Get-MgPolicyCrossTenantAccessPolicyPartner` — alert on any new partner.
- Disable automatic redemption unless required; force manual invitation acceptance for visibility.
- Use Conditional Access for guests: require MFA, block high-risk sign-ins, restrict guest access to a small app set.
- Audit guest accounts regularly: `userType eq 'Guest' and createdDateTime gt ...`; correlate against expected provisioning sources.
- Apply Restricted Guest defaults so guests cannot enumerate directory metadata.
- Alert on `Add a partner to cross-tenant access setting` audit events.

## References
- [Tenable — Entra ID synchronisation abuse](https://www.tenable.com/blog/despite-recent-security-hardening-entra-id-synchronization-feature-remains-open-for-abuse) — current state of the abuse
- [Invictus IR — CTS attack paths](https://www.invictus-ir.com/news/) — incident response perspective
- [Microsoft — CTS overview](https://learn.microsoft.com/en-us/entra/identity/multi-tenant-organizations/cross-tenant-synchronization-overview) — official docs
