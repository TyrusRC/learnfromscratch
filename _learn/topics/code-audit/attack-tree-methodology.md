---
title: Attack tree methodology
slug: attack-tree-methodology
aliases: [attack-trees, bruce-schneier-attack-trees]
---

> **TL;DR:** Attack trees, introduced by Bruce Schneier in 1999, decompose a single high-value adversary goal (rob the safe, exfiltrate the signing key, take over the domain) into AND/OR sub-goals you can quantify and prune. They are goal-oriented and complementary to element-oriented frameworks like STRIDE — see [[appsec-threat-modeling]] and the companion notes [[red-team-vs-pentest-engagement-shape]] and [[detection-engineering-pyramid-of-pain]] for how trees feed scenario design and detection coverage.

## Why it matters

STRIDE, LINDDUN, and most data-flow-diagram-first methods are great for finding broad classes of weakness across a system. They are weaker when leadership asks a focused question: *"How would someone actually steal the customer database?"* or *"What does it take to forge a release artifact?"* Those are single-goal questions. Attack trees were designed for exactly that shape of problem.

A practitioner who can produce a credible attack tree in a workshop gets three things at once:

- A shared mental model of the adversary's options that non-engineers can read.
- A pruning function — you can mark branches as too expensive, too detectable, or already mitigated, and focus the remaining defensive budget.
- A bridge into red-team scenario design and MITRE ATT&CK technique selection, because each leaf in a pruned tree maps to a concrete TTP.

The technique is cheap (whiteboard plus sticky notes works), but the discipline to do it well is rare. Most teams either stop at depth two or skip the attribute scoring entirely, leaving a pretty diagram with no decision value.

## Building an attack tree

### Pick a single root goal

The root is a concrete adversary win-state, not a category. "Compromise the company" is useless. "Sign a malicious update with the production code-signing key" or "exfiltrate the production customer PII database to attacker-controlled storage" are usable roots. One tree, one goal. If you need to cover multiple goals, build multiple trees and let them share sub-branches.

The crown-jewel inventory work behind notes like [[financial-sector-defender-playbook]] and [[healthcare-sector-defender-playbook]] is the natural input here — those crown jewels become tree roots.

### Decompose with AND / OR nodes

Each node is a sub-goal. Children of an OR node represent alternatives — any one is sufficient. Children of an AND node must all be achieved together. AND nodes are where the interesting defensive leverage lives, because breaking one conjunct breaks the branch.

A typical pattern:

- Root: *forge a signed release artifact*.
- OR: steal the signing key OR cause the build pipeline to sign attacker-controlled code OR coerce a privileged signer.
- "Cause the build pipeline to sign attacker-controlled code" AND: get code into a release branch AND get the pipeline to consume that branch AND defeat any release-time review.

Each of those AND conjuncts then decomposes further. Stop decomposing when a leaf maps to a concrete, attacker-observable action — something you could write a detection or a control statement against. That depth is usually three to six levels for an enterprise goal.

### Assign attribute values to leaves

The diagram is only half the method. Each leaf gets attribute values; the values propagate up the tree according to AND/OR semantics. Common attribute sets:

- **Cost** in dollars or attacker time. Propagates as sum across AND, minimum across OR.
- **Skill required** (script kiddie, competent, expert, nation-state). Propagates as maximum across AND, minimum across OR.
- **Detection probability** (0.0 to 1.0). Across AND, *being detected on any conjunct counts*, so propagate as `1 - product(1 - p_i)`; across OR the attacker picks the lowest-detection branch.
- **Legal risk** (negligible / civil / criminal / state-level retaliation).
- **Required access** (none, employee, contractor, insider with privilege).

You do not need precision. Order-of-magnitude estimates already separate plausible from implausible branches. Document the assumptions next to each leaf so reviewers can challenge them.

### Pruning

Walk the tree from leaves to root and mark:

- **Out of scope** — branches the adversary you are modelling will not take (a financially-motivated criminal will not spend a year on supply-chain implant work for a $20k target).
- **Already mitigated** — branches where the existing control is genuinely strong, with evidence. Pair this with the audit-evidence discipline from [[audit-evidence-sampling-and-scoring]] so "mitigated" means more than a policy document.
- **Cheap to harden** — branches you should fix now.
- **Expensive but necessary** — branches that drive multi-quarter roadmap items.

Pruning is the deliverable. An unpruned tree is just a diagram; a pruned tree is a prioritised work list.

## Tooling

- **ADTool** (open-source, University of Luxembourg) — proper AND/OR semantics, attribute propagation, exports to LaTeX. Best free option for serious work.
- **AttackTree+** (Isograph, commercial) — heavyweight, used in safety-critical industries (aerospace, defence). Strong attribute math, weak UX. Worth it only if you must produce auditor-grade documentation.
- **SecurITree** (Amenaza, commercial) — similar niche, Canadian vendor, common in critical-infrastructure work.
- **drawio / Excalidraw / Miro** — manual, no semantics, but fine for workshops and for trees with fewer than ~30 nodes. Most practitioners live here.
- **Markdown + indented bullets** — surprisingly effective for version-controlled trees that live next to architecture docs. Loses visual impact, gains diff-ability.

Vendor reality check: the commercial tools are sold on "rigorous quantitative risk analysis." In practice the numbers you feed in are estimates, so the outputs are estimates. Do not let a polished AttackTree+ report substitute for the workshop discussion that produced the estimates.

## Attack trees vs STRIDE

| Dimension | Attack trees | STRIDE |
|---|---|---|
| Orientation | Goal-oriented (one adversary win) | Element-oriented (each DFD element) |
| Output | Prioritised list of attack paths | Catalogue of weaknesses per element |
| Best for | Crown jewels, single high-value asset | Whole-system coverage, new designs |
| Quantification | Native (attribute propagation) | Bolt-on (DREAD, CVSS, etc.) |
| Workshop time | 2-4 hours per goal | 1-2 hours per component |
| Skill ceiling | High — depends on adversary realism | Medium — checklist-driven |

They are not competitors. A mature program runs STRIDE-style modelling during design (see [[appsec-threat-modeling]] and the deep companion on STRIDE referenced as `threat-modelling-stride-deep`) and attack trees against named crown jewels at least annually. PASTA (`threat-modelling-pasta`) sits between them, with attack-tree-shaped analysis as one of its later stages.

## Use cases where attack trees shine

- **Code-signing and release integrity** — a single goal ("ship a malicious signed artifact") with many viable paths. Pairs naturally with [[github-actions-workflow-source-audit]] and [[ghost-commit-smuggling]].
- **Customer-data exfiltration** — fits the breach narrative regulators care about. Cross-reference [[case-study-snowflake-2024]] and [[case-study-equifax-2017]] for realistic leaves.
- **Domain takeover in Active Directory** — pairs with [[bloodhound]] and [[adcs-attacks]] to populate the leaves with concrete techniques.
- **SaaS-to-SaaS lateral movement** — model "attacker obtains persistent access to production Salesforce / M365" using OAuth-abuse leaves; see [[oauth-device-code-phishing-m365]] and [[conditional-access-bypass-modern]].
- **Ransomware double-extortion goals** — model "encrypt and exfil the file estate" using [[ransomware-affiliate-playbook]] for the affiliate-shaped branches.
- **Build-pipeline takeover** — see [[ci-cd-as-cloud-attack-surface]] and [[npm-postinstall-and-typosquat-audit]] for leaf material.

## Common practitioner mistakes

- **Too shallow.** Stopping at depth two gives you a fancy bullet list, not a tree. Push until leaves are TTP-level.
- **Too generic.** Leaves like "phishing" are useless. "AiTM phishing of a privileged signer using a Tycoon2FA-style kit, bypassing FIDO2 because the account still has a fallback TOTP" is a leaf you can defend against. See [[aitm-evilginx-modern-phishing]] and [[tycoon2fa-and-modern-phish-kits]].
- **No quantitative attributes.** Without cost / skill / detection numbers you cannot prune, and without pruning the tree is not actionable.
- **Wrong adversary.** A tree modelled against a nation-state for a goal a criminal would target produces overspending; the reverse produces underinvestment. Pick the adversary explicitly, using the tradecraft notes ([[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-dprk-lazarus]], [[apt-tradecraft-iranian-irgc]]) for realism.
- **One person in a room.** Attack trees need a workshop with the system owners, an offensive practitioner, and a detection engineer. A solo tree reflects one person's blind spots.
- **Build it once, never revisit.** Trees decay as the environment changes. Re-run annually, or after any architectural shift.

## Integration with red-team scenario design and ATT&CK

A pruned attack tree is the natural input to red-team scoping (see [[red-team-vs-pentest-engagement-shape]] and [[pentest-proposal-and-scoping]]):

- Each surviving leaf becomes a candidate scenario objective.
- Branches the blue team claims are mitigated become explicit test hypotheses.
- Attribute values translate into engagement constraints — high-detection branches drive purple-team exercises ([[purple-team-feedback-loop]]) rather than stealth red-team ops.

On the detection side, each leaf maps to ATT&CK techniques, and those techniques feed [[siem-detection-use-case-catalog]], [[edr-rules-as-code-from-attack-patterns]], and emulation work via [[atomic-red-team-emulation-deep]]. Trees give detection engineers a *reason* a use case exists, which is what survives a SOC-leadership review of detection backlog.

## Defensive baseline

Even before any tree is built, every program should:

- Maintain a crown-jewel inventory so root goals are obvious.
- Name the adversary tier you defend against, and revisit annually.
- Have a workshop cadence — at minimum, one attack tree per crown jewel per year.
- Store trees in version control next to architecture docs, not in a slide deck.
- Tie surviving leaves to detection use cases and to red-team objectives, so the tree drives work rather than decorating a binder.

## Workflow to study

1. Read Schneier's original 1999 *Dr. Dobb's* article — it is short and clarifies the AND/OR semantics better than most modern rewrites.
2. Pick a crown jewel you already understand (your code-signing key, your customer database).
3. Build a tree on paper, depth four, before touching a tool. Time-box to 90 minutes.
4. Add cost, skill, and detection-probability attributes to every leaf. Be explicit about assumptions.
5. Hand the tree to one offensive and one defensive colleague and ask each to add one branch you missed and challenge one attribute.
6. Prune. Mark each surviving leaf with the ATT&CK technique IDs and the detection use cases that cover it.
7. Redraw cleanly in ADTool or drawio for sharing.
8. Six months later, redo it from scratch without looking at the old one. Compare. The deltas tell you where your mental model of the system has shifted.

## Related

- [[appsec-threat-modeling]]
- [[red-team-vs-pentest-engagement-shape]]
- [[detection-engineering-pyramid-of-pain]]
- [[atomic-red-team-emulation-deep]]
- [[purple-team-feedback-loop]]
- [[siem-detection-use-case-catalog]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[bloodhound]]
- [[adcs-attacks]]
- [[ci-cd-as-cloud-attack-surface]]
- [[github-actions-workflow-source-audit]]
- [[aitm-evilginx-modern-phishing]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[ransomware-affiliate-playbook]]
- [[case-study-snowflake-2024]]
- [[case-study-equifax-2017]]
- [[apt-tradecraft-russian-svr-fsb]]

## References

- Bruce Schneier, "Attack Trees," Dr. Dobb's Journal, December 1999: https://www.schneier.com/academic/archives/1999/12/attack_trees.html
- Schneier on Security blog tag for attack trees: https://www.schneier.com/tag/attack-trees/
- ADTool, University of Luxembourg SaToSS group: https://satoss.uni.lu/members/piotr/adtool/
- Kordy, Mauw, Radomirovic, Schweitzer, "Attack-Defense Trees" (Journal of Logic and Computation, 2014): https://satoss.uni.lu/members/piotr/papers/jlc2012.pdf
- OWASP Threat Modeling Process — attack trees section: https://owasp.org/www-community/Threat_Modeling_Process
- MITRE ATT&CK, technique catalogue used to populate leaves: https://attack.mitre.org/
