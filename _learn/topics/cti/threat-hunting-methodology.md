---
title: Threat hunting methodology
slug: threat-hunting-methodology
aliases: [threat-hunting, hunting-methodology]
---

> **TL;DR:** Threat hunting is the discipline of looking for adversary activity that no alert has fired on. It starts from a hypothesis ("if APT-X were here, I would see Y in process telemetry"), runs queries across deep data, and either confirms compromise, surfaces a detection gap, or produces a new rule. It is not the same as detection engineering ([[detection-engineering-pyramid-of-pain]]) and not the same as incident response ([[ir-from-source-signals]]). Treat it as a senior-analyst function fed by [[cti-collection-management]] and validated against [[atomic-red-team-emulation-deep]] and [[hypothesis-driven-hunting]].

## Why it matters

Detection coverage is always incomplete. Every SOC has gaps the SIEM does not know about: telemetry sources without rules, rules without tuning, TTPs the vendor has not published yet, and quiet living-off-the-land tradecraft that looks like admin work. Hunting is the function that operates inside those gaps.

Three things drive its existence:

- **Dwell time.** Mature adversaries (see [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-russian-svr-fsb]]) routinely sit on networks for months. Alerts caught the noisy ones. Hunters find the quiet ones.
- **New TTPs.** Tradecraft drifts faster than detection content. Hunting closes the gap between threat intel reporting ([[cti-collection-management]]) and shippable rules.
- **Validation.** Hunting tests whether your assumed coverage is real. It pairs naturally with [[purple-team-feedback-loop]] and [[atomic-red-team-emulation-deep]].

## Hunting vs detection engineering vs IR

The three are commonly confused, even by mature teams.

### Hunting

- Starts from a **hypothesis without an alert**.
- Input: threat intel, environmental knowledge, analyst intuition, a recent breach report.
- Output: either nothing (hypothesis disproven), a finding (becomes an incident), or a candidate detection (handoff to detection engineering).
- Cadence: bursty, project-shaped, sometimes continuous.

### Detection engineering

- Builds, tests, and tunes the **alerts themselves**.
- Input: hunt outputs, TTP libraries (ATT&CK), purple team results, internal incident lessons.
- Output: production rules with documented logic, validation, and false-positive budget. See [[siem-detection-use-case-catalog]] and [[edr-rules-as-code-from-attack-patterns]].
- Cadence: continuous engineering function with a backlog.

### Incident response

- Engages **after a confirmed compromise**.
- Input: alert, hunt finding, third-party tip, breach disclosure.
- Output: containment, eradication, recovery, lessons learned. See [[ir-from-source-signals]] and [[cloud-ir-aws-cloudtrail]].
- Cadence: reactive, on-call.

The clean handoff looks like: **hunter forms hypothesis -> finds suspicious activity -> escalates to IR if real -> hands TTP to detection engineering for permanent rule**. If your team blurs these into one role, you will either skip hunting (always firefighting) or skip rule production (every hunt rediscovers the same gap).

## Team composition

Threat hunting is a **senior analyst function**, not a tier-1 promotion path. The skills that matter:

- **Deep query literacy.** Comfortable writing KQL, SPL, OSQuery, EQL, or whatever native SIEM/EDR language ships. Not "use the wizard".
- **Telemetry fluency.** Knows what Sysmon Event ID 10 means, what a CloudTrail `AssumeRoleWithSAML` looks like, what a normal `lsass` access pattern is.
- **Adversary mental model.** Reads threat reports critically. Has internalized ATT&CK enough to think in techniques, not strings.
- **Investigative discipline.** Documents hypothesis, queries, results, dead ends. Does not chase shiny things without a plan.
- **Statistical comfort.** Knows the difference between "rare" and "anomalous". Can defend a finding from "but it's only one host" pushback.

Realistic sourcing: most hunters come from tier-3 SOC analysts ([[soc-tier-1-tier-2-tier-3-progression]]), IR consultants, or detection engineers who want more freedom. Tooling vendors that pitch "hunting for tier-1 analysts" are selling dashboards, not hunting.

## Tooling

Hunting is constrained by what telemetry is reachable and how flexibly you can query it.

### SIEM with deep query

- Long retention (90 days minimum, 1 year preferred for hypothesis hunting).
- Raw events, not just normalized fields.
- Ability to join across data sources without surcharge anxiety.

### EDR with raw telemetry

- Process trees, command lines, parent/child, image loads, network connections.
- Historical search across the fleet, not just the last 7 days.
- API access so hunters are not stuck in the GUI.

### Network flow and PCAP

- Zeek/Suricata logs, NetFlow, DNS query logs.
- Catches beaconing, lateral movement, and exfil patterns that endpoint telemetry misses or hides.

### Jupyter and notebooks

- For hunts that go beyond SIEM expressivity: time-series anomalies ([[time-series-anomaly-for-security]]), graph analysis, statistical baselining.
- Reproducibility matters. A notebook documents the hunt better than a screenshot.

### Cloud-native telemetry

- CloudTrail, Azure Activity, GCP Audit, k8s audit logs ([[cloud-ir-k8s-audit-logs]]).
- Identity-centric hunts ([[cloud-iam-misconfig-patterns]]) increasingly dominate cloud-heavy estates.

## Hunting cadence

Two models, both legitimate.

### Continuous hunting

- Hunter or small team dedicated full-time.
- Backlog of hypotheses, with new ones added from intel cycles and incident lessons.
- Best fit: large enterprises with mature SOCs, regulated industries with high dwell-time risk.

### Campaign-based hunting

- Time-boxed sprints, often quarterly, focused on a theme (e.g. "ransomware precursor activity", "OAuth abuse in M365").
- Useful when hunting is a part-time function for senior analysts.
- Risk: themes get stale, and the team drifts back into detection engineering or IR.

A pragmatic mid-size SOC blends both: one or two continuous hunters plus quarterly campaigns that pull in detection engineers and IR consultants ([[purple-team-feedback-loop]]).

## The hunting process

A repeatable hunt has five phases. Skipping any of them turns hunting into vibes.

1. **Hypothesis.** Specific, falsifiable, telemetry-grounded. "If actor X were operating here, I would see Y in data source Z." See [[hypothesis-driven-hunting]] for the discipline of phrasing this well.
2. **Data acquisition.** Confirm the telemetry exists, is complete, and covers the time window. Many hunts die here because the log source is broken and nobody knew.
3. **Analysis.** Run queries, baseline what "normal" looks like, look for deviations. Use [[structured-analytic-techniques-for-hunters]] to avoid confirmation bias.
4. **Outcome.** Either: finding (escalate to IR), gap (file detection backlog ticket), or null result (document and close).
5. **Handoff.** Even a null hunt produces value: a documented technique, a query saved for re-running, a telemetry gap surfaced.

## Measurement challenges

Hunting is hard to measure honestly. Success often looks like absence of incidents, which is invisible.

- **"Hunts run" is a vanity metric** if nobody asks about quality. A SOC running 100 trivial hunts a month is worse than one running 4 deep ones.
- **"Findings per hunt"** punishes hunters for testing well-defended hypotheses, which is exactly what you want them to do.
- **"Detections produced"** is better but still incomplete (some hunts produce process changes or policy work, not rules).
- **"Time to detect" (MTTD) over time** is the closest thing to a real outcome metric, and even that is noisy.

Honest CISO framing: hunting is **insurance against the gaps you cannot see**. Pitch it like you pitch tabletop exercises ([[tabletop-exercise-design-and-execution]]) - the value is in the gaps surfaced and the speed gained when something real happens.

## Maturity tiers

A realistic ladder:

- **Tier 0 - No hunting.** Alerts only. Tickets in, tickets out. Most SMBs and many regulated mid-market firms live here.
- **Tier 1 - Ad hoc.** Senior analyst occasionally pokes at the SIEM after reading a breach report. No process, no record, no follow-through.
- **Tier 2 - Structured.** Documented hypotheses, repeatable queries, hunt log, handoff to detection engineering. Quarterly campaigns or a part-time hunter.
- **Tier 3 - Continuous.** Dedicated hunting function, intel-driven backlog, feedback loop with [[purple-team-feedback-loop]] and [[detection-engineering-pyramid-of-pain]].
- **Tier 4 - Research-grade.** Hunters publish externally, contribute to ATT&CK, build novel telemetry. Rare and expensive.

Most organizations should target tier 2. Tier 3 is real for banks, large tech, critical infrastructure ([[financial-sector-defender-playbook]], [[manufacturing-ot-defender-playbook]]). Tier 4 is for vendors and a handful of giants.

## Output value

What a healthy hunting function actually produces:

- **New detections.** Rule candidates handed to detection engineering with sample data and false-positive analysis.
- **IOCs and TTPs.** Atomic indicators for short-term blocking; behavioural patterns for durable detection (climb the [[detection-engineering-pyramid-of-pain]]).
- **Telemetry gaps.** "We cannot see process creation on these 800 servers" - now you can fix it.
- **Architectural feedback.** Hunting surfaces flat networks, over-privileged service accounts ([[cloud-iam-misconfig-patterns]]), and missing segmentation.
- **Confirmed incidents.** Occasionally, the actual point: a real compromise that no alert caught.

## Defensive baseline before hunting

Hunting on a broken SOC is wasted senior-analyst time. Before standing up a hunting program, make sure:

- Log coverage is mapped against ATT&CK data sources, with known gaps.
- EDR is deployed widely enough to be statistically meaningful (above ~90 percent of endpoints).
- Tier-1 and tier-2 are functional ([[soc-runbook-design]], [[soc-ticket-hygiene-mttr]]) so hunters are not pulled into queue-clearing.
- Detection engineering exists, even informally, so hunt findings can be turned into rules.
- Threat intel exists in usable form ([[cti-collection-management]]), not just a feed nobody reads.

## Workflow to study

A study path for a senior analyst moving into hunting:

1. Read three threat reports per week and try to phrase one falsifiable hypothesis from each. Practice [[hypothesis-driven-hunting]].
2. Pick five ATT&CK techniques and map them against your telemetry. Where are the gaps?
3. Run [[atomic-red-team-emulation-deep]] tests for those techniques and hunt for them in your own data.
4. Build a hunt notebook template - hypothesis, data sources, queries, results, follow-ups, hand-off.
5. Run one campaign-based hunt end-to-end. Document everything, including dead ends.
6. Pair with detection engineering on converting your best hunt into a production rule. See [[edr-rules-as-code-from-attack-patterns]].
7. Build feedback loop with IR ([[ir-from-source-signals]]) and purple team ([[purple-team-feedback-loop]]).

## Vendor marketing vs reality

- "AI-driven autonomous hunting" almost universally means "anomaly dashboard with marketing on top". Real hunting needs hypothesis and human judgement.
- "Hunting included" in MDR contracts usually means generic IOC sweeps, not custom hypothesis work for your environment.
- "Tier-1 analysts hunting in our platform" means clicking pre-built queries. Useful triage, not hunting.
- A real hunting capability requires senior staff time, deep telemetry access, and tolerance for null results. Anyone promising hunting without those three is selling something else.

## Related

- [[hypothesis-driven-hunting]]
- [[structured-analytic-techniques-for-hunters]]
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[atomic-red-team-emulation-deep]]
- [[purple-team-feedback-loop]]
- [[ir-from-source-signals]]
- [[siem-detection-use-case-catalog]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[soc-tier-1-tier-2-tier-3-progression]]
- [[time-series-anomaly-for-security]]

## References

- SANS, "The Who, What, Where, When, Why and How of Effective Threat Hunting": https://www.sans.org/white-papers/36785/
- MITRE ATT&CK for hunters: https://attack.mitre.org/resources/
- David Bianco, "Pyramid of Pain" (foundational for prioritising hunt outputs): https://detect-respond.blogspot.com/2013/03/the-pyramid-of-pain.html
- ThreatHunter Playbook (open hunt patterns): https://threathunterplaybook.com/
- Splunk PEAK threat hunting framework: https://www.splunk.com/en_us/blog/security/peak-threat-hunting-framework.html
- CISA, "Threat Hunting Guidance": https://www.cisa.gov/resources-tools/services/cisa-threat-hunting
