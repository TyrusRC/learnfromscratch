---
title: Embedded firmware bug bounty methodology
slug: embedded-firmware-bug-bounty-methodology
aliases: [embedded-bb-method, firmware-bb-workflow]
---

> **TL;DR:** Embedded firmware bug bounty is a niche where buying a used router on eBay for $30, dumping its flash, and grepping CGI binaries for `system()` calls regularly produces unauthenticated RCE worth $5k-$25k via vendor programs and ZDI. Most consumer devices ship with a sprawling web admin, ancient busybox userland, and vendor-written CGI/PHP/Lua glue that has never been audited. Pair this with [[firmware-extraction]], [[firmware-emulation-firmadyne-qemu]], [[firmware-audit-methodology]], [[uart-jtag-debug]], and [[bootloader-and-secure-boot-attacks]] for the full stack workflow.

## Why it matters

Consumer routers, IP cameras, NAS boxes, smart-home hubs, and small-business network appliances are deployed by the millions and patched rarely. Vendors compete on price, so security investment lags badly. The result is a target-rich ecosystem with predictable bug classes (command injection, auth bypass, stack overflows in custom CGIs) where a methodical hunter can find chains in days, not months.

Unlike web bug bounty, embedded payouts are not always direct from the vendor. Many programs are run through ZDI (Zero Day Initiative), Pwn2Own categories, or vendor-specific PSIRTs with bounty tables. Some vendors (Synology, QNAP, Netgear) run public programs; others (TP-Link, Asus) pay informally or via ZDI. Demonstrating impact requires either live device exploitation or convincing emulation proof.

Companion notes: [[target-selection-heuristics]], [[program-selection-tactics]], [[demonstrating-impact]], [[report-writing]].

## Target acquisition

### Picking devices

- **eBay used market**: routers, cameras, and NAS units sell for $20-$80 used. Buy the exact model the vendor program covers. Prefer models with: recent firmware updates (active program), large deployed base (impact), and accessible serial/UART headers.
- **Vendor refurb stores**: Netgear, Asus, and Synology sell refurb units cheap. Sometimes you get a unit with older firmware, useful for n-day study.
- **Donations and surplus**: corporate e-waste, neighbors upgrading, hackerspace junk bins.
- **Avoid**: devices with secure boot fully enforced (newer enterprise gear) unless that is your specialty - see [[bootloader-and-secure-boot-attacks]].

### Reading the program landscape

- **Synology Security Bounty**: public program, pays up to $30k for RCE on DSM. See https://www.synology.com/en-global/security/responsible_disclosure.
- **QNAP Security Bug Bounty**: covers QTS, QuTS hero, and apps. Pays into low five figures.
- **Netgear Bug Bounty (via Bugcrowd)**: managed program covering routers, switches, Orbi.
- **TP-Link**: PSIRT contact, no public bounty table; ZDI route is common.
- **Asus**: PSIRT exists; ZDI also accepts Asus targets.
- **ZDI**: pays for routers, NAS, printers, cameras across many vendors. Pwn2Own categories (SOHO Smashup, IoT) pay $50k-$200k+ for chains.
- **CISA KEV bounties via vendor**: not direct, but a CVE that lands on KEV often unlocks better future payouts.

Cross-reference [[program-scope-reading]] and [[program-selection-tactics]].

## Firmware extraction

Three escalating approaches; try them in order. Deep-dive in [[firmware-extraction]].

### Download from vendor

Most vendors host firmware update images publicly. Grab the latest plus 2-3 older versions for diffing (see [[one-day-from-patch-diff]]). Check the support portal and any auto-update URL the device pings.

### Software unpacking

```bash
binwalk -Me firmware.bin
unblob firmware.bin   # newer, handles more formats
```

Look for: squashfs root, jffs2/ubifs partitions, kernel uImage, separate bootloader. Identify the CPU arch (MIPS, ARM, ARM64) from the kernel header for later emulation.

### Hardware extraction

When vendor encrypts firmware updates or strips them, fall back to hardware:

- **UART console**: solder a header, attach a USB-TTL adapter, often drops to a root shell or uboot prompt. See [[uart-jtag-debug]].
- **SPI flash dump**: clip onto the flash chip with a SOIC-8 clip and a CH341A programmer, dump the raw image.
- **eMMC**: trickier; use an eMMC adapter or in-circuit reading.
- **JTAG**: when available, gives full memory and CPU control via OpenOCD.

## Emulation for scale

Buying every device variant is expensive. Emulation lets you test at scale and fuzz remotely.

### FirmAE / Firmadyne

Best for Linux-based router firmware. Auto-extracts, builds a QEMU image, fakes NVRAM, and brings up the web admin on localhost. See [[firmware-emulation-firmadyne-qemu]].

```bash
./run.sh -r netgear_r7000 firmware.bin
# then browse to https://192.168.0.1 in the emulated network
```

Limitations: kernel modules and vendor-specific NVRAM features often break. Many bugs are still reachable on the web layer though.

### User-mode QEMU

For single-binary analysis (CGI fuzzing, command-line tool study):

```bash
qemu-mips-static -L ./squashfs-root ./squashfs-root/usr/bin/some_cgi
```

Pair with `chroot` for partial system emulation.

### Hybrid

Run the binary under user-mode QEMU and stub out missing syscalls or NVRAM calls with `LD_PRELOAD`. Or patch the binary to skip env checks.

## Web admin as primary surface

For the vast majority of consumer firmware, the web admin interface is the highest-value target. It is internet-exposed (deliberately or via UPnP), authenticated weakly, and written in custom C CGIs or PHP/Lua wrappers.

### Mapping the admin

1. Boot the device or emulate, then crawl the admin UI logged in.
2. Capture every request with Burp; note CGI endpoints, parameters, hidden actions.
3. Dump the squashfs and find the binaries that handle each endpoint. For boa/lighttpd/mini_httpd setups, look at the config to see which CGI handles which path.
4. Map endpoints to source binaries: `grep -r "endpoint_name" squashfs-root/`.

See [[expanding-attack-surface]] and [[getting-feel-for-target]].

### Common bug classes

- **Default credentials**: still surprisingly common; admin/admin, root/blank. Check old factory-reset behavior.
- **Auth bypass**: pre-auth endpoints that shouldn't be (debug pages, OEM service handlers, .cgi files reachable without session cookie). Diff post-auth handlers and look for missing checks on the pre-auth path.
- **OS command injection**: vendor scripts shell out to `iwconfig`, `ifconfig`, `ping`, `tcpdump` with user input. Grep:

  ```bash
  grep -rE "system\(|popen\(|exec[lv]" squashfs-root/usr/bin/
  ```

  Then in Ghidra, find paths from CGI entry to the `system()` call.

- **Stack buffer overflows**: `strcpy`/`sprintf`/`gets` on POST bodies or query params. Older MIPS firmware rarely uses stack canaries or ASLR; classic ret2libc and ROP work. See [[stack-buffer-overflow]] and [[rop-chains]].
- **Path traversal**: file download/upload CGIs that don't validate `../`.
- **Hardcoded backdoors**: magic URLs, magic packet handlers, hidden telnet enable commands.
- **SOAP/UPnP**: many routers expose UPnP/IGD with auth-less actions that change config or expose internals.
- **TR-069 / CWMP**: ACS protocol endpoints reachable on the LAN, sometimes WAN.

### Source review pattern

For each interesting binary:

1. Load in Ghidra; let it analyze.
2. Find string refs to URL paths or parameter names.
3. Trace from request parsing into business logic.
4. Look for sinks: `system`, `popen`, `strcpy`, `sprintf`, file open with user paths.
5. Verify reachability and auth requirement.

This mirrors [[firmware-audit-methodology]] and parallels [[android-source-review-methodology]] in spirit.

## Workflow to study

1. **Pick a vendor and model** based on program payout, deployed base, and your hardware budget. Cross-reference [[target-selection-heuristics]].
2. **Acquire device** plus firmware updates (current + 2 prior versions for diffing).
3. **Extract** with binwalk/unblob; fall back to UART/SPI if encrypted.
4. **Emulate** with FirmAE for web testing at scale.
5. **Map web admin** to CGI/handler binaries.
6. **Grep for low-hanging sinks** across all CGIs: command injection, `strcpy`, file paths.
7. **Pick 3-5 most promising endpoints**, reverse them in Ghidra, confirm reachability.
8. **Build PoC** in emulation; then verify on real hardware.
9. **Demonstrate impact** with shell, config exfiltration, or persistence. See [[demonstrating-impact]].
10. **Write report** with PoC, root cause, affected firmware versions. See [[report-writing-step-by-step]].
11. **Submit** to vendor program or ZDI; track status. See [[disclosure-and-comms]].

## Defensive baseline

If you are on the vendor side reading this, the minimum bar:

- Strip unused services (telnet, debug, miniupnpd) from release builds.
- Enable stack canaries, ASLR, NX, RELRO on all userland binaries.
- Audit every CGI for shell metacharacters; ban `system()` for user input.
- Sign firmware updates and validate signatures in the bootloader; see [[bootloader-and-secure-boot-attacks]].
- Run static analyzers (Semgrep with embedded rules, CodeQL) on each release.
- Run [[firmware-audit-methodology]] internally before shipping.
- Establish a public PSIRT and bounty program; the alternative is finding out on Twitter.

## Demonstrating impact

Vendors and ZDI both want a working PoC. Acceptable formats:

- Video of exploit landing a shell on the device.
- Network capture showing the exploit request and the device responding with attacker-controlled output (e.g., `id` output).
- For pre-auth chains: show the chain from unauthenticated TCP connection to root shell with no prior knowledge of credentials.
- For LAN-only bugs: state it clearly; payout tier may differ.
- For chains: each step's individual CVE if applicable. See [[demonstrating-impact]].

## ZDI submission flow

1. Confirm the bug is in scope at https://www.zerodayinitiative.com/advisories/upcoming/.
2. Email zdi@trendmicro.com with summary or use the web portal.
3. Provide: target device, firmware version, vulnerability class, PoC, impact.
4. Receive case number; analyst will reproduce.
5. Negotiate payout tier; sign contract.
6. Wait for vendor patch; ZDI publishes advisory.

Tips: ZDI pays more for chains and pre-auth. Splitting a chain into parts can sometimes pay more total; ask the analyst.

## Related

- [[firmware-extraction]]
- [[firmware-emulation-firmadyne-qemu]]
- [[firmware-audit-methodology]]
- [[uart-jtag-debug]]
- [[bootloader-and-secure-boot-attacks]]
- [[hardware-glitching-deep]]
- [[stack-buffer-overflow]]
- [[rop-chains]]
- [[target-selection-heuristics]]
- [[program-selection-tactics]]
- [[demonstrating-impact]]
- [[report-writing-step-by-step]]
- [[one-day-from-patch-diff]]
- [[n-day-rapid-exploitation]]
- [[building-a-research-home-lab]]

## References

- Zero Day Initiative published advisories: https://www.zerodayinitiative.com/advisories/published/
- FirmAE paper and code: https://github.com/pr0v3rbs/FirmAE
- Binwalk: https://github.com/ReFirmLabs/binwalk
- Synology Security Advisory program: https://www.synology.com/en-global/security/responsible_disclosure
- OWASP IoT Top 10: https://owasp.org/www-project-internet-of-things/
- Practical IoT Hacking (Chantzis et al.), No Starch Press: https://nostarch.com/practical-iot-hacking
