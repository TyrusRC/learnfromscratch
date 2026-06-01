---
title: Kerberos
slug: kerberos
---

> **TL;DR:** Three-message ticket-based auth (AS-REQ/REP, TGS-REQ/REP, AP-REQ/REP) backed by symmetric keys derived from passwords. Tickets carry the PAC — a SID/group blob the application server trusts. Almost every "AD attack" is really a manipulation of one of those messages.

## What it is
Kerberos v5 is the default authentication protocol on Windows networks. A client first proves password possession to the KDC (Authentication Service) and gets a TGT encrypted with the `krbtgt` key. The client then trades the TGT for service tickets (Ticket Granting Service) encrypted with each target service account's key. The server validates the ticket without contacting the KDC. Microsoft extends standard Kerberos with the Privilege Attribute Certificate (PAC), an authorisation blob inside the ticket containing user SID, group SIDs, and signatures.

## Preconditions / where it applies
- Any Active Directory environment — Kerberos runs on TCP/UDP 88
- A target principal must have an SPN registered for TGS issuance
- Time skew of ≤5 minutes between client and KDC (default)

## Technique
The exchanges and the attacks they enable:

**AS-REQ / AS-REP.** Client encrypts a timestamp with its long-term key (pre-auth) and asks for a TGT. The reply contains the TGT (opaque, encrypted with `krbtgt`) plus a session key encrypted with the user's key.
- No pre-auth → [[asreproast]]
- Forge with stolen `krbtgt` → [[golden-tickets]]

**TGS-REQ / TGS-REP.** Client presents the TGT and asks for a service ticket for an SPN. KDC encrypts the ticket with the target service account's long-term key.
- Service account's key is password-derived → [[kerberoasting]]
- Forge with stolen service key → [[silver-tickets]]
- Constrained / RBCD / unconstrained delegation use S4U2self / S4U2proxy variants → [[constrained-delegation]], [[resource-based-constrained-delegation]], [[unconstrained-delegation]]

**AP-REQ / AP-REP.** Client sends the service ticket to the application server. The PAC inside is what Windows trusts for authorisation.

Useful command primitives:

```bash
# Get a TGT with a password
getTGT.py corp.local/alice:Pass -dc-ip 10.0.0.10
export KRB5CCNAME=alice.ccache

# Use it
smbclient.py -k -no-pass dc01.corp.local
```

Key etypes: 23 (RC4-HMAC) — fast to crack, legacy; 17/18 (AES128/256) — modern default. Force RC4 when roasting (`-e rc4` in many tools) to speed cracking. The PAC is signed twice: server signature (key of target service) and KDC signature (`krbtgt`) — bypassing one without the other is the Bronze Bit (CVE-2020-17049) and noPac/sAMAccountName (CVE-2021-42278/42287) class.

In-memory Kerberos primitives are scriptable without Mimikatz: `Add-Type -AssemblyName System.IdentityModel` then `New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList "HTTP/host.corp.local"` triggers a normal TGS-REQ that lands the ticket in the current logon session — Mimikatz `kerberos::list /export` then writes it out as a `.kirbi`. This dual-step pattern (managed AD assembly invocation followed by 4769) is the cleanest host-side telemetry for behavioural detections.

## Detection and defence
- Disable RC4 domain-wide once compatibility is verified; require AES via msDS-SupportedEncryptionTypes
- Rotate `krbtgt` twice on a schedule (otherwise Golden Tickets survive password resets)
- Audit 4768 (TGT) / 4769 (TGS) / 4770 (renew) — focus on RC4 etype on AES-capable accounts, anomalous SPNs, and source IPs
- Enforce PAC validation (KB5008380 enforcement mode) and patch the regular Kerberos CVE drip

## References
- [RFC 4120](https://www.rfc-editor.org/rfc/rfc4120) — protocol specification
- [Hacker Recipes — Kerberos](https://www.thehacker.recipes/a-d/movement/kerberos) — attack-oriented walkthrough
- [HackTricks — Kerberos auth](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-kerberos-88/index.html) — practical command reference
- [ired.team — AD & Kerberos abuse index](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse) — curated lab walkthroughs for each Kerberos primitive
- See also: [[asreproast]], [[kerberoasting]], [[golden-tickets]], [[silver-tickets]]
