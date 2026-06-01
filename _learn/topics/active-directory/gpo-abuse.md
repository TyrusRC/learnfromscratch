---
title: GPO abuse
slug: gpo-abuse
---

> **TL;DR:** Group Policy Objects ship code (scheduled tasks, scripts, MSI installs, registry edits) to every machine or user in their linked scope. Write access to a GPO — even via inherited ACL on the SYSVOL folder or the AD object — means SYSTEM on every endpoint inside that scope on the next refresh.

## What it is
A GPO is two halves: an AD object under `CN=Policies,CN=System,DC=…` and a folder on the SYSVOL share at `\\corp.local\SYSVOL\corp.local\Policies\{GUID}\`. Writable Group Policy Container or Group Policy Template means an attacker can edit `gPCFileSysPath` contents (scripts, scheduled tasks, preferences) and the gPCMachineExtensionNames CSEs list. The next `gpupdate` (default refresh 90 ± 30 minutes, immediate on reboot/logon) executes the payload as SYSTEM (machine policy) or the logged-in user (user policy).

## Preconditions / where it applies
- `GenericAll`, `GenericWrite`, `WriteDACL`, `WriteOwner`, or `WriteProperty` on the GPO's AD object (gPCFileSysPath path counts too)
- Or Modify rights inside the SYSVOL GPO folder (`gPCFileSysPath`)
- The GPO is linked to an OU containing at least one interesting target (DCs, servers, admin workstations)

## Technique
SharpGPOAbuse (Windows) and pyGPOAbuse (Linux) automate the edits. To pop SYSTEM on every machine the GPO applies to, add an immediate scheduled task:

```bash
# Linux side
python3 pygpoabuse.py corp.local/alice:Pass -gpo-id '{31B2F340-...}' \
  -command 'powershell -enc <b64>' -taskname Updater
```

```powershell
# Windows side
SharpGPOAbuse.exe --AddComputerTask --TaskName "Updater" \
  --Author "NT AUTHORITY\SYSTEM" --Command "cmd.exe" \
  --Arguments "/c powershell -enc <b64>" --GPOName "Workstation Baseline"
```

Both tools edit `Machine\Preferences\ScheduledTasks\ScheduledTasks.xml`, bump the `versionNumber` attribute on the GPC, and add `{AADCED64-746C-4633-A97C-D61349046527}` to `gPCMachineExtensionNames`. On next policy refresh the task runs once with SYSTEM context and deletes itself.

For user-context payloads, drop a logon script (`User\Scripts\Logon\`) and toggle the GPT.ini version. For persistence on DCs, target a GPO linked to the Domain Controllers OU — but be aware that "Default Domain Controllers Policy" is heavily monitored.

Restore: always snapshot `GPT.ini`, the affected XML files, and `gPCMachineExtensionNames` before editing so you can revert.

## Detection and defence
- Event 5136 (AD object change) on Group Policy Container objects — filter on attributes `gPCMachineExtensionNames`, `versionNumber`
- File integrity on SYSVOL: any new `ScheduledTasks.xml`, `Registry.xml`, or `Scripts.ini` is a high-fidelity signal
- BloodHound's `GPLink`, `WriteGPLink`, `GenericAll`→GPO edges show abuse paths; remove non-Tier-0 principals from any GPO ACL
- Set advanced auditing on SYSVOL and force GPO change events to a SIEM

## References
- [SharpGPOAbuse](https://github.com/FSecureLABS/SharpGPOAbuse) — Windows tooling and technique writeup
- [pyGPOAbuse](https://github.com/Hackndo/pyGPOAbuse) — Linux/Impacket equivalent
- [HackTricks — GPO abuse](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/acl-persistence-abuse/index.html) — broader ACL→GPO paths
- See also: [[acl-abuse]], [[bloodhound]], [[ad-persistence]]
