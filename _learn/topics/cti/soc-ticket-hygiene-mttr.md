---
title: SOC ticket hygiene and MTTR
slug: soc-ticket-hygiene-mttr
aliases: [soc-ticket-hygiene, mttr-optimization]
---

> **TL;DR:** SOC ticket hygiene is the unglamorous discipline that decides whether your Mean Time To Respond (MTTR) numbers reflect reality or are a fiction analysts produce to keep leadership happy. A clean state taxonomy, honest false-positive accounting, and per-severity time budgets turn the queue into a measurable system instead of a graveyard of "closed - benign" with no notes. Pair this with [[soc-runbook-design]], [[soc-shift-handoff-runbook]], [[soc-tier-1-tier-2-tier-3-progression]], and [[detection-engineering-pyramid-of-pain]] so your detections, people, and tickets all reinforce each other instead of fighting.

## Why it matters

Most SOCs measure MTTR because an executive asked for a number, not because the number drives decisions. The result is a metric that goes down for the wrong reasons: analysts close tickets fast to hit SLA, auto-close rules eat real incidents, and reporting hides the fact that detections are noisy and runbooks are stale.

Ticket hygiene matters because the ticket is the only durable artefact of an investigation. Six months later, when [[ir-from-source-signals]] points back at an alert your team already saw, the ticket is what tells you whether someone actually looked or just clicked "false positive." It feeds [[purple-team-feedback-loop]], it informs [[detection-engineering-pyramid-of-pain]] tuning, and it is the raw input for honest MTTR reporting.

When hygiene is broken you get three predictable failures:

- Repeat incidents that "look new" because nobody could find the prior ticket.
- Detection engineers tuning blind because closure reasons are vague.
- Leadership chasing a green dashboard while real dwell time grows.

## Ticket state taxonomy

A taxonomy with too few states hides information; too many states nobody fills them in. A workable middle is eight states, every transition timestamped.

### Open / active states

- **new** - alert ingested, not yet acknowledged. The clock for Mean Time To Acknowledge (MTTA) runs here.
- **triaged** - an analyst has read it, assigned severity, and decided it is worth investigating. False positives can skip straight from new to a closed state.
- **investigating** - active work, evidence gathering, pivots into [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], EDR, or [[siem-detection-use-case-catalog]] queries.
- **contained** - immediate spread stopped (host isolated, credentials disabled, IP blocked) but root cause not yet fully addressed.
- **eradicated** - threat actor access removed, persistence cleaned, monitoring in place for recurrence.

### Closed states

- **closed - true positive** - confirmed malicious or policy-violating activity. Must reference the incident record if escalated.
- **closed - false positive** - detection logic fired on benign activity that the rule was not meant to catch. This is a detection-engineering bug.
- **closed - benign true positive** - rule correctly identified the behaviour, but the behaviour is authorised (sanctioned admin tool, approved scanner). This is a tuning / allowlist problem, not a detection bug.

The distinction between false positive and benign true positive is the single most useful hygiene improvement most SOCs can make. They demand different fixes.

## MTTD, MTTI, MTTR - say what you mean

Loose vocabulary destroys metric trust. Pin the definitions in writing and put them on the dashboard.

- **MTTD** - Mean Time To Detect. From the earliest evidence of activity (log timestamp) to alert creation. Measures detection latency, not analyst speed.
- **MTTA** - Mean Time To Acknowledge. From alert creation to first human acknowledgement. Measures queue health and staffing.
- **MTTI** - Mean Time To Investigate. From acknowledgement to a triage decision (escalate, contain, close). Measures runbook quality.
- **MTTR** - Mean Time To Respond or Resolve. Pick one and be consistent. "Respond" usually means time to containment; "Resolve" usually means time to closure. Reporting both is fine; conflating them is not.
- **Dwell time** - from initial compromise to detection. Often unknowable until post-incident analysis; do not pretend MTTD equals dwell time.

A common honest framing: "MTTD measures our detections, MTTA measures our staffing, MTTI measures our runbooks, MTTR measures everything combined."

## Time-budget targets per severity

Targets must be defensible against the analyst at 03:00 with five alerts open. Pick numbers your team can hit with current headcount, then tighten.

### Reasonable starting budgets

- **Critical** (active intrusion, ransomware precursor, exposed crown jewel): MTTA 15 min, MTTI 1 hr, MTTR-contain 4 hr, MTTR-resolve 24 hr.
- **High** (credible targeted activity, confirmed malware on endpoint): MTTA 30 min, MTTI 4 hr, MTTR-contain 24 hr, MTTR-resolve 72 hr.
- **Medium** (suspicious but not confirmed, policy violations with risk): MTTA 4 hr, MTTI 24 hr, MTTR-resolve 5 business days.
- **Low / informational**: MTTA 1 business day, MTTR-resolve 10 business days, or auto-close per rule.

These are starting points. Regulated environments ([[pci-dss-4-implementation]], [[hipaa-security-rule]], [[nis2-implementation]]) may impose tighter notification clocks that drive tighter internal budgets.

## False-positive rate management

A SOC drowning in false positives produces unreliable MTTR because analysts develop "click reflex" - close fast, look later, look never. Three tools help:

### Auto-closure rules

Auto-close is legitimate for well-understood, high-volume noise: known-good scanners hitting known-good targets, repeated benign DNS lookups, vulnerability scanner traffic from authorised IPs. Every auto-close rule must have:

- An owner (the detection engineer accountable for it).
- A measurable condition (specific source, specific destination, specific signature).
- A review date (quarterly minimum).
- A counter on the dashboard so leadership sees what is being suppressed.

Anti-pattern: auto-closing on broad fields like "alert name contains scan." That suppresses real incidents the day an attacker borrows scanner naming.

### Deduplication

Group tickets by entity (host, user, IP) within a time window before they hit the analyst queue. A ransomware deployment that lights up 200 endpoint alerts should be one ticket with 200 child events, not 200 tickets racing 200 SLAs.

### Fatigue mitigation

Track per-analyst close-rate distributions. Outliers in either direction (too fast, too slow) are signals, not punishments. Rotate runbook authorship so analysts close tickets against playbooks they helped write - see [[soc-runbook-design]].

## Ticket-quality metrics

MTTR is meaningless without a quality denominator. Sample 5-10% of closed tickets per week and grade them against a rubric:

- Closure reason matches evidence in the ticket.
- Pivot queries are recorded or linked.
- True/false/benign distinction is correct.
- Escalations include the escalation rationale.
- Containment actions taken are listed with timestamps and operator.

Express the result as a "well-documented ratio." A SOC with 95% SLA compliance and 30% well-documented ratio is producing fiction. A SOC with 80% SLA compliance and 90% well-documented ratio is producing intelligence.

## Reporting MTTR to leadership

Leadership wants one number; the SOC owes them context.

- Report MTTD, MTTA, MTTI, MTTR side by side. They diagnose different problems.
- Report per severity and per detection source. A blended average hides that endpoint alerts are healthy and identity alerts are broken.
- Report the well-documented ratio. Otherwise MTTR is gamed within a quarter.
- Report false-positive rate and auto-close volume. A falling MTTR with rising auto-close is not improvement.
- Show the trend, not the snapshot. A single month is noise.

When MTTR moves, explain *why*. Better detections ([[edr-rules-as-code-from-attack-patterns]]), better runbooks, more staff, or fewer alerts? The number alone does not say.

## Anti-patterns

### Closing valid tickets to hit SLA

The single most corrosive behaviour. It looks like good metrics and produces missed incidents. Counter with quality sampling and a no-blame policy for reopening tickets a peer closed too soon.

### Over-aggressive auto-close

Suppressing whole categories because they are "usually noise" turns the SOC into a filter the attacker has already studied. Every auto-close is a bet; review the bets.

### "Closed - other" or free-text closure

If analysts can type their own closure reason, the data is unanalysable within a month. Force a controlled vocabulary; allow free-text *in addition*, not *instead*.

### Severity drift

Analysts downgrade severity to give themselves more time. Audit severity-change events; require justification on downgrade.

### Treating MTTR as the SOC's job alone

MTTR is a function of detection quality, analyst experience, and tool ergonomics. Blaming analysts for slow response when the SIEM takes 90 seconds per query is a management failure.

## Correlating MTTR to its drivers

When MTTR is bad, decompose before reacting:

- **Detection quality** - high false-positive rate inflates MTTI as analysts re-prove every alert. Fix via [[detection-engineering-pyramid-of-pain]] and [[purple-team-feedback-loop]].
- **Analyst experience** - junior analysts on senior tickets stretch MTTI. Fix via [[soc-tier-1-tier-2-tier-3-progression]] and shadowing.
- **Tool quality** - slow SIEM, missing log sources, painful pivots. Fix via [[siem-detection-use-case-catalog]] investment and source onboarding.
- **Process quality** - missing runbooks, weak handoffs. Fix via [[soc-runbook-design]] and [[soc-shift-handoff-runbook]].

The cheapest improvement is usually runbook coverage of the top-10 alert types by volume.

## Defensive baseline

- Eight-state taxonomy enforced in the ticketing tool, no free-text closure reasons.
- MTTD, MTTA, MTTI, MTTR defined in writing, all four reported.
- Severity-tagged time budgets, downgrades audited.
- Weekly 5-10% quality sample with a documented rubric.
- Auto-close rules owned, reviewed quarterly, counted on the dashboard.
- Deduplication on host/user/IP before queue entry.
- Monthly review of top-10 alert types feeding [[detection-engineering-pyramid-of-pain]] tuning.
- Quarterly metric retrospective: are we measuring what we want, or what is easy?

## Workflow to study

1. Pull 30 days of closed tickets. Bucket by closure reason. Note the "other / unclear" rate.
2. Sample 50 tickets at random. Grade against a five-point rubric. Calculate the well-documented ratio.
3. Compute MTTD, MTTA, MTTI, MTTR by severity. Identify the worst pair (severity, metric).
4. For that pair, decompose: is it detection, analyst, tool, or process?
5. Pick one runbook to write or rewrite per [[soc-runbook-design]]. Re-measure after one month.
6. Add one auto-close rule with an owner and review date. Add its counter to the dashboard.
7. Present MTTR alongside the well-documented ratio to leadership. Watch what happens to the conversation.

## Related

- [[soc-runbook-design]]
- [[soc-shift-handoff-runbook]]
- [[soc-tier-1-tier-2-tier-3-progression]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[purple-team-feedback-loop]]
- [[ir-from-source-signals]]
- [[cti-collection-management]]
- [[edr-rules-as-code-from-attack-patterns]]

## References

- <https://www.first.org/standards/frameworks/csirts/csirt_services_framework_v2.1>
- <https://www.sans.org/white-papers/incident-handlers-handbook/>
- <https://attack.mitre.org/resources/get-started/>
- <https://www.nist.gov/privacy-framework/incident-response>
- <https://www.cisa.gov/resources-tools/resources/incident-response-plan-irp-basics>
- <https://csrc.nist.gov/pubs/sp/800/61/r2/final>
