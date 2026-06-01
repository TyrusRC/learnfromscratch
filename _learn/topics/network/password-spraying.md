---
title: Password spraying
slug: password-spraying
---

> **TL;DR:** Try one (or a handful of) weak password(s) against many accounts so per-account lockout never trips. Devastating against AD, M365/Entra ID, VPN portals, OWA, Citrix, and any SSO front-end that does not enforce conditional access.

## What it is
Password spraying inverts brute-force: instead of N passwords against one account (locks the account), it sends one password against N accounts (stays under per-account thresholds). The attacker rides predictable seasonal or organisational passwords (`Winter2026!`, `<Company>123`, `Welcome1`) across a large user list. Because per-account failure counts reset, and many auth back-ends lack per-source rate limiting, the spray can iterate weekly through lockout windows without ever locking a single user.

## Preconditions / where it applies
- A valid user list — pulled from LinkedIn scraping, [[osint-recon]], domain enumeration, GAL via [[smtp-enum]] or [[ldap-enum]], or NULL-session [[smb-enum]].
- An auth surface that returns differentiable success/fail responses: AD over Kerberos AS-REQ, NTLM via SMB/LDAP, M365 `login.microsoftonline.com`, Citrix/NetScaler, Fortinet/Pulse VPNs, OWA `/owa/auth.owa`, ADFS, Okta.
- Knowledge of lockout policy (`net accounts /domain`) to time waves below threshold.

## Technique
Build the user list first. Format-conversion matters — `john.doe`, `jdoe`, `doejo`, `john.doe@corp.local` are different surfaces. `kerbrute userenum` validates accounts against AD without generating lockouts (AS-REQ for nonexistent user returns a different error code than for valid user):

```bash
kerbrute userenum -d corp.local --dc dc01.corp.local users.txt
```

Spray with one wave per lockout window. Kerberos pre-auth spray is the gold standard internally — does not log as a failed logon on member servers, only on the DC:

```bash
kerbrute passwordspray -d corp.local --dc dc01.corp.local users.txt 'Winter2026!'
```

External spray against M365 / Entra ID — use a low-volume, distributed approach. `MSOLSpray` and successors hit `login.microsoftonline.com` and parse the AADSTS error codes:

```powershell
Invoke-MSOLSpray -UserList .\users.txt -Password 'Spring2026!' -Force
```

ADFS / OWA / Exchange — `o365spray`, `Spray365`, or custom `curl` loops against `/adfs/ls/?wa=wsignin1.0`. For SMB/LDAP spray inside the network use `nxc` (NetExec):

```bash
nxc smb dc01.corp.local -u users.txt -p 'Winter2026!' --continue-on-success
nxc ldap dc01.corp.local -u users.txt -p 'Winter2026!' --continue-on-success
```

Rules of engagement: one password per 30–60 minute window, pace below 5 attempts per account per lockout interval, monitor success without locking. Stop on first hit, verify the credential out-of-band (don't burn it on more sprays). Watch for honeypot accounts (`admin`, `administrator`, accounts with SPN like `SQLSvc` planted as bait).

Password candidates that consistently work: `<Season><Year>!`, `<Season><Year>`, `<Company>!`, `<Company>123`, `Welcome1`, `Password1`, `Changeme!`, plus anything leaked in recent breach combos for the org's email domain.

## Detection and defence
- Detection signal: many distinct accounts, single source, identical password timing — 4625 (NTLM) and 4768/4771 (Kerberos pre-auth fail) events with the same workstation field. SIEM rule: >N distinct usernames per source per hour.
- Defences: MFA on every external surface (especially legacy auth), conditional access blocking legacy protocols, Smart Lockout in Entra ID, Azure AD Password Protection banned-word lists, source-IP rate limiting at the edge, anomaly detection on geographic auth jumps.
- For internal AD: increase password length (15+), deploy Azure AD Password Protection on-prem, alert on `kerbrute`/`nxc` user-agents, and disable NTLM where possible to remove the easiest spray surface.

## References
- [HackTricks — Password Spraying](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/password-spraying.html) — tools and protocol-specific tactics.
- [TrustedSec — A Better Way to Spray](https://www.trustedsec.com/blog/a-better-way-to-do-password-spraying/) — detection-aware methodology.
- [Microsoft — Smart Lockout](https://learn.microsoft.com/en-us/entra/identity/authentication/howto-password-smart-lockout) — the Entra ID control that disrupts the spray model.
