---
title: Conditional Access bypass — modern patterns
slug: conditional-access-bypass-modern
aliases: [ca-bypass, entra-ca-bypass, conditional-access-evasion]
---

> **TL;DR:** Conditional Access (CA) policies in Entra ID gate sign-ins and token issuance by user, device, location, app, risk, and authentication strength. Bypasses come from policy gaps (legacy clients, excluded users / apps, missing policies), token-replay paths (CAE not enabled, refresh-token lifetime too long), and platform-specific edges (Linux client lacks device compliance check). Companion to [[aitm-evilginx-modern-phishing]] and [[entra-cross-tenant-sync-abuse]].

## Why CA is the control plane

Entra CA is the **chokepoint**. Even if AitM phishing succeeds, CA can:
- Require the resulting sign-in be from a compliant device → attacker session blocked.
- Require Phish-resistant MFA → AitM cookie capture fails (FIDO2 origin binding).
- Require trusted IP → attacker IP rejected.
- Apply session controls (Defender for Cloud Apps reverse-proxy) → block exfil.

When CA is comprehensive, AitM yields little. When CA has gaps, AitM yields full access. The gap analysis is the operator's main work.

## Common CA gap patterns

### Pattern 1 — Excluded users / break-glass accounts

Every CA policy needs at least one excluded user for break-glass. If those accounts have weak passwords or unrotated tokens, they're the bypass.

Recon: enumerate users with `MemberOf` empty + UPN matching `breakglass`, `emergency`, `admin-temp` patterns.

### Pattern 2 — Excluded apps

CA policies often exclude specific apps for compatibility (legacy MFA-incompatible service, contractor portal). If the exclusion is broader than necessary, attackers use the excluded app's authentication path to obtain tokens with broader scope.

### Pattern 3 — Missing policy on resource

Some resources have no CA policy applied. `Office 365`, `Exchange Online`, and `SharePoint` are usually covered; **Graph Explorer**, **Azure Portal**, and **specific custom apps** sometimes aren't.

Test the target with each app ID; see which trigger CA and which don't.

### Pattern 4 — Legacy auth not blocked

Basic auth / IMAP / POP / SMTP AUTH bypass CA entirely because they don't support the modern claims CA evaluates. Microsoft has been deprecating legacy auth, but it persists in tenants with old applications.

Test: try IMAP auth as the target user against `outlook.office365.com`. If it works, CA is bypassed.

### Pattern 5 — Refresh-token replay before CAE

Without Continuous Access Evaluation (CAE), access tokens live ~1 hour and refresh tokens ~90 days. A captured refresh token survives policy changes, password resets, and (until CAE is enabled) sign-in risk events.

Capture the token via AitM, then replay from anywhere. CA evaluates at sign-in, not at every request.

### Pattern 6 — Authentication-method gap

If a CA policy requires "MFA" but doesn't require **Phish-resistant MFA** (FIDO2 / Windows Hello for Business / certificate), then push, TOTP, or SMS are accepted. AitM captures these the same as a password.

### Pattern 7 — Geo / IP gap

CA "trusted IP" lists can be:
- Too broad (`/8` corporate range when contractor VPN exits via different IPs).
- Missing IPv6 entries.
- Stale (old VPN endpoints still trusted).

Attackers proxying through trusted IP (corporate VPN, compromised dev VM) bypass geo controls.

### Pattern 8 — Cross-tenant policy gap

Entra cross-tenant settings ([[entra-cross-tenant-sync-abuse]]) can permit guest users to bypass policies that target home-tenant users.

### Pattern 9 — Linux / non-managed device

CA policies often require "compliant device" (Intune-enrolled). Linux is harder to enrol; some orgs exclude Linux from compliance requirements, then Linux becomes the bypass platform.

## Recon approach (defender or red team)

If you have **Global Reader** or **Security Reader**:

- Pull all CA policies via Graph API: `https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies`
- For each: read `conditions`, `grantControls`, `sessionControls`, `state`.
- Map: which users / apps / platforms are covered, which are not.
- Look for policies in `enabledForReportingButNotEnforced` — these don't block.

Tools: ROADtools, AzureHound, Maester.

External / unauthenticated:
- Probe each Microsoft endpoint with a test account. Note which return CA challenge and which don't.
- Test legacy protocols against `outlook.office365.com`.
- Test device-code flow ([[oauth-device-code-phishing-m365]]).

## What to do with a CA-bypassed token

Once the attacker has a token that didn't pass full CA:
- Use Graph API to read mail / files.
- Use the token's refresh path to mint new access tokens.
- Persist by registering a new device or adding an alternate auth method.

## Defensive baseline

- **Default-deny** posture: a baseline CA policy applies to all users / all apps requiring MFA + compliant device.
- **Exemptions explicit**, time-bound, and audited monthly.
- **Phish-resistant MFA** required for administrative roles.
- **Block legacy authentication** unequivocally.
- **CAE enabled** for all eligible apps.
- **Sign-in risk + user risk** integrated with Identity Protection.
- **Token protection** for Edge browser sessions.
- **Continuous monitoring** of CA gap reports (Maester, ROADtools).

## Workflow to study in a lab

1. Create a test tenant; add a few users and apps.
2. Configure baseline CA: require MFA for all users.
3. Test each gap pattern above — observe whether the policy blocks.
4. Tighten the policy iteratively (add device compliance, add phish-resistant strength, block legacy).
5. Run ROADtools to dump policies; identify what remains.

## Related

- [[aitm-evilginx-modern-phishing]]
- [[oauth-device-code-phishing-m365]]
- [[mfa-fatigue-tradecraft]]
- [[entra-cross-tenant-sync-abuse]]
- [[m365-admin-attacks]]
- [[entra-actor-token-cross-tenant]]

## References
- [Microsoft Learn — Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/)
- [Maester — CA configuration analyser](https://maester.dev/)
- [ROADtools](https://github.com/dirkjanm/ROADtools)
- [dirkjanm — Entra ID research](https://dirkjanm.io/)
- See also: [[aitm-evilginx-modern-phishing]], [[oauth-device-code-phishing-m365]], [[entra-cross-tenant-sync-abuse]], [[m365-admin-attacks]]
