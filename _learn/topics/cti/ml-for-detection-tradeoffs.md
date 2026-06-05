---
title: ML for security detection — tradeoffs
slug: ml-for-detection-tradeoffs
aliases: [ml-detection-tradeoffs, ml-security-detection]
---

> **TL;DR:** Machine learning can find detections that rules cannot express, but it imports its own failure modes: scarce labels, drift, adversarial inputs, opaque decisions, and vendor "AI-washing". Treat ML as a layer that augments, not replaces, deterministic detections — anchor it to MITRE ATT&CK like [[detection-engineering-pyramid-of-pain]], pair it with behaviour baselines as in [[ueba-detection-ml-primer]] and [[time-series-anomaly-for-security]], and harden the pipeline itself against attacks like those in [[llm-eval-pipeline-poisoning]].

## Why it matters

Security teams are drowning in telemetry. Rule-based detections work when an attacker leaves a known artefact (a hash, a command line, a URL), but they struggle with subtle, behavioural, or polymorphic activity — exactly where modern adversaries operate. ML promises to learn patterns that no analyst could write down, especially for user-and-entity behaviour, beacon detection, lateral movement, and DGA-style domains.

The reality is messier. A poorly designed model floods analysts with false positives, degrades silently as the environment changes, and creates a new attack surface that adversaries actively target. A 1% false-positive rate on a billion-event-per-day SIEM means 10 million alerts. Analysts need to know *why* a model fired, not just that it fired. And vendor pitch decks have outpaced engineering rigour: "AI-powered" often means a logistic regression behind a marketing budget.

Understanding the tradeoffs lets you decide where ML pays off, where rules are still king, and how to measure both honestly. It also helps when reviewing third-party tooling — see [[case-study-snowflake-2024]] for a reminder that the weakest control is rarely the smartest one.

## Classes and patterns

### Supervised vs unsupervised

Supervised models learn from labelled examples — "this is malware, this is not". They tend to be precise on patterns similar to training data but generalise poorly to new techniques. They also depend on label quality, which is rarely as clean as researchers assume.

Unsupervised and semi-supervised models learn what "normal" looks like and flag deviations. They scale to scenarios where labels are scarce (most of security) but produce more false positives and require careful baseline maintenance. See [[time-series-anomaly-for-security]] for the canonical use case.

In practice, mature programs combine both: unsupervised models surface candidates, supervised models or rules triage them, and human-labelled outcomes feed back into the training set.

### Common detection tasks

- Beacon and C2 detection from netflow or proxy logs.
- User-and-entity behaviour analytics for impossible travel, off-hours access, privilege misuse — see [[ueba-detection-ml-primer]].
- DGA and phishing-domain classification from DNS and certificate logs.
- Malware family classification from static features.
- Insider-threat and data-exfiltration scoring.
- Phishing email triage, including AiTM kits like [[tycoon2fa-and-modern-phish-kits]].

### Failure modes specific to security ML

- **Class imbalance.** Malicious events are a vanishing minority. Precision/recall and PR-AUC matter; raw accuracy is meaningless.
- **Concept drift.** Attacker tradecraft, business behaviour, and infrastructure all change. A model trained six months ago may be silently degraded.
- **Adversarial inputs.** Attackers can probe the model, mutate payloads, and find blind spots — a problem rules also have, but ML decisions are often easier to game once the feature set is known.
- **Training-data poisoning.** If attackers can seed the telemetry that becomes training data (logs, sandbox detonations, threat-intel feeds), they can teach the model to ignore them. Related: [[llm-eval-pipeline-poisoning]].
- **Label leakage.** Features that encode the label (e.g. "alert-source = AV") inflate offline metrics and fail in production.

## Defensive baseline

A pragmatic ML-for-detection programme rests on a few non-negotiables.

### Anchor to the pyramid of pain

Use ML for behavioural detections high on the [[detection-engineering-pyramid-of-pain]], not for indicators that a SIEM rule could express in five lines. Hash matching does not need a neural net.

### Keep rules as a safety net

Deterministic detections give you auditability, low false-positive cost, and a clear story for IR. ML augments them by surfacing things rules cannot describe. The [[siem-detection-use-case-catalog]] should mark which use cases are rule-based, ML-based, or hybrid.

### Engineer for explainability

Analysts triaging an alert need a "why". Tree-based models, attention maps, SHAP values, or rule extraction from learned models all help. Black-box scores with no context are operationally useless and politically toxic when something is missed.

### Treat the pipeline as production software

Training data, feature pipelines, models, and inference endpoints need version control, integrity checks, signing, and access control. An attacker who can write to your feature store has owned your detection. Apply CI/CD discipline, not notebook discipline — see [[edr-rules-as-code-from-attack-patterns]] for the rules-as-code analogue.

### Measure adversarially

Standard cross-validation overestimates real-world performance. Evaluate against red-team campaigns, time-split data (train on month N, test on month N+1), and known evasions. Combine with [[atomic-red-team-emulation-deep]] runs to make sure detections survive the techniques you care about.

### Guard against poisoning

Validate and rate-limit log sources that feed training data. Quarantine new telemetry until provenance is established. Periodically retrain from clean baselines and diff models. Watch for sudden drops in alert volume — they may be a model learning to ignore an attacker, not the attacker going away.

### Resist AI-washing

When evaluating vendors, ask for: training data lineage, retraining cadence, drift monitoring, false-positive rates on your data (not theirs), explainability artefacts, adversarial evaluation results, and what happens when the model is wrong. Vague answers are a red flag. Cross-reference with [[cti-collection-management]] to see if their feeds are actually unique.

## Workflow to study

1. Read Sculley et al. *Hidden Technical Debt in Machine Learning Systems* — the canonical paper on why ML in production is mostly plumbing.
2. Work through a UEBA-style problem end to end: collect logs, label a small set, train a baseline, evaluate. Use [[building-a-research-home-lab]] data if you do not have production telemetry.
3. Reproduce a paper on adversarial evasion of malware classifiers (e.g. MalConv attacks). Notice how small perturbations flip predictions.
4. Build a drift monitor — population stability index, KL divergence on feature distributions, or simple alert-volume tracking — and alert when it trips.
5. Run a tabletop with the SOC: an analyst gets a model score and must decide. What additional context do they need? Wire that context into the alert.
6. Review three vendor "AI" detection products. Map their claims to the tradeoffs above. Note where marketing diverges from engineering.
7. Tie detections back to [[purple-team-feedback-loop]] so labelled outcomes from IR flow into retraining.
8. Study one real poisoning or evasion incident (e.g. tampering with sandbox verdicts) and write a runbook for your own pipeline.

## Related

- [[ueba-detection-ml-primer]]
- [[time-series-anomaly-for-security]]
- [[llm-eval-pipeline-poisoning]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[atomic-red-team-emulation-deep]]
- [[purple-team-feedback-loop]]
- [[cti-collection-management]]
- [[ai-agent-sandbox-design]]

## References

- [Hidden Technical Debt in Machine Learning Systems (Sculley et al., NeurIPS 2015)](https://papers.nips.cc/paper_files/paper/2015/hash/86df7dcfd896fcaf2674f757a2463eba-Abstract.html)
- [MITRE ATLAS — adversarial threat landscape for AI systems](https://atlas.mitre.org/)
- [NIST AI 100-2 E2023: Adversarial Machine Learning taxonomy](https://csrc.nist.gov/pubs/ai/100/2/e2023/final)
- [Google SRE Book — chapter on monitoring distributed systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Microsoft — Threat Modeling AI/ML Systems and Dependencies](https://learn.microsoft.com/en-us/security/engineering/threat-modeling-aiml)
- [Endgame / Elastic — EMBER malware classification dataset and baselines](https://github.com/elastic/ember)
