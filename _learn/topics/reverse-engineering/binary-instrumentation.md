---
title: Binary instrumentation
slug: binary-instrumentation
---

> **TL;DR:** Inject analysis code into a running process to measure coverage, taint flows, API calls, or to patch behaviour — Intel Pin, DynamoRIO, Frida, QBDI.

## What it is
Dynamic Binary Instrumentation (DBI) intercepts instructions, basic blocks, or function calls in a running target and runs analyst-supplied callbacks. Unlike [[dynamic-debugging]] (which stops on breakpoints), DBI rewrites the code on the fly so the program runs at near-native speed while emitting telemetry.

## Preconditions / where it applies
- The target runs on a supported arch/OS (x86-64 and AArch64 broadly; ARMv7 patchy).
- You can launch the process under the DBI engine or attach to a PID you own.
- For Frida hooking: the process is not in a hardened jailed sandbox that blocks `ptrace`/`task_for_pid`.

## Technique
Pick the engine by task:

- **Intel Pin** (x86, x86-64) — C++ pintools, granular instruction-level callbacks, the standard for coverage and taint research.
- **DynamoRIO** — similar to Pin, more permissive licence, AArch64 support.
- **QBDI** — Quarkslab's lightweight engine, easy Python bindings, good for fuzzing harnesses.
- **Frida** — JavaScript-driven, mobile + desktop, the everyday tool for hooking high-level functions.
- **TinyInst** — coverage-focused, designed for fuzzers (Jackalope, Fuzzilli).

Frida one-liner to hook an API:

```javascript
Interceptor.attach(Module.getExportByName('libssl.so', 'SSL_write'), {
  onEnter(args) {
    const buf = args[1];
    const len = args[2].toInt32();
    console.log(hexdump(buf, { length: Math.min(len, 256) }));
  }
});
```

Pin coverage skeleton (conceptual):

```cpp
VOID Trace(TRACE trace, VOID *v) {
  for (BBL bbl = TRACE_BblHead(trace); BBL_Valid(bbl); bbl = BBL_Next(bbl))
    BBL_InsertCall(bbl, IPOINT_ANYWHERE,
                   (AFUNPTR)RecordBlock, IARG_ADDRINT, BBL_Address(bbl), IARG_END);
}
```

Typical use cases:
- **Coverage** for greybox fuzzers (AFL++ QEMU mode, Jackalope, Honggfuzz Intel-PT).
- **Taint** to track attacker-controlled bytes to a crash site.
- **Hooking** to bypass licence checks, log crypto keys, redirect file/network IO.
- **Sandboxing** by intercepting syscalls and emulating responses.

Frida shines for mobile RE: `frida-trace -U -i 'CCCrypt*' <app>` instantly dumps every Common Crypto call with arguments.

## Detection and defence
- DBI engines leave fingerprints: extra threads, hooked APIs, `frida-agent` in `/proc/self/maps`, suspicious memory regions marked RWX.
- Mobile anti-tamper SDKs scan loaded modules and check `dlopen` lists; hide Frida via `frida-gum` injection and `gadget` in stealth mode.
- Anti-DBI: timing checks across blocks (Pin slows execution per block), self-hashing of code pages.

## References
- [Frida documentation](https://frida.re/docs/home/) — JS API and gadget mode
- [Intel Pin user guide](https://software.intel.com/sites/landingpage/pintool/docs/98869/Pin/html/) — pintool API reference
