---
title: BOF / Beacon Object File development
slug: bof-cobalt-strike-development
aliases: [bof-development, beacon-object-file-dev, coff-loader]
---

> **TL;DR:** Beacon Object Files (BOFs) are position-independent COFF objects loaded and executed in-process by a C2 implant's COFF loader. They give operators a way to extend a beacon with small, fast, post-ex tools without spawning a child process, dropping a DLL, or triggering a module-load callback. The pattern originated with Cobalt Strike but is now table stakes for [[sliver-c2-deep]], [[havoc-c2-deep]], and [[mythic-framework-deep]] via [[c2-frameworks]]-level adoption. BOFs still hit the same hooks as any other in-process code, so combine with [[edr-hooks-and-unhooking]] and [[syscall-direct-and-indirect]] / [[syswhispers-freshycalls-comparison]] for OPSEC.

## Why it matters

The old tradecraft was `fork & run`: beacon spawned `rundll32.exe`, injected a reflective DLL, and waited for output. That gives EDR three gifts: a new process, a remote thread, and a module load — all of which are heavily instrumented (PsSetCreateProcessNotifyRoutine, PsSetLoadImageNotifyRoutine, ETW-TI thread-create). BOFs collapse all three into "the beacon executes a bit more code in its own address space." There is no new process, no `LoadLibrary`, no entry in the PEB loader lists.

Trade-offs are real:

- BOFs run **single-threaded** and **synchronously** by default — long-running BOFs block the beacon.
- BOFs are still subject to userland API hooks. Calling `OpenProcess` from a BOF triggers the same hook as calling it from any other code unless you route through direct/indirect syscalls.
- BOFs have **no CRT**. No `printf`, no `malloc` (use `BeaconPrintf` and `MSVCRT$malloc` via DFR if you must).
- BOFs cannot persist state between executions. Each invocation is a fresh load/relocate/execute/free cycle.

For situational awareness (`whoami /priv`, enumerating LSA secrets, parsing the SAM), BOFs are the right shape. For long-running C2 (SOCKS, reverse shells), they are not.

## COFF basics

A BOF is a Microsoft COFF object file — the same `.obj` your linker would normally consume. The C2 framework ships a **COFF loader**: a piece of code that parses the COFF header, maps sections (`.text`, `.data`, `.rdata`, `.bss`) into RWX-ish memory, walks the relocation tables to fix up addresses, resolves imports via **dynamic function resolution (DFR)**, calls the exported `go` symbol, and finally frees the memory.

COFF header layout (relevant fields):

- `IMAGE_FILE_HEADER` — machine type, number of sections, symbol table offset.
- `IMAGE_SECTION_HEADER` array — name, virtual size, raw data pointer, relocations pointer.
- `IMAGE_RELOCATION` entries — `VirtualAddress`, `SymbolTableIndex`, `Type` (`IMAGE_REL_AMD64_REL32`, `IMAGE_REL_AMD64_ADDR64`, etc.).
- `IMAGE_SYMBOL` table — exported symbols (`go`) and external imports (`__imp_KERNEL32$LoadLibraryA`).

The loader's job is mostly relocation patching and symbol resolution. Open-source reference loaders worth reading: TrustedSec's `COFFLoader`, Yaxser's `COFFLoader2`, and the loaders inside [[sliver-c2-deep]] (`sliver/server/extensions`) and [[havoc-c2-deep]] (`Teamserver/cmd/server`).

## The beacon\_\* API surface

The BOF SDK exposes a handful of helpers the implant must implement. Practical subset:

- `BeaconPrintf(int type, const char* fmt, ...)` — output back to the operator. `type` is `CALLBACK_OUTPUT`, `CALLBACK_ERROR`, etc.
- `BeaconDataParse(datap* parser, const char* buffer, int size)` — initialize a parser over operator-supplied args.
- `BeaconDataInt(datap*)`, `BeaconDataShort(datap*)`, `BeaconDataExtract(datap*, int* size)` — pull typed values out.
- `BeaconOutput(int type, const char* data, int len)` — raw output (binary safe).
- `BeaconUseToken(HANDLE token)` / `BeaconRevertToken()` — impersonation, so the BOF runs under the beacon's stolen token.
- `BeaconIsAdmin()`, `BeaconGetSpawnTo(BOOL x86, char* buf, int len)` — environment queries.
- `BeaconInjectProcess`, `BeaconInjectTemporaryProcess`, `BeaconCleanupProcess` — used by injection-style BOFs.

These prototypes live in `bof.h` (or `beacon.h` depending on framework). Sliver and Havoc implement compatible shims, which is why a well-written BOF runs on all three with no source changes.

## Dynamic function resolution (DFR)

You cannot call `LoadLibraryA` directly from a BOF — there is no import table in a `.obj`. Instead, the BOF SDK uses a naming convention the COFF loader recognizes:

```c
DECLSPEC_IMPORT DWORD WINAPI KERNEL32$GetCurrentProcessId(void);
DECLSPEC_IMPORT HMODULE WINAPI KERNEL32$LoadLibraryA(LPCSTR lpLibFileName);
DECLSPEC_IMPORT BOOL    WINAPI ADVAPI32$OpenProcessToken(HANDLE, DWORD, PHANDLE);
```

The loader, when fixing up `__imp_KERNEL32$LoadLibraryA`, splits on the `$`, calls `LoadLibraryA("KERNEL32")` (already loaded), then `GetProcAddress(h, "LoadLibraryA")`, and patches the address into the relocation slot. This is why DFR feels like magic: you declare an extern with a weird name, and it just works at runtime.

Caveat: every DFR'd import becomes a normal `GetProcAddress` lookup at BOF-load time. EDRs watching `GetProcAddress` on sensitive symbols (`NtAllocateVirtualMemoryEx`, `EtwEventWrite`) will see this. Some operators preload sensitive imports via manual `LdrGetProcedureAddress` from within the BOF body instead.

## Hello-world BOF

Minimal example, `hello.c`:

```c
#include <windows.h>
#include "beacon.h"

DECLSPEC_IMPORT DWORD WINAPI KERNEL32$GetCurrentProcessId(void);

void go(char* args, int len) {
    datap parser;
    BeaconDataParse(&parser, args, len);
    char* who = BeaconDataExtract(&parser, NULL);

    DWORD pid = KERNEL32$GetCurrentProcessId();
    BeaconPrintf(CALLBACK_OUTPUT, "Hello %s, beacon PID %lu", who, pid);
}
```

Build:

```bash
x86_64-w64-mingw32-gcc -c hello.c -o hello.x64.o \
    -Wall -masm=intel -Wno-incompatible-pointer-types
```

Aggressor script (`hello.cna`):

```
alias hello {
    local('$args $bof');
    $bof = readbof($1, "hello.x64.o");
    $args = bof_pack($1, "z", $2);
    beacon_inline_execute($1, $bof, "go", $args);
}
```

`bof_pack` format characters: `b` = binary, `i` = int32, `s` = int16, `z` = zero-terminated string, `Z` = wide zero-terminated string. The format string on the C side must match exactly or `BeaconDataExtract` will return garbage.

## OPSEC considerations

- **Hooks still apply.** A BOF calling `KERNEL32$OpenProcess` hits whatever user-mode hook is on `OpenProcess`. Combine BOFs with indirect syscall stubs ([[syscall-direct-and-indirect]]) for sensitive primitives. Inline syscall stubs inside a BOF are fine — the COFF loader will happily relocate them.
- **AMSI/ETW.** BOFs don't trigger AMSI on load (they aren't scripts), but anything the BOF does that hits ETW provider callbacks (image load via `LoadLibrary`, thread create) will. See [[etw-bypass]] and [[amsi-bypass]] for in-process tampering primitives you can ship as a BOF.
- **Memory hygiene.** Beacon allocates the BOF in private RWX. EDRs scan RWX private regions. Some frameworks (Havoc's `inline-execute`, Cobalt Strike 4.10's `BeaconDataStoreProtectItem`) re-protect to RX after relocations are done.
- **No free, no problem?** Wrong. Any heap allocation inside the BOF must be freed before `go` returns. The COFF loader does not unwind for you. Memory leaks in BOFs accumulate in the beacon process forever.
- **Stdout vs OUTPUT.** `BeaconPrintf` is line-buffered and operator-visible. Don't log secrets unless you mean to.

## Framework compatibility

- **Cobalt Strike** — the reference. `bof.h`, aggressor `beacon_inline_execute`, `readbof`, `bof_pack`.
- **Sliver** — supports CS-compatible BOFs via the `coff-loader` extension. Loaded with `coff-loader install` then `execute-assembly`-style invocation. See [[sliver-c2-deep]].
- **Havoc** — first-class BOF support via `inline-execute` and the `Havoc` BOF API; CS BOFs run unmodified if they only use the documented `beacon_*` subset. See [[havoc-c2-deep]].
- **Mythic** — Apollo/Athena agents ship COFF loaders; the `execute_coff` command takes a CS-compatible BOF. See [[mythic-framework-deep]].
- **Brute Ratel** — has its own BOF format (BRC4 "badger objects") that is similar but not identical. Don't assume cross-compatibility.

## Common bugs

- **Pointer truncation.** Compiling x64 BOF with 32-bit headers (`-m32`). `sizeof(void*)` mismatch causes `IMAGE_REL_AMD64_ADDR64` relocations to corrupt adjacent data. Build with the matching `mingw` cross-compiler.
- **Missing DFR prefix.** Calling `LoadLibraryA` directly compiles but fails at load time with `Failed to resolve symbol`. Add `KERNEL32$` prefix.
- **Unfreed handles.** `OpenProcess` followed by `return` without `CloseHandle` leaks a handle in the beacon process every invocation. Use a goto-cleanup pattern.
- **Stack corruption from wrong `bof_pack` format.** Aggressor sends `i` (4 bytes) but C side calls `BeaconDataExtract` (expects length-prefixed blob). Result: garbage args, occasional crash.
- **Calling CRT functions.** `printf`, `memcpy`, `strlen` — none of these exist. Use `MSVCRT$memcpy` via DFR or inline implementations. Some compilers emit implicit `memset` / `memcpy` calls for struct init; mark those `__declspec(dllimport)` from `MSVCRT$` too.
- **Long-running loops.** A `Sleep`-loop BOF blocks the beacon's check-in. Refactor into multiple short BOFs or use `BeaconInjectProcess` for long work.

## Workflow to study

1. Read TrustedSec's `COFFLoader` source end to end. It's ~600 lines of well-commented C.
2. Build and run the "hello world" BOF above against a local `COFFLoader` (no beacon needed for development).
3. Port a single OSEP/SE-adjacent capability (e.g. `whoami /priv` enumeration via `GetTokenInformation`) into a BOF.
4. Add an indirect syscall stub for `NtOpenProcessToken`, swap your `ADVAPI32$` call for it, and verify with a hook-detection tool that the BOF no longer touches the user-mode trampoline.
5. Run the same BOF unmodified through Sliver and Havoc. Note differences in arg packing tooling.
6. Read a non-trivial BOF in the wild: `TrustedSec/CS-Situational-Awareness-BOF`, `outflanknl/C2-Tool-Collection`, or `ajpc500/BOFs`.

## Related

- [[syswhispers-freshycalls-comparison]]
- [[syscall-direct-and-indirect]]
- [[c2-frameworks]]
- [[sliver-c2-deep]]
- [[havoc-c2-deep]]
- [[mythic-framework-deep]]
- [[edr-hooks-and-unhooking]]
- [[process-injection-techniques]]
- [[amsi-bypass]]
- [[etw-bypass]]
- [[custom-windows-shellcode-writing]]

## References

- https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/beacon-object-files_main.htm
- https://github.com/trustedsec/COFFLoader
- https://www.trustedsec.com/blog/a-developers-introduction-to-beacon-object-files/
- https://sliver.sh/docs?name=BOFs
- https://github.com/HavocFramework/Havoc
- https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
