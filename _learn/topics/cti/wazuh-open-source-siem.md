---
title: Wazuh — open-source SIEM/XDR
slug: wazuh-open-source-siem
---

> **TL;DR:** Wazuh is a forked-from-OSSEC HIDS extended into a full SIEM/XDR with manager nodes, agents (Windows/Linux/macOS/Docker), OpenSearch-based indexer, and a Kibana-derivative dashboard. Free, GPLv2, scales to thousands of endpoints; popular SOC stack for budget-constrained teams or as the first SIEM before a Splunk migration.

## What it is
Wazuh architecture has four moving parts:
- **Agent** — runs on endpoints; collects logs, file integrity, registry, syscall (Auditd / Sysmon), MITRE ATT&CK aligned rule hits, vulnerability inventory
- **Manager** — receives agent data, runs decoders + rules, triggers active response
- **Indexer** — OpenSearch cluster storing events
- **Dashboard** — OpenSearch Dashboards (Kibana fork) with Wazuh app

Rules + decoders are XML; community rule corpus maps to MITRE ATT&CK and includes Sysmon, AWS, GCP, Office 365, GitHub, Zeek, Suricata sources.

## Preconditions / where it applies
- Sufficient hardware: minimum 8 GB RAM manager, 16 GB indexer for ~500 agents
- Endpoint coverage plan: which hosts need agents vs. log-forwarding only
- Existing log sources to forward (firewall, EDR, Cloud)

## Tradecraft

**Quick all-in-one install (lab):**

```bash
curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
# Dashboard at https://server:443, default admin password printed
```

For production split: separate VM per component (`-wi`, `-ws`, `-wd`).

**Agent deployment:**

```bash
# Linux
curl -sO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.0-1_amd64.deb
WAZUH_MANAGER='10.0.0.5' dpkg -i wazuh-agent_4.7.0-1_amd64.deb
systemctl enable --now wazuh-agent
```

```cmd
:: Windows MSI
msiexec.exe /i wazuh-agent-4.7.0-1.msi /q WAZUH_MANAGER="10.0.0.5"
NET START WazuhSvc
```

**Data sources to enable on day one:**
- Sysmon — drop config (SwiftOnSecurity), Wazuh decoder parses every event
- Auditd on Linux — Wazuh's MITRE-mapped auditd ruleset
- Cloud: AWS CloudTrail, GCP Audit, Office 365, Azure
- Firewall syslog (pfSense, FortiGate, Palo)
- Kubernetes audit logs
- Zeek logs ([[zeek-network-detection]]) — wazuh-zeek module

**Active response — automatic IR action:**

```xml
<!-- ossec.conf -->
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>5710</rules_id>  <!-- SSH brute force -->
  <timeout>600</timeout>
</active-response>
```

Triggers `iptables -A INPUT -s SRC -j DROP` on the agent host. Risky in prod — start with notify-only.

**Custom rule example:**

```xml
<!-- /var/ossec/etc/rules/local_rules.xml -->
<group name="suspicious_powershell,">
  <rule id="100100" level="12">
    <if_sid>91802</if_sid>  <!-- parent: PowerShell ScriptBlock -->
    <field name="win.eventdata.scriptBlockText" type="pcre2">
      (DownloadString|FromBase64String|IEX|Invoke-Expression)
    </field>
    <description>Suspicious PowerShell scriptblock</description>
    <mitre><id>T1059.001</id></mitre>
  </rule>
</group>
```

Restart manager: `systemctl restart wazuh-manager`. Hits show up in dashboard under MITRE Discover within a minute.

**Vulnerability detector** — built-in CVE scanning per agent:

```xml
<vulnerability-detector>
  <enabled>yes</enabled>
  <interval>5m</interval>
  <run_on_start>yes</run_on_start>
  <provider name="redhat"><enabled>yes</enabled></provider>
  <provider name="canonical"><enabled>yes</enabled></provider>
  <provider name="msu"><enabled>yes</enabled></provider>
  <provider name="nvd"><enabled>yes</enabled></provider>
</vulnerability-detector>
```

Inventory each agent's installed packages, match against NVD + vendor feeds. Replaces low-end VM scanner for many SMBs.

**File integrity monitoring (FIM):**

```xml
<syscheck>
  <directories check_all="yes" report_changes="yes" realtime="yes">/etc</directories>
  <directories check_all="yes" realtime="yes">/var/www/html</directories>
  <ignore>/etc/mtab</ignore>
  <ignore type="sregex">.log$</ignore>
</syscheck>
```

Real-time FIM uses inotify on Linux, ETW on Windows — alerts on writes within seconds.

**Detection content sources:**
- Wazuh ruleset (default, ~3,000 rules)
- Atomic Red Team integration tests for verification
- SOCFortress free rule packs
- Sigma → Wazuh converter (manual mapping) — see [[sigma-rules-detection-as-code]]

**Integration patterns:**
- SOAR: TheHive + Cortex ingestion via Wazuh API
- TI: MISP IOC sync into custom_lists, matched in rules ([[misp-threat-intel-sharing]])
- EDR: forward CrowdStrike / Defender JSON via API to Wazuh for unified dashboarding
- Slack / Discord webhooks via custom integration script
- Compliance reports built-in: PCI DSS, HIPAA, NIST 800-53, GDPR, TSC SOC 2

## OPSEC for blue team

- Wazuh manager listens on 1514 UDP / 1515 TCP — restrict via firewall; agent auth is per-key but the registration channel (1515) is sensitive
- OpenSearch admin panel exposed at 9200 — never publish; use VPN or reverse proxy with mTLS
- Rule changes hot-reload but mistakes silently fail; tail `/var/ossec/logs/ossec.log` after every restart
- Active response can disrupt production — start with `restart-wazuh` (no-op) before firewall drops
- Vulnerability detector pulls full NVD JSON nightly — ensure egress allowed; offline-mode supports air-gapped install

## When NOT to pick Wazuh

- Multi-petabyte log volumes: OpenSearch scaling hits cost wall earlier than Splunk SmartStore or Elastic frozen tier
- Heavy SOAR requirement: Wazuh has hooks but no native SOAR; pair with TheHive/Cortex
- Compliance with FedRAMP / classified env: GovCloud-style hosting story is weak compared to commercial
- Endpoint EDR depth: Wazuh HIDS is solid but not on par with CrowdStrike / Defender for Endpoint behavioural detection

## References
- [Wazuh docs](https://documentation.wazuh.com/)
- [Wazuh ruleset GitHub](https://github.com/wazuh/wazuh-ruleset)
- [SOCFortress detection content](https://www.socfortress.co/)
- [The Open Source SIEM (Wazuh) book](https://www.packtpub.com/) — practitioner walkthrough
- [Wazuh Discord community](https://wazuh.com/community/)

See also: [[sigma-rules-detection-as-code]], [[misp-threat-intel-sharing]], [[zeek-network-detection]], [[chainsaw-evtx-hunting]], [[hayabusa-windows-event-log-triage]], [[velociraptor-threat-hunting]], [[soc-runbook-design]], [[detection-engineering-pyramid-of-pain]], [[siem-detection-use-case-catalog]], [[atomic-red-team-emulation-deep]]
