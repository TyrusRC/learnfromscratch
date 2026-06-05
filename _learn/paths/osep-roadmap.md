---
title: OSEP roadmap (PEN-300)
slug: osep-roadmap
aliases: [osep-prep-roadmap, pen-300-roadmap]
---

{% raw %}

> **TL;DR:** A 16-week roadmap from "I just passed OSCP" to "I can sit OSEP". Heavier on tooling-development and EDR-evasion than on enumeration. Pair with [[oscp-vs-osep-mindset]] and [[osep-full-chain-walkthrough]].

## Prerequisites
- Pass OSCP first, or be at OSCP-equivalent comfort.
- Read C# without a tutorial open. (Not "write" — "read".)
- Build a lab: at least one Windows workstation, one server, a domain controller, an EDR you can put in dev mode (Defender or Elastic Defend).

## Lab setup (do this before week 1)
- Domain: `corp.local`. DC on Win2022. Workstation on Win11.
- Enable Defender + AMSI in default config.
- Install Sysmon with a sane config (SwiftOnSecurity).
- Optional: a second forest `partner.local` with a trust to `corp.local`. Required for the cross-forest weeks.

## The 16 weeks

### Week 1 — mindset and OPSEC
- Read: [[oscp-vs-osep-mindset]], [[opsec-fundamentals]], [[infrastructure-design]], [[c2-frameworks]].
- Deliverable: a written threat model of your own home lab, listing what telemetry exists where.

### Week 2 — C# loader fundamentals
- Read: [[windows-api-and-syscalls]], [[c-and-asm-primer]].
- Labs: write a C# "Hello, world" that uses P/Invoke to call `MessageBoxW`. Then one that loads shellcode into a private memory region and runs it via `CreateThread`.
- Deliverable: minimal shellcode runner in C# that you'll iterate on weekly.

### Week 3 — AMSI and ETW
- Read: [[amsi-bypass]], [[amsi-providers-tampering]], [[etw-bypass]].
- Labs: implement an AMSI bypass in C# (memory patch on `AmsiScanBuffer`). Verify by importing the AMSI signature test string after the patch.
- Deliverable: AMSI patch + ETW patch helper class you can reuse.

### Week 4 — process injection (classic)
- Read: [[process-injection-techniques]], [[process-hollowing]], [[reflective-dll-injection]], [[thread-hijacking]].
- Labs: implement classic CreateRemoteThread injection, then process hollowing, then APC injection.
- Deliverable: three injection primitives in your toolkit.

### Week 5 — process injection (advanced)
- Read: [[atom-bombing]], [[early-bird-apc]], [[module-stomping]], [[process-doppelganging]], [[process-ghosting]], [[process-herpaderping]].
- Labs: implement module stomping (overwrite a benign loaded module with your payload).
- Deliverable: a module-stomping demo bypassing a sample EDR signature.

### Week 6 — syscalls and unhooking
- Read: [[syscall-direct-and-indirect]], [[edr-hooks-and-unhooking]].
- Labs: build a direct-syscall NtAllocateVirtualMemory + NtWriteVirtualMemory + NtCreateThreadEx chain. Bonus: indirect syscalls via SysWhispers3.
- Deliverable: a syscall-based shellcode runner.

### Week 7 — client-side initial access
- Read: [[client-side-attacks-primer]], [[office-vba-macros-initial-access]], [[jscript-hta-wsh-initial-access]].
- Labs: build a Word macro that AMSI-patches then runs a Sliver/Mythic stager.
- Deliverable: working phishing payload chain that bypasses default Defender on Win11.

### Week 8 — application allowlisting bypass
- Read: [[applocker-bypass-techniques]], [[wldp-bypass]], [[living-off-the-land]].
- Labs: enable AppLocker default rules on the workstation, then bypass via msbuild, installutil, and writable path.
- Deliverable: documented bypasses for each of the three buckets.

### Week 9 — network filter bypass and C2
- Read: [[c2-protocol-design]], [[dns-c2-and-icmp-c2]], [[domain-fronting-and-cdn-abuse]], [[pivoting-and-tunneling]].
- Labs: stand up a Sliver C2 fronted via Cloudfront (or a Cloudflare Worker). Add DNS C2 as a fallback transport.
- Deliverable: working multi-transport C2 with documented detection signatures for each.

### Week 10 — Windows credentials
- Read: [[credential-dumping]], [[lsa-secrets]], [[dpapi-secrets]], [[cached-domain-credentials]], [[wdigest-cleartext-enable]], [[ssp-package-injection]].
- Labs: dump LSASS with nanodump and parse offline with pypykatz; pull DPAPI master keys and decrypt browser-stored creds.
- Deliverable: full credential-harvest workflow with no Mimikatz on disk.

### Week 11 — Windows lateral movement
- Read: [[lateral-movement-playbook]], [[psexec-family]], [[wmi-exec]], [[smb-exec]], [[winrm-exec]], [[dcom-exec]], [[overpass-the-hash]], [[pass-the-ticket]].
- Labs: lateral move via four different protocols from one host; observe which raise alerts in Defender.
- Deliverable: a per-protocol noise rating + your chosen default.

### Week 12 — Linux post-exploitation and lateral
- Read: [[linux-post-exploitation-tradecraft]], [[linux-userland-and-kernel-rootkit-primer]], [[ssh-agent-hijack]], [[ssh-execution]].
- Labs: drop a PAM backdoor; hide a process and a file via LD_PRELOAD; pivot SSH via agent forwarding abuse.
- Deliverable: Linux persistence + evasion toolkit (scripts + LD_PRELOAD `.so`).

### Week 13 — kiosk and edge cases
- Read: [[kiosk-breakout-techniques]], [[shell-upgrade-techniques]].
- Labs: lock a VM into a Citrix-published Notepad; break out to cmd.exe via file dialog.
- Deliverable: a documented kiosk-breakout checklist.

### Week 14 — AD attacks deep
- Read: [[constrained-delegation]], [[resource-based-constrained-delegation]], [[unconstrained-delegation]], [[s4u2self-abuse]], [[shadow-credentials]], [[acl-abuse]], [[adcs-attacks]], [[cross-forest-trust-abuse]], [[child-to-forest-root]], [[mssql-trusted-links]], [[mssql-xp-cmdshell-impersonation-chains]].
- Labs: build a chain that uses two delegation types and ends with cross-forest DA.
- Deliverable: BloodHound diagram + Rubeus command log of the chain.

### Week 15 — combining the attacks
- Read: [[osep-full-chain-walkthrough]], [[ad-attack-path-playbook]], [[recon-to-foothold]].
- Labs: full mock — phishing → workstation → AD → cross-forest DA — under EDR-on conditions.
- Deliverable: chain executed end-to-end with no detection events you didn't anticipate.

### Week 16 — exam prep, report template, sit
- Read: [[oscp-exam-methodology]] (re-read for time-mgmt patterns), [[report-writing-for-pentesters]].
- Labs: full 48-hour mock against a community OSEP-like challenge (Sektor7, MalDev Academy, or your own scenario).
- Deliverable: complete OSEP-format report; book the exam.

## Required tooling list (build or acquire)

- Sliver or Mythic C2 (free; open source).
- SysWhispers3 for indirect syscall stubs.
- Nanodump for LSASS.
- Rubeus, Certify, SharpHound, SharpKatz (build yourself from source).
- Donut for shellcode generation from .NET assemblies.
- Process Hacker / Process Explorer for blue-team analysis.
- Sysmon + sane config for telemetry observation.

## Community courses that pair well
- Sektor7 — RED Team Operator (Endgame and Malware Development).
- MalDev Academy — comprehensive malware-development curriculum.
- Cybernetics Pro Labs (HTB) — AD-heavy practice.

## References
- [OffSec PEN-300 syllabus](https://www.offsec.com/courses/pen-300/)
- [SpecterOps blog](https://posts.specterops.io/)
- [MDSec — research and tradecraft](https://www.mdsec.co.uk/blog/)
- [Sektor7 RTO courses](https://institute.sektor7.net/)
- [MalDev Academy](https://maldevacademy.com/)
- See also: [[oscp-vs-osep-mindset]], [[oscp-roadmap]], [[osep-full-chain-walkthrough]], [[report-writing-for-pentesters]]

{% endraw %}
