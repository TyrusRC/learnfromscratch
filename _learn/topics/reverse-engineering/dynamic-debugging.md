---
title: Dynamic debugging
slug: dynamic-debugging
---

> **TL;DR:** When static analysis stalls, attach a debugger (gdb, lldb, WinDbg, x64dbg) and watch the program tell you what it actually does.

## What it is
Dynamic debugging means running the target under a debugger, setting breakpoints, stepping through instructions, and inspecting state. It's the answer to obfuscation, runtime decryption, indirect calls, and bugs whose root cause requires watching the heap. Complements [[static-analysis]] and [[binary-instrumentation]].

## Preconditions / where it applies
- You can run the binary (right OS, arch, deps) or attach to a running PID you control.
- Debugger ↔ target arch match (gdb-multiarch, lldb with multiarch, WinDbg for x86/x64/ARM).
- For protected targets, expect [[anti-debugging]] tricks; defeat first.

## Technique

### Linux (gdb)
```bash
gdb --args ./sample arg1 arg2
(gdb) starti                       # stop at first instruction
(gdb) b *0x401234                  # absolute address
(gdb) b main
(gdb) catch syscall execve
(gdb) x/16gx $rsp                  # examine memory
(gdb) info proc mappings
```

GEF or pwndbg massively improve UX: `pip install pwndbg` (or clone), source the init in `~/.gdbinit`. They auto-print registers, stack, code, and detect canaries.

### Windows
- **x64dbg / x32dbg** — modern, scriptable, plugin ecosystem (ScyllaHide, xAnalyzer).
- **WinDbg / WinDbg Preview** — kernel + user, time-travel debugging (TTD) records and rewinds execution.

WinDbg essentials: `bp kernelbase!CreateFileW`, `g` (go), `t` (step into), `p` (step over), `kn` (call stack), `!analyze -v` (crash triage), `dt nt!_EPROCESS @$proc`.

### macOS
`lldb` is the system debugger. SIP blocks attaching to system binaries; codesign re-signing or DevTools team ID grants exceptions.

### Mobile
Android: `gdbserver` / `lldb-server` pushed to device, `adb forward`, attach from host. Frida-based hooking ([[binary-instrumentation]]) often beats raw debugging.
iOS: lldb over USB on a jailbroken device, debugserver from the Xcode toolchain.

### Common patterns
- **Find where a string is decoded** — search memory for plaintext, set a hardware watchpoint on the buffer, run, catch the writer.
- **Bypass a check** — break at the conditional, flip the flag, continue.
- **Recover keys** — break on `BCryptEncrypt` / `CCCrypt` / `EVP_EncryptInit_ex`, dump arg buffers.
- **Track heap corruption** — `set environment MALLOC_CHECK_=3` on glibc, or PageHeap (`gflags /p /enable app.exe`).

Time-travel (rr on Linux, TTD on Windows) is transformative: record once, scrub forward and backward over the same crash deterministically.

## Detection and defence
- See [[anti-debugging]] for the runtime probes that detect attached debuggers.
- Kernel-mode debugging (`/dev/kmem`, KdNet) needs additional privileges; modern OSes restrict heavily (KPTI, SIP, SELinux).
- Debug logs containing addresses can leak ASLR slides — be careful when sharing.

## References
- [pwndbg documentation](https://pwndbg.re/) — gdb on steroids, exploit-dev oriented
- [WinDbg command index](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/commands) — full command reference
