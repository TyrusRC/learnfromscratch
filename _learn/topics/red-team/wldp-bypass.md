---
title: WLDP bypass
slug: wldp-bypass
---

> **TL;DR:** Windows Lockdown Policy is the in-process API script hosts call to ask "may I run this?" Defender and WDAC consult it. Patch `WldpQueryDynamicCodeTrust` / `WldpIsClassInApprovedList` in-process and dynamic code loads stop being checked.

## What it is
WLDP (`wldp.dll`) is the userland gate that Windows script hosts and the .NET runtime use to ask the OS whether dynamic code (script blocks, dynamically loaded assemblies, COM objects) is allowed under the current code-integrity policy. It complements AMSI: AMSI scans content, WLDP enforces policy. When WDAC is on, WLDP enforces the script policy.

## Preconditions / where it applies
- Code execution inside a script host (PowerShell, JScript) or .NET runtime
- Write access to your own process memory
- Relevant primarily when WDAC / Constrained Language Mode is enforced — without WDAC, WLDP usually returns "trusted" trivially

## Technique
Key functions:
- `WldpQueryDynamicCodeTrust` — called by .NET to validate dynamic assembly loads
- `WldpIsClassInApprovedList` — called by script hosts to check COM class allowlist
- `WldpIsDynamicCodePolicyEnabled` — sets the global gate

Patch them to return success / "trusted":

```c
void* p = GetProcAddress(GetModuleHandleW(L"wldp.dll"), "WldpQueryDynamicCodeTrust");
DWORD old; VirtualProtect(p, 4, PAGE_EXECUTE_READWRITE, &old);
// xor eax, eax ; ret -> S_OK / trusted
BYTE patch[] = { 0x33, 0xC0, 0xC3 };
memcpy(p, patch, sizeof(patch));
VirtualProtect(p, 4, old, &old);
```

In a Constrained Language Mode breakout you typically patch the trio: `AmsiScanBuffer` (AMSI), `EtwEventWrite` (telemetry), and `WldpQueryDynamicCodeTrust` (policy). The order matters: ETW first to stop telemetry of the patches themselves, then AMSI and WLDP.

**.NET reflective load chain** — with WDAC on, loading an arbitrary assembly with `Assembly.Load` fails unless WLDP signs off. Patch WLDP first, then `Assembly.Load(byte[])` proceeds.

**Script policy bypass classics:** Casey Smith / Matt Graeber catalogued multiple historic bypasses where a signed Microsoft script (XSL, MSBuild, InstallUtil) was the gate's blind spot. With newer Microsoft block-rule policies most of these are addressed, but the WLDP-patch pattern survives because it operates below the policy decision.

**ACG interaction.** Arbitrary Code Guard (`ProcessDynamicCodePolicy`) hardens the *same* surface from a different angle: with ACG opted into your own process, existing pages cannot be flipped to writable and new RWX allocations are refused, which kills the inline WLDP patch from inside that process. The caveat defenders forget is that ACG does not block a *remote* process from calling `VirtualAllocEx` + `WriteProcessMemory` into an ACG-protected target — so an attacker who already has another foothold can still drop the WLDP patch from the outside.

## Detection and defence
- ETW-TI emits the same write-virtual-memory / protect-virtual-memory signal as AMSI patching — combined with the function name resolution beforehand, that's a high-confidence indicator
- WDAC, when enforced kernel-side for kernel-mode code, isn't affected by userland WLDP patches — only the script side weakens
- Defenders should enable WDAC in enforcement (not audit) and apply Microsoft's recommended block rules to remove LOLBin script primitives the WLDP-patch needs to leverage
- Hunt: writes to first bytes of `wldp.dll!Wldp*` functions in any process

## References
- [Microsoft Docs — WDAC](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/wdac) — overview
- [bohops blog](https://bohops.com/) — historic WLDP / script policy bypass research
- [Microsoft — recommended block rules](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/microsoft-recommended-block-rules) — what defenders should block
- [ired.team — ACG / ProcessDynamicCodePolicy](https://www.ired.team/offensive-security/defense-evasion/acg-arbitrary-code-guard-processdynamiccodepolicy) — the dynamic-code mitigation that overlaps WLDP and its remote-injection gap
- [[amsi-bypass]] [[etw-bypass]] [[living-off-the-land]]
