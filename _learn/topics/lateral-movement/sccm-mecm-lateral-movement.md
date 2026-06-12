---
title: SCCM / MECM lateral movement
slug: sccm-mecm-lateral-movement
---

> **TL;DR:** Microsoft Configuration Manager (SCCM / MECM) is the centralised software-deployment system on most large Windows estates; it has client agents on every endpoint, primary-site SQL with credentials for every device, and Network Access Accounts often configured with domain-admin equivalents. SharpSCCM and Misconfiguration Manager (`misconfigurationmanager.com`) made the attack paths public: NAA credential dump, application deployment to specific devices, SCCM PXE secret extraction, and Site System Server takeover.

## What it is
SCCM has three roles: clients (every Windows endpoint), management points (negotiation), site servers (the brains, backed by MSSQL). The site server runs as `SMS Provider`, holds policies, and lets administrators push applications, scripts, and OS images. Clients authenticate to MPs with computer accounts; the site server has Kerberos delegation to almost everything. Attack surfaces: (1) Network Access Accounts (NAA) — secrets stored on every client, decryptable with DPAPI under SYSTEM; (2) Application deployment — push code to any client SCCM manages; (3) PXE boot media — extract policy passwords if PXE password protection is disabled; (4) Hierarchy attacks — coerce a site server's machine account and relay to the SQL DB.

## Preconditions / where it applies
- SCCM is the management system (look for `CcmExec` service on endpoints, `SMS_*` services on site servers).
- For NAA dump: SYSTEM on a managed client.
- For app deployment: SCCM admin (a Full Administrator role, often given more widely than expected via the Configuration Manager console).
- For PXE secret: network reachability to PXE-enabled MP and an unprotected boot environment.

## Tradecraft
**Pattern 1 — NAA / OSD account credential dump (CRED-1).** Clients cache the Network Access Account (used when fetching OS images during PXE) in the WMI namespace `root\ccm\policy\Machine\ActualConfig` encrypted with DPAPI. SharpSCCM (`SharpSCCM.exe local secrets`) decrypts under SYSTEM:

```powershell
# As SYSTEM on a client
.\SharpSCCM.exe local secrets
# Output: NAA UserName + Password (plaintext)
```

NAAs are frequently scoped too high — domain users, occasionally domain admins. Re-use the cred for RDP / WinRM to other machines, or feed to BloodHound for path-finding.

**Pattern 2 — Application deployment to arbitrary client (TAKEOVER-1).** With SCCM admin rights:

```powershell
.\SharpSCCM.exe exec --device TARGET-PC --path "powershell.exe -enc <b64>"
# Or via console: deploy a new application that runs as SYSTEM on the target collection
```

Lands code as SYSTEM on the target. Less observable than psexec because the SCCM client expects to run remotely-pushed code.

**Pattern 3 — Hierarchy takeover (HIERARCHY-1, NTLM relay to site DB).** Coerce the site server's computer account via PetitPotam / DFSCoerce / Printerbug, relay the NTLM auth to the SCCM MSSQL DB. The site server account is `db_owner` on the SCCM database; you can read every secret column (including the encrypted NAA), and add yourself as a Full Administrator. Tooling: `ntlmrelayx.py -t mssql://SCCM-SQL/CM_XYZ -socks` with PetitPotam targeting the site server.

**Pattern 4 — Client push installation account (ELEVATE-1).** "Client Push Installation Account" is configured with admin rights on every device that may receive client installation. SCCM admin → read CPIA from the console → cred replay. Misconfiguration Manager catalogues a dozen similar named-account abuses.

**Pattern 5 — PXE secrets (CRED-2).** When PXE is enabled, an unauthenticated TFTP client can fetch the boot WIM and policy blobs. Without PXE password protection, the policy blobs include media-installation passwords and (older versions) NAA. Use [`PXEThief`](https://github.com/MWR-CyberSec/PXEThief).

**Pattern 6 — SCCM admin enumeration.** Misconfiguration Manager publishes a methodology to enumerate every Configuration Manager admin role and the specific tenants/collections they cover. Many orgs grant "Full Administrator" via nested AD groups; one stale member = SCCM admin.

```powershell
# In Configuration Manager PowerShell module
Get-CMAdministrativeUser | Select LogonName, RoleNames, CollectionNames
```

**Quick recon from a managed endpoint.**

```powershell
# Is SCCM installed?
Get-Service CcmExec
# Find management point
Get-WmiObject -Namespace root\ccm -Class SMS_Authority
# Trigger a hardware inventory cycle (background, low signal)
Invoke-WmiMethod -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000001}'
```

## Detection and defence
- Disable NAA entirely on modern SCCM — use Enhanced HTTP and computer-account auth instead. Microsoft has supported this since 2016; the only blocker is image-based OSD with non-domain-joined devices.
- For SCCM admin: enforce Tier 0 separation. SCCM Full Administrator = domain admin equivalent; treat it that way.
- Enable PXE password protection and signed boot media.
- Coercion protection: Extended Protection for Authentication (EPA) on the SCCM SQL endpoint; SMB signing; disable WebClient on site systems.
- Audit SCCM application deployments: any new application pushed to admin-tier hosts requires change ticket. Site DB query:

```sql
SELECT * FROM v_DeploymentSummary WHERE CreationTime > DATEADD(day, -1, GETDATE())
```

- Sigma rule: client receiving an unscheduled application push outside maintenance window.

## OPSEC pitfalls
- SharpSCCM and PXEThief have signatures in most modern EDRs as of 2024; rebuild or BYOL-rename.
- `SMS_*` services log heavily under `C:\Windows\CCM\Logs\` and `C:\Program Files\Microsoft Configuration Manager\Logs\`. Application deployments appear in `AppEnforce.log` and `execmgr.log`.
- The site server's audit status messages (`SMSAuth`) include who created each application. Use a stolen SCCM admin account that already does deployments, not a fresh one.

## References
- [Misconfiguration Manager](https://github.com/subat0mik/Misconfiguration-Manager) — catalogue of SCCM attack paths (CRED-, ELEVATE-, TAKEOVER-, RECON-)
- [SharpSCCM](https://github.com/Mayyhem/SharpSCCM) — primary exploitation tooling
- [PXEThief](https://github.com/MWR-CyberSec/PXEThief) — PXE-boot policy extraction
- [SpecterOps — SCCM blogs](https://specterops.io/blog/) — research series

See also: [[psexec-family]], [[smb-exec]], [[adminsdholder-abuse]], [[bloodhound]], [[rmm-tool-abuse-screenconnect-anydesk]]
