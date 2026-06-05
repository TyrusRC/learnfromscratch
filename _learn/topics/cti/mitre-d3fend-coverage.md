---
title: MITRE D3FEND coverage mapping
slug: mitre-d3fend-coverage
aliases: [d3fend, defensive-mitre-mapping]
---

> **TL;DR:** MITRE D3FEND is the defensive counterpart to ATT&CK — an ontology that maps defensive techniques to digital artifacts (files, processes, network sessions, credentials) and ties them back to specific offensive techniques. Use D3FEND when you want to answer "given that adversaries do X, what defensive countermeasures actually counter it?" rather than re-inventing the question. It pairs naturally with [[detection-engineering-pyramid-of-pain]] for detection selection, [[atomic-red-team-emulation-deep]] for validation, and [[cti-collection-management]] for tying it to threat intel. Realistic warning: D3FEND is much younger and less mature than ATT&CK; treat it as a vocabulary and gap-analysis tool, not a complete maturity model on its own. Compare with [[cmmi-bsimm-samm-comparison]] for structured maturity assessment.

## Why it matters

ATT&CK gave defenders a shared vocabulary for adversary behavior, but for years there was no equivalent on the defensive side. People described controls in vendor jargon ("our EDR has behavioral AI") instead of in terms of the artifact being defended or the technique being countered. D3FEND fills that gap by:

- Defining defensive techniques (e.g. "Process Lineage Analysis", "Executable Allowlisting", "Inbound Traffic Filtering") with formal definitions.
- Modeling **digital artifacts** — the things being defended (Process, File, User Account, Network Session, etc.) — as a knowledge graph.
- Mapping defensive techniques to the **offensive** ATT&CK techniques they counter, with explicit relationships ("evicts", "isolates", "detects", "hardens", "deceives").

For defenders this means you can finally do honest coverage analysis: "ATT&CK T1059.001 PowerShell — which D3FEND countermeasures apply, and do we actually implement any of them?" That conversation is far more useful than the vendor-bingo version.

It also matters for leadership communication. Boards understand "we cover N% of ATT&CK techniques" badly, but they understand "for each top adversary TTP, here are the defensive layers we have and where we are blind" much better. D3FEND gives you the structure to tell that story.

## D3FEND knowledge graph structure

D3FEND is not a flat list — it is an ontology (DAO/OWL) with a few core abstractions worth understanding before you try to use it.

### Defensive tactics (top of the hierarchy)

Mirrors ATT&CK's tactic concept but for defense:

- **Model** — understand the environment (asset inventory, network mapping, identifier mapping).
- **Harden** — reduce attack surface (application hardening, credential hardening, platform hardening, message hardening).
- **Detect** — identify malicious activity (file analysis, identifier analysis, message analysis, network traffic analysis, platform monitoring, process analysis, user behavior analysis).
- **Isolate** — limit blast radius (execution isolation, network isolation).
- **Deceive** — mislead the adversary (decoy environments, decoy objects).
- **Evict** — remove the adversary (credential eviction, process eviction).
- **Restore** — recover state (covers backup restoration, recently expanded).

### Defensive techniques

Under each tactic, specific techniques like:
- `D3-PLA` Process Lineage Analysis
- `D3-EAL` Executable Allowlisting
- `D3-ITF` Inbound Traffic Filtering
- `D3-DA` Decoy Account
- `D3-MFA` Multi-factor Authentication

Each has a stable ID, a definition, and links into the knowledge graph.

### Digital artifacts

The "thing being defended/observed" — Process, File, Network Session, User Account, Certificate, Email, etc. These connect defensive techniques to ATT&CK techniques: an ATT&CK technique produces or modifies an artifact, and a D3FEND technique observes, hardens, or removes that same artifact.

### Relationships

The verbs are the interesting part:
- **detects**
- **hardens**
- **isolates**
- **deceives** (or "decoys")
- **evicts**
- **restores**
- **may-be-associated-with** (weaker linkage)

This is what lets you traverse the graph: "Show me all D3FEND techniques where the technique *isolates* or *detects* the artifact produced by ATT&CK T1055 (Process Injection)."

## How to use D3FEND for coverage analysis

The honest workflow looks like this:

1. **Pick your offensive scope.** Don't try to cover all of ATT&CK. Start with a small TTP set driven by [[cti-collection-management]] — the adversaries actually relevant to your environment (use [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]], etc., or [[ransomware-affiliate-playbook]] depending on threat model).
2. **For each ATT&CK technique, query D3FEND.** The D3FEND site lets you put in an ATT&CK ID and get the set of defensive techniques mapped to it. Mappings Explorer (CTID project, below) also bridges this.
3. **Score current coverage per defensive technique.** Not "do we own a tool that claims to do this" — "do we actually implement it, with what scope, monitored by whom, validated when?" Anything less honest will mislead you.
4. **Identify gaps.** Techniques where D3FEND lists multiple countermeasures but you implement zero are higher priority than those with one weak countermeasure already in place.
5. **Feed gaps into roadmap.** Use [[detection-engineering-pyramid-of-pain]] to choose detection-side fills, [[purple-team-feedback-loop]] to validate, [[atomic-red-team-emulation-deep]] to test specific techniques.

A spreadsheet view (offensive technique × defensive technique × status) is fine and what most teams end up with. The fancier graph queries are nice but not strictly required for a small program.

## Center for Threat-Informed Defense companion projects

D3FEND itself is MITRE proper. CTID is a separately-funded research center with many sponsors (banks, clouds, vendors) that builds adjacent tooling. The pieces worth knowing:

### Attack Flow

A schema and visualization for representing **sequences** of ATT&CK techniques as adversary playbooks (not just a flat list). Useful when communicating with leadership ("this adversary chains T1566 → T1059.001 → T1547.001 → T1021.002") and when designing scenarios for [[tabletop-exercise-design-and-execution]] or [[purple-team-feedback-loop]].

### ATT&CK Workbench

A self-hosted instance of the ATT&CK knowledge base that you can extend with your own techniques, sub-techniques, and notes. Useful when you need to track org-specific TTPs not in the public ATT&CK without losing the schema.

### Mappings Explorer

Probably the most operationally useful CTID project. It cross-walks ATT&CK to:
- NIST 800-53 controls
- Azure / AWS / GCP native security controls
- VERIS, CVE, CIS Controls
- And to D3FEND

For compliance-driven orgs, this is the bridge that lets you say "this ATT&CK coverage gap maps to NIST control X which auditors care about" — useful when wired into [[soc2-vs-iso27001]] or [[pci-dss-4-implementation]] discussions.

### Other CTID projects

Attack Flow Builder, Adversary Emulation Library (FIN6, APT29, menuPass, etc.), Insider Threat TTP knowledge base, Sensor Mappings to ATT&CK. All worth a skim, but Mappings Explorer and Attack Flow are the two most teams use day-to-day.

## Integration with detection engineering

D3FEND is a planning and selection tool, not a detection authoring tool. The integration pattern that works:

1. **Pick adversary technique** (from ATT&CK, scoped by [[cti-collection-management]]).
2. **Pick defensive technique** (from D3FEND, e.g. D3-PLA Process Lineage Analysis).
3. **Author detection** using your engineering process from [[detection-engineering-pyramid-of-pain]] and catalog in [[siem-detection-use-case-catalog]].
4. **Tag the detection** with both the ATT&CK ID and the D3FEND ID.
5. **Validate** with [[atomic-red-team-emulation-deep]] or [[purple-team-feedback-loop]].
6. **Track coverage** by reporting on the matrix, not individual rule counts.

For prevention controls, similar pattern but using [[edr-rules-as-code-from-attack-patterns]] or hardening playbooks.

## Realistic limitations

Be honest about what D3FEND is and is not:

- **Less mature than ATT&CK.** Coverage of defensive techniques is uneven; some areas (Harden, Detect) are well-developed, others thinner. Mapping density to ATT&CK varies.
- **Not a checklist.** A defensive technique listed in D3FEND does not mean "you should implement all of these." Many are mutually exclusive design choices (allowlisting vs behavioral detection) or context-dependent.
- **Not a maturity model.** Implementing a technique and implementing it well are very different. D3FEND tells you the *what*, not the *how well*. Pair with maturity frameworks from [[cmmi-bsimm-samm-comparison]] or [[appsec-maturity-checklist]].
- **Vendor mapping is patchy.** Vendors love claiming D3FEND coverage. Verify against actual capability, not marketing.
- **Knowledge graph is academic.** The OWL/RDF formalism is great for researchers, harder for operators. Most teams use the web UI and CSV exports.
- **Mappings can be optimistic.** "may-be-associated-with" is a weak link; "detects" / "hardens" are stronger but still need interpretation.

The right framing: D3FEND is a shared vocabulary and gap-analysis tool, not a finished defense plan.

## Communicating D3FEND coverage to leadership

What works:

- **Don't show the knowledge graph.** Executives glaze over.
- **Pick a threat narrative** (e.g. "ransomware affiliates targeting our sector" — see [[ransomware-affiliate-playbook]], [[case-study-moveit-2023]]).
- **Show top 10–15 ATT&CK techniques used by that threat** (Attack Flow visualization helps).
- **For each, show D3FEND countermeasures and our status** (green/yellow/red with brief evidence).
- **Tie gaps to investment asks** — concrete projects, not "more SOC headcount."
- **Show the trend** — last quarter vs this quarter coverage delta.

What does not work: percentage-of-D3FEND-techniques-covered. The denominator is arbitrary and the metric is gameable.

## Integration with maturity-model assessment

D3FEND coverage is one input to broader maturity assessment, alongside:

- **CMMI-style capability maturity** ([[cmmi-bsimm-samm-comparison]]) — process maturity around each control.
- **NIST CSF function coverage** (Identify / Protect / Detect / Respond / Recover).
- **Control framework compliance** (ISO 27001 controls, NIST 800-53, PCI DSS requirements via [[pci-dss-4-implementation]]).
- **Operational metrics** ([[soc-ticket-hygiene-mttr]], detection efficacy, alert quality).

A useful synthesis: "for our top adversary set, we cover N D3FEND techniques at L≥3 maturity, our NIST CSF Detect function is at Tier 3, our operational MTTR is 4 hours." That triangulation is far more honest than any single number.

## Workflow to study

If you are getting started:

1. **Read the D3FEND ontology overview.** Understand tactics, techniques, artifacts, and relationships. Skim the OWL reference but don't drown in it.
2. **Pick five ATT&CK techniques from your relevant threat model** and look them up in D3FEND. See what countermeasures map.
3. **Try Mappings Explorer** for one of those techniques to see the cloud-control and 800-53 cross-walks.
4. **Build a small coverage spreadsheet** for that small TTP set. Be brutally honest about current state.
5. **Wire one gap into your detection engineering backlog** using [[siem-detection-use-case-catalog]] and validate with [[atomic-red-team-emulation-deep]].
6. **Read Attack Flow examples** for a couple of well-known adversaries (APT29, FIN6) to see how technique sequences are modeled.
7. **Repeat at larger scope.** Expand to your full priority threat list. Reassess quarterly, not annually.

Realistic effort: a single analyst can produce a defensible D3FEND coverage view for a focused threat set in 2–4 weeks. Org-wide rollout with detection engineering integration is a multi-quarter program. Vendors selling "D3FEND coverage in a box" are mostly selling repackaged ATT&CK navigators.

## Related

- [[detection-engineering-pyramid-of-pain]]
- [[atomic-red-team-emulation-deep]]
- [[cti-collection-management]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[ransomware-affiliate-playbook]]
- [[purple-team-feedback-loop]]
- [[siem-detection-use-case-catalog]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[cmmi-bsimm-samm-comparison]]
- [[appsec-maturity-checklist]]
- [[tabletop-exercise-design-and-execution]]
- [[soc-ticket-hygiene-mttr]]
- [[case-study-moveit-2023]]

## References

- D3FEND knowledge base — https://d3fend.mitre.org/
- D3FEND ontology and OWL reference — https://d3fend.mitre.org/ontologies/
- Center for Threat-Informed Defense — https://ctid.mitre.org/
- Attack Flow project — https://ctid.mitre.org/projects/attack-flow/
- Mappings Explorer — https://center-for-threat-informed-defense.github.io/mappings-explorer/
- MITRE ATT&CK — https://attack.mitre.org/
