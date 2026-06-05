---
title: Case study — 3CX supply-chain compromise (2023)
slug: case-study-3cx-supply-chain
aliases: [3cx-2023, smooth-operator, north-korea-3cx]
---

> **TL;DR:** 3CX (a widely-used VoIP softphone) shipped digitally signed installers that contained a malicious DLL. The DLL retrieved second-stage instructions from a GitHub-hosted icon file with embedded data. Investigation found the build environment had been compromised via a *prior* supply-chain compromise — Trading Technologies' X_TRADER installer — used by a 3CX developer. The first publicly-disclosed cascading supply-chain incident: one vendor's compromise enabled another vendor's compromise. Companion to [[case-study-snowflake-2024]] and [[case-study-okta-2023-support-system]].

## Why this matters

- **Cascading supply chain** — the attacker compromised vendor A to compromise vendor B. Modelling threats only as direct vendor risk misses this.
- 3CX was used by thousands of organisations including Fortune 500; trojanised installer was widely deployed before discovery.
- Discovery was **EDR telemetry**, not 3CX self-detection. Treats the EDR vendor as a credible last line.
- Attribution to North Korean (Lazarus / UNC4736) operators with longer track record of supply-chain campaigns.

## The chain

1. North Korean operators compromised Trading Technologies' build environment (months earlier).
2. They shipped a trojanised X_TRADER installer.
3. A 3CX developer installed X_TRADER on their workstation.
4. Operators pivoted into 3CX's build environment.
5. Trojanised 3CX's electron-based softphone build, replacing `ffmpeg.dll` with a malicious version.
6. 3CX's CI signed and shipped the bad build to customers.
7. Customers' installations made outbound HTTPS to GitHub-hosted icon files.
8. Icon files contained appended encrypted payload (steganography-ish; ICO trailer bytes).
9. Payload retrieved second-stage shellcode; persistence and C2.
10. Mandiant / CrowdStrike / SentinelOne detected the outbound pattern on customer endpoints.

## The technical primitives

- **Trojanised DLL via build pipeline**: signature was valid because 3CX signed the bad build.
- **ICO steganography**: payload appended after the ICO data; image rendered normally; appended bytes decrypted by the implant.
- **GitHub as dead-drop**: legitimate-looking high-availability infrastructure for command delivery.
- **Multi-platform**: Windows and macOS builds both affected.

## Detection

CrowdStrike, SentinelOne, and others initially detected on **behavioural indicators**:
- Signed 3CX process making outbound HTTPS to GitHub repos.
- DLL loaded by signed Electron app spawning network handler in unusual order.
- Slack / customer-support traffic from 3CX hosts containing query patterns not associated with normal use.

These are general "code-signing alone is not enough" signals.

## What this teaches

- **Code-signing trust** must be paired with **build-environment integrity**. SLSA / in-toto / Sigstore provenance helps.
- **Cascading risk modelling**: list your vendors' vendors. The 3CX → X_TRADER chain shows two-hop blast radius.
- **EDR with behavioural rules** is more effective than file-hash IOC matching for fresh-launched campaigns.
- **Build-pipeline isolation** — production build infrastructure should not allow developer-installed apps.
- **Egress allowlists from build servers**.

## IR lessons

- Customer IR involved **identifying the compromised 3CX builds**, removing them, hunting for second-stage implants.
- Removal of 3CX alone did not remove persistence — separate IR was needed.
- Vendor-coordinated IR worked: 3CX, vendors who detected (CrowdStrike, SentinelOne, Mandiant), customer hunting.

## Detection use cases (SIEM)

Map into [[siem-detection-use-case-catalog]]:

- Signed binary making outbound HTTPS to raw GitHub content.
- Newly-installed signed app spawning shell or PowerShell in first 60 seconds of run.
- DLL load events from non-vendor paths into signed processes.
- Beacons on long sleep intervals (jitter-aware) to CDN-fronted endpoints.

## Generalising

The cascading model:

```
Vendor C (target) ←  Vendor B (intermediary) ← Vendor A (initial)
                  (B's product installed)    (A's product installed)
```

Replace with any modern vendor stack: a developer installs npm packages and pip libraries from many upstreams; any of those compromised enables pipeline access; pipeline access enables downstream-product compromise.

The xz incident ([[cve-2024-3094-xz-utils-backdoor]]) is the next iteration, with a maintainer-takeover step in front of the build pipeline.

## References
- [Mandiant — 3CX investigation report](https://cloud.google.com/blog/topics/threat-intelligence/3cx-software-supply-chain-compromise/)
- [CrowdStrike — 3CXDesktopApp blog](https://www.crowdstrike.com/blog/crowdstrike-detects-and-prevents-active-intrusion-campaign-targeting-3cxdesktopapp-customers/)
- [SentinelOne — Smooth Operator analysis](https://www.sentinelone.com/blog/smoothoperator-ongoing-campaign-trojanizes-3cxdesktopapp-in-supply-chain-attack/)
- [3CX advisory](https://www.3cx.com/blog/news/security-incident-update/)
- See also: [[cve-2024-3094-xz-utils-backdoor]], [[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]], [[supply-chain-attacks-on-models]]
