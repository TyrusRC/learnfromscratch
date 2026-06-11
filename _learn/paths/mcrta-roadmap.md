---
title: MCRTA roadmap (MITRE Certified Red Team Associate)
slug: mcrta-roadmap
aliases: [mcrta-prep-roadmap, mitre-red-team-associate-roadmap]
---
{% raw %}

> MCRTA is the MITRE ATT&CK Defender (MAD) take-home practical that certifies you can turn a CTI report into a faithful adversary-emulation plan, execute it with CALDERA and Atomic Red Team, and hand telemetry back to a defender. It is methodology-first, not exploit-dev. Plan on 8 focused weeks (~10 hrs/week) if you already have OSCP-level offensive comfort and basic Windows AD literacy. Ideal candidate: a junior-to-mid red teamer, purple teamer, or detection engineer who wants structured emulation discipline rather than another shell-popping cert.

## Who this is for

- You have shipped at least one internal pentest or red team engagement and can navigate a Windows domain without hand-holding.
- You understand the ATT&CK matrix at the tactic level and have read at least three CTI reports cover-to-cover (Mandiant, CrowdStrike, Microsoft Threat Intel).
- You can stand up a small AD lab (DC + 2 workstations) without a tutorial.
- You are comfortable writing — the exam is graded on the quality of your written emulation plan and report, not on flag count.
- You are not looking for a custom-exploit cert. If you want that, see [[osep-roadmap]] or [[oscp-roadmap]] instead.

## What MCRTA tests

- Format: take-home practical, no live proctor, multi-week window (typically 30 days from voucher activation).
- Deliverables: (1) an adversary emulation plan document and (2) an execution report mapping each TTP to evidence and outcome.
- Environment: your own lab. MITRE does not provide infrastructure — bring your own AD + endpoints + EDR-free or EDR-aware boxes.
- Coverage: ATT&CK tactics, techniques, sub-techniques fluency; CTI-to-TTP translation; emulation execution with CALDERA / Atomic Red Team / manual; telemetry capture; D3FEND counter-mapping; Engage deception touchpoints.
- Grading: rubric-based on faithfulness to the chosen adversary, completeness of TTP coverage, evidence quality, and clarity of defensive recommendations.
- No multiple choice. No timed shell-popping. No CTF flags.
- Re-take policy: one free retake on the same voucher if you fail the first submission.
- Passing bar is qualitative — graders are MAD-trained analysts looking for a report they could hand to a blue team Monday morning.

## Lab setup (do before week 1)

- Hypervisor: Proxmox 8.x or VMware Workstation 17 — you will run 4-6 VMs concurrently.
- Domain controller: Windows Server 2022 Eval, single-forest single-domain, raise functional level to 2016+.
- Endpoints: 2x Windows 11 Enterprise Eval joined to the domain, one as a "user workstation" and one as a "developer/admin" box.
- C2 + emulation host: Ubuntu 22.04 LTS running CALDERA 5.x and the Atomic Red Team repo cloned locally.
- Telemetry: Sysmon 15.x with Olaf Hartong's modular config, Windows Event Forwarding to a central collector, optional Wazuh or Elastic Agent for SIEM-side validation.
- Network: isolated vSwitch with one NATed jump host. No production exposure.
- Reference corpus: download the MITRE Adversary Emulation Library and the FIN6, APT3, and menuPass plans before you start.

## The 8 weeks

### Week 1 — ATT&CK matrix fluency

- Read: [[mitre-attack-mapping]], [[cti-pyramid-of-pain]], [[red-team-vs-pentest-engagement-shape]], [[red-team-operations]]
- Labs: walk every tactic column in the Enterprise matrix and pick one sub-technique per tactic to execute manually on your lab.
- Deliverable: a personal cheat-sheet mapping each ATT&CK tactic to your three favourite sub-techniques and the log source that catches them.

### Week 2 — CTI to emulation translation

- Read: [[adversary-emulation-planning]], [[ransomware-affiliate-playbook]], [[mitre-attack-mapping]], [[cti-pyramid-of-pain]]
- Labs: take a public Mandiant or CrowdStrike report on FIN6 or Scattered Spider and produce a TTP list with sub-technique IDs.
- Deliverable: one adversary emulation plan in the MITRE template format, scoped to 15-25 TTPs.

### Week 3 — Atomic Red Team

- Read: [[atomic-red-team-execution]], [[mitre-attack-mapping]], [[purple-team-feedback-loop]]
- Labs: install Invoke-AtomicRedTeam, execute at least 30 atomics across 8 different techniques, capture Sysmon and 4688 evidence.

```powershell
Install-Module -Name invoke-atomicredteam -Scope CurrentUser
Invoke-AtomicTest T1059.001 -ShowDetailsBrief
Invoke-AtomicTest T1059.001 -TestNumbers 1,2 -GetPrereqs
Invoke-AtomicTest T1059.001 -TestNumbers 1,2
```

- Deliverable: a CSV with columns `technique_id, atomic_number, command, host, timestamp, evidence_path, detected_y_n`.

### Week 4 — CALDERA operator

- Read: [[caldera-adversary-emulation]], [[adversary-emulation-planning]], [[red-team-operations]]
- Labs: stand up CALDERA, deploy the Sandcat agent on two endpoints, run the built-in "Nighthawk" and "Worthy Adversary" operations, then build a custom adversary profile matching the FIN6 plan from week 2.

```bash
git clone https://github.com/mitre/caldera.git --recursive
cd caldera && pip3 install -r requirements.txt
python3 server.py --insecure --build
```

- Deliverable: a custom CALDERA adversary YAML with 10+ abilities mapped to your week-2 plan.

### Week 5 — Telemetry capture and purple handoff

- Read: [[purple-team-feedback-loop]], [[atomic-red-team-execution]], [[caldera-adversary-emulation]]
- Labs: forward Sysmon + Security + PowerShell logs to a central collector, replay week 3-4 executions, write Sigma rules for three of the techniques you covered.
- Deliverable: a Sigma rule pack (3-5 rules) with reference PCAPs and EVTX samples zipped together.

### Week 6 — D3FEND and defensive mapping

- Read: [[d3fend-countermeasure-mapping]], [[mitre-attack-mapping]], [[purple-team-feedback-loop]]
- Labs: for every TTP in your emulation plan, map at least one D3FEND countermeasure ID and note whether your lab currently implements it.
- Deliverable: an attack-to-defence matrix (Excel or Markdown table) ready to drop into a client report.

### Week 7 — Engage and deception touchpoints

- Read: [[engage-deception-engineering]], [[d3fend-countermeasure-mapping]], [[adversary-emulation-planning]]
- Labs: place one canary file, one fake service account, and one decoy SMB share in the lab, then re-run the FIN6 emulation and document which decoys fired.
- Deliverable: a one-page Engage matrix mapping your decoys to the adversary's expected goals.

### Week 8 — Dry run the exam

- Read: [[adversary-emulation-planning]], [[red-team-operations]], [[purple-team-feedback-loop]], [[mitre-attack-mapping]]
- Labs: pick a fresh adversary you have not emulated (APT41 or menuPass), do the full pipeline end to end in five days, time-boxed.
- Deliverable: a complete exam-shaped submission — plan + execution report + defensive mapping — reviewed by a peer before you book the real voucher.

## Required tooling

- CALDERA 5.x with Sandcat and Manx agents
- Atomic Red Team + Invoke-AtomicRedTeam PowerShell module
- Sysmon 15.x + Olaf Hartong modular config
- Windows Event Forwarding or Wazuh / Elastic Agent
- Sigma + sigmac (or pySigma) for rule authoring
- ATT&CK Navigator (self-hosted or hosted)
- MITRE Adversary Emulation Library (local clone)
- A note-taking tool that survives 8 weeks — Obsidian, Logseq, or Joplin

## Practice corpus

- MITRE Adversary Emulation Library — FIN6, APT3, menuPass, OceanLot, Wizard Spider plans
- CTI report corpus: Mandiant M-Trends, CrowdStrike Global Threat Report, Microsoft Threat Intelligence blog, Google TAG
- DetectionLab by Chris Long for a reproducible Windows AD + telemetry stack
- GOAD (Game of Active Directory) for richer AD attack surface
- Splunk Attack Range and Atomic Red Team test plans
- TryHackMe MITRE room and Throwback network for low-stakes warmup

## Pragmatic notes from people who sat the exam

- Methodology beats tooling. Graders want to see you read the CTI, picked TTPs, executed them, and mapped evidence — not that you wrote a custom loader.
- Do not over-tool. CALDERA + Atomic Red Team + a small AD lab is enough. Bringing Cobalt Strike or Sliver adds noise and zero points.
- Write the report as you go. The execution report is a 1:1 mapping table — TTP → command → host → timestamp → evidence → outcome. Build it during execution, not after.
- Pick an adversary you actually find interesting. You will spend 30+ hours inside their playbook, and fatigue shows in the writing.
- Faithfulness matters more than coverage. Executing 20 TTPs that match the adversary beats 50 random atomics.
- Reference D3FEND IDs explicitly. Graders reward defensive translation; do not skip the "what would have stopped this" column.

## Failure modes to avoid

- Treating it like OSCP and chasing shells — there is no flag, and clever exploitation without ATT&CK mapping scores zero.
- Picking a sprawling adversary (Lazarus, APT28) with 200+ documented TTPs and trying to cover all of them.
- Forgetting telemetry — if you cannot show the evidence artefact, the TTP "did not happen" for grading purposes.
- Writing the report in the last 48 hours from memory.
- Mapping to ATT&CK at the tactic level only. Graders want sub-technique IDs (T1059.001, not T1059).

## After MCRTA

- Move to MAD's MITRE ATT&CK Purple Teaming certification to pair this with defensive depth, or to the [[osep-roadmap]] for offensive exploit-dev rigour.
- Volunteer to lead one purple team exercise at work using your exam pipeline — it is the fastest way to internalise [[purple-team-feedback-loop]].
- Contribute one new atomic test or one CALDERA ability back upstream; it is the cheapest way to keep the muscle warm.

## References

- https://mad-certified.mitre.org/
- https://attack.mitre.org/resources/adversary-emulation-plans/
- https://github.com/mitre/caldera
- https://github.com/redcanaryco/atomic-red-team
- https://d3fend.mitre.org/
- https://engage.mitre.org/

See also: [[mitre-attack-mapping]], [[adversary-emulation-planning]], [[caldera-adversary-emulation]], [[atomic-red-team-execution]], [[purple-team-feedback-loop]], [[d3fend-countermeasure-mapping]], [[engage-deception-engineering]], [[red-team-operations]]

{% endraw %}
