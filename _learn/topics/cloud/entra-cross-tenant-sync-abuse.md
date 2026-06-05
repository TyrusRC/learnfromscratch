---
title: Entra cross-tenant sync (XTS) abuse
slug: entra-cross-tenant-sync-abuse
aliases: [xts-abuse, entra-id-cross-tenant-sync, b2b-direct-connect-abuse]
---

> **TL;DR:** Cross-tenant synchronisation (XTS) is an Entra ID (Azure AD) feature that mirrors users from a source tenant to a target tenant as guest objects. If a target tenant misconfigures inbound XTS — accepting from any tenant or from an attacker-controlled tenant — the attacker can push attacker-owned guest users into the victim tenant, which often inherit broad default access. Identity-layer compromise without phishing a single user. Companion to [[m365-admin-attacks]] and [[cloud-identity-mental-model]].

## Why this matters

- Entra ID cross-tenant features (XTS, B2B Direct Connect, Multi-tenant org) are new and **frequently misconfigured**.
- The attack class is **identity injection**, not credential theft.
- Defenders rarely audit inbound cross-tenant policies; the controls live in a separate admin blade.
- Attack persistence is high — even after detection, removing a synced guest may not invalidate every credential or session.

## How XTS works

The feature lets two Entra tenants sync user objects across the boundary. In the source tenant, an admin configures outbound XTS to specify which users push to which target. In the target tenant, an admin configures inbound XTS to accept from which sources.

When XTS is misconfigured to accept from "all tenants" or from a tenant the victim doesn't actually trust, attackers can:
- Register a new tenant they control.
- Configure outbound XTS to push attacker-controlled users.
- Cause those users to appear as guests in the victim tenant.

If the victim's **default user permissions** allow guests to read directory data, enumerate users, view groups, or invoke Graph API, the attacker has immediate footprint.

## The chain to impact

1. Attacker plants a guest user in the victim tenant.
2. Guest user reads directory metadata (`users.read.all` for guests is sometimes default).
3. Attacker enumerates roles, devices, applications, service principals.
4. Attacker identifies a misconfigured application consent or service-principal trust.
5. Chain to privileged access (via dirkjanm's research on Entra application consent, dynamic group memberships, or PRT abuse).

## Pre-conditions to look for

- Inbound XTS configured to "Default" (allow all) instead of explicit allowlist.
- Guest default permissions left at "Limited access" (default) rather than "Restricted access" — still permits more than you'd expect.
- B2B trust settings allowing token issuance for guests.
- Dynamic groups with rules that match guest user properties.
- Conditional Access policies that exclude guest UPN suffixes.

## Recon approach

If you have any kind of presence in the victim tenant:
- Inspect `crossTenantAccessPolicy/default` in Microsoft Graph.
- Inspect `crossTenantAccessPolicy/partners` and look for tenant IDs you don't recognise.
- Check `policies/cross-tenant-access` blade in the Entra admin UI.
- Audit recent guest invitations and externalUserSyncs.

External recon (from a controlled tenant): attempt to configure outbound XTS to the target tenant. The target's inbound policy decides whether your sync succeeds.

## Workflow to demonstrate in a lab

1. Stand up two Entra tenants (free trial tier each).
2. In Tenant B, configure inbound XTS to accept from Tenant A.
3. In Tenant A, configure outbound XTS to sync a user named `attacker@a.onmicrosoft.com` to Tenant B.
4. Observe the user appear in Tenant B as a guest.
5. Authenticate that user against Tenant B and call `https://graph.microsoft.com/v1.0/users` — observe directory enumeration access.

## Detection

- Audit log entry for `Add external user` events tied to XTS.
- New guest UPNs from unfamiliar source tenants.
- Cross-tenant access policy changes.
- Unusual Graph API calls from guest users.

Microsoft's Defender for Cloud Apps and Entra ID Protection cover some of these, but custom KQL rules are often more reliable.

## Defensive baseline

- Set inbound XTS default to **block**.
- Explicitly allowlist trusted partner tenants.
- Restrict guest default permissions to "Restricted access".
- Conditional Access policies that block any sign-in from guests outside expected partners.
- Audit `crossTenantAccessPolicy/*` regularly.

## Related identity-layer attacks

- **B2B Direct Connect** — even more permissive than guest invites; same misconfig class.
- **Multi-tenant organisations** — newer feature, similar acceptance defaults.
- **Application consent attacks** — paired with XTS becomes "attacker-controlled guest grants consent to attacker app".
- **PRT replay** ([[gmsa-decryption]]-adjacent on the AD-Entra hybrid edge).
- **Cross-tenant-aware Conditional Access bypass**.

See also: [[m365-admin-attacks]], [[gcp-workload-identity-federation-abuse]].

## References
- [dirkjanm — Entra research blog](https://dirkjanm.io/)
- [Microsoft Learn — cross-tenant sync](https://learn.microsoft.com/en-us/entra/identity/multi-tenant-organizations/cross-tenant-synchronization-overview)
- [Microsoft — configure cross-tenant access settings](https://learn.microsoft.com/en-us/entra/external-id/cross-tenant-access-settings-b2b-collaboration)
- [SpecterOps — Entra ID research](https://posts.specterops.io/)
- See also: [[m365-admin-attacks]], [[cloud-identity-mental-model]], [[cloud-iam-misconfig-patterns]]
