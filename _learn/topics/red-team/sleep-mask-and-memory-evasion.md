---
title: Sleep mask and memory evasion
slug: sleep-mask-and-memory-evasion
aliases: [sleep-obfuscation, beacon-memory-evasion, sleep-mask]
---

> **TL;DR:** EDRs scan process memory for implant signatures while the beacon sleeps. Sleep obfuscation encrypts the beacon in memory during sleep intervals, stack spoofing hides the call stack origin, and module stomping disguises the implant's memory region as a legitimate DLL — together they defeat in-memory scanning.

## What it is
Memory evasion addresses the detection gap that exists while an implant is idle. A beacon spends >99% of its time sleeping between check-ins. During this window, EDR memory scanners (and manual analysts) can find the implant's code and configuration in cleartext. Sleep mask techniques encrypt the implant's memory during sleep and restore it only for the brief check-in window. Complementary techniques — stack spoofing and module stomping — hide the origin and location of the implant's code.

## Preconditions / where it applies
- Beacon / implant running in a target process with sleep intervals (any C2 framework, not just Cobalt Strike)
- EDR with periodic memory scanning (CrowdStrike, SentinelOne, Elastic, Defender for Endpoint)
- Kernel-level ETW Threat Intelligence provider monitoring `VirtualProtect` / memory permission changes
- CRTL (Certified Red Team Lead) and advanced CRTO — this is where engagements fail against mature SOCs

## Technique

### Cobalt Strike sleep_mask (built-in)

Cobalt Strike 4.5+ introduced `sleep_mask` in the Malleable C2 profile:

```c
stage {
    set sleep_mask "true";   // encrypt beacon during sleep
    set userwx    "false";   // never RWX — use RX and flip to RW for decrypt
    set cleanup   "true";    // free stager memory
}
```

The sleep mask kit (shipped with CS) provides a customisable mask stub. The default XOR-encrypts the beacon's `.text` section and heap allocations during `Sleep()`, then decrypts on wake. It flips the beacon's memory from RX → RW (for encryption), encrypts, sleeps, decrypts, flips RW → RX, and resumes.

**Problem:** The mask stub itself must remain executable and unencrypted — it's a ~200-byte decryptor loop sitting in memory. EDR vendors signature this stub. Custom sleep mask kits replace the stub with unique implementations.

### Ekko — timer-based sleep obfuscation

Ekko (by C5pिder) uses `CreateTimerQueueTimer` / `NtSetTimer` to schedule the decryption callback, then encrypts the beacon and suspends via `NtDelayExecution`. The key insight: the encryption and decryption happen in **ROP chains executed by the OS timer dispatcher**, not in the beacon's own thread context.

```c
// Ekko simplified flow:
// 1. Queue ROP chain: VirtualProtect(beacon, RW) → SystemFunction032(encrypt) → Sleep → 
//    SystemFunction032(decrypt) → VirtualProtect(beacon, RX)
// 2. Main thread calls WaitForSingleObject — it looks like a normal waiting thread
// 3. Timer fires the ROP chain in a thread pool thread
// 4. Beacon wakes up decrypted and executable

// SystemFunction032 — undocumented RC4 function in advapi32.dll
// Used because it encrypts in-place without needing a custom crypto loop in memory
typedef NTSTATUS(NTAPI* pSystemFunction032)(PUNICODE_STRING data, PUNICODE_STRING key);
```

Detection-wise, Ekko's ROP chain is visible if the EDR inspects timer queue objects, but most don't. The beacon thread's call stack during sleep shows only `NtWaitForSingleObject` — no suspicious return addresses.

### Foliage — APC-based sleep obfuscation

Similar to Ekko but uses `NtQueueApcThread` to queue the encrypt/decrypt operations as APCs on the current thread:

```c
// Foliage flow:
// 1. Create event object
// 2. Queue APCs: VirtualProtect(RW) → encrypt → NtDelayExecution → decrypt → VirtualProtect(RX) → SetEvent
// 3. Enter alertable wait (NtTestAlert or SleepEx) — APCs fire in order
// 4. Wait on event to know when cycle completes
```

APC-based approaches are stealthier against timer-object inspection but require an alertable wait state.

### Zilean — a more recent variant

Zilean combines sleep encryption with **heap encryption** — it walks the process heap and encrypts beacon-related allocations (configuration, tasking buffers, C2 responses) in addition to the code sections. This addresses the gap where EDRs scan heap memory for beacon configuration strings (watermark, C2 URLs, public key).

### Stack spoofing

During sleep, the beacon's thread has a call stack. If an analyst or EDR inspects it, the return addresses reveal the implant's location. Stack spoofing overwrites the thread's stack frames with legitimate-looking return addresses.

**ThreadStackSpoofer** — overwrites the saved return address at the stack frame boundary before sleeping:

```c
// Before sleep: spoof the return address
// Original: ... → beacon_sleep() → main_loop() → ReflectiveLoader() [suspicious]
// Spoofed:  ... → beacon_sleep() → ntdll!RtlUserThreadStart+0x21 [looks normal]

// Save the real return address
void* realRetAddr = _ReturnAddress();
// Overwrite with benign address
*(void**)(_AddressOfReturnAddress()) = (void*)GetProcAddress(GetModuleHandle("ntdll"), "RtlUserThreadStart");
// Sleep
Sleep(interval);
// Restore
*(void**)(_AddressOfReturnAddress()) = realRetAddr;
```

**CallStackMasker** — more sophisticated: it fabricates an entire plausible call stack by chaining gadgets from legitimate DLLs. The spoofed stack looks like a normal Windows thread waiting in a system call.

**SilentMoonwalk** — uses a different approach: instead of spoofing after the fact, it uses a custom trampoline that never places the beacon's return address on the stack in the first place.

### Module stomping

Instead of allocating fresh memory (which EDRs monitor), overwrite the `.text` section of a loaded but unused DLL:

```c
// 1. Load a sacrificial DLL
HMODULE hMod = LoadLibrary("C:\\Windows\\System32\\amsi.dll"); // or any DLL you won't need

// 2. Find its .text section
PIMAGE_NT_HEADERS nt = (PIMAGE_NT_HEADERS)((BYTE*)hMod + ((PIMAGE_DOS_HEADER)hMod)->e_lfanew);
PIMAGE_SECTION_HEADER text = IMAGE_FIRST_SECTION(nt);
void* textBase = (BYTE*)hMod + text->VirtualAddress;
SIZE_T textSize = text->Misc.VirtualSize;

// 3. Make it writable, copy beacon shellcode, restore to RX
DWORD old;
VirtualProtect(textBase, textSize, PAGE_READWRITE, &old);
memcpy(textBase, beaconShellcode, beaconSize);
VirtualProtect(textBase, textSize, PAGE_EXECUTE_READ, &old);

// 4. Execute — beacon now lives inside amsi.dll's memory range
((void(*)())textBase)();
```

Memory scanners see executable code in a region backed by `amsi.dll` — a legitimate, signed Microsoft DLL. The region has `SEC_IMAGE` flags, not `MEM_PRIVATE`.

### Phantom DLL hollowing

An evolution of module stomping: instead of loading a real DLL, create a **section object** from a DLL on disk, map it into the process, then overwrite it. The mapped section has `SEC_IMAGE` backing and appears in the process's module list, but the DLL was never truly "loaded" (no `LdrLoadDll` event, no `DLL_PROCESS_ATTACH` callback).

```c
// 1. Open DLL file → NtCreateSection(SEC_IMAGE)
// 2. NtMapViewOfSection into current process
// 3. Overwrite .text with beacon shellcode
// Result: beacon lives in a "DLL" that looks legitimate in memory but was never loaded through the loader
```

### Gargoyle — timer-based execution

Gargoyle is an older technique: the implant marks its memory as non-executable (RW) and uses `SetTimer`/`CreateTimerQueueTimer` to periodically mark it RX, execute a check-in, then mark it RW again. The code only exists as executable memory for milliseconds:

```text
Timeline:
[RW - sleeping] ----timer fires----> [RX - executing] ----done----> [RW - sleeping]
     ~60 seconds                          ~200ms                        ~60 seconds
```

This defeats point-in-time memory scans unless the scan happens during the brief execution window.

## Detection and defence
- **VirtualProtect flipping** — ETW Threat Intelligence logs `PAGE_READWRITE` ↔ `PAGE_EXECUTE_READ` transitions on image-backed memory; rapid flipping is a strong signal
- **Unbacked executable memory** — memory regions with `MEM_PRIVATE` and `PAGE_EXECUTE*` that don't correspond to a file on disk; module stomping avoids this, but phantom DLL hollowing still has anomalies (mapped section with modified bytes)
- **Timer queue inspection** — Ekko's ROP chain is visible in timer objects; tools like `BeaconHunter` enumerate timer queues for suspicious callbacks
- **Call stack validation** — compare thread stacks against known-good patterns; spoofed stacks may reference code at unusual offsets within legitimate functions
- **Sleep mask stub detection** — the small decryptor loop has instruction patterns (XOR loop, `SystemFunction032` call) that can be signatured even when the beacon body is encrypted
- **Heap scanning** — even with code encryption, heap allocations may contain beacon metadata; Zilean addresses this but increases complexity
- **Hardware breakpoints on sleep functions** — set a breakpoint on `NtDelayExecution`; when it fires, scan the calling process's memory for decrypted beacon signatures (they must be present briefly before encryption)
- **PE-sieve / Moneta / Hunt-Sleeping-Beacons** — open-source tools that detect modified image sections, unbacked executable memory, and sleeping beacons

## OPSEC notes
- Sleep mask without stack spoofing is incomplete — the call stack still points to the implant
- Module stomping with a DLL that's normally loaded by the target process (e.g., `amsi.dll` in PowerShell) is suspicious if the DLL's code doesn't match the on-disk version
- Choose a sacrificial DLL that the process wouldn't normally load — but also one that won't cause crashes when its `DllMain` runs
- `userwx false` in the profile is critical — an RWX region containing encrypted beacon code is trivially detected
- Combine sleep mask + stack spoofing + module stomping for defence-in-depth; no single technique is sufficient against a mature EDR

## References
- [C5pider — Ekko](https://github.com/Cracked5pider/Ekko) — timer-based sleep obfuscation
- [SecIdiot — Foliage](https://github.com/SecIdiot/FOLIAGE) — APC-based sleep obfuscation
- [mgeeky — ThreadStackSpoofer](https://github.com/mgeeky/ThreadStackSpoofer)
- [Cobalt Strike Sleep Mask Kit](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/artifact-and-resource-kits.htm)
- [forrest-orr — Phantom DLL hollowing](https://github.com/forrest-orr/phantom-dll-hollower)
- [JoeDesimone — gargoyle](https://github.com/JLospinoso/gargoyle) — original timer-based execution
- [Elastic — Hunt Sleeping Beacons](https://www.elastic.co/blog/hunting-memory) — detection methodology

See also: [[cobalt-strike-operations]], [[cobalt-strike-malleable-c2-profiles]], [[edr-hooks-and-unhooking]], [[syscall-direct-and-indirect]], [[av-evasion-primer]], [[process-injection-techniques]], [[etw-tampering-deep]]
