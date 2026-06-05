---
title: Case study — Equifax (2017, Apache Struts CVE-2017-5638)
slug: case-study-equifax-2017
aliases: [equifax-breach, apache-struts-equifax, cve-2017-5638]
---

> **TL;DR:** Equifax's dispute-resolution portal ran an outdated Apache Struts version vulnerable to CVE-2017-5638 (OGNL injection via crafted `Content-Type` header) — a public patch was available, the team was notified internally, but the patch wasn't applied to that specific instance. Attackers exploited the bug for ~76 days before discovery, exfiltrating ~147M US consumer records. The incident is studied for **basic vulnerability management failure** at large scale and for the social aftermath (executive resignations, congressional testimony, FTC settlement). Companion to [[case-study-capital-one-2019]] and [[one-day-from-patch-diff]].

## Why this matters

- **The bug was already public, patched, and announced** when exploited. Patch management is the lesson, not novel exploitation.
- Equifax was a **credit bureau** — the data was uniquely sensitive (SSNs of half of US adult population).
- The incident drove **regulatory change** (state-level breach notification updates, FTC settlement standards).
- The breach happened against a backdrop of **expired SSL certificate** preventing a traffic-inspection tool from catching the exfil — the perfect storm of compounding small failures.

## The vulnerability

Apache Struts 2 has a feature for content negotiation. When a multipart parser fails, the error path passed the `Content-Type` header through Object-Graph Navigation Language (OGNL) — a dynamic expression language. Crafted `Content-Type` headers became code execution.

```
Content-Type: %{(#_='multipart/form-data').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS).(#_memberAccess?(#_memberAccess=#dm):((#container=#context['com.opensymphony.xwork2.ActionContext.container']).(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class)).(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear()).(#context.setMemberAccess(#dm)))).(@java.lang.Runtime@getRuntime().exec('id'))}
```

The Apache Struts team released a patch (Struts 2.3.32 / 2.5.10.1) on **March 7, 2017**. Equifax was breached **starting May 13, 2017** — over two months later.

## The chain

1. **March 7** — Struts patch released; CVE-2017-5638 public.
2. **March 8** — Equifax security team alerted internally to patch the vulnerability across all systems.
3. **March 9** — Equifax sysadmins searched for vulnerable systems, missed the dispute-resolution portal.
4. **May 13** — Attackers exploited CVE-2017-5638 on the portal.
5. **May 13 – July 30** — Attackers operated inside Equifax. ~76 days of active operation.
6. **July 29–30** — Equifax expired SSL certificate on a network-inspection tool; once replaced, exfil traffic became visible. Attackers detected.
7. **September 7** — Public breach disclosure.

## What attackers achieved

- ~143M (later revised to ~147M) US consumer records.
- Records included SSN, DOB, address, sometimes credit card numbers, driver's license numbers.
- Data sold / used / leveraged across multiple criminal-and-state campaigns.
- ~2,000 attempts at additional exploitation across the network detected post-incident.

## Specific compounding failures

- **Vulnerability scanning didn't catch the portal** — scan was incomplete or the asset wasn't in scope.
- **Manual patch instruction didn't get applied** to that specific system.
- **Network segmentation absent** — once in, attackers reached the consumer-data database.
- **Certificate expiration on the inspection tool** — the tool that would have detected exfil was blind for 19 months due to an expired cert.
- **Slow detection** — 76 days from compromise to detection.
- **Internal alerting failure** — disclosure delayed weeks past technical discovery.

## What this teaches

- **Patch management** is foundational and frequently broken at scale.
- **Asset inventory** must include every internet-facing system. Missing one is catastrophic.
- **Network segmentation** between application tier and data tier limits blast radius.
- **Inspection tools** must be monitored for their own health — an expired cert on a security tool is itself a security incident.
- **Time-to-patch** under 30 days for internet-facing critical CVEs is the industry standard since.
- **Egress monitoring** for unusual data volumes catches active campaigns.

## Defensive baseline informed by Equifax

- **Automated patch management** with attestation that every relevant system applied the patch.
- **Comprehensive asset inventory** — automated discovery, cross-checked against asset databases.
- **Vulnerability scanning across all internet-facing assets** monthly minimum, weekly for high-risk.
- **Network segmentation** with deny-by-default between presentation and data tiers.
- **Egress monitoring** with volumetric alerting.
- **Health-monitoring** of security infrastructure (cert expiration, log gaps).
- **Time-to-patch SLAs** — under 7 days for KEV, under 30 days for high-severity.

## Detection lessons

The 76-day operational window included signals that could have triggered detection:

- The Struts exploit pattern has obvious indicators (`%{` OGNL syntax in headers).
- Outbound data volume from the portal was high.
- Database query patterns from the portal were anomalous.

The expired cert blinded the inspection. Health monitoring of detection tools is itself a control.

## Regulatory aftermath

- **FTC settlement** of up to $700M.
- **Congressional testimony** by the CEO.
- **Executive resignations** including CIO, CSO, CEO.
- **State-level breach-notification laws** updated.
- **SEC charges** against an executive for insider trading prior to public disclosure.

For security professionals: the incident is studied in CISO masters' programs and DPO certification tracks. Worth knowing the timeline cold.

## How to teach the chain

Reproduce CVE-2017-5638 in a lab:
1. Spin up vulnerable Struts version in a Docker container.
2. Send `curl` with the OGNL-payload `Content-Type` header.
3. Observe RCE.
4. Patch to Struts 2.3.32; observe attack failing.

Then walk through the *organisational* failure mode separately — asset inventory, patch attestation, cert monitoring.

## Related

- [[case-study-capital-one-2019]] — similar "control gap" theme.
- [[case-study-moveit-2023]] — similar broad-impact appliance compromise.
- [[case-study-solarwinds-2020]] — different vector but similar regulatory aftermath.
- [[command-injection]] / [[ssti]] — adjacent classes.
- [[known-vuln-workflow]] / [[one-day-from-patch-diff]] — defender flip-side.
- [[appsec-maturity-checklist]] — programmatic baseline.

## References
- [Apache Struts CVE-2017-5638 advisory](https://cwiki.apache.org/confluence/display/WW/S2-045)
- [GAO Equifax report](https://www.gao.gov/products/gao-18-559)
- [US House Oversight Committee report](https://republicans-oversight.house.gov/wp-content/uploads/2018/12/Equifax-Report.pdf)
- [FTC Equifax settlement](https://www.ftc.gov/enforcement/refunds/equifax-data-breach-settlement)
- See also: [[case-study-capital-one-2019]], [[case-study-moveit-2023]], [[command-injection]], [[appsec-maturity-checklist]], [[one-day-from-patch-diff]]
