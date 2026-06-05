---
title: SOC runbook design
slug: soc-runbook-design
aliases: [runbook-design, soc-playbook-design]
---

> **TL;DR:** A SOC runbook is the difference between an analyst calmly closing a phishing alert in eight minutes and panicking through a 90-minute Slack thread at 3 AM. Good runbooks are short, executable, version-controlled, and updated after every retro. They are the connective tissue between [[siem-detection-use-case-catalog]], [[atomic-red-team-emulation-deep]], [[soc-shift-handoff-runbook]], and [[ir-from-source-signals]]. Bad runbooks are 40-page PDFs nobody reads.

## Why it matters

Most SOC failures are not failures of detection. They are failures of response consistency. Two analysts handed the same alert reach different conclusions, take different containment actions, and write different tickets. That variance is what breaks MTTR, breaks metrics, and breaks trust with IT and business owners.

Runbooks are the cheapest control you can deploy. They cost zero dollars in licensing. They survive analyst turnover. They are training material for new hires, a forcing function for detection engineers (if you cannot write a runbook for your rule, the rule is not ready for production), and the source of truth for SOAR automation later.

The catch: most runbooks are written once, read never, and rot inside Confluence. This note is about avoiding that.

## When to write a runbook

Not every alert deserves a runbook. Writing one for a unique once-a-year event is wasted effort. Triggers that justify a runbook:

- **Repeated alert types.** If you have seen the same alert fire more than three times in a quarter, write the runbook.
- **High-volume noisy detections** where consistent triage and tuning decisions matter (e.g., Suspicious PowerShell, Impossible Travel, AV detection on endpoint).
- **High-severity low-frequency incidents** where you cannot afford the analyst to improvise (ransomware indicator, domain controller compromise, executive account takeover).
- **Cross-team handoff patterns.** Anything that needs IT, legal, HR, or comms to be paged on a predictable cadence.
- **Recently lived incidents.** A retro almost always produces a runbook update or a new one. See [[purple-team-feedback-loop]].

If a detection has no runbook and is not a candidate for one, that is a signal the detection should be deprecated or auto-closed.

## Runbook structure

The goal is a single page. If the analyst has to scroll past the fold during an incident, the runbook has failed. Keep it terse and procedural.

### 1. Header

- Alert / incident name (exact, matches SIEM rule name)
- Severity matrix (when is this Low, Medium, High, Critical)
- Runbook owner (a person, not a team)
- Last reviewed date
- Linked detection rule(s) and MITRE ATT&CK technique IDs

### 2. Trigger

What event fires this runbook. Be specific: SIEM rule ID, EDR alert name, ticket source. If the runbook is triggered by a human reporting phishing, say so.

### 3. Immediate steps (first 5 minutes)

The hard cap is five minutes. These are reflex actions:

- Acknowledge the ticket and set status
- Capture initial context (user, host, source IP, timestamp)
- Decide: real or false positive based on a small checklist
- If real, page on-call / open incident channel

### 4. Investigation

A short list of queries and pivots, in order. Include actual SIEM / EDR query snippets inline. The analyst should not have to remember Splunk SPL or KQL syntax under pressure. Cross-link to [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], or [[cloud-ir-k8s-audit-logs]] for cloud-specific pivots.

Investigation steps answer: what happened, who is affected, when did it start, is it still active.

### 5. Containment

Exact actions, with the authority level required. "Isolate host via EDR" only if the analyst can do it without approval. If they need a manager, say so and include the page command.

### 6. Eradication

Removal actions: kill processes, remove persistence, revoke tokens, reset credentials. Reference [[edr-rules-as-code-from-attack-patterns]] for evidence-of-removal queries.

### 7. Recovery

When can the host be returned to the user? Who reimages? Who restores from backup? What monitoring stays elevated for the next 72 hours?

### 8. Post-incident

Ticket fields to fill, IOCs to push to threat intel ([[cti-collection-management]]), retro requirement (yes / no), and whether this runbook itself needs updating.

## Single-page discipline

Long runbooks fail under pressure. There is real research on this from aviation and emergency medicine: cognitive load during a high-stress event collapses people's ability to follow long procedures. Checklists work. Manuals do not.

Practical limits:

- One screen of content on a 13-inch laptop in Confluence or Markdown view
- Maximum five investigation queries
- Maximum three containment actions per severity tier
- No prose paragraphs longer than three lines

If a runbook does not fit, split it. "Phishing - user clicked link" and "Phishing - credentials submitted" are two runbooks, not one.

## Embedding the right things inline

Things that belong inline in the runbook:

- SIEM / EDR query strings (copy-pasteable)
- Direct links to the detection rule source
- Slack / Teams channel names and on-call paging commands
- The exact ticket template
- Contact list for escalation (named people, not "the IT team")
- Decision trees as bullet trees, not flowcharts

Things that do not belong inline:

- Background on the threat actor (link to a CTI note)
- Full incident response policy (link)
- Training material (separate doc)

## Version control

Runbooks must be diffable. Two practical patterns:

### Git-backed

Runbooks as Markdown in a repo. PR workflow forces review, history is automatic, you can lint for required sections in CI. Render through a static site or sync to the team wiki via a bot. Works well for SOCs with engineering muscle.

### Confluence (or similar) with discipline

Native page history, required labels, scheduled review reminders, page restrictions to prevent silent edits. Slower than Git but everyone can edit. Most enterprise SOCs land here.

Either way: every runbook has an owner, a last-reviewed date, and a review cadence (90 or 180 days). Stale runbooks are quietly worse than no runbook because they create false confidence.

## SOAR integration

Once the runbook is stable, parts of it become code. Common integration targets: Splunk SOAR (Phantom), Tines, Torq, Palo Alto Cortex XSOAR, Swimlane.

What automates well:

- Enrichment (WHOIS, threat intel lookups, asset owner from CMDB)
- Containment for well-scoped cases (block IOC at firewall, isolate host)
- Notification (open incident channel, page on-call)
- Evidence collection (pull EDR triage package, snapshot VM)

What does not automate well:

- Judgment calls (is this user behavior actually suspicious for their role)
- Cross-team coordination beyond paging
- Anything where a wrong action causes business impact bigger than the alert

The runbook stays the source of truth. The SOAR playbook is a faithful implementation of part of it. When they drift, fix the runbook first, then the code.

## Updating runbooks after incidents

The single biggest predictor of runbook quality: does the team update them after every incident retro?

Mechanism that works:

- Retro produces an action item: "Update runbook X" with an owner and due date.
- The runbook PR / page edit is required to close the incident in the ticket system.
- Quarterly, the SOC lead reviews all runbooks touched in the last 90 days and confirms changes landed.

Without that loop, runbooks rot at the rate of one detail per incident. After a year they describe a world that does not exist.

## Measuring effectiveness

Metrics that mean something:

- **Mean alert-to-resolution time per runbook.** If it goes up, something changed (volume, complexity, staffing).
- **False positive rate before vs after runbook deployment.** A good runbook should make FP triage faster and more consistent, not change the underlying detection.
- **Analyst-to-analyst variance.** Same alert type, different analysts: how different are their resolution times and notes? Use this as a training signal.
- **Skip rate.** What fraction of analysts say they followed the runbook? Audit a sample by reading their tickets.
- **Time to first containment action** for high-severity runbooks. This is the metric that matters for ransomware-class events.

Metrics that lie: number of runbooks written, page views in Confluence, "completeness" scores.

## Common failure modes

- **Written once by the wrong person.** A senior analyst writes a runbook full of assumed context. A new analyst cannot follow it. Test runbooks with the most junior person on shift.
- **Too long.** See above.
- **Out of date queries.** SIEM schema changed, runbook did not. Lint queries in CI if you can.
- **Generic phishing runbook.** Phishing has at least four variants worth separate runbooks: link click, credential submit, attachment open, business email compromise. Cross-link [[aitm-evilginx-modern-phishing]] and [[oauth-device-code-phishing-m365]] for the modern flavors.
- **No owner.** Nobody updates it. Assign a named owner with a calendar reminder.
- **Living in a different system than the alert.** Analyst opens ticket in ServiceNow, runbook lives in Confluence, queries live in Splunk. Three tabs minimum. Link them from the alert itself if your SIEM supports it.
- **Runbook describes investigation but not containment.** Easy to write the fun part, hard to write the part with business impact. Containment must be explicit.

## Workflow to study

1. Pick your three noisiest alerts in the SIEM. Read 20 closed tickets for each.
2. Note the variance in resolution time, queries used, and outcome.
3. Draft a one-page runbook for the worst-variance one. Write it for a brand-new analyst.
4. Walk a junior analyst through it on the next live alert. Watch where they hesitate.
5. Edit. Get the runbook on screen during the next incident retro. Update again.
6. After three iterations, pick the parts that automate cleanly and write a SOAR playbook for them.
7. Repeat for the next alert. Build a catalog. Cross-link with [[detection-engineering-pyramid-of-pain]].

## Related

- [[siem-detection-use-case-catalog]]
- [[atomic-red-team-emulation-deep]]
- [[soc-shift-handoff-runbook]]
- [[ir-from-source-signals]]
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[purple-team-feedback-loop]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[cloud-ir-aws-cloudtrail]]
- [[aitm-evilginx-modern-phishing]]

## References

- <https://www.sans.org/white-papers/incident-handlers-handbook/>
- <https://csrc.nist.gov/pubs/sp/800/61/r2/final>
- <https://attack.mitre.org/resources/>
- <https://www.first.org/standards/frameworks/csirt_services_framework>
- <https://www.cisa.gov/sites/default/files/publications/Federal_Government_Cybersecurity_Incident_and_Vulnerability_Response_Playbooks_508C.pdf>
- <https://github.com/certsocietegenerale/IRM>
