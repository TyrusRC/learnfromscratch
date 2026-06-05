---
title: OSCP vs OSEP — the mindset shift
slug: oscp-vs-osep-mindset
aliases: [oscp-vs-osep, exam-mindset-shift]
---

{% raw %}

> **TL;DR:** OSCP rewards *speed at finding a foothold and grinding privesc* on intentionally vulnerable boxes. OSEP rewards *operating quietly inside an assumed-breach environment with modern endpoint defences*. The shift isn't just "harder content" — it's a different game. This note maps the differences across mindset, tooling, OPSEC, and study habits. Pair with [[oscp-roadmap]] and [[osep-roadmap]].

## Five differences that change everything

### 1. Foothold model

- **OSCP:** you start with no access. Recon and exploit to get a shell.
- **OSEP:** you start with *some* access (a user mailbox, a workstation, a low-priv shell) — the foothold is given. The exam tests what you do after.

Implication: OSEP modules begin with "you already have a Word document running on the user's workstation". Read the brief carefully — the implicit assumed-breach is not optional.

### 2. Tooling philosophy

- **OSCP:** off-the-shelf tools (`nmap`, `gobuster`, `winPEAS`, `evil-winrm`, `impacket`). MSF allowed once.
- **OSEP:** *expects* you to modify or rewrite tooling. The exam may explicitly block known-bad signatures. You'll AMSI-patch, you'll write a .NET loader, you'll generate custom shellcode.

Implication: practise *reading and editing C# loaders, COFF stubs, BOFs, .NET assemblies*. The OSEP course gives you the templates; the exam tests if you can adapt.

### 3. OPSEC

- **OSCP:** noisy. You break things. You spam nmap top-ports. You run mimikatz directly. The lab boxes don't care.
- **OSEP:** stealthy. Defender for Endpoint and AppLocker are *on*. Mimikatz hits AMSI. PowerShell spawns get flagged.

Implication: every action is "what does the EDR see?" — parent-child chains, file writes, network endpoints, signed-binary execution. You'll learn to *think* about telemetry before you fire any command.

### 4. AD complexity

- **OSCP:** small AD. Kerberoast a user, get domain admin. 1-2 step chain.
- **OSEP:** constrained delegation, RBCD, forest trusts, ACL chains, MSSQL linked-server chains across domains. 5-10 step chain.

Implication: BloodHound becomes essential for OSEP, but you have to *avoid being caught running it*. Selective collection, OPSEC mode, sometimes parsing LDAP yourself.

### 5. Time budget

- **OSCP:** 24h. Drive-by, sprint between boxes, never overthink.
- **OSEP:** 48h. Plan, reset, plan again. The exam rewards patience — burning the wrong gadget on a noisy action means re-rolling stages.

Implication: write everything down. Snapshot tools and notes. A failed exam usually has "I didn't track what I'd already tried" as a root cause.

## Vocabulary that changes

| OSCP word | OSEP equivalent |
|---|---|
| reverse shell | beacon |
| Mimikatz | nanodump + offline |
| `psexec.py` | WMI exec via custom .NET |
| BloodHound | SharpHound `--Stealth` + offline analyser |
| nmap | curated ping sweep, no version scan |
| reverse shell as user | execute-assembly from beacon |
| persistence: cron / Run key | persistence: scheduled task with TriggerLogon, COM hijack |
| pass the hash | pass the ticket; protocol transition |

## What stays the same

- Enumeration is still 80% of the work.
- Linux privesc vectors don't change (LinPEAS, GTFOBins, kernel exploits) — see [[linpeas-and-enumeration-flow]].
- Reading code (config files, scripts, source dumps) is the highest-ROI activity in both.
- The reporting bar (be reproducible, narrate the chain, screenshot evidence) is identical.

## Practice transitions

If you've passed OSCP and are starting OSEP:

1. **Week 1 — C# loaders.** Take a Mimikatz binary and build a loader that runs it in-memory while bypassing AMSI. Repeat with Rubeus, Seatbelt.
2. **Week 2 — process injection.** Implement CreateRemoteThread, QueueUserAPC, and one of the doppelganging-family ([[process-doppelganging]], [[process-hollowing]]) by hand.
3. **Week 3 — AD delegation.** Set up a lab with two domains and a trust. Practise constrained delegation, RBCD, S4U2Self/Proxy until the Rubeus flags are reflex.
4. **Week 4 — combined chains.** Pick an assume-breach scenario; deliver an OSEP-style payload end-to-end with a real EDR in dev mode.

If you're going *directly* from zero to OSEP (not recommended), pad with two months of OSCP-style boxes first. OSEP assumes the OSCP-floor skills are reflex.

## Anti-patterns

- **Treating OSEP like OSCP.** Spamming a known-bad payload and wondering why nothing works.
- **Treating OSCP like OSEP.** Spending 4 hours building a custom loader for a box that just wants `gobuster /admin`.
- **Skipping OSEP's labs.** OSCP labs are extensible. OSEP labs are the *only* place you'll practise some of the chains. Do them all.
- **Trusting MSF on OSEP.** It's not banned; it's just useless against the exam's EDR posture.

## A useful framing

OSCP teaches you how a single host falls. OSEP teaches you how a *network* falls *without anyone noticing*. Different sport.

## References
- [OffSec — OSCP exam guide](https://help.offsec.com/hc/en-us/articles/360050293792)
- [OffSec — OSEP course overview](https://www.offsec.com/courses/pen-300/)
- [Sektor7 — RED team operator courses](https://institute.sektor7.net/) (community recommendation for OSEP prep)
- [MalDev Academy](https://maldevacademy.com/) (community recommendation for OSEP prep)
- See also: [[oscp-roadmap]], [[osep-roadmap]], [[oscp-exam-methodology]]

{% endraw %}
