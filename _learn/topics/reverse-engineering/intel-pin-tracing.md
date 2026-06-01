---
title: Intel Pin for Dynamic Tracing
slug: intel-pin-tracing
---

> **TL;DR:** Intel Pin is a JIT-based DBI framework — write a Pintool in C++ that instruments at instruction, basic-block, routine, or image granularity to record traces and propagate taint.

## What it is
Pin rewrites the target binary in-memory as it runs, inserting analysis callbacks the tool author registers. The granularity ladder is `INS` (per-instruction), `BBL` (basic block), `TRACE` (single-entry multi-exit), `RTN` (function), and `IMG` (module load). Compared to DynamoRIO, Pin trades a less elegant API for richer instrumentation primitives; compared to Frida, it works on stripped native binaries without symbols and at much lower per-instruction overhead.

## Preconditions / where it applies
- x86 / x86-64 user-mode binaries on Linux or Windows
- Targets that tolerate ~5-20x slowdown
- Triage of obfuscated samples where static analysis stalls (packed crypto, VM-based protectors)

## Technique
A minimal BBL-count Pintool plus a routine hook.

```c
// bblcount.cpp — compile with the Pin makefile harness
#include "pin.H"
#include <iostream>
static UINT64 bbl_count = 0;

VOID CountBBL(UINT32 n) { bbl_count += n; }

VOID Trace(TRACE trace, VOID *v) {
    for (BBL bbl = TRACE_BblHead(trace); BBL_Valid(bbl); bbl = BBL_Next(bbl)) {
        BBL_InsertCall(bbl, IPOINT_ANYWHERE, (AFUNPTR)CountBBL,
                       IARG_UINT32, BBL_NumIns(bbl), IARG_END);
    }
}

VOID Image(IMG img, VOID *v) {
    RTN r = RTN_FindByName(img, "RC4_crypt");
    if (RTN_Valid(r)) {
        RTN_Open(r);
        RTN_InsertCall(r, IPOINT_BEFORE, (AFUNPTR)[](ADDRINT k){
            std::cerr << "RC4 key ptr=" << std::hex << k << "\n";
        }, IARG_FUNCARG_ENTRYPOINT_VALUE, 1, IARG_END);
        RTN_Close(r);
    }
}

int main(int argc, char **argv) {
    PIN_InitSymbols();
    if (PIN_Init(argc, argv)) return 1;
    IMG_AddInstrumentFunction(Image, 0);
    TRACE_AddInstrumentFunction(Trace, 0);
    PIN_AddFiniFunction([](INT32, VOID*){
        std::cerr << "bbls=" << bbl_count << "\n";
    }, 0);
    PIN_StartProgram();
}
```

Run as `pin -t obj-intel64/bblcount.so -- ./target`. For taint, shadow each register and memory byte in a parallel map and propagate on `INS_IsMov` / arithmetic.

## Detection and defence
- Samples probe `/proc/self/maps` for `pinbin` or scan parent process names; rename the Pin loader and unmap helper pages to defeat trivial checks.
- Timing-based anti-DBI compares `rdtsc` deltas — patch the instrumentation point or virtualise the TSC via a Pintool callback.
- DynamoRIO and Frida-trace are softer when the target is already symbolised; pick Pin for opaque, allergic-to-symbols binaries.

## References
- [Intel Pin user guide](https://software.intel.com/sites/landingpage/pintool/docs/98690/Pin/html/) — official API reference
- [DynamoRIO comparison](https://dynamorio.org/page_pin_compat.html) — feature parity matrix

See also: [[ida-hexrays]], [[ghidra-decompiler]], [[frida-hook]].
