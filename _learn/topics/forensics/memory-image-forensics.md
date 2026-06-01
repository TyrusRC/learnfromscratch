---
title: Memory-image forensics
slug: memory-image-forensics
---

> **TL;DR:** Volatility 3 against a raw RAM dump reconstructs processes, network sockets, loaded DLLs, command lines, and credentials. Capture memory before powering off — disk encryption keys live in RAM.

## What it is
Memory forensics parses a physical RAM acquisition (raw `.dmp`, `.lime`, `.vmem`, hibernation file, or crashdump) to recover runtime state that disk analysis cannot see: in-memory injected code, decrypted strings, BitLocker / LUKS keys, browser session cookies, command-line arguments, and active TCP sessions. Volatility 3 (Python) is the modern tool; Volatility 2 still ships unique plugins.

## Preconditions / where it applies
- A live host whose memory you can image with `winpmem` / `DumpIt` / `Magnet RAM Capture` (Windows), `avml` / `LiME` (Linux), or `osxpmem` (macOS).
- A VM whose hypervisor exposes guest memory: `.vmem` from VMware, `.sav` from VirtualBox, libvirt `virsh dump`.
- Volatility 3 with the matching symbol pack (auto-fetched for Windows; manual ISF generation for Linux / macOS via `dwarf2json`).

## Technique
Identify what platform the image is and pick the right plugin tree.

```bash
vol -f mem.raw windows.info               # OS / build / DTB
vol -f mem.raw windows.pslist             # process list from EPROCESS
vol -f mem.raw windows.pstree             # parent-child tree
vol -f mem.raw windows.cmdline            # full command lines
vol -f mem.raw windows.netscan            # active + closed sockets
vol -f mem.raw windows.malfind            # private + RX regions (injection)
vol -f mem.raw windows.dumpfiles --pid 1234
vol -f mem.raw windows.hashdump           # SAM hashes (needs SYSTEM hive in RAM)
vol -f mem.raw windows.lsadump            # cached LSA secrets
```

For Linux: `linux.pslist`, `linux.bash` (recovers bash history from heap), `linux.netstat`, `linux.check_modules` for rootkit-hidden kernel modules.

High-value workflows:
- **Process injection hunt** — `windows.malfind` flags `MEM_PRIVATE + PAGE_EXECUTE_READWRITE`. Dump with `windows.vadinfo --pid X --address Y`, then run `yara` or push into a disassembler.
- **Credential theft** — `windows.hashdump` and `windows.lsadump` for SAM + cached domain creds.
- **Browser session** — `windows.dumpfiles --pid <browser>` recovers in-memory tabs and cached pages.
- **Disk encryption keys** — `bulk_extractor -E aes` and `aeskeyfind` recover BitLocker / LUKS key schedules from RAM.

## Detection and defence
- Anti-forensics: secure boot + memory encryption (Intel TME, AMD SME) make cold-boot recovery harder. Hibernation files should be encrypted or disabled on high-value hosts.
- EDR should detect `winpmem` / `RamCapture` drivers loading — these are forensic tools also used by attackers to harvest LSASS.
- For IR, always pair memory capture with disk image ([[disk-image-forensics]]) and packet capture ([[traffic-analysis]]) to triangulate.

## References
- [Volatility 3](https://github.com/volatilityfoundation/volatility3) — Python rewrite, current plugin set
- [WinPMem](https://github.com/Velocidex/WinPmem) — Windows memory acquisition driver
- [avml](https://github.com/microsoft/avml) — Microsoft's Linux memory acquisition tool
- [Art of Memory Forensics](https://www.memoryanalysis.net/amf) — the canonical textbook
- See also: [[disk-image-forensics]], [[traffic-analysis]]
