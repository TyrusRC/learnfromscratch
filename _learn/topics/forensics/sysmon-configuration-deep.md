---
title: Sysmon configuration deep dive
slug: sysmon-configuration-deep
aliases: [sysmon, sysmon-config, sysmon-event-ids]
---

> **TL;DR:** Sysmon (System Monitor) is a free Windows sysinternals driver that logs process creation, network connections, file writes, registry changes, DNS queries, and more into the Windows Event Log. The value is entirely in the configuration XML that controls what gets logged and what gets filtered. SwiftOnSecurity's config is the baseline; olafhartong's modular config gives finer control. Sysmon telemetry feeds [[sigma-rules-detection-as-code]], [[elastic-detection-rules]], and [[hayabusa-windows-event-log-triage]].

## Critical event IDs

| ID | Event | Detection value |
|---|---|---|
| **1** | Process creation | Full command line, parent process, hashes, user — the single most important event |
| **3** | Network connection | Source/dest IP+port per process — detects C2, lateral movement |
| **5** | Process terminated | Completes process lifecycle |
| **7** | Image loaded (DLL) | Detects DLL side-loading, reflective loading, unsigned DLLs |
| **8** | CreateRemoteThread | Process injection (classic technique) |
| **10** | ProcessAccess | LSASS access for credential dumping (T1003) |
| **11** | File create | Dropped payloads, staged tools, written configs |
| **12** | Registry key create/delete | Persistence via Run keys, services |
| **13** | Registry value set | Actual value written — catches encoded payloads in registry |
| **14** | Registry key/value rename | Evasion via renaming registry persistence |
| **15** | FileCreateStreamHash | Alternate data stream (ADS) writes — MOTW bypass, hidden payloads |
| **17/18** | Pipe created/connected | Named pipe pivoting (Cobalt Strike SMB beacon) |
| **19/20/21** | WMI filter/consumer/binding | WMI persistence and lateral movement |
| **22** | DNS query | Process-level DNS — maps domain IOCs to specific processes |
| **23** | File delete (archived) | Captures deleted files — anti-forensics detection |
| **25** | Process tampering | Detects process hollowing, herpaderping |
| **26** | File delete logged | File deletion without archiving the content |
| **27** | File block executable | Blocks executables written to monitored paths |
| **28** | File block shredding | Blocks file shredding in monitored paths |
| **29** | FileExecutableDetected | Logs when executable content is written |

## SwiftOnSecurity vs olafhartong configs

**SwiftOnSecurity** (`sysmonconfig-export.xml`):
- Single monolithic XML, community-maintained
- Good default excludes for noisy benign processes
- Best for: quick deployment, "better than nothing" baseline
- Weakness: one-size-fits-all, can be noisy in dev environments

```bash
# Deploy SwiftOnSecurity config
sysmon64.exe -accepteula -i sysmonconfig-export.xml
```

**olafhartong** (`sysmon-modular`):
- Modular XML files per event ID, merged at build time
- Each module has include/exclude rules with documented rationale
- Best for: tuned enterprise deployment, understanding what each filter does
- Supports generating environment-specific configs

```bash
# Clone and merge modules
git clone https://github.com/olafhartong/sysmon-modular
cd sysmon-modular
# Merge into single config
python merge.py --config-name production
sysmon64.exe -accepteula -i production.xml
```

## Configuration XML structure

```xml
<Sysmon schemaversion="4.90">
  <HashAlgorithms>md5,sha256,IMPHASH</HashAlgorithms>
  <DnsLookup>True</DnsLookup>

  <EventFiltering>
    <!-- Process creation: include everything, exclude noise -->
    <RuleGroup name="ProcessCreate" groupRelation="or">
      <ProcessCreate onmatch="exclude">
        <Image condition="is">C:\Windows\System32\backgroundTaskHost.exe</Image>
        <Image condition="is">C:\Windows\System32\SearchProtocolHost.exe</Image>
        <ParentImage condition="is">C:\Windows\System32\svchost.exe</ParentImage>
        <CommandLine condition="begin with">C:\Windows\system32\DismHost.exe</CommandLine>
      </ProcessCreate>
    </RuleGroup>

    <!-- LSASS access: only include suspicious access masks -->
    <RuleGroup name="ProcessAccess" groupRelation="or">
      <ProcessAccess onmatch="include">
        <TargetImage condition="is">C:\Windows\System32\lsass.exe</TargetImage>
      </ProcessAccess>
    </RuleGroup>

    <!-- DNS: log all, exclude CDN/update noise -->
    <RuleGroup name="DnsQuery" groupRelation="or">
      <DnsQuery onmatch="exclude">
        <QueryName condition="end with">.windowsupdate.com</QueryName>
        <QueryName condition="end with">.microsoft.com</QueryName>
      </DnsQuery>
    </RuleGroup>
  </EventFiltering>
</Sysmon>
```

**Filtering logic:** `onmatch="exclude"` means log everything EXCEPT matches (allowlist approach for noise). `onmatch="include"` means log ONLY matches (targeted collection). Default is exclude — if no rule matches, the event is logged.

## Deployment via GPO

```
1. Copy sysmon64.exe + config.xml to \\domain\NETLOGON\sysmon\
2. Create GPO → Computer Config → Preferences → Scheduled Tasks
3. Create Immediate Task:
   - Action: Start a program
   - Program: \\domain\NETLOGON\sysmon\sysmon64.exe
   - Arguments: -accepteula -i \\domain\NETLOGON\sysmon\config.xml
4. Add second task for config updates:
   - Program: sysmon64.exe
   - Arguments: -c \\domain\NETLOGON\sysmon\config.xml
   - Trigger: Daily (pulls latest config)
```

Alternative: deploy via SCCM/Intune package, or use `sysmon -c <url>` for remote config (Sysmon 15+).

## Performance tuning

- **Event ID 7 (ImageLoad)** is the noisiest — generates thousands of events per minute per host. Filter aggressively or disable unless hunting DLL side-loading.
- **Event ID 10 (ProcessAccess)** on LSASS: high value but high volume. Filter to only `TargetImage` = `lsass.exe` with suspicious `GrantedAccess` masks (`0x1010`, `0x1FFFFF`).
- **Event ID 3 (NetworkConnect)** for browsers generates extreme volume. Exclude browser paths or limit to specific ports.
- **Hash algorithms:** MD5+SHA256+IMPHASH adds CPU overhead; drop MD5 if not needed for legacy IOC matching.
- **Monitor log channel size:** increase `Microsoft-Windows-Sysmon/Operational` max size to 256MB+ or forward to SIEM in real-time.

```powershell
# Check Sysmon driver status
fltmc instances | findstr SysmonDrv
# Check current config
sysmon64.exe -c
# Update config without reinstall
sysmon64.exe -c new_config.xml
```

## Evasion techniques (know the limits)

| Technique | Description | Mitigation |
|---|---|---|
| **Minifilter unhooking** | Unload SysmonDrv from minifilter stack via `fltMC unload` | Monitor Event ID 255 (driver errors), restrict fltMC access |
| **Driver unload** | `sysmon -u` requires admin — but so does the attacker post-privesc | Protect Sysmon service with ACL, monitor service stop events |
| **Config poisoning** | Replace config XML to exclude attacker's tools | Store config hash, alert on Sysmon config change (Event ID 16) |
| **Timestomping Event ID 2** | Modify file creation times to blend in | Correlate with MFT timestamps in [[disk-image-forensics]] |
| **Blind spots** | Kernel-level rootkits operate below Sysmon's usermode hooks | Pair with ETW-based telemetry and EDR kernel sensors |
| **Process name spoofing** | Rename malicious binary to excluded process name | Detect via hash mismatch in Event ID 1 |

## High-value detection queries

```
# Sigma: LSASS access from non-system process (Event ID 10)
logsource: {product: windows, category: process_access}
detection:
  selection:
    TargetImage|endswith: '\lsass.exe'
    GrantedAccess|contains: ['0x1010', '0x1FFFFF']
  filter:
    SourceImage|startswith: 'C:\Windows\System32\'
  condition: selection and not filter

# Splunk: suspicious DNS query (Event ID 22)
index=sysmon EventCode=22
| where len(QueryName) > 50 OR QueryName LIKE "%.xyz"
| stats count by Image QueryName
```

## References
- [Sysmon documentation](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon)
- [SwiftOnSecurity sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config)
- [olafhartong sysmon-modular](https://github.com/olafhartong/sysmon-modular)
- [TrustedSec — Sysmon Community Guide](https://github.com/trustedsec/SysmonCommunityGuide)

See also: [[sigma-rules-detection-as-code]], [[elastic-detection-rules]], [[detection-as-code-pipeline]], [[hayabusa-windows-event-log-triage]], [[chainsaw-evtx-hunting]], [[detection-engineering-pyramid-of-pain]], [[kape-triage-collection]]
