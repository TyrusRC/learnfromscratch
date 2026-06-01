---
title: RDP enumeration
slug: rdp-enum
---

> **TL;DR:** Identify NLA status, harvest the host cert/hostname, screen for unpatched pre-auth CVEs (CVE-2019-0708 BlueKeep, CVE-2019-1181 DejaBlue), and try low-and-slow credential spraying against valid users.

## What it is
RDP enumeration is service-fingerprinting for 3389/tcp (and 3389/udp for UDP transport). The two most interesting facts to extract before authenticating are whether Network Level Authentication (NLA) is required — when off, a pre-auth attack surface opens up — and the TLS cert / NetBIOS name leaked in the X.224 handshake, which often reveals the domain and machine name without any credential.

## Preconditions / where it applies
- Network reach to 3389/tcp on the target.
- For NLA-disabled hosts: any unauthenticated probe; potentially exploitable via legacy pre-auth CVEs.
- For NLA-enabled hosts: a valid credential is required, but you can still validate username/password pairs and observe lockout behaviour. See [[password-spraying]].

## Technique
Service fingerprint and cert grab:

```bash
nmap -p3389 --script rdp-ntlm-info,rdp-enum-encryption,ssl-cert 10.0.0.0/24
```

`rdp-ntlm-info` is the high-value script: it returns the NetBIOS domain, DNS domain, computer name, and OS build via an NTLM challenge embedded in the CredSSP negotiation — no credentials, no logs of interactive logon. Build numbers from the cert and the script let you map straight to KB-level patches.

BlueKeep triage (un-patched 7/2008R2/XP):

```bash
nmap -p3389 --script rdp-vuln-ms12-020 10.0.0.0/24
# Validate carefully — Metasploit module is unstable and crashes targets.
```

Credential validation without full login (uses ncrack or hydra; respect lockout policy from [[ldap-enum]]):

```bash
nxc rdp 10.0.0.0/24 -u users.txt -p 'Spring2026' --continue-on-success
```

If NLA is off and you have an unprivileged session, screen-brute via `xfreerdp` — useful for credentialed-but-not-authorised checks:

```bash
xfreerdp /v:10.0.0.25 /u:alice /d:CORP /p:'Spring2026' \
  /cert:ignore +clipboard /dynamic-resolution
```

For lateral movement post-auth: `tsclient` drive redirection (`/drive:share,/tmp`) and clipboard sharing remain handy data-exfil channels.

## Detection and defence
- 4625 (logon failure) bursts from one source against multiple usernames — standard RDP-spray signature.
- 4624 with `LogonType=10` from unusual source IPs flags successful interactive RDP; alert on first-time pairs of (user, source subnet).
- Enforce NLA, require MFA at the front (RD Gateway with conditional access), and segment RDP behind a jump host.
- Patch BlueKeep/DejaBlue — both have public, reliable exploit code.
- Lockout / rate-limit policies plus `Account Lockout Policy` GPO mitigate the spray surface.

## References
- [HackTricks — pentesting RDP](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-rdp.html) — script and tool cookbook.
- [Microsoft — CVE-2019-0708 (BlueKeep)](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2019-0708) — vendor advisory and patch matrix.
- [NetExec wiki — RDP module](https://github.com/Pennyw0rth/NetExec/wiki) — spraying syntax and options.
- [ired.team — lateral movement RDP](https://www.ired.team/offensive-security/lateral-movement/t1076-rdp-hijacking) — post-auth tradecraft.
