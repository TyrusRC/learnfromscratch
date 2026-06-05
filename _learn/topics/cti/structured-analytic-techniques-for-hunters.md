---
title: Structured analytic techniques for hunters
slug: structured-analytic-techniques-for-hunters
aliases: [structured-analytic-techniques, sats-hunting]
---

> **TL;DR:** Structured Analytic Techniques (SATs) come from intelligence analysis tradecraft (CIA, ODNI) and exist to fight cognitive bias when evidence is ambiguous, adversaries are deceptive, or stakes are high. Threat hunters borrow a small subset — Analysis of Competing Hypotheses (ACH), Key Assumptions Check, Devil's Advocacy, red-cell, indicators/signposts, and premortem — to keep hunts honest. Pair this with [[hypothesis-driven-hunting]] for the hunt loop, [[cti-collection-management]] for the inputs, and [[deception-and-honeypot-strategy]] for the adversary perspective.

## Why it matters

Threat hunting is an analytic discipline pretending to be an engineering one. Hunters stare at sparse, noisy, partially-adversarial evidence and decide whether a behavior is benign, broken, or malicious. The failure modes are not technical — they are cognitive:

- Anchoring on the first plausible hypothesis (usually "admin did it").
- Confirmation bias when querying — you write the KQL that proves your theory.
- Availability bias from the last incident or last vendor briefing.
- Mirror-imaging — assuming the adversary thinks like you.
- Groupthink in hunt reviews where the senior analyst speaks first.

SATs do not make analysts smarter. They slow down judgment, externalize assumptions, and force the team to consider hypotheses they would otherwise dismiss. They originated in the Cold War (Heuer's *Psychology of Intelligence Analysis*) and were systematized in the CIA's *Tradecraft Primer* and ODNI's later guides. For hunters working alongside [[detection-engineering-pyramid-of-pain]] and [[purple-team-feedback-loop]], a handful of these techniques pay for themselves.

## Core techniques worth learning

### Analysis of Competing Hypotheses (ACH)

The flagship technique. Used when you have ambiguous evidence and 2+ plausible explanations.

Process:

1. List all reasonable hypotheses (include the boring ones: misconfig, sysadmin, automation, vendor agent).
2. List every piece of evidence and indicator — including absence of evidence.
3. Build a matrix: hypotheses across the top, evidence down the side. Mark each cell C (consistent), I (inconsistent), or N/A.
4. Focus on **disproving** hypotheses, not proving the favorite. The hypothesis with the fewest "I" marks survives.
5. Identify what evidence would shift the answer — that becomes your next hunt query.

ACH shines on questions like "is this lateral movement or a vuln scanner?" or "is this exfil or a misbehaving backup agent?" It is overkill for "is mimikatz.exe malicious."

### Key Assumptions Check (KAC)

Before you commit to a hunt hypothesis, write down every assumption you are making:

- About the adversary (they care about this asset, they avoid EDR, they pivot through RDP).
- About the environment (all hosts forward logs, the asset inventory is current, service accounts are tagged).
- About the data (timestamps are UTC, the SIEM is not dropping events at peak, retention covers the window).

Mark each assumption as **supported**, **unsupported**, or **unsupported but unlikely to be wrong**. The unsupported ones are your blind spots. This is the single highest-ROI technique for new hunters and is closely tied to [[cti-collection-management]] — most failed hunts trace back to a collection gap nobody surfaced.

### Devil's Advocacy

Assign one analyst — by name, in the meeting — to argue against the consensus. Not "play devil's advocate if you feel like it." Their job is to find the holes. Rotate the role so it is not always the same person being annoying. Useful when the team is rapidly converging on "yes, this is the threat actor we briefed last week."

### Red-cell analysis

Step into the adversary's shoes. Given their known TTPs (see [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-russian-svr-fsb]], [[ransomware-affiliate-playbook]]), what would they do next in your environment? What does your network look like to them? Red-cell is not red-team — no exploitation — it is a thought exercise that feeds hunt hypotheses and informs [[deception-and-honeypot-strategy]] placement.

### Indicators and signposts

Define ahead of time the observable events that would confirm or refute a hypothesis. Two flavors:

- **Confirming indicators**: if I see X, Y, Z together, my hypothesis is supported.
- **Disconfirming signposts**: if I see A or B, I should abandon this hypothesis.

Write them down *before* querying. This prevents the "well, that kind of looks like beaconing if I squint" problem. Indicators also feed back into [[siem-detection-use-case-catalog]] as detection candidates.

### Premortem

Borrowed from Gary Klein. Before the hunt starts, imagine it has failed completely — adversary present, hunt missed them. Why?

Typical answers:

- Collection gap (we don't log DNS from that subnet).
- Time window too narrow.
- Hypothesis too specific (we hunted for a single C2 family).
- The adversary used a living-off-the-land binary we treat as noise.
- Service account behavior masks the actor.

Each "reason it failed" becomes a mitigation in the hunt plan. Cheap, fast, and disliked by optimists.

### Quality of Information Check

Before weighting a piece of CTI heavily, ask: who collected it, how, when, with what motive? Vendor blog from a sales-driven team gets a different weight than a JPCERT incident report. This pairs with [[cti-collection-management]] and the admiralty grading scale (A1, B2, etc.).

## When SATs add value vs over-complicate

SATs are not free. Each one costs 30 minutes to several hours of analyst time. Use them when:

- Evidence is genuinely ambiguous and the answer matters (suspected nation-state, ransomware staging, insider).
- The team is converging too fast on a comforting answer.
- A hunt is going to drive a costly action (mass password reset, EDR isolation wave, customer notification).
- You are training junior analysts — running ACH on an old case is a great exercise.

Skip them when:

- The detection has a clean kill chain and reproducible IoCs.
- It is a known commodity malware family with a runbook (see [[soc-runbook-design]]).
- The hunt is exploratory data-mining with no specific hypothesis yet.
- Time pressure during active incident response — use ACH-lite (3 hypotheses, 10 minutes) instead.

The honest take: most SOCs that "do SATs" do them performatively in a quarterly slide deck. The teams that actually benefit treat KAC and premortem as standing agenda items in every hunt kickoff, and reserve full ACH for the hard cases.

## Integrating SATs into a hunt review

A practical cadence that survives contact with reality:

- **Hunt kickoff (15 min)**: Key Assumptions Check + Premortem. Written, not verbal.
- **Mid-hunt checkpoint (10 min)**: are signposts pointing where we expected? Any disconfirming evidence ignored?
- **Hunt close-out (30-60 min)**: if findings are ambiguous, run ACH. If findings are clear, skip to lessons learned.
- **Quarterly review**: pick one closed hunt, re-run it as ACH with a different analyst leading. Compare conclusions.

Document outputs in the hunt ticket alongside the queries — the assumptions list is more valuable than the query six months later when someone re-runs the hunt and the environment has drifted.

For mature programs, this feeds into [[purple-team-feedback-loop]] and [[detection-engineering-pyramid-of-pain]]: the disconfirming signposts that never fired become detection gaps, and the confirming indicators become detection candidates.

## Workflow to study

1. Read Heuer's *Psychology of Intelligence Analysis* (free PDF from CIA, ~180 pages). Skim chapters 1-4, study chapters 5-8 on ACH.
2. Read the CIA *Tradecraft Primer* (2009, also public). Pick the 6 techniques above and ignore the rest for now.
3. Take three closed incidents from the last year. Run ACH on each retrospectively. Compare your answer to the post-incident report.
4. Run a Key Assumptions Check on your next live hunt. Write it in the ticket.
5. In your next hunt review, assign a devil's advocate by name. Make notes on what they catch.
6. Run a premortem before a large hunt. Track which predicted failures actually appeared.
7. Build an indicators/signposts template in your hunt ticketing system so it is filled out every time.
8. After 90 days, review which techniques produced value and which were ceremony. Drop the ceremony.

Pair this with [[hypothesis-driven-hunting]] for the underlying hunt loop and [[threat-hunting-methodology]] for program-level structure. Karpathy's general advice on surfacing assumptions and defining verifiable success criteria applies here too.

## Realistic effort and who succeeds

- A junior hunter can learn KAC and premortem in a week and use them immediately.
- ACH takes 3-6 full runs to feel natural — most analysts give up after one frustrating session.
- Devil's advocacy fails in teams without psychological safety. If the senior analyst takes disagreement personally, do not bother.
- Vendor "threat hunting platforms" rarely encode SATs — this is an analyst-discipline problem, not a tooling problem.
- The analysts who succeed treat hunting as writing: drafts, revisions, peer review. The ones who treat it as querying-until-something-pops do not benefit from SATs and usually do not stay in the role.

Be honest with yourself: if your hunt program is still struggling with collection, telemetry coverage, and basic [[soc-runbook-design]], SATs are not your bottleneck. Fix the foundation first, then layer in tradecraft.

## References

- https://www.cia.gov/static/9a5f1162fd0932c29bfed1c030edf4ae/Pyschology-of-Intelligence-Analysis.pdf
- https://www.cia.gov/static/955180a45afe3f5013772c313b16face/Tradecraft-Primer-apr09.pdf
- https://www.dni.gov/files/documents/ICD/ICD%20203%20Analytic%20Standards.pdf
- https://www.sans.org/white-papers/36677/
- https://www.sciencedirect.com/topics/computer-science/analysis-of-competing-hypotheses
- https://www.rand.org/pubs/research_reports/RR1408.html

## Related

- [[hypothesis-driven-hunting]]
- [[threat-hunting-methodology]]
- [[cti-collection-management]]
- [[deception-and-honeypot-strategy]]
- [[detection-engineering-pyramid-of-pain]]
- [[purple-team-feedback-loop]]
- [[siem-detection-use-case-catalog]]
- [[soc-runbook-design]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[ransomware-affiliate-playbook]]
- [[ir-from-source-signals]]
- [[tabletop-exercise-design-and-execution]]
