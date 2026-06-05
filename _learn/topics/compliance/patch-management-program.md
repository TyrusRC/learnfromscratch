---
title: Patch management program
slug: patch-management-program
aliases: [patch-management, patching-program]
---

> **TL;DR:** A patch management program is the operational arm that closes findings produced by [[vulnerability-management-lifecycle]]. It ingests vendor advisories, prioritises with [[cvss-epss-kev-prioritisation]], tests, deploys within asset-class SLAs, and proves the patch landed. Programs fail not because patches do not exist, but because inventories are wrong, change windows are too tight, "patched" never gets verified, and exceptions (see [[vuln-exception-management]]) become permanent. [[case-study-equifax-2017]] is the canonical example of what happens when a known-CVE patch sits ungated for months.

## Why it matters

Patch management is the single highest-leverage control most organisations operate. Auditors care (PCI DSS 4 Requirement 6, HIPAA Security Rule technical safeguards, NIS2 Article 21, DORA, ISO 27001 A.8.8). Attackers care more — KEV-listed vulnerabilities are weaponised within days of disclosure, and ransomware affiliates (see [[ransomware-affiliate-playbook]]) routinely chain edge-device CVEs that have been patched for weeks.

The job is not "install updates." It is:

- Know every asset that needs patches (inventory truth).
- Know which patches matter now (prioritisation).
- Test without breaking production.
- Deploy within a defensible SLA.
- Prove deployment landed and the host actually rebooted.
- Manage the long tail (OT, legacy, third-party appliances) honestly.

A program that looks healthy on a dashboard but cannot answer "is CVE-2024-XXXX patched on every internet-facing box right now?" is not a program. It is theatre.

## Patch sources

You cannot patch what you are not watching. Subscribe and ingest, do not rely on the news cycle.

- **Operating systems**
  - Microsoft: MSRC Security Update Guide, Patch Tuesday (second Tuesday), out-of-band advisories.
  - Apple: Apple Security Releases page, rapid security responses for macOS / iOS.
  - Linux distros: Red Hat Security Advisories (RHSA), Ubuntu Security Notices (USN), Debian DSA, SUSE SUSE-SU, Amazon Linux ALAS.
- **Network / appliance vendors:** Cisco PSIRT, Fortinet PSIRT, Palo Alto, Citrix, Ivanti, F5, VMware (Broadcom). These are where the edge-device KEVs come from.
- **Hypervisor / virtualisation:** VMware ESXi, Hyper-V, Proxmox, Xen.
- **Container base images:** Track upstream (Alpine, Debian-slim, distroless, UBI). Rebuild and redeploy is the patch action, not `apt upgrade` inside a running container.
- **Language ecosystems:** npm advisories, PyPI / OSV, RubyGems, Go vulndb, Maven Central / OSS Index, NuGet.
- **Third-party libraries baked into your own product:** SBOM-driven, see [[secure-sdlc-rollout-playbook]] and [[sast-dast-ci-integration]].
- **Authoritative aggregators:** CISA KEV catalogue, NVD, vendor-specific RSS, commercial feeds (Tenable, Qualys, Rapid7).

If your program does not have a documented owner for each source and a defined ingestion cadence, it is reactive by default.

## Testing process

The fastest way to lose executive trust is to push a Patch Tuesday update that blue-screens the EDR fleet. Build trust through repeatable testing.

- **Test environment:** a representative subset — gold images, one of each server role, a sample workstation per persona. Does not have to be huge; it has to be representative.
- **Canary deployment:** ring-based rollout. Ring 0 = IT and security volunteers. Ring 1 = non-critical office users (~5 percent). Ring 2 = broader user base. Ring 3 = production servers. Ring 4 = critical / regulated systems. Each ring gates the next on stability metrics (crash reports, helpdesk volume, EDR telemetry).
- **Rollback plan:** documented per asset class. For Windows: WSUS / Intune supersedence, snapshots for VMs, image redeploy for workstations. For Linux: `dnf history undo`, package pinning, immutable infra redeploy. For containers: redeploy previous image tag — never patch a running container.
- **Acceptance criteria:** define before deployment. Reboot completes, services come up, smoke tests pass, no spike in EDR alerts, no spike in tickets.

Skipping testing for "small" patches is how organisations end up with the CrowdStrike-2024-shaped outage of their own making.

## Patch windows and cadence

- **Weekly** for workstation OS, browsers, language runtimes on developer machines.
- **Monthly** for server OS, hypervisor, on a defined maintenance window (e.g., third Saturday).
- **Quarterly** for firmware, BIOS, appliance OS where vendor cadence is slower.
- **Emergency / out-of-band** for KEV additions, actively exploited CVEs, or anything that hits your tier-0 assets. SLA measured in hours, not weeks.
- **Continuous** for container images and serverless — every CI build pulls the latest base. No "monthly" cadence; you redeploy on every release anyway.

Publish the calendar. Engineering and business owners need to plan around it. Surprise windows kill the program.

## Automation tooling

You will not patch a fleet of thousands by hand. Tooling per platform:

- **Windows:** WSUS (legacy, free), SCCM / MECM (enterprise, heavy), Intune / Windows Update for Business (cloud-native), Autopatch (managed). Third-party: PDQ Deploy, ManageEngine, BigFix, Tanium, Action1.
- **macOS:** Jamf, Kandji, Mosyle, Intune (limited), Apple Business Manager + MDM for forced updates.
- **Linux:** RHEL Satellite / Foreman, Spacewalk descendants, Canonical Landscape, SUSE Manager, Ansible / Salt / Chef pipelines that wrap `dnf`, `apt`, `zypper`. Live patching (kpatch, kgraft, Ksplice) for kernel hot-fixes where reboots are expensive.
- **Containers:** rebuild on base-image change, push to registry, trigger redeploy. Image-scanning gate in CI (Trivy, Grype, Snyk, Wiz). Never `kubectl exec` and `apt upgrade`.
- **Network gear:** vendor tooling (Cisco DNA Center, FortiManager, Panorama) or scripted via NETCONF / RESTCONF / Ansible network modules.
- **Mobile:** MDM-enforced minimum OS version with Conditional Access blocking older builds (see [[conditional-access-bypass-modern]] for what attackers do when CA is misconfigured).

Automation does not remove the need for change control. It removes the manual toil.

## KEV / emergency patch process

A separate, faster track for vulnerabilities meeting any of:

- Listed on CISA KEV.
- High EPSS score with public exploit (see [[cvss-epss-kev-prioritisation]]).
- Vendor advisory marks as actively exploited.
- Affects internet-facing or tier-0 assets.

Process shape:

1. Watch channel fires (KEV update, vendor RSS, CTI alert).
2. Within 1 hour: scope query against asset inventory and exposure data.
3. Within 4 hours: decision — patch now, mitigate (WAF rule, ACL, disable service), or accept (rare, requires CISO sign-off).
4. Within 24-72 hours for internet-facing: patch deployed and verified.
5. Within 7 days for internal tier-0.
6. Post-action: confirm patch landed (attestation), update the watchlist, brief leadership.

The KEV track must bypass the normal CAB. Pre-approved standing change is how you keep it honest without ignoring change control.

## SLAs by asset class

Defensible SLAs are written, signed by leadership, and tracked. Indicative ranges:

| Class | Critical | High | Medium |
|---|---|---|---|
| Internet-facing perimeter | 24-72h | 7d | 30d |
| Production server | 7d | 14d | 30d |
| Workstation / laptop | 7d | 14d | 30d |
| Mobile (MDM-enforced) | 14d | 30d | 60d |
| IoT / appliance | 30d | 60d | 90d or compensating |
| OT / ICS | Windowed (quarterly+), compensating controls primary |

OT deserves its own treatment — see [[manufacturing-ot-defender-playbook]]. Patching a PLC mid-shift is not a thing. Network segmentation, unidirectional gateways, and detection carry the load until the maintenance window.

## Exception interaction

Patches that cannot land within SLA enter [[vuln-exception-management]]. Discipline matters:

- Time-boxed (90 days max default).
- Compensating controls documented and tested.
- Re-reviewed before expiry.
- Visible to leadership.
- Never used as a backdoor for "we just do not want to patch."

A program with thousands of permanent exceptions has no program.

## Attestation discipline

"Deployed" is not "patched." Prove it:

- **Query the host.** Build version, KB number, package version, kernel uname.
- **Reboot verification.** Pending reboots are unpatched in practice. Track `LastBootUpTime` against patch install time.
- **Vulnerability scanner reconciliation.** Authenticated scan after the window closes; the CVE should be gone, not just suppressed.
- **Configuration drift detection.** EDR / CMDB / scanner agree on build state.
- **Sample manual verification.** Pick 1 percent randomly, log in, check. Auditors love this evidence and it catches tooling lies.

The "patch-but-don't-reboot" failure mode is so common it deserves its own KPI: percentage of patched hosts with pending reboot older than 7 days.

## Regulatory drivers

- **PCI DSS 4.0 Requirement 6.3.3:** critical vulnerabilities patched within 1 month, all others per risk-based prioritisation. See [[building-a-pci-dss-program-practitioner]].
- **HIPAA Security Rule:** security management process (administrative safeguards) requires risk-based vulnerability remediation. See [[hipaa-security-rule]].
- **NIS2 Article 21(2)(e):** vulnerability handling and disclosure as part of basic cyber hygiene. See [[nis2-implementation]].
- **ISO 27001 A.8.8:** management of technical vulnerabilities.
- **DORA:** ICT risk management, in scope for financial entities.
- **SOC 2 CC7.1:** detection and remediation of vulnerabilities.

Auditors will ask for: policy, SLAs, exception register, sample patch deployment evidence, scanner reports showing closure, and KEV handling proof.

## Common failure modes (be honest)

- **Inventory is wrong.** You patched 95 percent of "known" assets — but the 5 percent you do not know about includes the legacy Jenkins box exposed to the internet. See [[case-study-equifax-2017]].
- **Untested patches break production.** Once burned, the program loses executive support for years.
- **Patch-but-don't-reboot.** Common on Linux servers and Windows file servers. Kernel patched, kernel not loaded.
- **OT patching paralysis.** Treated as "too hard," nothing changes, segmentation also never gets done. Worst of both worlds.
- **Third-party appliances.** Vendor releases firmware, customer never applies it. Common in network gear and printers (yes, printers).
- **Container drift.** Long-running containers never rebuilt. Base image vulnerabilities accumulate silently.
- **SaaS blind spot.** "It is SaaS, they patch it" is sometimes true and sometimes catastrophically false (see [[case-study-moveit-2023]], [[case-study-snowflake-2024]]).
- **Compliance theatre.** Dashboard says green, reality says otherwise. Auditor catches it, or attacker does.

## Workflow to study

1. Pick one asset class (e.g., internet-facing Linux servers).
2. Walk the end-to-end loop: advisory ingest -> inventory query -> prioritisation -> test -> deploy -> verify -> close.
3. Time each stage. Where is the bottleneck? Almost always: testing or change approval.
4. Add a KEV scenario on top. Can the program collapse the timeline?
5. Build attestation evidence end-to-end for one CVE. Could you hand it to an auditor tomorrow?
6. Repeat for workstations, then containers. Same skeleton, different tools.

## Related

- [[vulnerability-management-lifecycle]]
- [[cvss-epss-kev-prioritisation]]
- [[vuln-exception-management]]
- [[case-study-equifax-2017]]
- [[case-study-moveit-2023]]
- [[building-a-pci-dss-program-practitioner]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[manufacturing-ot-defender-playbook]]
- [[secure-sdlc-rollout-playbook]]
- [[ransomware-affiliate-playbook]]

## References

- CISA Known Exploited Vulnerabilities catalogue: https://www.cisa.gov/known-exploited-vulnerabilities-catalog
- Microsoft Security Update Guide: https://msrc.microsoft.com/update-guide
- Red Hat Security Advisories: https://access.redhat.com/security/security-updates/
- PCI DSS v4.0.1 Requirement 6: https://www.pcisecuritystandards.org/document_library/
- NIST SP 800-40 Rev. 4 (Guide to Enterprise Patch Management Planning): https://csrc.nist.gov/publications/detail/sp/800-40/rev-4/final
- ENISA guidance on vulnerability disclosure and patching under NIS2: https://www.enisa.europa.eu/topics/incident-response/coordinated-vulnerability-disclosure
