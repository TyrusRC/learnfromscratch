---
title: Detection engineering — Pyramid of Pain
slug: detection-engineering-pyramid-of-pain
aliases: [pyramid-of-pain, detection-engineering-baseline]
---

> **TL;DR:** David Bianco's Pyramid of Pain (2013) ranks indicator types by how *painful* their detection is for the adversary to overcome. From bottom (trivial to evade) to top (very hard): hash values → IP addresses → domain names → network/host artifacts → tools → TTPs (tactics, techniques, procedures). Detection engineering programmes that focus too low on the pyramid catch only commodity attacks; programmes building toward TTPs catch sophisticated adversaries. Companion to [[siem-detection-use-case-catalog]] and [[atomic-red-team-emulation-deep]].

## The pyramid (bottom to top)

```
          TTPs                  ←  hardest to evade
       Tools
    Network/Host Artifacts
   Domain Names
  IP Addresses
 Hash Values                    ←  easiest to evade
```

Each level up is meaningfully harder for the adversary to change.

## Hash values

- File hashes (SHA-256, MD5).
- Easy to detect (signatures).
- **Easy to evade**: recompile, repack, change one byte → new hash.
- Useful for IoC-feed-based detections of known commodity malware.
- Limited efficacy against custom or modified samples.

## IP addresses

- C2 server IPs, exfil endpoints.
- Easy to detect.
- **Easy to evade**: rotate IPs, use CDN, rent new VPS.
- Useful for blocking known infrastructure.
- Limited against frequently-rotating C2.

## Domain names

- Phishing domains, C2 domains.
- Easy to detect (DNS / proxy logs).
- **Easy to evade**: register new domain (~$10).
- Useful for blocking specific known-bad.
- Domain-generation algorithms (DGA) make this harder but DGA detection by ML compensates.

## Network / Host artifacts

- Specific User-Agent strings.
- Registry keys created.
- Specific file paths.
- Specific URI patterns.
- Mutexes.
- Service / scheduled-task names.

**Moderately painful**: adversary must re-engineer tooling to evade. New version requires effort.

## Tools

- Specific tools (Mimikatz, Cobalt Strike, Sliver, PsExec).
- Detected via behavioural signatures (process tree, file hashes of tool components, network behaviour).

**Painful**: adversary must develop new tool or significantly modify. Time investment in days to weeks.

## TTPs

- Tactics, techniques, procedures.
- E.g., "uses DCSync after Kerberoasting", "exfils to MEGA after disabling Defender", "uses LolBin chains like `certutil → wmic`".
- Mapped to MITRE ATT&CK.

**Very painful**: adversary must change *how they think and operate*. Tradecraft change is months of retraining and methodology evolution.

## Where most programmes stop

Most SIEMs and threat-intel feeds operate at the bottom three levels:
- Subscription to IoC feeds.
- Block / alert on known-bad IPs / domains / hashes.

This catches commodity malware and known campaigns but misses:
- Custom-built tools.
- Living-off-the-Land tradecraft.
- Sophisticated APT operations.

## Building TTP detections

Examples of TTP-level detections:

- **DCSync**: detect any non-DC making `DRSReplicaSync` requests.
- **Kerberoasting**: detect TGS requests with RC4 + unusual SPN coverage.
- **EDR-killing**: driver loads with specific characteristics + unsigned drivers.
- **Cobalt Strike beacon**: jitter / sleep / HTTP profile patterns.
- **DNS tunneling**: high-cardinality subdomain queries to single domain.
- **Mass-export S3**: volume anomaly per principal.

Each TTP detection is research-intensive to build and maintain. ROI is high — survives multiple campaigns.

## Detection-as-code

Modern detection engineering treats detections as code:
- Detections in version control.
- Sigma format (cross-SIEM).
- Test data + unit tests.
- CI pipeline validates against test cases.
- Production deployment via standard CI/CD.

Tools: Sigma + Sigma converter, Splunk's content updates, Elastic's detection rules repo, Microsoft Sentinel content hub.

## The detection-engineering loop

1. **Threat intelligence** identifies TTPs (see [[cti-collection-management]]).
2. **Engineer detection** — write Sigma / KQL / Splunk rule.
3. **Test** with Atomic Red Team / synthetic data.
4. **Deploy** to SIEM.
5. **Tune** for false-positive rate.
6. **Validate** with red-team exercise.
7. **Document** rationale, references, evidence pattern.
8. **Retire** when obsolete.

## Detection coverage matrix

Track:
- Each detection ↔ MITRE ATT&CK technique.
- Coverage gaps by tactic / technique.
- Confidence per detection.
- Effectiveness measured by red-team / threat-hunt results.

Tools: DeTT&CT, MITRE's own ATT&CK Navigator.

## Common detection-engineering anti-patterns

- **Volume goal**: "we have 1000 rules" — quality > quantity.
- **No tests**: rules not validated; degrade over time.
- **No retirement**: stale rules accumulate.
- **No coverage measurement**: don't know what's missing.
- **Threshold-only**: alert when count > N; misses sophisticated single-event attacks.
- **Single source**: one log source per rule; missing context.

## Workflow to study

1. Read David Bianco's Pyramid of Pain post.
2. Read MITRE ATT&CK getting-started.
3. Map your existing detections to ATT&CK techniques.
4. Identify highest-pain gaps.
5. Build one TTP-level detection.
6. Test with Atomic Red Team.
7. Document and iterate.

## Related

- [[siem-detection-use-case-catalog]]
- [[atomic-red-team-emulation-deep]]
- [[cti-collection-management]]
- [[purple-team-feedback-loop]]
- [[ir-from-source-signals]]
- [[deception-and-honeypot-strategy]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-dprk-lazarus]]
- [[ransomware-affiliate-playbook]]

## References
- [Bianco — "The Pyramid of Pain" (2013)](https://detect-respond.blogspot.com/2013/03/the-pyramid-of-pain.html)
- [MITRE ATT&CK](https://attack.mitre.org/)
- [Sigma rules / SigmaHQ](https://github.com/SigmaHQ/sigma)
- [DeTT&CT](https://github.com/rabobank-cdc/DeTTECT)
- [Florian Roth — detection-engineering writeups](https://www.nextron-systems.com/blog/)
- See also: [[siem-detection-use-case-catalog]], [[atomic-red-team-emulation-deep]], [[cti-collection-management]], [[purple-team-feedback-loop]]
