---
title: WDigest Cleartext Credential Re-Enable
slug: wdigest-cleartext-enable
---

> **TL;DR:** Flip `HKLM\...\WDigest\UseLogonCredential` to `1`, wait for any interactive logon, then read cleartext passwords straight out of LSASS with `sekurlsa::wdigest`.

## What it is
A configuration downgrade: KB2871997 (2014) made WDigest stop caching reversible cleartext credentials by default on Windows 8.1 / 2012 R2 and later. The behaviour is gated by a single registry DWORD — restoring the value reverts LSASS to keeping the user's plaintext password in `wdigest.dll`'s credential structure on every interactive or RDP logon. See also [[credential-dumping]] and [[lsa-secrets]].

## Preconditions / where it applies
- Local administrator or SYSTEM (write access to `HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest`)
- LSA Protection (RunAsPPL) **not** enforced — otherwise LSASS memory read is blocked without a vulnerable signed driver
- A fresh interactive / RDP / RunAs logon **after** the flip; existing sessions are not retroactively populated

## Technique
Set the registry value, optionally hop a session to seed creds, then dump.

```cmd
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest ^
    /v UseLogonCredential /t REG_DWORD /d 1 /f
:: wait for / induce a fresh logon, then on the attacker box:
mimikatz # privilege::debug
mimikatz # sekurlsa::wdigest
```

Patient operators pair this with a logoff lure (fake "session expired" prompt) or simply wait for the next morning's RDP. Reg.exe is noisy — prefer `NtSetValueKey` via a small loader, or the same write through WMI `StdRegProv`.

## Detection and defence
- Sysmon EID **13** (RegistryValueSet) on `...\WDigest\UseLogonCredential` — extremely high signal, almost never legitimately changed
- Windows Security EID **4657** with the same key path
- Hardening: enforce LSA Protection (`RunAsPPL=1`), deploy Credential Guard, and set `UseLogonCredential=0` via GPO so a tamper is reverted

## References
- [ired.team — Forcing WDigest to Store Credentials in Plaintext](https://www.ired.team/offensive-security/credential-access-and-credential-dumping/forcing-wdigest-to-store-credentials-in-plaintext) — original walkthrough
- [MITRE ATT&CK T1112 / T1003.001](https://attack.mitre.org/techniques/T1003/001/) — LSASS Memory dumping context
