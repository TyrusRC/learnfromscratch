---
title: FreeRTOS audit
slug: freertos-audit
aliases: [freertos-vulns, freertos-bug-classes]
---

> **TL;DR:** FreeRTOS is the most widely-deployed real-time kernel, shipped in billions of IoT / embedded / industrial devices, also under "Amazon FreeRTOS" / now FreeRTOS-LTS. Tiny C kernel (~10KB binary), preemptive multitasking, no MMU assumption. Attack surface is dominated by the *application + integrated components* (TCP/IP stack, mbedTLS, MQTT, OTA) rather than the kernel itself, but several historical CVEs in the bundled TCP/IP stack (FreeRTOS+TCP) shipped pre-auth RCE on networked devices. Companion to [[zephyr-audit]] and [[rtos-shared-bug-classes]].

## Why FreeRTOS

- **Most deployed RTOS** by device count.
- **Tiny footprint** — runs on Cortex-M0+, AVR, RISC-V, dozens of others.
- **Cooperative or preemptive** scheduling.
- **No memory protection by default** — all tasks share address space.
- **MIT licensed** since AWS adoption.

## Architecture

- **Tasks** — separate threads with own stacks.
- **Queues / semaphores / mutexes** for IPC.
- **Tickless idle** support.
- **Memory allocators** (heap_1, heap_2, heap_3, heap_4, heap_5) — vendor picks.
- **MPU support** (FreeRTOS-MPU) — optional, separates tasks via Cortex-M MPU.

Without MPU, every task can read/write every other task's memory.

## Class 1 — Application logic bugs

The kernel itself is small and audited. Most bugs live in:
- Application task code.
- Vendor-shipped drivers.
- Integrated components (TCP/IP, TLS, MQTT, OTA).

Standard C bug classes apply.

## Class 2 — FreeRTOS+TCP CVEs

FreeRTOS+TCP (the bundled TCP/IP stack) had a high-profile vulnerability cluster disclosed by Zimperium / others in 2018 and again later. CVE list spanned ~13 distinct issues:
- ARP cache poisoning leading to RCE.
- DHCP parsing buffer overflow.
- DNS response parsing overflow.
- TCP option-parsing bugs.

Mass-deployed; many vendor devices vulnerable for years after disclosure.

## Class 3 — Memory allocator behaviour

heap_1: allocate but never free. Predictable; UAF impossible.
heap_2, heap_3, heap_4: free supported; fragmentation possible.
heap_5: multiple regions.

UAF in application code can trash kernel structures if heap shared. Even without UAF, heap exhaustion → behaviour failure.

## Class 4 — Task isolation absence

Without MPU:
- Task A can read Task B's stack.
- Task A can corrupt Task B.
- Compromised network parser can read crypto keys in another task's data.

With MPU, isolation is per-task but configuration mistakes (overly-broad region grants) leak.

## Class 5 — Stack overflow

Tasks have fixed stacks defined at create time. Overflow:
- Adjacent task corruption.
- Kernel data corruption.
- Reboot / crash.

FreeRTOS has stack-overflow hook; many vendor builds don't enable.

## Class 6 — OTA update vulnerabilities

AWS IoT-aware FreeRTOS supports OTA. CVEs in OTA:
- Improper signature verification under specific configs.
- Path issues in image staging.
- MQTT credential leak.

Vendors integrating need to follow the secure-config guidance.

## Class 7 — Race conditions in critical sections

`taskENTER_CRITICAL()` / `taskEXIT_CRITICAL()` disable interrupts. Forgetting to wrap shared-data access:
- ISR vs task race.
- Inconsistent state.

Common in application code.

## Class 8 — Interrupt-safe API misuse

Some FreeRTOS APIs have ISR-safe variants (`xQueueSendFromISR`). Using non-ISR-safe from ISR → undefined behaviour.

## Audit shape

For a FreeRTOS application:
1. Identify task list and priorities.
2. Identify shared resources.
3. Audit critical sections / IPC use.
4. Check stack sizes vs measured high-water marks.
5. Check heap configuration.
6. Audit network-facing code (FreeRTOS+TCP version, mbedTLS).
7. Audit OTA configuration.
8. Check MPU usage (or absence).

## Defensive baseline

- **Use FreeRTOS-MPU** with strict per-task region grants.
- **Stack-overflow hook enabled**.
- **Heap allocator with free** (heap_4 typically) + fragmentation monitoring.
- **TLS with strong cert pinning** for outbound connections.
- **OTA with signed images** and rollback support.
- **Vendor-shipped components** kept current.

## Workflow to study

1. Install FreeRTOS kernel + reference application.
2. Run on STM32 or ESP32 dev board.
3. Inject classic bugs (stack overflow, UAF) and observe.
4. Read FreeRTOS+TCP CVE writeups.
5. Audit a real device firmware extracted with [[firmware-extraction]].

## Real-world incidents

- **Zimperium FreeRTOS+TCP disclosure (2018)** — 13+ CVEs in TCP/IP stack.
- **Various vendor device CVEs** — Cisco AVR, Quanta, others built on FreeRTOS.
- **OTA-related CVEs** in specific AWS IoT FreeRTOS versions.

## Related

- [[zephyr-audit]]
- [[rtos-shared-bug-classes]]
- [[firmware-audit-methodology]]
- [[firmware-extraction]]
- [[firmware-emulation-firmadyne-qemu]]
- [[bootloader-and-secure-boot-attacks]]
- [[hardware-glitching-deep]]
- [[uart-jtag-debug]]

## References
- [FreeRTOS documentation](https://www.freertos.org/)
- [Zimperium — FreeRTOS+TCP disclosure](https://blog.zimperium.com/freertos-tcpip-stack-vulnerabilities-details/)
- [AWS IoT Device Defender](https://aws.amazon.com/iot-device-defender/)
- [CVE database — FreeRTOS](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=freertos)
- See also: [[zephyr-audit]], [[rtos-shared-bug-classes]], [[firmware-audit-methodology]], [[firmware-extraction]]
