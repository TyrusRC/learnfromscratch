---
title: SysWhispers / FreshyCalls / NimGenSyscalls - direct syscall tooling comparison
slug: syswhispers-freshycalls-comparison
aliases: [syswhispers-deep, freshycalls-deep, direct-syscall-tooling]
---

> **TL;DR:** SysWhispers (v1/v2/v3), FreshyCalls, and the Nim/Rust ports all solve the same problem - emit `Nt*`/`Zw*` stubs that put the System Service Number (SSN) into `eax` and execute `syscall` without traversing hooked `ntdll`. They differ in how they resolve the SSN (hard-coded table vs runtime sort vs egg-hunt), how much randomisation they bake in, and how visible the resulting stubs are to EDR memory scanners. This note compares them as build-time tooling. Pair with [[syscall-direct-and-indirect]] for the runtime mechanics, [[hells-halos-tartarus-gates-comparison]] for the resolver algorithms underneath, [[edr-hooks-and-unhooking]] for what they sidestep, and [[bof-cobalt-strike-development]] / [[sliver-c2-deep]] / [[havoc-c2-deep]] for how implants ship them.

## Why it matters

Most user-mode EDRs hook `ntdll!Nt*` with a `jmp` to an inspection thunk. Calling the documented Win32 wrapper - `CreateFile`, `VirtualAllocEx`, `NtCreateThreadEx` - means executing the hook first. If the operator wants to skip that, they need:

1. The correct SSN for the target OS build (changes every Windows feature update, sometimes between insider builds).
2. A stub that loads the SSN into `eax`, sets up the syscall ABI, and executes `syscall; ret`.
3. Ideally, an instruction stream that does not look like a textbook stub when an EDR enumerates RX regions in the process.

Hand-writing this for every syscall on every Windows build is grim. SysWhispers and friends generate it. Choice of generator changes the operational profile - especially after EDR vendors started signaturing the stubs themselves. See also [[process-injection-techniques]] for callers that benefit, and [[etw-bypass]] for sibling primitives that often ride along.

## The toolchain landscape

### SysWhispers (v1)

Original by jthuraisamy, written in Python. Given a list of syscalls and a target Windows version, it emits MASM (`.asm`) and a header. The SSN table is **baked into the binary**: each function checks the OS build at runtime, picks an SSN from a hard-coded table, then jumps to a shared `syscall` thunk.

- Pros: simple, deterministic, easy to debug.
- Cons: SSN table is a static fingerprint - vendors signature `mov eax, <N>` sequences. Every new Windows build needs a new table.

### SysWhispers2

The pivot. Instead of shipping an SSN table, it resolves SSNs at runtime by enumerating exported `Zw*` functions in `ntdll`, sorting them by address, and using the index as the SSN (Hell's Gate / "sort by address" trick). See [[hells-halos-tartarus-gates-comparison]] for the underlying primitive.

- Pros: no per-build table; survives Windows updates as long as export ordering holds.
- Cons: stubs still look like SysWhispers - a `mov r10, rcx; mov eax, <ssn>; syscall; ret` template is easy to memory-scan.

### SysWhispers3

The hardening pass. Adds:

- **Randomised function names** at generation time so symbol stripping / debug strings differ per build.
- **EGG bytes**: stubs are emitted with a placeholder DWORD where `syscall` would be. A post-compile Python step patches the egg with `0F 05` (`syscall`) or a `jmp <random_ntdll_address>` to perform an **indirect syscall** through a legitimate `ntdll` `syscall; ret` gadget. That makes call-stack walks land inside `ntdll`, defeating naive "syscall from non-ntdll module" telemetry.
- **Jumper / jumper_randomized** modes to spread the indirect jump across different ntdll trampolines per call.

This is the version most modern offensive tooling targets. Tradeoff: more moving parts, the post-compile patcher must run, and the indirect-jump table is itself a signature surface.

### FreshyCalls

mrexodia's C++ implementation. Header-only, integrates directly into Visual Studio. Uses the same "sort exports by address" approach as SysWhispers2 but:

- Resolves on first call and caches.
- Uses C++ templates so each syscall is a typed function - fewer footguns vs raw MASM.
- Smaller stub variance; primarily aimed at developer ergonomics rather than evasion.

Operationally similar detection profile to SysWhispers2. Often chosen when the toolchain is already C++ and a `.asm` file in the build feels heavy.

### Nim ports - NimGenSyscalls, NimlineWhispers, ParallelNimcalls

Nim's FFI and `{.emit.}` pragma make it easy to inline assembly. NimGenSyscalls (and forks) port the SysWhispers approach so that Nim implants (popular for [[c2-frameworks]] like NimPlant, and seen in [[havoc-c2-deep]] post-ex) can call direct syscalls without dragging in a separate `.asm` file. ParallelNimcalls adds per-thread resolver state.

Detection-wise: similar template, but Nim binaries are statistically rare, so signatures sometimes lag. That is a vendor-coverage gap, not a real primitive advantage.

### Rust ports

`rust-syscalls`, `ntapi`-flavoured wrappers, and inline `asm!` blocks. Rust's `naked_fn`/`global_asm!` make stubs straightforward. Trend in 2024-2026 implants ([[sliver-c2-deep]] shellcode loaders) is to use Rust with indirect syscalls and AES-decrypted stub blobs.

### Inline MASM vs compiler intrinsic

Pre-VS2019 you needed MASM for x64 inline assembly (MSVC dropped `__asm` for x64). Choices:

- **`.asm` files** assembled by `ml64.exe`, linked into the binary. SysWhispers default.
- **`__emit__` / opcode arrays** copied into RX memory at runtime - flexible but obvious in static analysis.
- **Clang / GCC inline `asm`** - portable, used by FreshyCalls-style C++ and Rust ports.

## Comparison criteria

| Criterion | SysWhispers v1 | SysWhispers2 | SysWhispers3 | FreshyCalls | Nim/Rust ports |
|---|---|---|---|---|---|
| SSN source | Static table | Sort exports | Sort exports | Sort exports | Sort exports |
| Per-build maintenance | High | Low | Low | Low | Low |
| Indirect syscall support | No | No | Yes | No (manual) | Varies |
| Stub randomisation | Names only | Names only | Names + egg + jumper | Templated | Varies |
| Build complexity | MASM + Python | MASM + Python | MASM + Python + patcher | C++ header | Single language |
| Typical detection vector | `mov eax, <N>` constant table | Stub template signature | Indirect-jump table, egg artefacts | Template signature | Same template, less coverage |

None of these are silver bullets. A modern EDR with kernel callbacks (`PsSetCreateThreadNotifyRoutine`, `ObRegisterCallbacks`) and ETW Threat Intelligence sees the syscall regardless of how the SSN was loaded - see [[etw-bypass]] for the ETW-TI angle and [[edr-bypass-at-exploitation-time]] for the kernel-side picture.

## Defensive baseline

If you build detections, the stubs themselves are still useful telemetry:

- **ETW Threat Intelligence** (`Microsoft-Windows-Threat-Intelligence`) emits events on memory allocation / protection changes regardless of which `Nt*` path is used. Kernel-mode only, not bypassable from user mode without a driver.
- **Call-stack inspection** at hooked Win32 frontends: a missing `ntdll` frame is suspicious. SysWhispers3 indirect mode defeats the simple version of this; vendors counter with shadow-stack / Intel CET enforcement plus stack-walk validation.
- **Image-load + RX scanning**: hunt for the canonical stub template (`mov r10, rcx; mov eax, imm32; syscall; ret`) in non-`ntdll` modules. SysWhispers3 reduces this signal but does not eliminate it.
- **SSN sanity**: compare the SSN executed (visible to a kernel callback) against the SSN exported by `ntdll` for the same function. Mismatch = tampering or indirect resolver gone stale.

For deeper context on what defenders deploy, see [[detection-engineering-pyramid-of-pain]].

## Workflow to study

Treat this as a lab exercise across two or three afternoons; nothing here belongs on an engagement until you have run it end to end on disposable infra.

1. Build SysWhispers v1 against a Windows 10 22H2 VM. Drop a `NtAllocateVirtualMemory` call into a minimal C program. Verify in WinDbg that the SSN matches `ntdll!NtAllocateVirtualMemory`'s first `mov eax`.
2. Rebuild with SysWhispers2. Diff the generated `.asm`. Observe the runtime resolver - put a breakpoint on the first call and watch it walk the export table.
3. Rebuild with SysWhispers3 in `jumper_randomized` mode. Run the post-compile patcher. In WinDbg, disassemble the stub - confirm the `0F 05` was patched, and step into the indirect jump landing inside `ntdll`. Snapshot call stacks at the syscall point.
4. Repeat with FreshyCalls in a C++ project. Compare binary size, build complexity, and the stub template.
5. Port the same call to NimGenSyscalls or a Rust crate. Observe how much smaller the developer footprint is.
6. Run all five binaries past an EDR you have a lab licence for. Note which detect on file write, which detect on first syscall, and which let the allocation through but alert on the follow-up `NtCreateThreadEx`. Triangulate against [[edr-hooks-and-unhooking]].
7. Bake one stub into a BOF following [[bof-cobalt-strike-development]] and another into a Sliver/Havoc loader. Re-run the EDR test - implant context changes the telemetry surface considerably.

Keep a build matrix: tool x Windows build x EDR x detect/no-detect. After a dozen rows the pattern is more useful than any blog post.

## Related

- [[syscall-direct-and-indirect]]
- [[hells-halos-tartarus-gates-comparison]]
- [[edr-hooks-and-unhooking]]
- [[etw-bypass]]
- [[amsi-bypass]]
- [[process-injection-techniques]]
- [[bof-cobalt-strike-development]]
- [[sliver-c2-deep]]
- [[havoc-c2-deep]]
- [[mythic-framework-deep]]
- [[c2-frameworks]]
- [[edr-bypass-at-exploitation-time]]
- [[detection-engineering-pyramid-of-pain]]

## References

- SysWhispers GitHub - jthuraisamy. https://github.com/jthuraisamy/SysWhispers
- SysWhispers2 GitHub. https://github.com/jthuraisamy/SysWhispers2
- SysWhispers3 GitHub - klezVirus. https://github.com/klezVirus/SysWhispers3
- FreshyCalls - mrexodia. https://github.com/crummie5/FreshyCalls
- "SysWhispers is dead, long live SysWhispers" - klezVirus blog post on v3 indirect syscalls. https://klezvirus.github.io/RedTeaming/AV_Evasion/NoSysWhisper/
- MDSec - "Bypassing User-Mode Hooks and Direct Invocation of System Calls". https://www.mdsec.co.uk/2020/12/bypassing-user-mode-hooks-and-direct-invocation-of-system-calls-for-red-teams/
