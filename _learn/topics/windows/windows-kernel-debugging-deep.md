---
title: Windows kernel debugging — deep
slug: windows-kernel-debugging-deep
aliases: [windbg-kd-deep, windows-kd-deep]
---

> **TL;DR:** WinDbg (classic) and WinDbg Preview (with the Debugger Data Model, JavaScript, NatVis, and TTD) are the canonical tools for live kernel-mode debugging and crash-dump triage on Windows. This note is the practitioner-depth companion to [[kernel-debugging-with-windbg]] and [[windows-kernel-architecture]], and pairs naturally with exploit-side notes like [[hevd-stack-overflow-walkthrough]] and defender-side notes like [[edr-bypass-at-exploitation-time]]. If you cannot drive `!process 0 0`, walk an `_EPROCESS`, set a `bp` on `nt!NtCreateFile`, attach over KDNET, and read a `!analyze -v` bucket, you are not yet kernel-fluent — fix that.

## why it matters

Kernel debugging is the ground truth for Windows. User-mode tooling (Procmon, ETW, EDR telemetry) can be lied to by a rootkit, hooked by another driver, or simply blind to the moment a bug triggers. The kernel debugger sits *below* PatchGuard, *below* the scheduler, and *below* most anti-analysis. It is the same tool used by:

- Microsoft escalation engineers triaging a customer BSOD.
- Driver developers validating IRP flow against the [[kernel-objects-and-irps]] model.
- Rootkit hunters chasing IRP hooks, SSDT-equivalent manipulation, and patched callbacks.
- Exploit developers like the ones in [[hevd-stack-overflow-walkthrough]] who need to confirm a controlled `RIP` in ring 0.
- Vulnerability researchers performing a [[windows-driver-ioctl-audit]].

Without it, "I think the driver did X" is a guess. With it, you can prove it.

## setup: getting a kernel debugger attached

### Enabling kernel debugging on the target

On the debuggee, `bcdedit` controls boot configuration:

```
bcdedit /debug on
bcdedit /dbgsettings net hostip:192.168.56.1 port:50000 key:1.2.3.4
bcdedit /set {current} debugtype net
```

Legacy transports still exist and you will see them in old docs:

- **Serial:** `bcdedit /dbgsettings serial debugport:1 baudrate:115200`. Mostly dead outside embedded.
- **1394 / USB2 debug cable:** historical, rarely usable on modern hardware.
- **Network (KDNET):** the modern default. Works over a supported NIC; Microsoft maintains a compatibility list. Key is host-generated via `kdnet.exe`.

Reboot after changing `bcdedit`. On modern systems with Secure Boot you may need to disable it, or use a test-signed configuration — note that this changes the security posture of the box and is not appropriate on production.

### Hyper-V and VM debugging

For VMs, prefer KDNET over a virtual NIC or use Hyper-V's named-pipe COM. With Hyper-V the host-side flow is:

1. `Set-VMComPort` to map COM1 to a named pipe.
2. On the guest, point `bcdedit /dbgsettings serial` at that COM port.
3. WinDbg `File -> Kernel Debug -> COM` with the pipe path.

For VMware / VirtualBox / QEMU the equivalent is a virtual serial port or KDNET over the host-only network. The same patterns used in [[building-a-research-home-lab]] apply: snapshot before each session.

### Symbols

You cannot debug Windows without symbols. Set:

```
.sympath srv*c:\symbols*https://msdl.microsoft.com/download/symbols
.reload /f
```

For private symbols (your own driver), add the local PDB path *before* the symbol server entry. `!sym noisy` will show you exactly which PDB load failed and why — usually a mismatched build ID.

## core commands you must own

### Process and thread inspection

- `!process 0 0` — list every `_EPROCESS`.
- `!process <addr> 7` — full dump including threads, handles, VAD tree.
- `.process /i /p <addr>; .reload /user` — context-switch into a user-mode process so user symbols resolve. Critical when chasing a crash that crosses the boundary, as in [[windows-processes-and-threads]].
- `!thread <addr>` — show the `_ETHREAD`, stack, wait reason.
- `!token <addr>` — decode a `_TOKEN`, including privileges and integrity level. Useful when validating a [[capabilities-privesc]]-style escalation on Windows (token-stealing payloads).

### Object manager and drivers

- `!object \Driver` — enumerate driver objects.
- `!drvobj <name> 7` — show `MajorFunction` dispatch table; this is where IRP hooks live.
- `!devobj <addr>` — device object detail; pair with [[kernel-objects-and-irps]].
- `!irp <addr>` — decode an in-flight IRP, including the stack location each driver sees.
- `!object \??` — the global DOS device namespace; symlinks like `\??\C:` resolve here.

### Memory and pool

- `!pool <addr>` — identify which pool tag owns an allocation. Pair with `!poolfind <tag>` to hunt all allocations for a tag (useful for rootkit pool grooming analysis).
- `!vad <addr>` — VAD tree for a process.
- `dt nt!_EPROCESS <addr>` — structured pretty-print. `dt -r1` recurses one level.
- `!pte <addr>` — page-table walk; essential for SMEP/SMAP and CR4 reasoning in exploitation work like [[hevd-stack-overflow-walkthrough]].

### Crash triage

- `!analyze -v` — first command on any dump. It buckets the crash, names the faulting module, and proposes a `STOP` code interpretation.
- `.bugcheck` — raw bugcheck code and parameters.
- `kb`, `kv`, `kP` — stack walks with arguments. `kP` shows source/parameter names if private PDBs are present.
- `.exr -1; .cxr <ctx>` — switch to the exception context recorded in a minidump.

## live debugging vs crash-dump analysis

These are *different jobs*:

- **Live KD** is interactive. You can set breakpoints (`bp`, `ba`), single-step (`t`, `p`), edit memory (`eb`, `ed`), and run scripts. It is invasive and slow. Best for development, exploitation, and rootkit hunting on a controlled box.
- **Crash-dump analysis** is post-mortem. You get a `.dmp` (kernel summary, full kernel, or complete memory) and reconstruct what happened. Best for production incident triage and supplier escalation. Memory-only artefacts (transient heap state) are frozen at the moment of bugcheck.

Generate a dump on demand with `.dump /f c:\dumps\full.dmp` from a live KD session, or trigger a crash from the target via `NotMyFault` (Sysinternals) or `MEMORY.DMP` configured in System Properties.

## Time-Travel Debugging (TTD)

TTD records a trace of a process and lets you step *backwards*. Today TTD is a user-mode feature (kernel TTD remains an internal Microsoft capability), but it integrates with WinDbg Preview and is invaluable for analyzing user-mode components of a kernel issue — e.g., the service that issued the malformed IOCTL that crashed your driver.

Workflow:

1. `TTD.exe -out c:\traces -accepteula <target.exe>` or attach to a running PID.
2. Open the `.run` file in WinDbg Preview.
3. Use `!tt 0` to go to the start, `g-` to reverse-execute, `dx @$cursession.TTD.Calls("module!func")` to query every call site via the Data Model.

## scripting: NatVis, JavaScript, Debugger Data Model

The Debugger Data Model (`dx`) lets you query the debugger like a database. Examples:

```
dx -r2 @$cursession.Processes.Where(p => p.Name == "lsass.exe").Select(p => p.Threads)
dx Debugger.Sessions.First().Processes[4].Threads.Count()
```

JavaScript extensions live in `.js` files loaded with `.scriptload`. They register Data Model providers, so a one-line `dx` query can drive a 200-line analysis. NatVis adds typed visualizers — useful for custom driver structures so `dt` prints them sensibly.

Practical scripts to write or borrow:

- Walk every `_DRIVER_OBJECT` and flag dispatch routines pointing *outside* the owning driver's PE range — classic IRP-hook tell.
- Enumerate kernel callbacks (`PsSetCreateProcessNotifyRoutine`, `CmRegisterCallback`, `ObRegisterCallbacks`) and validate the target module.
- Diff two snapshots of the System process's handle table to find injected handles.

## attacker view: detecting the debugger

If you are simulating an adversary against an instrumented lab, expect malware to check:

- `KdDebuggerEnabled` and `KdDebuggerNotPresent` flags exported by `nt`.
- `NtQuerySystemInformation(SystemKernelDebuggerInformation)`.
- Timing — `rdtsc` deltas across instructions that single-step trivially.
- Presence of the `\Device\KdDebug` object or kernel-debugger driver objects.

This matters for [[edr-bypass-at-exploitation-time]] and for analyzing samples used by groups in [[apt-tradecraft-russian-svr-fsb]] and [[apt-tradecraft-dprk-lazarus]]. Mitigation: use a release-signed driver build, attach late, and consider Hyper-V's hypervisor-debugger path which is harder to fingerprint than KDNET.

## defender use cases

### Rootkit hunting

- `!drvobj` every driver, diff dispatch routines against `lm` module ranges.
- Walk `KiServiceTable` / `KeServiceDescriptorTableShadow` equivalents (PatchGuard makes hooking these unstable, but artefacts remain).
- Enumerate minifilter altitudes (`!fltkd.filters`) and compare to the known EDR set in the [[siem-detection-use-case-catalog]] for that host.
- Cross-check with user-mode telemetry per [[detection-engineering-pyramid-of-pain]] — kernel artefacts sit at the top of the pyramid because changing them costs the adversary the most.

### BSOD analysis at scale

Production fleets generate kernel minidumps to `%SystemRoot%\Minidump`. Feed them through `!analyze -v` headlessly via `cdb.exe -z` or `kd.exe -z`, bucket by `IMAGE_NAME` and bugcheck code, and you have a vendor-quality bug-reporting pipeline. Fold the output into IR per [[ir-from-source-signals]].

## workflow to study

1. Build a Hyper-V VM, enable KDNET, attach WinDbg Preview, prove you can break in with `Ctrl+Break`.
2. Run `!process 0 0`, pick `lsass.exe`, switch context, `!handle 0 f`. Understand every column.
3. Load HEVD (HackSys Extreme Vulnerable Driver), trigger the stack-overflow IOCTL, catch the crash live, then redo it with [[hevd-stack-overflow-walkthrough]] as a guide.
4. Crash the VM with NotMyFault, save the dump, open it cold, run `!analyze -v`, write down what each parameter of the bugcheck means.
5. Write a JavaScript extension that lists every driver whose dispatch routines point outside its image. Run it against your dev VM, then against a VM with a deliberately hooked driver.
6. Record a TTD trace of a user-mode service that talks to your kernel driver, and replay across an IOCTL round-trip.
7. Practice the detection-side reasoning from [[edr-rules-as-code-from-attack-patterns]] using the artefacts you collected.

## related

- [[kernel-debugging-with-windbg]]
- [[windows-kernel-architecture]]
- [[hevd-stack-overflow-walkthrough]]
- [[edr-bypass-at-exploitation-time]]
- [[windows-driver-ioctl-audit]]
- [[kernel-objects-and-irps]]
- [[windows-api-and-syscalls]]
- [[windows-processes-and-threads]]
- [[detection-engineering-pyramid-of-pain]]
- [[ir-from-source-signals]]
- [[building-a-research-home-lab]]

## References

- Microsoft Learn — Getting started with WinDbg (kernel-mode): https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/getting-started-with-windbg--kernel-mode-
- Microsoft Learn — Setting up KDNET network kernel debugging automatically: https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/setting-up-a-network-debugging-connection-automatically
- Microsoft Learn — Time Travel Debugging overview: https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/time-travel-debugging-overview
- Microsoft Learn — Debugger Data Model and dx command: https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/data-model
- HackSys Extreme Vulnerable Driver (HEVD): https://github.com/hacksysteam/HackSysExtremeVulnerableDriver
- Sysinternals NotMyFault: https://learn.microsoft.com/en-us/sysinternals/downloads/notmyfault
