---
title: Entra conditional access bypass
slug: entra-conditional-access-bypass
---

> **TL;DR:** Entra Conditional Access (CA) policies are evaluated per-signal — User-Agent, IP, device compliance, application, location — and any signal a defender forgot to constrain becomes a bypass: legacy-auth endpoints, niche client app IDs, device-spoofing, or trusted-IP gaps.

## What it is
Entra CA gates token issuance on signals collected during sign-in. Each policy targets specific users, apps, platforms, and conditions, and applies grant controls (MFA, compliant device, hybrid join). Misses fall into four buckets: (1) legacy protocols (IMAP/POP/SMTP-AUTH, EAS basic auth) that historically bypassed modern CA, (2) excluded apps or client IDs, (3) trusted-IP/named-location lists that include attacker-reachable ranges, (4) device-compliance signals that can be forged or replayed.

## Preconditions / where it applies
- Stolen username+password (password spray, AiTM phishing residue, or breach-corpus reuse).
- Knowledge of the target tenant's CA posture — inferrable via `roadrecon` or by observing sign-in error codes.
- For device-based bypasses: ability to register a device or replay a Primary Refresh Token (see [[entra-device-code-prt-pivot]]).

## Technique
**Legacy auth (where still enabled):** historic carve-outs let basic-auth EWS/IMAP/POP/SMTP bypass CA policies targeting "Modern Authentication clients." Microsoft has retired most of these; SMTP-AUTH is the longest-lived holdout.

```bash
curl -v --user 'victim@tenant.onmicrosoft.com:Password1' \
  smtps://smtp.office365.com:587 --mail-from victim@... --mail-rcpt me@...
```

**Client-app exclusion:** policy targets "All cloud apps" minus a handful of exclusions (often Teams or a custom integration). Authenticate with the excluded app's client ID via ROPC/device code:

```bash
roadtx auth --client 1fec8e78-bce4-4aaf-ab1b-5451cc387264 \
  --resource https://graph.microsoft.com -u victim@... -p 'Password1'
```

**Trusted-location bypass:** if CA's "trusted IPs" includes the corp VPN egress, route through a compromised VPN endpoint or a corp-host SOCKS proxy.

**Device-state forgery:** the `x-ms-DeviceId` / `x-ms-DeviceType` headers and the PRT cookie identify the device. With `roadtx device` you can register a fake compliant device under a stolen user, then sign in with its PRT to satisfy "require compliant device" or "require hybrid join."

**User-Agent / platform exclusions:** policy says "block Android" — change UA string. Some CA rules naively trust the UA without correlating to the IdP's platform signal.

**AiTM (EvilProxy-style) does not technically bypass CA — it relays the user's compliant session — but the resulting tokens carry the MFA claim, so CA is satisfied.** Combine with [[az-cli-tokens]] for persistence.

## Detection and defence
- Set CA baseline: block legacy authentication for everyone; require MFA for all users on all apps; require compliant or hybrid-joined device for high-priv roles.
- Use token-binding / Continuous Access Evaluation so stolen tokens die when device falls out of compliance.
- Alert on sign-ins from unfamiliar locations even when CA grants — Entra ID Protection risk signals.
- Audit CA exclusions (`Get-MgIdentityConditionalAccessPolicy`) quarterly; treat exclusions as risk debt.
- Use `What If` tool and Conditional Access policy reports to find unprotected sign-in paths.

## References
- [Microsoft — Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview) — policy model
- [Dirk-jan Mollema — roadrecon](https://github.com/dirkjanm/ROADtools) — CA enumeration
- [TrustedSec — CA bypass research](https://trustedsec.com/blog/) — recurring write-ups on CA gaps
