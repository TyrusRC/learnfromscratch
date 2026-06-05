---
title: Hypothesis-driven threat hunting
slug: hypothesis-driven-hunting
aliases: [hypothesis-hunting, hunting-hypotheses]
---

> **TL;DR:** Hypothesis-driven hunting replaces "let's go look for bad" with a falsifiable claim ("If X adversary did Y here, we'd expect to see Z in data source D") that you can either confirm, refute, or admit was untestable. TaHiTI (Targeted Hunting integrating Threat Intelligence) and David Bianco's Pyramid of Pain / hunting maturity model are the dominant frames. Companion to [[threat-hunting-methodology]], [[structured-analytic-techniques-for-hunters]], [[detection-engineering-pyramid-of-pain]], and the adversary tradecraft notes: [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-dprk-lazarus]].

## Why it matters

Most "hunts" in industry are actually unstructured browsing of a SIEM — analysts pivot on whatever looks weird until time runs out, then write a vague "no findings" note. That has three problems:

- It is not reproducible. A different analyst on a different day finds different "weird things".
- It is not falsifiable. You cannot say "we looked and the adversary is not here" because you never defined what "here" or "the adversary" would look like.
- It does not feed [[detection-engineering-pyramid-of-pain]]. Negative results vanish, and detection gaps stay open.

Hypothesis-driven hunting forces you to write down the claim *before* you query, which means you can measure coverage, hand off to another analyst, and convert refuted hypotheses into either new detections or documented blind spots.

Compliance frameworks rarely require this explicitly, but mature SOCs in finance ([[financial-sector-defender-playbook]]) and critical infra ([[manufacturing-ot-defender-playbook]]) increasingly expect documented hunt journals as evidence of "proactive detection" controls.

## Sources of hypotheses

A hypothesis is only as good as where it comes from. The four canonical sources:

### From CTI

You read a report — CISA advisory, vendor blog, [[cti-collection-management]] feed — describing an adversary TTP. You translate it: "Mandiant says APT29 uses device-code phishing against M365 tenants ([[oauth-device-code-phishing-m365]]). Our exec team uses M365. If APT29 targeted us last quarter, we'd expect Azure AD sign-in logs showing device-code grants to non-managed devices from atypical ASNs."

This is the TaHiTI sweet spot — CTI-driven, intel-grounded, scoped.

### From an ATT&CK technique

You pick a technique (T1078.004 Cloud Accounts, T1098.001 Additional Cloud Credentials) and ask: "What would this look like in *our* telemetry? Do we even have the data?" This is great for detection-gap discovery but weak on prioritization — you'll burn weeks hunting techniques no relevant adversary uses against you.

### From environment knowledge

The hunter knows something the SIEM doesn't: "Engineering deploys via a single CI runner. If an attacker compromised it, we'd see git-push events from the runner to repos it has no business touching." See [[ci-cd-as-cloud-attack-surface]], [[github-actions-workflow-source-audit]]. These hypotheses are often the highest-yield because the attacker doesn't know your environment as well as you do.

### From a detection gap

Purple team ([[purple-team-feedback-loop]]) or [[atomic-red-team-emulation-deep]] surfaces that a technique was executed and nothing fired. The hypothesis becomes: "If the technique runs again in production, would we catch it? Hunt the last 90 days for residue."

## Structuring the hypothesis

A testable hunting hypothesis has four parts:

1. **Actor / threat** — who or what. ("A Lazarus operator", "any actor using Cobalt Strike", "a malicious insider".)
2. **Action / TTP** — what they did. ("Persisted via WMI event subscription", "exfiltrated via DNS tunneling".)
3. **Observable** — what evidence would exist. ("__EventConsumer instances in WMI repository", "DNS queries with high-entropy subdomains to rare parent domains".)
4. **Data source + scope** — where and over what window. ("Sysmon event ID 19/20/21 across 5,000 Windows endpoints, last 30 days".)

Template:

> "If [actor] performed [TTP] in [scope] during [window], we would expect to observe [observable] in [data source]. Absence of [observable] would refute the hypothesis with [coverage caveats]."

The coverage caveat is the part most hunters skip and it's the part that makes the negative result meaningful. "We didn't see it" is worthless if Sysmon was only deployed on 60% of endpoints.

## Workflow to study

### Step 1 — Pick and write

Pull one item from your [[cti-collection-management]] queue or backlog. Write the hypothesis in the template above. If you can't write it cleanly, the source isn't specific enough — go back and read more, or pick something else.

### Step 2 — Data-source check

Before any query: confirm the data exists at the scope and window you claimed. Check:

- Is the log source actually onboarded to the SIEM?
- What's the retention? (Hypothesis covers 30 days but logs only retained 14 — fix scope or fix retention.)
- Are there known parsing failures or coverage gaps? (Sysmon config might exclude the EID you need.)

If the data isn't there, the hunt outcome is "we couldn't test this" — that itself is a finding that goes to engineering, not a failure.

### Step 3 — Query construction

Build queries iteratively. Start broad to see baseline volume, then narrow with filters that *don't* assume the attacker's specific tradecraft. Bad: filter for "powershell.exe -enc". Good: filter for "any process with base64-decoded command line longer than N chars" — captures encoded payloads regardless of launcher.

For AD-heavy hunts, lean on [[bloodhound]] and [[adcs-attacks]] paths. For cloud, see [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]], [[cloud-ir-k8s-audit-logs]].

### Step 4 — Evaluate evidence

For each hit, ask: is this the predicted observable, a false positive, or unrelated weirdness? Don't chase unrelated weirdness in the same hunt — log it as a follow-up hypothesis and move on. Scope discipline matters.

Use [[structured-analytic-techniques-for-hunters]] (ACH, key assumptions check) when evidence is ambiguous.

### Step 5 — Decide outcome

Three buckets:

- **Supported** — observable found, consistent with the hypothesis. Escalate to IR per [[ir-from-source-signals]]. Do not keep hunting; hand off.
- **Refuted** — observable not found, coverage was adequate. Document the negative result with queries, time window, data sources, and coverage caveats. If the TTP is detectable, convert to a detection ([[edr-rules-as-code-from-attack-patterns]], [[siem-detection-use-case-catalog]]).
- **Inconclusive** — coverage was inadequate or evidence was ambiguous. Document what you'd need to make it conclusive (more retention, missing log source, additional context) and route to engineering or detection team.

### Step 6 — Journal

The hunt journal is the deliverable. Minimum fields per hunt:

- ID, date, hunter, reviewer
- Hypothesis (verbatim, template form)
- Data sources and coverage caveats
- Queries (full, copy-pasteable, with platform noted)
- Findings (counts, sample events, screenshots if needed)
- Outcome (supported / refuted / inconclusive)
- Actions (IR ticket, detection ID created, engineering ticket for gap)
- Lessons / follow-up hypotheses

A simple markdown file per hunt in a git repo beats any commercial "threat hunting platform" for most teams.

## Common pitfalls

- **Vague** — "Hunt for Lazarus." Not testable. Refine to a specific TTP and observable.
- **Untestable** — observable exists only in data you don't collect. Either fix collection or pick a different hypothesis.
- **Scope too broad** — "All endpoints, all time." Hunt will never finish, queries will time out, results will be unreviewable. Time-box and scope.
- **No exit criteria** — hunter keeps pivoting forever. Define up front: "If I see N or fewer events matching the observable after applying these filters, hypothesis is refuted."
- **Confirmation bias** — hunter wants the hypothesis to be true and over-interprets weak evidence. Apply [[structured-analytic-techniques-for-hunters]] explicitly.
- **Skipping the journal** — undocumented hunts are unreproducible and don't compound. The journal is the moat.
- **Re-hunting the same thing** — without a journal, teams re-run the same hunts every quarter. Tag and search before starting.

## Examples by adversary

- **Russian SVR / APT29** ([[apt-tradecraft-russian-svr-fsb]]) — cloud identity persistence: hunt for service principal credential additions ([[cloud-iam-misconfig-patterns]]) outside change windows; OAuth consent grants to unknown apps; device-code grants from atypical geographies. See [[case-study-solarwinds-2020]].
- **Chinese MSS clusters** ([[apt-tradecraft-chinese-mss]]) — edge device exploitation, web shells on perimeter appliances. Hunt for outbound connections from edge devices to non-mgmt destinations; new files in appliance web roots; unexpected SSL/SSH tunnels.
- **DPRK / Lazarus** ([[apt-tradecraft-dprk-lazarus]]) — supply-chain implants ([[case-study-3cx-supply-chain]]), recruiter-themed social engineering ([[deepfake-assisted-phishing]]). Hunt for signed-but-anomalous binaries calling out from developer workstations; LinkedIn-themed phishing landing on engineering identities.
- **Iranian IRGC** ([[apt-tradecraft-iranian-irgc]]) — password spray then VPN/RDP. Hunt for sign-in failure bursts followed by single success from same IP across multiple users.
- **Ransomware affiliates** ([[ransomware-affiliate-playbook]]) — discovery sweeps, [[bloodhound]]-like LDAP queries, mass SMB enumeration before encryption. Hunt for single endpoints generating SMB SYN to >N hosts in a window.

## Realistic effort and who succeeds

- A real hypothesis-driven hunt takes a senior analyst 1–3 days end-to-end (read CTI, write hypothesis, validate data, query, evaluate, journal, create detection). Vendors selling "hunts in 30 minutes" are selling dashboards, not hunts.
- Programs that succeed have: (1) dedicated hunt time (not "between tickets"), (2) a journal nobody can skip, (3) tight coupling to detection engineering ([[siem-detection-use-case-catalog]], [[purple-team-feedback-loop]]), and (4) leadership that values documented negative results as much as findings.
- Programs that fail try to measure hunts by "number of incidents discovered" — which incentivizes finding things even when nothing's there, and disincentivizes hunting well-defended areas.
- Vendor marketing reality: most "AI-driven autonomous hunting" products are UEBA repackaged ([[ueba-detection-ml-primer]], [[ml-for-detection-tradeoffs]]). Useful as a tip generator, not a replacement for hypothesis discipline.

## References

- https://www.betaalvereniging.nl/wp-content/uploads/TaHiTI-Threat-Hunting-Methodology.pdf
- https://detect-respond.blogspot.com/2015/10/a-simple-hunting-maturity-model.html
- https://www.sans.org/white-papers/generating-hypotheses-for-successful-threat-hunting/
- https://attack.mitre.org/resources/adversary-emulation-plans/
- https://www.threathunting.net/
- https://www.cisa.gov/news-events/cybersecurity-advisories

## Related

- [[threat-hunting-methodology]]
- [[structured-analytic-techniques-for-hunters]]
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[atomic-red-team-emulation-deep]]
- [[purple-team-feedback-loop]]
- [[siem-detection-use-case-catalog]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[ueba-detection-ml-primer]]
- [[ir-from-source-signals]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-dprk-lazarus]]
- [[apt-tradecraft-iranian-irgc]]
- [[ransomware-affiliate-playbook]]
- [[case-study-solarwinds-2020]]
- [[case-study-3cx-supply-chain]]
- [[bloodhound]]
- [[cloud-ir-aws-cloudtrail]]
- [[cloud-ir-azure-activity-log]]
- [[cloud-ir-gcp-audit-logs]]
