---
title: LSASS protection (PPL) and bypasses
slug: lsass-protection-ppl
aliases: [lsass-ppl, protected-process-light-lsass]
---
{% raw %}

Protected Process Light (PPL) is the kernel-enforced trust hierarchy that Windows applies to a handful of sensitive processes — most importantly `lsass.exe` when `RunAsPPL=1` is set. With PPL on, a normal `OpenProcess(PROCESS_VM_READ, lsass)` from any userland process (even SYSTEM) returns `ACCESS_DENIED`, because the kernel checks the caller's protection level against the target's signer level inside `PspCheckForInvalidAccessByProtection`. This is the single biggest reason your 2018-era credential dumping playbook stopped working on a hardened 2022/2025 endpoint, and it's the reason BYOVD became the dominant LSASS-dump tradecraft.

## Mental model — the PPL trust lattice

Every protected process carries a `PS_PROTECTION` byte in `EPROCESS.Protection`, split into a 4-bit *type* and a 4-bit *signer*. The signer ladder, low to high:

```
None(0) < Authenticode(1) < CodeGen(2) < Antimalware(3) < Lsa(4)
       < Windows(5) < WinTcb(6) < WinSystem(7)
```

The rule the kernel enforces:

```
caller.signer >= target.signer  AND  caller.type >= target.type
```

`lsass.exe` with `RunAsPPL=1` is `PsProtectedSignerLsa-Light` (signer 4, type PPL). To open it for read/write you need at least a PPL with signer `Lsa` or higher — and you can't just claim that in your PE header. The signer is derived from an EKU in the certificate chain (`1.3.6.1.4.1.311.10.3.22` for LSA, `...3.6` for WinTcb), and `MiValidateSectionSignature` checks it when the binary is mapped. So the only legitimate way "up the ladder" is to be signed by Microsoft with the right EKU, which nobody outside Redmond can do.

`RunAsPPL` is `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL = 1` (DWORD). On Windows 11 22H2+ it can be UEFI-locked (`RunAsPPLBoot = 2`), which means even a SYSTEM attacker can't flip the reg key and reboot to disable it — the value is mirrored in a UEFI variable that requires Secure Boot to mutate.

## Tradecraft — what actually works in 2025

The userland-only path is essentially dead against `RunAsPPL=1` + recent patches. What you'll see in real engagements:

**1. BYOVD against the EPROCESS protection byte.** The classic. Load a vulnerable signed driver, use its arbitrary kernel write primitive to zero `EPROCESS.Protection` on lsass, then dump normally. `mimikatz` ships `mimidrv.sys` for exactly this:

```
mimikatz # privilege::debug
mimikatz # !+
mimikatz # !processprotect /process:lsass.exe /remove
mimikatz # sekurlsa::logonpasswords
mimikatz # !processprotect /process:lsass.exe   # restore
mimikatz # !-
```

`mimidrv.sys` is Microsoft-signed by Benjamin Delpy's cert and is on the Microsoft vulnerable driver blocklist since 2022 — it will not load on a HVCI box and Defender will scream. So the field moved to third-party vulnerable drivers:

- `RTCore64.sys` (MSI Afterburner) — `MmMapIoSpace` primitive, CVE-2019-16098. Used by `KDMapper`-style loaders and `PPLKiller`.
- `mhyprot2.sys` (Genshin Impact anticheat) — kernel read/write/terminate, weaponised by Trend Micro disclosure 2022, then by RansomHouse and others.
- `zam64.sys` / `zamguard64.sys` (Zemana / MalwareFox / SteelFox) — arbitrary kernel write, used heavily by EDR-killers and the 2024 SteelFox crimeware.
- `procexp.sys` (Sysinternals) — has its own LPE history, sometimes used because it's blessed.
- `Avast aswArPot.sys` — used by Cuba/AvosLocker variants to terminate AV/EDR before touching LSASS.

The pattern is identical: open the driver's device, send the IOCTL that gives you a write primitive, walk `PsInitialSystemProcess` -> `ActiveProcessLinks` to find lsass, write 0 to `Protection`, dump, restore.

**2. Userland tricks against weaker configurations.** If PPL is off (huge chunk of the estate still), `comsvcs.dll` MiniDump is the LOLBin everyone reaches for:

```
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump 1234 C:\Windows\Temp\l.bin full
```

This still hits `MiniDumpWriteDump` under the hood, which calls `OpenProcess` with `PROCESS_ALL_ACCESS` — PPL kills it dead. `PPLdump` (itm4n, 2021) abused KnownDlls and the `WerFaultSecure` PPL to coerce a privileged miniwrite, patched in 2022. `PPLBlade` (tastypepperoni, 2023) is essentially the modern fork — DLL hijack against `dfsvc.exe` / `PrintNotify` PPL hosts; most variants are EDR-signatured now.

**3. Credential alternatives.** When LSASS is a fortress, don't push on the door. See [[dpapi-secrets]] for masterkey theft (offline if you have the user's password or the domain backup key), [[lsa-secrets]] for SECURITY hive registry secrets, browser credential stores (Chromium's `Local State` AES key is DPAPI-wrapped), and Kerberos ticket harvest from `klist`/`Rubeus` which doesn't need LSASS memory at all. This is the move 80% of the time on a mature target — see [[credential-dumping]] and [[living-off-the-land]].

## Detection — what defenders should hunt

Driver-load is the single highest-signal event:

- **Sysmon Event ID 6** (`DriverLoad`) — alert on any non-allowlisted signed driver, especially with a `Signature` matching the known-vulnerable list (MITRE has a curated CSV, LOLDrivers.io is the canonical reference).
- **Windows Security 4697** — service installed (driver registered as kernel service).
- **Microsoft Defender ASR**: `56a863a9-875e-4185-98a7-b882c64b5ce5` — *Block abuse of exploited vulnerable signed drivers*. Should be `Block` not `Audit`.
- **WDAC / HVCI** — vulnerable driver blocklist (`SiPolicy.p7b`) auto-updates monthly since 2023. This breaks most off-the-shelf BYOVD.
- **EDR kernel callbacks** — `PsSetCreateProcessNotifyRoutineEx`, `ObRegisterCallbacks` — if attackers are clearing your callbacks (see [[edr-hooks-and-unhooking]]), look for the *absence* of expected telemetry as a signal.

Splunk-style hunt for driver loads outside the gold image:

```
index=sysmon EventCode=6
| stats count by Computer, ImageLoaded, Signature, Hashes
| search NOT [ inputlookup approved_drivers.csv ]
```

Watch for handle-open patterns on lsass — Sysmon Event 10 (`ProcessAccess`) with `TargetImage` ending in `lsass.exe` and `GrantedAccess` containing `0x1010` / `0x1410` / `0x1438` is the classic dump signature. PPL doesn't suppress the log; it just makes the open fail. Alert on the *attempt*.

## OPSEC pitfalls

- **Dropping a driver is loud.** Disk write of a `.sys`, service registration, then `NtLoadDriver` — three high-signal events in under a second. If your EDR is awake, you've already lost. Stage the driver in `\\.\pipe\` or memory-mapped where the driver loader allows it, but the load itself still goes through `ZwLoadDriver` and is logged.
- **Hash renaming is useless against the MS blocklist.** HVCI checks the *Authenticode hash* of the PE, not the filename. Strip signatures and the driver won't load at all on a Secure Boot box. Re-sign with your own cert and HVCI rejects it.
- **Restore the protection byte.** If you zero `EPROCESS.Protection` and forget to put it back, the next legitimate LSASS interaction (Credential Guard, defender scan) may crash or alert on an inconsistent state. Always `!processprotect` back to `PsProtectedSignerLsa-Light` (`0x41`) before unloading.
- **Don't unload the driver immediately.** Some EDRs flag rapid load/unload as BYOVD-shaped behaviour. Either leave it (loud, but blends) or unload after a delay from a separate process.
- **Credential Guard is a different beast.** VBS + Credential Guard moves NTLM/Kerberos secrets into `LsaIso.exe` running in VTL1. PPL bypass gets you nothing useful — you'll dump empty LSASS. Check `msinfo32` -> *Virtualization-based security Services Running* before you burn a driver.

## References

- https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection
- https://www.elastic.co/security-labs/protecting-your-devices-from-information-theft-detecting-byovd
- https://itm4n.github.io/lsass-runasppl/
- https://www.loldrivers.io/
- https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control/design/microsoft-recommended-driver-block-rules
- https://github.com/gentilkiwi/mimikatz/wiki/module-~-process

See also: [[credential-dumping]] · [[lsa-secrets]] · [[dpapi-secrets]] · [[byovd-attacks]] · [[edr-hooks-and-unhooking]] · [[edr-bypass-at-exploitation-time]] · [[living-off-the-land]]

{% endraw %}
