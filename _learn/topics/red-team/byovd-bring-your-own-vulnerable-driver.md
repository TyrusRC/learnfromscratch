---
title: BYOVD — Bring Your Own Vulnerable Driver
slug: byovd-bring-your-own-vulnerable-driver
---

> **TL;DR:** Adversaries load a Microsoft-signed but vulnerable kernel driver (CVE-classified) to get arbitrary kernel R/W, then kill or blind EDR by patching its userland callbacks and unloading its minifilter. Lazarus's RustDoor, Scattered Spider's `kdmapper` chains, and BlackByte's `RTCore64.sys` all use this primitive.

## What it is
Kernel-mode drivers run at Ring 0 with full memory access. Microsoft requires drivers be code-signed, but old/legitimate signed drivers (with CVEs) remain installable. Once loaded, an attacker exploits the driver's vulnerable IOCTL (e.g., arbitrary MSR write, arbitrary physical memory mapping) to gain kernel R/W, then walks `EPROCESS` / `_PSP_CREATE_PROCESS_NOTIFY_ROUTINE` arrays to nuke EDR.

## Preconditions / where it applies
- SeLoadDriverPrivilege (administrator) on the target
- Driver Signature Enforcement still bypassed because the driver IS legitimately signed
- HVCI (Hypervisor-protected Code Integrity) NOT enforced — HVCI is the main mitigation; on by default since Windows 11 22H2 on Secured-core PCs only
- Microsoft Vulnerable Driver Blocklist NOT enabled or out of date (most enterprises before 2023)

## Notable vulnerable drivers
| Driver | CVE | Capability |
|---|---|---|
| `RTCore64.sys` (MSI Afterburner) | CVE-2019-16098 | Arbitrary MSR + physical mem R/W |
| `gdrv.sys` (Gigabyte) | CVE-2018-19320 | Arbitrary kernel R/W |
| `dbutil_2_3.sys` (Dell) | CVE-2021-21551 | Kernel R/W via IOCTL |
| `procexp152.sys` (Sysinternals) | (unfixed termination) | Arbitrary process terminate |
| `truesight.sys` (Adlice) | — | Process terminate, used by Scattered Spider 2024 |
| `wnbios.sys` | CVE-2022-26496 | Physical mem map |

## Tradecraft

**Stage the driver:**

```cmd
:: Copy signed .sys to target
copy RTCore64.sys C:\Windows\Temp\
:: Create service and start it
sc create rtcsvc binPath= C:\Windows\Temp\RTCore64.sys type= kernel
sc start rtcsvc
```

**Open handle and issue exploit IOCTLs from userland loader:**

```c
HANDLE h = CreateFileW(L"\\\\.\\RTCore64", GENERIC_READ|GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
// Build RTCORE_MEMORY_READ struct, point to EPROCESS field
DeviceIoControl(h, IOCTL_RTCORE_MEMORY_READ, &in, sizeof(in), &out, sizeof(out), &br, NULL);
```

**EDR blinding pattern:**

1. Resolve EDR driver name (e.g., `MsMpEng.exe` for Defender, `CSAgent.sys` for CrowdStrike)
2. Walk `PsLoadedModuleList` to find its base
3. Patch `PsSetCreateProcessNotifyRoutine`, `ObRegisterCallbacks`, `CmRegisterCallback` slots — zero out EDR entries
4. Optionally unmap minifilter callbacks (`FltRegisterFilter` callback table)

**Public tools:**
- `EDRSandblast` (wavestone-cdt) — automates BYOVD via `RTCore64`, supports kernel/userland unhook
- `Backstab` (Yaxser) — terminates EDR via `procexp152.sys`
- `KDMapper` (TheCruZ) — loads unsigned drivers via `iqvw64e.sys` (Intel)
- `Realblindingedr`, `EDRPrison`, `Terminator` — variants in the wild

**OPSEC tradeoffs:**
- Service creation (`sc create … type= kernel`) generates 7045 + 4697; some operators use `NtLoadDriver` direct syscall to skip SCM
- Driver file on disk is a YARA goldmine (driver hashes are widely tracked); rename and reorder sections, or pack — but the signature won't survive modification
- Defender's ASR rule "Block abuse of exploited vulnerable signed drivers" (BCDAB8E5-…) blocks the blocklist drivers in real time

## Detection and defence
- Enable Microsoft Vulnerable Driver Blocklist (default on Windows 11 since 22H2): `DeviceGuard` policy with `HVCI` + blocklist
- HVCI prevents loading unsigned/altered drivers, and blocks read/write of executable kernel memory — kills most BYOVD R/W primitives
- 7045 service install where ImagePath ends in `.sys` and ServiceType = `kernel` from a non-admin process is a high-fidelity Sigma signal
- Defender for Endpoint detects most blocklist drivers under "VulnerableDriverDetected"
- Sysmon 6 (driver load) — alert on loads outside `\Windows\System32\drivers\` and from temp paths
- Hunt EDR connector silence: if EDR agent stops heartbeating but Windows service is still "running", suspect kernel patching

## References
- [LOLDrivers](https://www.loldrivers.io/) — community catalog of vulnerable signed drivers
- [Microsoft Vulnerable Driver Blocklist](https://learn.microsoft.com/windows/security/application-security/application-control/microsoft-recommended-driver-block-rules)
- [EDRSandblast](https://github.com/wavestone-cdt/EDRSandblast)
- [Mandiant — Bring Your Own Vulnerable Driver](https://cloud.google.com/blog/topics/threat-intelligence/) — case studies

See also: [[edr-hooks-and-unhooking]], [[etw-bypass]], [[defender-for-identity-evasion]], [[process-injection-techniques]], [[opsec-fundamentals]], [[living-off-the-land]], [[applocker-bypass-techniques]]
