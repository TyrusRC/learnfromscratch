---
title: CSPM / CNAPP / DSPM — cloud security tooling landscape
slug: cspm-cnapp-dspm-landscape
aliases: [cspm-cnapp-dspm, cloud-security-tooling]
---

> **TL;DR:** The cloud security tooling market is an alphabet soup — CSPM, CWPP, CNAPP, DSPM, KSPM — sold as transformative by vendors but mostly delivering misconfiguration scanners with varying depth. A CNAPP buy is a 12–18 month program, not a switch-flip: agentless API scans surface thousands of findings in week one, and without a remediation pipeline (ownership, SLAs, IaC fix-back) it becomes very expensive shelfware. This note maps categories to vendors, contrasts agent vs API-only architectures, and is a companion to [[cloud-iam-misconfig-patterns]], [[k8s-admission-webhook-abuse]], [[cloud-ir-aws-cloudtrail]], and [[vulnerability-management-lifecycle]].

## Why it matters

Most cloud breaches in the case-study record ([[case-study-capital-one-2019]], [[case-study-snowflake-2024]]) trace to posture issues a CSPM-class tool would have flagged — public buckets, over-permissive IAM, missing MFA, unmanaged identities. The category exists because cloud console + native tooling (AWS Config, GCP Security Command Center, Azure Defender) don't unify findings across accounts, clouds, and workloads in a way large orgs can operationalize. CNAPP vendors sell that unification.

The honest framing: the technology is mature, the operating model is not. Buying Wiz does not give you cloud security; it gives you a high-resolution scoreboard of how bad things are. What you do with the scoreboard determines whether the spend was worth it.

## Category definitions and overlap

### CSPM — Cloud Security Posture Management

Continuous assessment of cloud configurations against benchmarks (CIS, NIST, PCI). Detects public S3 buckets, security groups open to 0.0.0.0/0, unencrypted volumes, IAM users without MFA. Almost always API-only, agentless. First-generation tools: DivvyCloud, RedLock, Dome9. See [[cloud-iam-misconfig-patterns]] for the failure modes these tools catch.

### CWPP — Cloud Workload Protection Platform

Runtime protection for VMs, containers, serverless. Vulnerability scanning of images and hosts, runtime behavior detection, file integrity. Historically agent-based (Twistlock, Aqua, Sysdig). The category older defenders called "host security in the cloud."

### CNAPP — Cloud Native Application Protection Platform

Gartner's 2021 umbrella term that swallowed CSPM + CWPP + IaC scanning + CIEM (Cloud Infrastructure Entitlement Management) + container security + sometimes API security. Marketed as "one platform from code to cloud." In practice, most CNAPPs are strong in 2–3 of those pillars and weaker in the rest — read the vendor's history to predict where.

### DSPM — Data Security Posture Management

Discovers and classifies sensitive data (PII, PHI, secrets, source code) across cloud storage, SaaS, databases. Maps who can access what data and flags exposure paths. Newer category (2022–) born from the realization that CSPM tells you the bucket is public but not whether it contains 80M SSNs.

### KSPM — Kubernetes Security Posture Management

Subset of CNAPP/CSPM focused on Kubernetes — RBAC, pod security, network policies, admission control. Overlaps heavily with [[k8s-admission-webhook-abuse]] and [[k8s-manifest-source-audit]] topics.

### CIEM — Cloud Infrastructure Entitlement Management

Identity-focused: who can do what across accounts, role chains, unused permissions, privilege right-sizing. Tied tightly to [[cloud-identity-mental-model]]. Most CNAPPs now bundle this.

## Vendor landscape (2025)

### Full-stack CNAPP

- **Wiz** — Agentless graph-based scanner. Strong on visualization (the "attack path" view that wins POVs). Weaker historically on runtime; acquired Gem Security for CDR (cloud detection and response).
- **Orca Security** — Agentless via "SideScanning" (snapshots EBS volumes). Similar pitch to Wiz; longer in-market.
- **Palo Alto Prisma Cloud** — Acquired Twistlock + RedLock + Bridgecrew; broadest coverage but heaviest to operate. Enterprise default.
- **CrowdStrike Falcon Cloud Security** — Strong if you already run Falcon EDR; CWPP-first, CSPM bolted on.
- **Microsoft Defender for Cloud** — Free baseline tier covers a lot; pay for advanced features. Default in Azure-heavy shops, weaker for AWS/GCP.
- **Sysdig** — Strong runtime/Falco lineage; container/K8s focus.
- **Aqua Security** — Container-first heritage; full CNAPP now.
- **Lacework** — ML-driven anomaly pitch; struggled commercially, acquired by Fortinet 2024.
- **Snyk Cloud** — Developer-led, IaC-strong, weaker on runtime.

### DSPM-pure-play

- **BigID, Cyera, Dig Security** (acquired by Palo Alto), **Sentra**, **Eureka**, **Normalyze**, **Symmetry Systems**. Expect consolidation — every CNAPP vendor is buying or building DSPM.

### CSP-native

- **AWS Security Hub + Config + GuardDuty + Macie** — Macie is AWS's DSPM-ish offering for S3.
- **GCP Security Command Center (SCC) Premium/Enterprise** — incorporates Mandiant attack surface; now competes directly with CNAPPs.
- **Azure Defender for Cloud** — see above.

The "CNAPP vs native" question is real. CSP-natives are cheaper and better integrated to that cloud's primitives, but worse across clouds and weaker on cross-account graph analysis.

## Architecture: agent vs API-only

### API-only / agentless

- Reads cloud APIs (Describe*, Get*, List*) and snapshots disks for vuln scan.
- Pros: trivial deploy (one role per account), no production impact, no agent ops burden.
- Cons: blind to runtime behavior, can't enforce, snapshot freshness lags, expensive at scale (every snapshot = data egress + storage).
- Wiz, Orca are the archetypes.

### Agent-based

- Daemonset/sidecar on hosts or pods; eBPF or kernel module.
- Pros: real-time process/network/file events, can block, sees encrypted traffic post-decrypt.
- Cons: agent ops (deployment, version skew, performance overhead), platform compatibility matrix.
- Sysdig, CrowdStrike, Falco.

### Hybrid (most CNAPPs today)

Agentless for posture + selective agents for runtime on crown-jewel workloads. The realistic deployment shape.

## Realistic deployment timeline

A serious CNAPP rollout in a mid-to-large org is not 30 days.

- **Month 0–1**: Procurement, POV against 1–2 vendors. Real findings emerge here — use them in negotiation.
- **Month 1–2**: Connect 1–3 highest-risk accounts. Tune scope. First findings dump: expect thousands. Triage to identify top 50 issues by exploitability + blast radius.
- **Month 2–4**: Build the remediation pipeline — ticketing integration (Jira/ServiceNow), owner mapping (which team owns which account/tag/namespace), SLA policy (critical: 7 days, high: 30, etc.).
- **Month 4–8**: Roll out to remaining accounts. Add IaC scanning to CI ([[sast-dast-ci-integration]]). Introduce policy-as-code guardrails so new misconfigs don't accrue.
- **Month 8–12**: Runtime/CWPP coverage on production. Tune detections, integrate with SOC ([[siem-detection-use-case-catalog]]).
- **Month 12–18**: Measure MTTR trend, retire native point tools, expand to SaaS posture / DSPM.

Skipping the ownership + ticketing work is the single most common failure mode. Without it, the tool generates findings nobody acts on, the security team becomes the ticket courier, and engineering ignores the noise.

## Common pitfalls

- **Alert flood, no triage** — 50,000 medium findings on day one is useless. Filter to "internet-exposed + sensitive data + lateral path" first.
- **No remediation pipeline** — finding without owner + SLA + tracking = ignored finding. See [[vulnerability-management-lifecycle]] for the same lesson in vuln mgmt.
- **Misconfig overwhelm** — fixing every CIS benchmark fail is not the goal; reducing exploitable attack paths is.
- **Multi-cloud inconsistency** — vendor coverage of AWS is always deeper than GCP/Azure. Validate per-cloud during POV.
- **Confusing CSPM with prevention** — CSPM finds bad state after it exists. Pair with IaC scanning + admission control ([[k8s-admission-webhook-abuse]]) to prevent.
- **Identity sprawl uncovered** — CIEM findings (unused IAM, role chains) are scary but huge to remediate; budget engineering time.
- **DSPM and data team friction** — DSPM scans buckets and databases; data engineering will push back on scan impact and access. Get them in the room early.
- **Vendor lock-in via custom policy** — writing 200 custom Wiz queries makes migration painful. Keep custom logic minimal.

## Defensive baseline (recommended starting program)

1. **Pick the budget tier first**: CSP-native + IaC scanning is the floor for cost-constrained orgs. Add CNAPP when you have multi-cloud or runtime needs.
2. **Always enable cloud-native logging first** — CloudTrail, GCP Audit Logs, Azure Activity Log ([[cloud-ir-aws-cloudtrail]], [[cloud-ir-gcp-audit-logs]], [[cloud-ir-azure-activity-log]]). CNAPP findings without the audit log substrate are hard to investigate.
3. **POV with real accounts**, not vendor demo tenants. Two vendors, same accounts, compare findings + false positive rate.
4. **Negotiate hard on per-workload pricing**. List prices are aspirational; 40–60% discounts are common.
5. **Wire to ticketing on day one** — no Jira/ServiceNow integration = the program dies.
6. **Define MTTR by severity**, publish the trend monthly to leadership.
7. **Layer IaC scanning** in CI to stop new misconfigs ([[terraform-and-iac-source-audit]], [[github-actions-workflow-source-audit]]).
8. **Use admission control** to enforce K8s policies inline.
9. **Tie to incident response** — CNAPP findings should feed [[siem-detection-use-case-catalog]] and [[cloud-red-team]] purple exercises.

## Measurement

- **MTTR by severity** — primary KPI. Target: critical < 7 days, high < 30, medium < 90.
- **Exposure window** — time from misconfig introduced to detection.
- **Reopen rate** — findings that come back; signals upstream IaC drift.
- **Coverage** — % accounts connected, % workloads with agent, % data stores classified.
- **Net new findings rate** — should trend down as IaC guardrails take hold; if flat or rising, prevention is not working.

Avoid vanity metrics like "total findings remediated" — easy to game by closing duplicates.

## Workflow to study (8–10 weeks)

1. **Weeks 1–2**: Read CIS Benchmarks for AWS/Azure/GCP cover-to-cover. This is the substrate every CSPM checks against.
2. **Weeks 3–4**: Stand up a free-tier AWS account; enable Security Hub, Config, GuardDuty, Macie. Intentionally misconfigure (public bucket, open SG, IAM user no MFA) and observe detection latency.
3. **Weeks 5–6**: Try open-source equivalents: Prowler, ScoutSuite, CloudSploit, Kube-bench, Trivy. Compare findings to native tooling.
4. **Weeks 7–8**: Get vendor trials (Wiz, Orca, Prisma offer them) — pay attention to onboarding experience and findings noise.
5. **Weeks 9–10**: Read the [[case-study-capital-one-2019]] post-mortem; map which CNAPP findings would have flagged the SSRF + IAM combination pre-breach.

Pair with [[cloud-identity-mental-model]] and [[cloud-iam-misconfig-patterns]] for the IAM substrate, and [[k8s-admission-webhook-abuse]] for the Kubernetes side.

## Vendor marketing vs reality

- "Code-to-cloud" — most vendors do code scanning weakly; you still need Snyk/Semgrep for serious SAST.
- "Agentless = full coverage" — false; runtime detection requires runtime data.
- "AI-powered prioritization" — usually a graph + heuristics; useful but not magic.
- "Shift-left" — only works if developers actually own the findings, which requires culture not tooling.
- "Single pane of glass" — every CNAPP claims this; none deliver it for SaaS, identity, and endpoint together.

## Related

- [[cloud-iam-misconfig-patterns]]
- [[k8s-admission-webhook-abuse]]
- [[cloud-ir-aws-cloudtrail]]
- [[cloud-ir-azure-activity-log]]
- [[cloud-ir-gcp-audit-logs]]
- [[cloud-ir-k8s-audit-logs]]
- [[cloud-identity-mental-model]]
- [[vulnerability-management-lifecycle]]
- [[terraform-and-iac-source-audit]]
- [[k8s-manifest-source-audit]]
- [[sast-dast-ci-integration]]
- [[siem-detection-use-case-catalog]]
- [[case-study-capital-one-2019]]
- [[case-study-snowflake-2024]]
- [[cloud-red-team]]

## References

- <https://www.gartner.com/en/documents/4011582> — Gartner Market Guide for Cloud-Native Application Protection Platforms (originating CNAPP definition)
- <https://www.cisecurity.org/cis-benchmarks> — CIS Benchmarks for AWS, Azure, GCP, Kubernetes (the substrate every CSPM evaluates)
- <https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html> — AWS Security Hub documentation
- <https://cloud.google.com/security-command-center/docs> — GCP Security Command Center documentation
- <https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-cloud-introduction> — Microsoft Defender for Cloud overview
- <https://github.com/prowler-cloud/prowler> — Prowler open-source CSPM (good for hands-on study)
