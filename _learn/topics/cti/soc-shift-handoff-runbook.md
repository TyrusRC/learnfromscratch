---
title: SOC shift handoff — runbook discipline
slug: soc-shift-handoff-runbook
aliases: [soc-handoff, shift-changeover]
---

> **TL;DR:** Shift handoff is where incidents get lost. A SOC running 24x7 either with 8/12 hour rotations or a follow-the-sun model lives or dies by the discipline applied to the changeover: what state each active incident is in, which tickets are blocked, which alerts were deferred and why, which watchlist items still matter. Treat handoff as a runbook artifact with the same rigor as [[soc-runbook-design]] and [[ir-from-source-signals]], feed lessons back through [[purple-team-feedback-loop]], and align it with the catalog from [[siem-detection-use-case-catalog]].

## Why it matters

The single biggest source of "we missed it" in mature SOCs is not detection gap. It is loss of context across a shift boundary. An analyst on Tuesday night sees something odd, decides it is probably benign, makes a note in the ticket, and goes home. Wednesday morning the day shift opens a backlog of 200 alerts, never reads that note, closes the ticket as a duplicate. The intruder dwells for three more weeks.

This pattern shows up in nearly every post-mortem of a long-dwell breach. It is also the failure mode least likely to be fixed by a new tool. It is fixed by process — explicit handoff documentation, mandatory sync, and a culture where "I do not know what state this is in" is an acceptable answer that triggers escalation, not embarrassment.

## Cadence patterns

Most SOCs land in one of these patterns:

- **Single-site 8 hour rotation.** Three shifts per day, all in the same office or region. Typical for regulated enterprises with on-prem SOCs. Easier to do a face-to-face sync but burns more headcount.
- **Single-site 12 hour rotation.** Two shifts (day / night), often 4-on-4-off or similar. Common for MSSPs and lean in-house teams. Longer shifts mean handoff is less frequent but each handoff carries more state.
- **Follow-the-sun across 2-3 regions.** Asia-Pacific hands to EMEA hands to Americas. Common for global enterprises and large MSSPs. Each region works a normal business day, no nights. Handoff is purely async or briefly synchronous via video, and time-zone overlap is usually 1-2 hours.
- **Hybrid.** Business hours fully staffed at HQ, night and weekend covered by a regional team or MSSP. Handoff happens twice — once into the after-hours team, once back.

The cadence choice is driven by headcount, budget, regulatory expectations, and whether the org tolerates night shifts. Follow-the-sun is operationally cleaner for analyst wellbeing but requires three sites, hiring in three jurisdictions, and tight coordination. 8/12 hour shifts are cheaper but produce burnout and turnover, which themselves cause handoff failures because the people leaving have low motivation to write a clean handoff for the people arriving.

## What gets handed off

A handoff is not "all the tickets" — that is just the queue. Handoff is the delta and context that the next shift cannot reconstruct from the tools alone.

- **Active incidents with state.** Each open incident needs: current containment status, last action taken, who took it, what the next planned action is, who owns the escalation path, and any external parties involved (vendor, legal, comms). Tie the state vocabulary to your [[soc-runbook-design]] so "contained" means the same thing on every shift.
- **Open tickets with status.** For each non-incident ticket: is it waiting on a user, waiting on engineering, waiting on more data, or genuinely ready for the next shift to action. "Waiting" tickets should have an expected timeline.
- **Deferred alerts with reasoning.** Alerts the previous shift consciously chose not to chase. Document why — "Splunk lag, will check at 0800", "user travelling, ticket opened with IT", "FP candidate, see ticket #4421 for detection-tuning thread". This is the layer that most often goes missing and most often hides intrusions.
- **Watchlist items.** Hosts, users, IPs, processes the previous shift has flagged for elevated scrutiny but that have not yet crossed into an incident. Include the reason and a TTL — watchlist items without expiry rot fast.
- **Anomalies seen.** Anything weird that did not fit a rule. A new outbound destination, a spike in failed logins on a service account, a SaaS app no one recognises. Even if dismissed, write it down — patterns emerge across shifts.
- **Tooling and pipeline state.** Detection pipelines down, SIEM ingestion lag, EDR sensor coverage gaps, log source silence. The next shift needs to know what they cannot trust right now.
- **External context.** Active CVEs being weaponised, threat-intel reports relevant today, planned change-management windows that will generate noise, scheduled red-team activity from [[purple-team-feedback-loop]].

## Handoff documentation template

Treat the handoff log as a structured artifact, not freeform notes. A minimum template:

```
Shift: <date> <region> <shift-id>
Outgoing lead: <name>
Incoming lead: <name>

Active incidents:
  - INC-1234 | <one-line summary> | state: containment-in-progress | last action: isolated host at 14:22 by analyst-A | next: forensic image, owner: analyst-B incoming shift | escalation: IR manager on call
  - ...

Open tickets requiring action this shift:
  - TKT-5678 | waiting on user response since 12:00 | escalate if no reply by 18:00

Deferred / dismissed alerts (with reasoning):
  - alert-id 998877 | reason: known maintenance window per CM-2024-44 | revisit if seen after 16:00

Watchlist:
  - host: corp-laptop-447 | reason: anomalous PowerShell at 09:14 | TTL: 24h
  - user: svc-jenkins-prod | reason: new outbound IP on uncommon port | TTL: 48h

Pipeline / tooling state:
  - SIEM ingestion lag on firewall feed ~15 min
  - EDR sensor missing on 3 newly built VMs (IT ticket TKT-5701)

Threat-intel / external context:
  - CISA KEV update overnight, two new CVEs relevant to internet-facing edge appliances

Outstanding questions for incoming shift:
  - Did the change-management window for the AD upgrade complete cleanly?
```

This template lives in a wiki or a ticketing-system custom form, not in chat. Chat is for the sync conversation, not the durable record.

## Sync meeting vs async

- **Synchronous handoff (15-30 min).** Outgoing and incoming leads on a video or in person, walk through the active-incident list and any high-severity items. Best for incident-heavy shifts and same-region rotations. Forces both parties to acknowledge state.
- **Async handoff.** Outgoing lead writes the handoff doc, posts a summary in the shift channel, incoming lead acknowledges by reply. Necessary for follow-the-sun where time-zone overlap is poor. Risk: things get skimmed.
- **Hybrid (recommended).** Async written record always, plus a short synchronous overlap whenever there are active incidents or sev-2+ tickets. The sync is mandatory for any incident at containment stage or earlier.

The non-negotiable rule: incoming shift acknowledges receipt of handoff in writing before the outgoing shift logs off. No silent ghosting.

## Common failure modes

- **Incidents lost between shifts.** Ticket marked "monitoring" by outgoing shift, incoming shift assumes that means done. Fix: state vocabulary must distinguish "monitoring with action expected" from "monitoring passively". Tie to runbook from [[soc-runbook-design]].
- **Duplicate work.** Incoming shift re-triages an alert the previous shift already dismissed because the dismissal note was buried. Fix: deferred-alert log is a first-class section of handoff, not a hidden ticket comment.
- **Stale watchlist items.** Hosts on a watchlist for weeks, no one remembers why. Fix: TTL on every entry, auto-expire and force renewal.
- **Handoff fatigue on quiet shifts.** Analyst writes "nothing to report" because the shift was uneventful, missing low-signal anomalies. Fix: even quiet shifts document tooling state and any weak signals seen.
- **Handoff at the wrong altitude.** Outgoing shift hands over alert-level minutiae but skips the strategic picture (the campaign trend, the noisy detection that needs tuning). Fix: separate sections for "operational state right now" and "trends / things to fix soon".
- **Skipping handoff on weekends or holidays.** Reduced-staffing shifts deprioritise the discipline. Fix: handoff template is the same regardless of headcount, even if shorter.

## Incident-state pass-off discipline

For active incidents, the outgoing shift owns the incident until the incoming shift has explicitly accepted. This is non-trivial: it means the outgoing shift cannot leave until acceptance is logged. Practical mechanisms:

- Incident has an `assigned_to` field that must be reassigned at handoff, not left on the previous owner.
- Incoming owner posts an acceptance message: "Taking INC-1234, current state contained, next action forensic image at 16:00, escalation IR-manager-on-call".
- If the incoming shift has questions, the outgoing analyst stays available (chat or phone) until those are resolved or escalated.
- Major incidents have a dedicated incident commander whose role does not change at shift boundary — they are paged 24x7 until incident closure. Shift analysts rotate under the commander.

Tie this to the source-signal lifecycle work in [[ir-from-source-signals]] so that data-collection state (what logs are being captured, what forensic artifacts have been pulled) is explicit.

## Communication-tool patterns

- **Slack / Mattermost / Teams.** Per-shift channel for ephemeral chat. Per-incident channel for incident response. Don't mix the two. The handoff doc lives outside chat in a wiki or ticketing system.
- **Jira / ServiceNow / TheHive.** Ticket of record for each incident and each handoff. Custom fields for state vocabulary, watchlist TTL, deferred-alert reasoning.
- **Wiki / Confluence / Notion.** The handoff template, the runbooks themselves, the on-call escalation tree.
- **Pager / on-call tool.** PagerDuty, Opsgenie, etc. Sev-1 escalations bypass shift handoff entirely — they wake whoever is on the rota regardless of region.

Anti-pattern: critical handoff state living only in DMs between two senior analysts. When one of them is on PTO, the SOC loses memory.

## Follow-the-sun coverage for weekends and holidays

The cleanest follow-the-sun model still has weekend asymmetry. APAC's Monday is EMEA's Sunday. Local public holidays differ per region. Practical patterns:

- **Coverage matrix.** Document explicitly which region covers which hours on which days. Holidays in one region get backfilled by an adjacent region.
- **Reduced-staffing protocols.** On a region's holiday, the on-call rota covers, and routine triage is deferred to the next business day with explicit deferral notes.
- **Cross-region runbooks.** Every region runs the same playbooks. No region has secret tribal knowledge. This is hard culturally — fight it actively.
- **Periodic cross-region exercises.** Tabletop or live-fire across regions so analysts have actually worked together before a real incident hits at 03:00 in their counterpart's time zone.

## Workflow to study

1. Pick a real ticket from your queue this week. Reconstruct from logs alone what state it was in at each shift boundary. Compare to what the handoff log said. Note gaps.
2. Audit one week of deferred-alert reasoning. How many had reasoning written? How many were re-opened by a later shift unnecessarily?
3. Audit one month of watchlist entries. How many had a TTL? How many expired without review?
4. Pick a sev-2+ incident from the last quarter. Map the shift boundaries during its lifecycle. Where did context drop?
5. Sit through a handoff sync as an observer. Note what was said verbally that was not in the written log. That delta is your gap.
6. Run a tabletop where the incident spans three shifts. Force the team to use only the written handoff between shifts. See what breaks.

## Related

- [[soc-runbook-design]]
- [[ir-from-source-signals]]
- [[siem-detection-use-case-catalog]]
- [[purple-team-feedback-loop]]
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[atomic-red-team-emulation-deep]]

## References

- SANS reading room, "Building a World-Class Security Operations Center": https://www.sans.org/white-papers/
- MITRE 11 Strategies of a World-Class Cybersecurity Operations Center: https://www.mitre.org/news-insights/publication/11-strategies-world-class-cybersecurity-operations-center
- NIST SP 800-61r2 Computer Security Incident Handling Guide: https://csrc.nist.gov/pubs/sp/800/61/r2/final
- FIRST CSIRT Services Framework: https://www.first.org/standards/frameworks/csirts/
- Google SRE Workbook, on-call and handoff chapters: https://sre.google/workbook/on-call/
