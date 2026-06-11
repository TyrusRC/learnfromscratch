---
title: OSCP vs OSEP vs OSWE — track comparison
slug: oscp-osep-oswe-track-comparison
aliases: [offsec-track-comparison, oscp-osep-oswe]
---

{% raw %}

> **TL;DR:** The three OffSec mid-tier offensive certifications test different skills with similar formats. **OSCP** = breadth + black-box network/web pentest. **OSEP** = depth + assumed-breach + custom tooling against EDR. **OSWE** = source-driven whitebox web exploitation with a single Python script per target. Pick based on what you want to *do for a living* — and the order matters. Pair with [[oscp-roadmap]], [[osep-roadmap]], [[oswe-roadmap]].

## Side-by-side

| Dimension | OSCP (PEN-200) | OSEP (PEN-300) | OSWE (WEB-300) |
|---|---|---|---|
| Exam duration | 24h hack + 24h report | 48h hack + 24h report | 48h hack + 24h report |
| Format | 3 standalone + 1 AD set | 1-3 connected scenarios | 2-3 source-provided apps |
| Starting position | External, no creds | Often assumed-breach | Source code in hand |
| Allowed tools | Most OSS; 1 MSF auto-exploit | Most OSS; commercial allowed | Most OSS + IDEs + debuggers |
| Skill emphasis | Breadth, speed, methodology | Custom tooling, evasion, AD depth | Source review, exploit dev for web |
| Languages required | minimal Python | C#, PowerShell, Python | PHP / Node / Java / .NET / Python / Ruby (read all) |
| Pass threshold | 70 / 100 (with bonus) | 100 / 100 (all targets) | 85 / 100 |
| Prep time (avg) | 3-6 months | 4-6 months after OSCP | 4-6 months after OSCP |

## What each one *teaches* you to do

### OSCP — "I can get a shell"
- Recon at speed.
- Use public exploits and adapt them.
- Privilege escalate in Linux and Windows reliably.
- Move laterally in a small AD environment.
- Write a coherent report under pressure.

Career impact: junior-to-mid pentester role; baseline credential for client-facing offensive work.

### OSEP — "I can operate inside a hostile environment"
- Write malware loaders that evade modern EDR.
- Land payloads through realistic phishing.
- Operate stealthily inside an AD environment.
- Cross trust boundaries (delegation, forest trusts).
- Custom tooling discipline.

Career impact: red-team consultant, internal red team, advanced offensive engineer.

### OSWE — "I can find the bug from source"
- Read code in many languages.
- Identify auth bypass, deserialisation, SSRF, injection chains.
- Build a single-script exploit that ties multiple steps together.
- Work without dynamic analysis when needed.

Career impact: application security engineer, source-code auditor, bug-bounty escalation.

## Recommended order

Different opinions, but the consensus path:

1. **OSCP first.** Foundational. Hiring managers know what an OSCP can do; OSEP/OSWE without OSCP raises questions.
2. **OSEP or OSWE second** depending on the role you want.
   - Red team / internal pentest → OSEP.
   - Application security / code review → OSWE.
3. Both eventually for a senior offensive engineer / Triple OSC3.

Going OSEP without OSCP-level fluency means burning lab hours on basics. Going OSWE without OSCP web fluency is harder than the OSWE on its own.

## Skills overlap

```
       ┌─────────────┐
       │   web bugs  │ ─── OSCP & OSWE
       └─────────────┘
              │
              ▼
       ┌─────────────┐
       │   methodology │ ─── all three
       └─────────────┘
              │
              ▼
       ┌─────────────┐
       │      AD     │ ─── OSCP & OSEP
       └─────────────┘
              │
              ▼
       ┌─────────────┐
       │   reporting │ ─── all three
       └─────────────┘
```

OSCP's web is breadth; OSWE's web is depth. OSCP's AD is "get DA in a small environment"; OSEP's AD is "get cross-forest DA from a workstation foothold with EDR enabled".

## Costs (current at time of writing — verify)

OffSec sells each course as PEN-200, PEN-300, WEB-300. Pricing tiers vary (one-time, subscription, "Learn One/Learn Unlimited"). Expect roughly:

- One exam attempt + course material: low thousands USD per cert.
- Lab time differs heavily across tiers; "Learn Unlimited" gives a year of multi-course access.

For organisations: there are corporate licenses; for individuals, pay attention to current bundle pricing and time-bounded promotions.

## Adjacent OffSec certs (each has its own roadmap in this repo)

- **OSED (EXP-301)** — Windows user-mode exploit dev. The "binary OSCP". See [[osed-roadmap]].
- **OSMR (EXP-312)** — macOS control bypasses + userland exploitation. See [[osmr-roadmap]].
- **OSEE (EXP-401)** — advanced Windows kernel exploitation. The "binary OSEP". See [[osee-roadmap]].
- **OSWA (WEB-200)** — black-box web assessor; the entry-tier web cert below OSWE. See [[oswa-roadmap]].
- **OSDA (SOC-200)** — the OffSec defender cert; SIEM/EDR/IR analyst track. See [[osda-roadmap]].
- **AI-300** — AI Red Teamer (prompt injection, agentic chains, model supply chain). See [[ai-300-roadmap]].
- **OSWP** — wireless cert; historically dated; revamped recently.

## Non-OffSec certs worth knowing exist

- **CRTP / CRTE / CRTM** (Altered Security) — AD-focused; complements OSEP.
- **MCRTA** (MITRE) — adversary-emulation-from-ATT&CK methodology. See [[mcrta-roadmap]].
- **eWPTX** (eLearnSecurity) — advanced web pentest; broader than OSWE; less industry recognition.
- **GPEN / GXPN** (SANS/GIAC) — pricier; corporate-focused; good if your employer pays.

## Bypass advice

- **Lab time matters more than course content.** OSCP / OSEP / OSWE all have community-equivalent labs (HTB, PG Practice, TryHackMe, Cybernetics) that match or exceed the official lab quality.
- **Practice the report format.** A pass that fails to report properly fails the cert.
- **For OSEP and OSWE, the exam reflects the course closely.** Skipping course modules to "self-study only" works for OSCP; for the others, the official labs encode the exact toolchain expected.

## Failure modes to avoid

- Going for OSEP without OSCP-level command-line reflex → run out of time.
- Going for OSWE without comfort reading C# / Java / PHP → time gets eaten by language lookup, not exploitation.
- Treating any of them as "trivia exams". They're skill exams.
- Not snapshotting the lab VM. Lose half an hour to environment break.

## Recommended pivot points

After OSCP + one of OSEP/OSWE: pick the other, or move to:
- **OSED** for binary skill development.
- **AWAE alumni → bug bounty** scaling.
- **OSEP alumni → red-team consulting**.

After all three (the "Triple OSC3"): the next bar is OSEE (binary) or OffSec's own "OSCE3" tier completion.

## References
- [OffSec — All courses overview](https://www.offsec.com/courses-and-certifications/)
- [TJ Null's preparation lists (OSCP, OSWE)](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/)
- [HackTricks](https://book.hacktricks.xyz/) — encyclopedic
- [VulnHub](https://www.vulnhub.com/) — practice VMs for offline labs
- See also: [[oscp-roadmap]], [[osep-roadmap]], [[oswe-roadmap]], [[osed-roadmap]], [[osmr-roadmap]], [[osee-roadmap]], [[oswa-roadmap]], [[osda-roadmap]], [[ai-300-roadmap]], [[mcrta-roadmap]], [[oscp-vs-osep-mindset]], [[oscp-exam-methodology]], [[report-writing-for-pentesters]]

{% endraw %}
