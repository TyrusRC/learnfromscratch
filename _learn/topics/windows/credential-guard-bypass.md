---
title: Credential Guard Bypass
slug: credential-guard-bypass
---

> **TL;DR:** With SYSTEM and (usually) PPL-bypass primitives, defeat VBS-protected LSAIso by patching WDigest's `g_IsCredGuardEnabled` / `g_fParameter_UseLogonCredential` in LSASS memory or by abusing LsaIso's exposed crypto (Pass-the-Challenge) — credentials end up cleartext or crackable despite Credential Guard appearing enabled.

## What it is
Credential Guard (CG) moves NTLM hashes, Kerberos TGTs and WDigest cleartext into **LSAIso**, a trustlet running in VTL1 inside a Hyper-V-backed Virtual Secure Mode. LSASS in VTL0 only talks to LSAIso through ALPC and never sees the secrets. Bypass families: (1) **WDigest patching** — flip the two globals in `wdigest.dll` so LSASS resumes caching cleartext on next interactive logon; (2) **Pass-the-Challenge** — call LsaIso's `NtlmIumCalculateNtResponse` to compute responses without ever extracting the NT hash; (3) **patch downgrade** of CG hardening fixes via Windows Downdate (largely mitigated).

## Preconditions / where it applies
- Local SYSTEM, plus the ability to write to LSASS — i.e. a PPL bypass (signed driver, RTCore-style BYOVD) since LSASS runs as PPL on CG hosts
- For WDigest patching: a fresh interactive / RDP logon must occur after the patch to populate cleartext
- Target running CG (VBS + HVCI + `LsaCfgFlags=1`); patch level matters because Microsoft has hardened several bypass paths

## Technique
Locate the two WDigest globals via signature scan or PDB offsets, flip both bytes, then wait for a logon and dump as usual with [[credential-dumping]] tooling. Pass-the-Challenge instead invokes LsaIso's ALPC interface from within LSASS to relay NTLMv1 challenge/response pairs offline.

```text
# WDigest patching flow
1. Open LSASS (requires SeDebugPrivilege + PPL bypass)
2. Find wdigest.dll base
3. Pattern-scan for g_IsCredGuardEnabled  (BYTE) -> write 0x00
4. Pattern-scan for g_fParameter_UseLogonCredential (BYTE) -> write 0x01
5. Force a new logon (e.g. RDP back in) and run sekurlsa::wdigest
```

```cmd
:: helper: ensure UseLogonCredential is also on in the registry so survival across reboots is easier
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest ^
    /v UseLogonCredential /t REG_DWORD /d 1 /f
```

OPSEC: PPL bypass and LSASS writes are extremely loud. Pass-the-Challenge is quieter — no LSASS write, just ALPC traffic to LsaIso — but only yields NTLMv1 responses, useful against legacy services or for offline cracking.

## Detection and defence
- Enable Credential Guard *with* LSA-as-PPL (`RunAsPPL=1`) and HVCI; revoke vulnerable drivers via the Microsoft blocklist
- Sysmon EID 10 (`ProcessAccess`) on `lsass.exe` with `0x1FFFFF` / write-memory access masks
- Disable WDigest entirely (`UseLogonCredential=0` enforced by GPO) and Defender ASR rule "Block credential stealing from LSASS"
- 4673/4674 audit on `SeDebugPrivilege` from non-baseline processes

## References
- [itm4n — Revisiting a Credential Guard Bypass](https://itm4n.github.io/credential-guard-bypass/) — modern WDigest patch walkthrough
- [Oliver Lyak — Pass-the-Challenge: Defeating Credential Guard](https://research.ifcr.dk/pass-the-challenge-defeating-windows-defender-credential-guard-31a892eee22) — LsaIso abuse
- [ired.team — Forcing WDigest to store plaintext](https://www.ired.team/offensive-security/credential-access-and-credential-dumping/forcing-wdigest-to-store-credentials-in-plaintext) — registry side of the same primitive

Related: [[credential-dumping]], [[lsa-secrets]], [[ntlm]]
