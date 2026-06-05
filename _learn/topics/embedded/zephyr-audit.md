---
title: Zephyr Project audit
slug: zephyr-audit
aliases: [zephyr-rtos-audit, zephyr-vulns]
---

> **TL;DR:** Zephyr is the Linux Foundation's open-source RTOS — modern, modular, security-conscious from the ground up. Supports Cortex-M / Cortex-A / RISC-V / Xtensa / ARC. Larger than FreeRTOS (more features, mbedTLS, Bluetooth stack, USB, networking, file systems). Active security disclosure programme; CVEs tracked centrally. Audit focus: network protocol stacks, Bluetooth, USB, file systems, modules trusting input. Companion to [[freertos-audit]] and [[rtos-shared-bug-classes]].

## Why Zephyr

- **Modern RTOS** designed since 2016 with security in mind.
- **Apache 2.0 licensed** — friendly for commercial use.
- **Active community + corporate backing** (Intel, NXP, Nordic, others).
- **Modular** — only pull in needed subsystems.
- **Cooperative or preemptive** scheduling.
- **MMU / MPU support** with userspace.

Used in: IoT devices, BLE peripherals, Cellular modems, Industrial sensors.

## Architecture

- **Kernel** — small core scheduler, threads, IPC.
- **Drivers** — extensive HAL.
- **Subsystems** — networking (IP / TCP / UDP / HTTP / MQTT / CoAP / LwM2M), Bluetooth, USB, file systems (LittleFS, FAT), shell, console.
- **Modules** — external repos (mbedTLS, Trusted Firmware-M).
- **Configuration** — Kconfig + Devicetree.

## User mode and security

- **CONFIG_USERSPACE** — separate user / supervisor; uses MPU.
- **System call layer** — user-mode threads call kernel via supervisor-call.
- **Memory partitions** — per-thread memory grants.
- **Kernel objects** — typed (semaphore, mutex, queue); ownership enforced.

This is more sophisticated than FreeRTOS-MPU but still constrained by Cortex-M architecture.

## Class 1 — Network stack CVEs

Zephyr's networking stack has had CVEs:
- **IPv4 / IPv6** parsing bugs.
- **TCP option handling**.
- **DNS parsing**.
- **DHCPv4**.

Many similar in shape to FreeRTOS+TCP issues; the protocol surface is intrinsic difficulty.

## Class 2 — Bluetooth stack CVEs

Zephyr ships a comprehensive BLE host + controller. Vulnerabilities:
- **L2CAP** packet parsing.
- **SMP (Security Manager)** key handling.
- **GATT** server bugs.
- **Mesh** specific bugs.

BLE attack surface is one of the largest in Zephyr.

See [[ble-and-bluetooth-low-energy-attacks]].

## Class 3 — USB stack

USB device-side stack accepts host-supplied descriptors and class messages. Parser bugs apply.

## Class 4 — File system

LittleFS, FAT, ext2: file-name parsing, large-file handling. Disclosed CVEs around path-handling edge cases.

## Class 5 — Shell / console

The Zephyr shell is a development convenience. If left in production:
- Command injection.
- Information disclosure.
- Sometimes accidental world-readable login.

## Class 6 — System-call boundary

User-to-kernel SVC boundary in Zephyr USERSPACE has had bugs:
- Argument validation missing.
- Pointer-from-user not validated.

When user-mode is exploited, system-call boundary is the next layer.

## Class 7 — Crypto stack

Zephyr uses mbedTLS or PSA Crypto APIs (newer). Implementation bug class:
- Side-channel issues in some implementations.
- Misuse of API in application code.

See [[cryptography-side-channels-survey]].

## Class 8 — Trusted Firmware-M integration

Zephyr can pair with TF-M for ARM TrustZone-M. Misconfiguration:
- Secure-side service exposed too broadly.
- Non-secure code accessing secure resources via flawed interface.

## Audit shape

For a Zephyr application:
1. Identify enabled subsystems (Kconfig).
2. Identify external connections (Bluetooth peripheral, USB, IP server).
3. Audit each network-facing parser.
4. Check shell / console exposure in production.
5. Verify USERSPACE enabled where appropriate.
6. Verify TF-M secure-side service interface.
7. Audit crypto API usage.

## Defensive baseline

- **Enable USERSPACE** with strict per-thread memory partitions.
- **Disable shell** in production.
- **Update Zephyr** kernel + modules promptly; subscribe to security mailing list.
- **mbedTLS / PSA Crypto** with current versions.
- **TF-M integration** for secure-element-backed crypto.
- **Network stack hardening** — disable unused protocols.
- **Watchdog enabled**.

## Workflow to study

1. Install Zephyr + west.
2. Build and run a sample for QEMU or supported hardware.
3. Browse Zephyr CVE database; reproduce one against an older version.
4. Build with USERSPACE; test isolation.
5. Audit a real product's Zephyr fork (e.g., Nordic nRF Connect SDK).

## Real-world incidents

- **Cisco / Linksys / Nordic / Intel** devices built on Zephyr have shipped CVE-affected versions.
- **Zephyr security advisories** published quarterly — track at https://github.com/zephyrproject-rtos/zephyr/security/advisories.

## Security programme

- **Zephyr Project Security Working Group** active.
- **GitHub security advisories** standardised.
- **PSIRT-style coordinated disclosure**.

## Related

- [[freertos-audit]]
- [[rtos-shared-bug-classes]]
- [[firmware-audit-methodology]]
- [[firmware-extraction]]
- [[ble-and-bluetooth-low-energy-attacks]]
- [[bootloader-and-secure-boot-attacks]]
- [[android-trusty-tee-attacks]]
- [[cryptography-side-channels-survey]]

## References
- [Zephyr Project](https://zephyrproject.org/)
- [Zephyr security](https://docs.zephyrproject.org/latest/security/)
- [Zephyr advisories on GitHub](https://github.com/zephyrproject-rtos/zephyr/security/advisories)
- [Nordic nRF Connect SDK (Zephyr-based)](https://www.nordicsemi.com/Products/Development-software/nRF-Connect-SDK)
- See also: [[freertos-audit]], [[rtos-shared-bug-classes]], [[firmware-audit-methodology]], [[ble-and-bluetooth-low-energy-attacks]]
