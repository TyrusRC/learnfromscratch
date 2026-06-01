---
title: Shadow credentials
slug: shadow-credentials
---

> **TL;DR:** With write access to a target's `msDS-KeyCredentialLink`, plant an attacker-owned public key, then PKINIT as the target to recover their TGT and NT hash.

## What it is
`msDS-KeyCredentialLink` is the multi-valued attribute that backs Windows Hello for Business / Azure AD device key trust. Each entry binds a public key to the principal — the matching private key proves identity through PKINIT during Kerberos pre-authentication. The attribute is writable by an object's owner, by anyone with GenericAll/GenericWrite, and by computer accounts on themselves. Plant your own KeyCredential, request a TGT via PKINIT, and you've authenticated as the victim — no password reset, no event 4724 — and bonus: PKINIT returns the user's NT hash inside the PAC for offline reuse.

## Preconditions / where it applies
- AD with the `2016+ KDC schema` (KeyCredentialLink schema present) and a domain-joined CA available for PKINIT — basically any modern AD.
- Write right on the victim's `msDS-KeyCredentialLink`:
  - GenericAll / GenericWrite / WriteProperty on the victim.
  - The owner of the victim (objects can rewrite their own ACL).
  - Computer accounts on themselves (relay-friendly).
- A KDC with the Windows Hello cert template + PKINIT (default in modern domains).

## Technique
Use Certipy or `ntlmrelayx --shadow-credentials` (post-relay). Certipy's `shadow auto` does add/auth/remove in one shot.

```bash
# Auto: add a KeyCredential, PKINIT, dump TGT + NT, restore previous values
certipy shadow auto -username me@corp.lab -p 'pw' -account victim

# Manual breakdown
certipy shadow add  -username me@corp.lab -p 'pw' -account victim
certipy auth -pfx victim.pfx -dc-ip 10.0.0.1   # → TGT + NT hash
certipy shadow remove -username me@corp.lab -p 'pw' -account victim -device-id <id>
```

Whisker (Windows / .NET) is the equivalent for in-host workflows; `pyWhisker` for Linux without Certipy. Both libraries hash the public key and produce the `KEYCREDENTIAL` binary blob per MS-ADTS spec.

Common chains:
- [[acl-abuse|GenericAll on victim user]] → shadow → DA via cascading paths.
- Computer takeover (you compromised the machine account hash) → shadow yourself → TGT for the computer → S4U2Self ([[constrained-delegation]]) for any user against the computer.
- [[ntlm-relay-ws2025-mitigations|Coerce + relay to LDAPS]] → write KeyCredentialLink → SYSTEM-on-target via the resulting TGT.

When auditing what's on the attribute, deserialise carefully — multiple entries from real Hello enrolments are normal; just appending one extra is the stealthy move.

After PKINIT succeeds, chain straight into S4U with Rubeus: `Rubeus.exe s4u /impersonateuser:Administrator /self /altservice:cifs,host,http /ptt` against the computer you just shadowed yields tickets for multiple services in one round-trip — no second TGS-REQ visible to the KDC per service. Verify the write landed by reading the attribute back through PowerView (`Get-DomainComputer victim -Properties msDS-KeyCredentialLink`) before authenticating; race conditions with Defender for Identity's auto-removal have been observed when the write event fires close to the PKINIT request, so insert a 30–60s gap if you control timing.

## Detection and defence
- Audit 4662 with the `msDS-KeyCredentialLink` attribute GUID `5b47d60f-6090-40b2-9f37-2a4de88f3063` — writes outside expected device-registration flows are anomalous.
- Defender for Identity flags shadow credentials via the `Suspected Shadow Credentials` detector.
- Bind PKINIT to strong cert mapping (KB5014754) and turn on full enforcement (KDC events 39/41).
- Keep `Authenticated Users` from owning user/computer objects (creator inherits owner — limit who can create objects).
- Add tier-0 accounts to Protected Users (denies NTLM, denies PKINIT? no — but tightens elsewhere) and audit changes to `msDS-KeyCredentialLink` everywhere.
- See [[adcs-esc14-altsecidentities]] for the post-KB5014754 cousin technique.

## References
- [SpecterOps — Shadow Credentials](https://posts.specterops.io/shadow-credentials-abusing-key-trust-account-mapping-for-takeover-8ee1a53566ab) — original write-up
- [Certipy — Shadow Credentials](https://github.com/ly4k/Certipy) — tooling
- [the.hacker.recipes — Shadow credentials](https://www.thehacker.recipes/ad/movement/kerberos/shadow-credentials) — full walkthrough
- [Microsoft — MS-ADTS msDS-KeyCredentialLink](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/de61eb56-b75f-4743-b8af-e9be154b47af) — attribute schema
- [ired.team — Shadow Credentials](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/shadow-credentials) — Whisker + Rubeus s4u chain walkthrough
