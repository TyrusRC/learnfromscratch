---
title: Time-series anomaly detection for security
slug: time-series-anomaly-for-security
aliases: [time-series-detection, volumetric-anomaly-detection]
---

> **TL;DR:** Time-series anomaly detection on security telemetry (logins per minute, DNS queries per host, egress bytes per app) is one of the cheapest ways to spot "something changed" without writing brittle signatures. The trick is matching the model to the signal shape (stationary vs seasonal, business-hours vs always-on), tuning alerts against business cycles, and treating drift as a first-class operational concern. Companion notes: [[ueba-detection-ml-primer]] for entity-centric models and [[ml-for-detection-tradeoffs]] for when ML is the wrong tool.

## Why it matters

Signature and rule-based detection (see [[detection-engineering-pyramid-of-pain]]) covers known bad. Time-series anomaly detection covers "this host normally sends 50 MB outbound at 3am, today it sent 12 GB" — the volumetric and rate-of-change signals that adversaries leak even when they evade content inspection. It pairs naturally with [[siem-detection-use-case-catalog]] as a coverage layer for data exfil, credential stuffing, beaconing, ransomware staging, and abuse of automation accounts.

The cost profile is attractive: most SIEMs already aggregate counters; you only need a baseline and a threshold function. The risk profile is sharp: false positives at scale erode analyst trust faster than almost any other detection class, so tuning discipline matters more than model choice.

## Signal classes

Pick signals where (a) the metric has a meaningful baseline, (b) adversary actions plausibly perturb it, and (c) you can attribute spikes to an entity for triage.

### Authentication and identity
- Logins per user per minute / per IP per minute — credential stuffing, password spray, [[mfa-fatigue-tradecraft]].
- Failed auth ratio per tenant — spray detection across [[m365-admin-attacks]] and [[conditional-access-bypass-modern]].
- Token issuance rate per app registration — OAuth abuse, [[oauth-device-code-phishing-m365]].
- MFA prompts per user per hour — pairs with [[aitm-evilginx-modern-phishing]] triage.

### Query and command volume
- DNS queries per host (total and NXDOMAIN ratio) — DGA, beaconing, tunneling.
- LDAP queries per service account — recon and [[apt-tradecraft-chinese-mss]] style enumeration.
- Database queries per app per minute — data theft staging.
- Process creation rate per host — living-off-the-land bursts mapped via [[atomic-red-team-emulation-deep]].

### Network bytes and flows
- Egress bytes per host per destination ASN — exfil, see [[case-study-snowflake-2024]] for the impact lens.
- Inbound bytes per public service — DDoS, scraping.
- New external destinations per host per day — beacon discovery, C2 rotation.
- TLS JA3/JA4 cardinality per host — tooling change.

### Cloud control plane
- API calls per IAM principal per minute across [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]].
- Kubernetes `exec`/`portforward` counts per namespace from [[cloud-ir-k8s-audit-logs]].
- Secret reads per service account.

## Modelling approaches

There is no universal best model — choose by signal shape and operational constraints.

### Moving average and z-score
- Compute rolling mean and standard deviation over a trailing window (e.g. 1h, 24h, 7d).
- Alert when current value exceeds `mean + k*sigma` (k typically 3-6).
- Strengths: trivial to implement, cheap, explainable.
- Weaknesses: assumes near-stationary signal, blows up on seasonal data, sensitive to recent contamination (if yesterday was bad, today's baseline is poisoned).

### ARIMA and SARIMA
- ARIMA models autoregressive + differencing + moving average components; SARIMA adds seasonal terms.
- Good for signals with clear short-term autocorrelation (per-minute login counts on a stable service).
- Requires stationarity assumptions and parameter selection (`p,d,q` and seasonal `P,D,Q,s`).
- Heavier to operate than EWMA; usually overkill unless you need forecasting too.

### Holt-Winters (triple exponential smoothing)
- Decomposes into level, trend, seasonal components; handles weekly seasonality cleanly.
- A pragmatic default for business-hours services (auth volume, helpdesk traffic).
- Available in most stats libraries; cheap to retrain nightly.

### Prophet
- Facebook/Meta library designed for analyst-friendly forecasting with holidays, change-points, multiple seasonalities.
- Forgiving with missing data; good for noisy operational metrics.
- Slow at scale (thousands of series) unless parallelised; not ideal for sub-minute cadence.

### Isolation Forest
- Tree ensemble that isolates anomalies via random splits; works on multivariate feature vectors derived from windows.
- Useful when "anomaly" depends on combinations of features (volume + entropy + destination diversity), not a single metric.
- Pairs well with [[ueba-detection-ml-primer]] entity feature stores.

### Autoencoders and LSTM
- Train a neural network to reconstruct "normal" windows; reconstruction error becomes the anomaly score.
- High ceiling on complex signals; high operational cost (GPU training, drift retraining, opacity).
- Reserve for high-value pipelines where simpler models demonstrably fail; see [[ml-for-detection-tradeoffs]] for the cost/benefit framing.

### Robust statistics and STL
- Seasonal-Trend decomposition (STL) plus median absolute deviation (MAD) on residuals gives a robust, explainable baseline.
- Resistant to outliers contaminating the baseline — important because adversary activity is the outlier you want to catch.

## Seasonality and business cycles

Most security telemetry has at least two seasonalities:

- Daily: business hours vs overnight, batch jobs at fixed UTC times.
- Weekly: weekday vs weekend, Monday spikes after weekend backlogs.
- Annual: holidays, fiscal quarter closes, payroll runs.

If your model ignores seasonality, you will alert every Monday morning and miss the 3am Saturday exfil. Practical rules:

- For always-on services (cloud APIs, internal microservices), short windows with EWMA or ARIMA usually suffice.
- For human-driven services (VPN, M365, helpdesk), use Holt-Winters or Prophet with explicit weekly seasonality.
- Encode known business events (Black Friday, quarter-end) as exogenous regressors or maintenance windows so the model does not learn the spike as "normal".
- Treat off-hours activity on business-hours services as a separate detection — a low absolute volume can still be a high relative anomaly.

## Alert tuning

The default failure mode is "too many alerts of the wrong kind". Tuning checklist:

- Express thresholds as percentiles of historical anomaly scores, not raw z-scores — easier to reason about volume budgets.
- Define an alert budget per detection per shift (e.g. <=2/day for a tier-2 queue) and tune until you meet it.
- Require sustained anomalies (N consecutive windows above threshold) for noisy signals to suppress single-window jitter.
- Combine weak signals: an anomaly in egress bytes AND an anomaly in new destinations AND an anomaly in process creation is stronger than any one alone.
- Suppress during known maintenance windows fed from change-management feeds.
- Capture analyst dispositions (true/false positive, benign cause) and feed them back via [[purple-team-feedback-loop]].

## Drift detection

Models go stale. Drift comes in three flavours:

- Concept drift — the meaning of "normal" changes (new product launch shifts login volume up 5x).
- Data drift — the input distribution shifts (new logging agent doubles event counts).
- Adversarial drift — attackers learn your thresholds and slow-walk activity beneath them.

Operational hygiene:

- Track model error (residual distribution) over time; alert when its mean or variance shifts significantly.
- Retrain on a fixed cadence (nightly or weekly) with a held-out validation window.
- Keep model versions immutable and tagged so you can correlate alert quality changes with model changes.
- Run shadow models in parallel before promoting; compare alert overlap and FP rate.
- For adversarial drift specifically, layer behaviour-based detections from [[edr-rules-as-code-from-attack-patterns]] so a slow exfil still trips on technique signatures.

## Integration with detection-as-code

Treat anomaly detectors like any other detection artifact:

- Store model configuration (signal, window, model class, hyperparameters, thresholds) in version control alongside Sigma/EQL rules.
- Code-review changes; require a test case showing the detector firing on a known-good simulation.
- CI runs the detector against a fixture dataset and asserts on alert counts and labels.
- Document the detector with hypothesis, signal source, mapped ATT&CK techniques, response playbook, owner, last-validated date — same metadata as in [[siem-detection-use-case-catalog]].
- Emit alerts into the same case management pipeline as rule-based detections; do not silo "ML alerts" into a separate queue analysts learn to ignore.
- Validate with adversary emulation: an [[atomic-red-team-emulation-deep]] run should perturb your modelled signals; if it does not, your detector is not measuring what you think.

## Defensive baseline

- Inventory the top 20 security-relevant time series in your environment and assign owners.
- Start with EWMA + percentile thresholds before reaching for ML; many detections never need more.
- Pair every anomaly detector with an entity attribution path (user, host, service account) so triage is possible.
- Feed analyst dispositions back into model tuning at least monthly.
- Document expected business cycles per detector; review quarterly.
- Run a quarterly purple-team exercise that injects synthetic anomalies and measures detection and time-to-alert.

## Workflow to study

1. Pick one signal you understand operationally (e.g. failed logins per tenant per minute).
2. Pull 60-90 days of history into a notebook; plot it and stare at it. Identify daily and weekly seasonality by eye.
3. Fit three baselines: rolling z-score, Holt-Winters, Prophet. Compare residual distributions on a held-out week.
4. Inject synthetic anomalies (a credential spray simulation via [[atomic-red-team-emulation-deep]]); measure which model catches them at which threshold.
5. Pick the simplest model that meets your detection goals at your alert budget.
6. Wire it into your SIEM as a scheduled job; route alerts through the same triage path as rule-based detections.
7. Add drift monitoring on residuals; schedule weekly retrains.
8. After 30 days, review analyst dispositions and tune thresholds.
9. Document the detector in your catalog and assign an owner.
10. Repeat for the next signal.

## Related

- [[ueba-detection-ml-primer]]
- [[ml-for-detection-tradeoffs]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[purple-team-feedback-loop]]
- [[atomic-red-team-emulation-deep]]
- [[cti-collection-management]]
- [[cloud-ir-aws-cloudtrail]]
- [[cloud-ir-k8s-audit-logs]]
- [[case-study-snowflake-2024]]

## References

- https://otexts.com/fpp3/ — Hyndman and Athanasopoulos, "Forecasting: Principles and Practice", canonical reference for ARIMA, ETS, Holt-Winters and STL.
- https://facebook.github.io/prophet/ — Prophet documentation and methodology paper.
- https://scikit-learn.org/stable/modules/outlier_detection.html — scikit-learn isolation forest and one-class SVM references.
- https://www.elastic.co/guide/en/machine-learning/current/ml-ad-overview.html — Elastic anomaly detection job design and operational guidance.
- https://attack.mitre.org/techniques/T1071/ — ATT&CK C2 application layer protocols, the technique class most often surfaced by volumetric anomalies.
- https://www.first.org/global/sigs/metrics/ — FIRST detection metrics SIG, useful for framing alert budgets and tuning KPIs.
