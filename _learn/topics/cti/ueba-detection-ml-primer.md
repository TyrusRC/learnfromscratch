---
title: UEBA — User and Entity Behavior Analytics primer
slug: ueba-detection-ml-primer
aliases: [ueba-primer, behavioral-analytics-primer]
---

> **TL;DR:** UEBA (User and Entity Behavior Analytics) baselines what is "normal"
> for each user, host, and service, then flags deviations that signature- and
> rule-based SIEM detections miss — insider abuse, account takeover, slow
> lateral movement, and abnormal data egress. It is a complement to, not a
> replacement for, the rule layer described in [[siem-detection-use-case-catalog]]
> and the threat-hunt feedback loop in [[detection-engineering-pyramid-of-pain]].
> If you are also building a time-series anomaly stack, pair this with
> [[time-series-anomaly-for-security]].

## Why it matters

Signature SIEM detections answer "did we see this known-bad thing?" They are
cheap, explainable, and brittle. UEBA answers a different question: "is this
account, host, or service doing something it has never done before — in a way
that resembles attack tradecraft?" That framing catches a class of incidents
the rule layer misses:

- **Insider threat** — a finance analyst suddenly mass-downloading from
  SharePoint at 02:00 UTC.
- **Account takeover (ATO)** — an OAuth refresh token used from a new ASN
  while the legitimate session is still active (see
  [[aitm-evilginx-modern-phishing]] and [[oauth-device-code-phishing-m365]]).
- **Lateral movement** — a service account that has logged into ten hosts in
  an hour after a year of logging into one.
- **Slow data exfiltration** — small but persistent outbound transfer that
  never trips a static volume threshold.

The trade-off is honest: UEBA generates probabilistic signals that need
triage and tuning, not deterministic alerts that you can page on at 03:00.
Treat it as a hunting and risk-scoring layer that feeds your investigation
queue, not as a replacement for high-confidence rules.

## Core concepts

### Entities and baselines

A UEBA system models entities — typically `user`, `host`, `service account`,
`workload identity`, sometimes `application` or `IP`. For each entity it
builds a baseline of behavior across features such as:

- Logon times (hour-of-day, day-of-week histograms).
- Source geographies, ASNs, and device fingerprints.
- Authentication types (interactive, network, service, OAuth).
- Resource access patterns (which SharePoint sites, which S3 prefixes,
  which Kubernetes namespaces).
- Volume features (bytes sent, files opened, queries run).
- Peer-group membership — does this user behave like others in HR?

Baselines are typically rolling windows (28–90 days) with separate weekday
and weekend profiles to avoid trivial false positives.

### Detection families

UEBA blends several modelling families. None is magic on its own.

- **Statistical thresholds** — z-scores, EWMA, MAD. Cheap, explainable,
  works well for univariate features like "bytes egressed per hour".
- **Time-series anomaly** — STL decomposition, Prophet, ARIMA, or
  isolation-forest-on-features. See [[time-series-anomaly-for-security]].
- **Peer-group analysis** — cluster users by role/department/manager, then
  flag a user whose behavior diverges from their cluster.
- **Sequence models** — n-grams, HMMs, or transformer-based encoders over
  process-execution or command-line sequences.
- **Graph analytics** — build a logon graph, look for new edges, unusual
  betweenness, or "kerberoasting-shaped" subgraphs.
- **Supervised classifiers** — only useful when you have labeled incidents,
  which most shops do not. Beware of label leakage.

### Risk scoring and fusion

A single anomaly is rarely actionable. Mature UEBA systems aggregate
per-entity risk over a sliding window: an unusual logon time plus a new
geo plus a first-seen admin tool execution combine into an investigation
score. This is where vendor "kill chain" or "MITRE coverage" dashboards
come from.

## What UEBA catches that rules miss

| Pattern | Why rules struggle | Why UEBA catches it |
| --- | --- | --- |
| Stolen valid credentials | Auth is "successful" | Logon geo/time/device deviate from baseline |
| Insider data theft | No known IOC | Volume and access breadth deviate from peer group |
| Slow lateral movement | Each hop is legitimate | Graph features show new host-pair edges |
| Service account abuse | Service accounts are noisy | Peer-group analysis flags the outlier service account |
| Tycoon2FA / AiTM token replay | Token validates | Concurrent sessions, impossible-travel-on-token features fire — see [[tycoon2fa-and-modern-phish-kits]] |
| Cross-tenant Entra sync abuse | Native Microsoft API | Sudden cross-tenant graph edges — see [[entra-cross-tenant-sync-abuse]] |

## Commercial landscape

You will encounter these in real environments. Know enough to be dangerous
in an interview or scoping call.

- **Microsoft Sentinel UEBA** — built on Entra ID Protection + Defender
  signals. Strong in M365-heavy estates; weak outside Microsoft telemetry.
- **Splunk UBA** — separate product from core Splunk, Hadoop-based,
  ships with around 65 packaged models. Heavy footprint.
- **Exabeam** — pioneered the "Smart Timelines" risk-aggregation UX.
  Cloud-native rebuild ("New-Scale") replaced the on-prem Advanced
  Analytics product.
- **Securonix** — Snowflake-backed, strong on insider-threat content.
- **Gurucul** — heavy on configurable risk models and identity analytics.
- **Vectra AI / Darktrace** — network-centric UEBA-adjacent; treat their
  marketing claims with the same scepticism as any AI-security product
  (see [[ai-agent-sandbox-design]] for related model-risk thinking).

## Open-source and roll-your-own

You do not need a six-figure license to get started.

- **Elastic ML** — built into the Elastic Stack, time-series and
  population analysis, decent docs.
- **Wazuh + custom rules** — limited UEBA but workable for SMB.
- **OpenSearch Anomaly Detection** — Random Cut Forest under the hood.
- **Apache Metron / Spot** — historical interest; mostly archived.
- **PyOD, river, scikit-learn** — for building your own pipelines on top
  of a data lake (Snowflake, BigQuery, ClickHouse).
- **Sigma rules + statistical post-processing** — write Sigma to extract
  the events of interest, then apply z-scores in a notebook.

A practical minimum viable UEBA: ship auth logs and process events into
a columnar store, compute per-entity rolling statistics nightly, surface
top-N risk-scored entities to the hunt queue. Start simple before reaching
for neural networks.

## Defensive baseline

UEBA is only as good as the telemetry under it. Before tuning models,
make sure you have:

- Identity logs from your IdP — Entra ID sign-ins, Okta system log, AWS
  IAM Identity Center events. Compare with [[m365-admin-attacks]] and
  [[conditional-access-bypass-modern}} for the attacker view.
- Endpoint process telemetry — EDR or Sysmon at minimum.
- Network metadata — Zeek, VPC flow logs, proxy logs.
- Cloud control-plane logs — see [[cloud-ir-aws-cloudtrail]],
  [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]],
  [[cloud-ir-k8s-audit-logs]].
- A clean identity model — service accounts labelled as such, human
  accounts mapped to departments. Without this, peer-group analysis is
  meaningless.

Pair UEBA output with [[atomic-red-team-emulation-deep]] runs so you can
actually measure whether models fire on known tradecraft. Feed disagreements
back through the [[purple-team-feedback-loop]].

## Evaluation pitfalls

This is where most UEBA deployments quietly die.

- **False-positive rate at scale** — a 0.1% FPR across 50k users per day
  is 50 alerts. The math has to be done before deployment.
- **Baseline drift** — return-to-office, layoffs, M&A, or a new SaaS
  rollout will silently shift the baseline. Models need retraining
  cadences and drift monitors.
- **Cold start** — new joiners have no history. Decide whether to inherit
  the peer-group baseline or run looser thresholds for the first 30 days.
- **Label scarcity** — you almost never have enough confirmed-incident
  labels for supervised learning. Most production models are unsupervised
  or weakly supervised.
- **Explainability** — analysts will not action "the model said so". Every
  alert needs the top contributing features.
- **Adversarial drift** — sophisticated attackers (see
  [[apt-tradecraft-chinese-mss]] and [[apt-tradecraft-russian-svr-fsb]])
  deliberately blend in with baseline behavior. UEBA is part of defense
  in depth, not a silver bullet.
- **Vendor benchmarks are marketing** — insist on a PoC against your own
  data and a red-team emulation, not a canned demo.

## Workflow to study

1. Read the Microsoft Sentinel UEBA docs end-to-end — they are the most
   public, concrete description of a production system.
2. Build a tiny UEBA at home: ingest your own Okta or Entra logs into
   DuckDB, compute z-scores on hour-of-day and source ASN per user.
3. Run a [[atomic-red-team-emulation-deep]] sequence against a lab
   identity, confirm whether your toy model fires.
4. Read at least one Exabeam or Securonix incident write-up to see how
   risk-aggregation timelines are presented to analysts.
5. Cross-walk every UEBA model you encounter to MITRE ATT&CK technique
   IDs — this anchors the conversation in tradecraft, not vendor jargon.
6. Compare UEBA findings against the rule catalog in
   [[siem-detection-use-case-catalog]] and prune any rule whose detection
   UEBA already covers reliably.

## Related

- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[time-series-anomaly-for-security]]
- [[atomic-red-team-emulation-deep]]
- [[purple-team-feedback-loop]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[cti-collection-management]]
- [[ir-from-source-signals]]
- [[case-study-okta-2023-support-system]]
- [[case-study-snowflake-2024]]
- [[aitm-evilginx-modern-phishing]]
- [[tycoon2fa-and-modern-phish-kits]]

## References

- Microsoft Sentinel UEBA documentation: https://learn.microsoft.com/en-us/azure/sentinel/identify-threats-with-entity-behavior-analytics
- Splunk UBA product overview: https://www.splunk.com/en_us/products/user-behavior-analytics.html
- Exabeam New-Scale Analytics: https://www.exabeam.com/platform/
- Elastic Machine Learning anomaly detection guide: https://www.elastic.co/guide/en/machine-learning/current/ml-ad-overview.html
- OpenSearch Anomaly Detection (Random Cut Forest): https://opensearch.org/docs/latest/observing-your-data/ad/index/
- MITRE ATT&CK Insider Threat TTP mapping: https://attack.mitre.org/resources/adversary-emulation-plans/
