---
title: Opsec fundamentals
slug: opsec-fundamentals
---

> **TL;DR:** Every action leaves traces in three places: on the host (EDR, event logs), on the wire (NetFlow, proxy logs), and in cloud control planes (CloudTrail, Azure Activity). Plan each step against that triad.

## What it is
Operational security in offensive work is the discipline of knowing what you leak with each action, deciding whether the leak is acceptable, and choosing tradecraft that minimises the residual. Not "avoid detection" — "control what gets recorded and when."

## Preconditions / where it applies
- Always. Even labs benefit from baking in OPSEC habits early
- Especially: long-haul engagements, environments with mature SOCs, anything cloud where audit logs are immutable

## Technique
**Triad.**
- *Host:* EDR telemetry, Sysmon, Defender ASR, AppLocker decisions, prefetch, $MFT timestamps, registry MRU
- *Wire:* DNS queries (resolver logs), JA3/JA4 TLS fingerprints, proxy logs with destination + UA + bytes, NetFlow
- *Cloud:* CloudTrail / Azure Activity / GCP Audit Log, IAM action records, KMS key usage, S3 object access

**Decisions per action.**
1. What process will my action attribute to? (parent-PID, command line, integrity level)
2. What network traffic does it produce, and does it match expected baseline for that user/host/time?
3. What audit log entries appear, and how long before someone reads them?

**Common pitfalls.**
- Running tooling under your operator account name as the process owner
- Default JA3 from your Go/Rust runtime — instantly identifiable
- Picking the same redirector / hosting provider you used last week
- Beacon timing patterns that survive jitter (autocorrelation)
- Touching `Domain Admins` / sensitive groups before you need to
- Using PowerShell with default execution policy bypass switches that script-block-log every line
- Pushing tools to disk in `%TEMP%` with original names

**Quiet defaults.**
- Sleep + jitter tuned to the engagement length
- Indirect syscalls + sleep mask + return-address spoofing on implants
- Per-host derived encryption keys so a single beacon dump doesn't unlock others
- Separate kill switches per tier
- Time-of-day windows that match the target's working hours
- Stage tooling on the box only when needed; clean up after each phase

**Burn discipline.** If something detects, stop. Investigate what fired. Don't re-run the same payload thirty seconds later. Most defenders' first move is "watch for it to come back."

## Detection and defence
- Mature blue teams look for *absence* of expected telemetry (a process that disabled ETW)
- UEBA tools alert on "user accessing systems they don't normally touch" — pick lateral targets that fit the role
- Cloud control-plane logs are immutable and frequently shipped to SIEM in near real-time — assume CloudTrail wins
- Honeypots in AD: fake KCD accounts, fake LAPS-protected machines, fake S3 buckets with canary tokens

## References
- [SpecterOps blog](https://posts.specterops.io/) — research on OPSEC failure modes
- [TrustedSec blog](https://trustedsec.com/blog) — practical OPSEC tradecraft
- [Mandiant blog](https://www.mandiant.com/resources/blog) — APT case studies on noise vs persistence
- [[c2-protocol-design]] [[ad-recon-low-noise]] [[purple-team-feedback-loop]]
