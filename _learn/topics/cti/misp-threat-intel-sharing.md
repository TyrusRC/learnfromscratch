---
title: MISP — threat intel sharing platform
slug: misp-threat-intel-sharing
---

> **TL;DR:** MISP (Malware Information Sharing Platform) is the de facto open-source TI platform. Communities and ISACs share IOCs, behaviours, and reports as "events" with structured attributes (`md5`, `ip-src`, `domain`, `mutex`, etc.). MISP federates between instances, integrates with SIEMs (Splunk, Sentinel, Elastic), exports to STIX/TAXII, and feeds NIDS rule generation.

## What it is
MISP is a LAMP-stack PHP application originally built by CIRCL Luxembourg. Core concepts:
- **Event** — a thematic container (campaign, malware family, incident) with attributes and objects
- **Attribute** — a single IOC of typed value (IP, domain, hash, URL, mutex, registry key, etc.) with category and tags
- **Object** — composite attribute group (file = filename + md5 + sha256 + magic; person = email + name + phone)
- **Tag / Taxonomy** — controlled vocabularies (TLP, MITRE ATT&CK, kill chain phase, sector)
- **Galaxy** — high-level concept (threat actors, malware families, tools) linked from events
- **Sharing group** — recipients of an event (own org, sector ISAC, public)

## Preconditions / where it applies
- Threat intel team or 24/7 SOC consuming feeds beyond raw blocklists
- Capacity to triage IOCs (false positives are common in shared feeds)
- Integration ownership — MISP without SIEM connection is a wiki

## Tradecraft

**Standard deployment:**

```bash
docker run -d -p 80:80 -p 443:443 --name misp \
  -e MYSQL_HOST=db -e MYSQL_USER=misp \
  coolacid/misp-docker:core-latest
# Or production Ansible: github.com/MISP/misp-ansible
```

**First-week checklist:**
1. Configure organisation identity (`UUID`, `nationality`, `sector`)
2. Enable default feeds: CIRCL OSINT, abuse.ch (URLhaus, ThreatFox, MalwareBazaar), AlienVault OTX
3. Set TLP defaults (TLP:AMBER for internal, TLP:WHITE for shareable)
4. Wire to SIEM (Splunk MISP42 app / Sentinel TI Indicators connector)
5. Configure Tor for safer attribute browsing (visiting attacker URLs leaks IPs without it)
6. Enable Galaxies (threat actor library) — they're huge but invaluable

**Event creation workflow:**

```python
from pymisp import PyMISP, MISPEvent, MISPAttribute, MISPObject

misp = PyMISP('https://misp.org', 'API_KEY', False)
e = MISPEvent()
e.info = 'Phishing wave targeting finance sector – 2025-12'
e.distribution = 1  # this community
e.threat_level_id = 2
e.analysis = 2

# Add IOCs
e.add_attribute('domain', 'evil-bank-login.tld', category='Network activity', to_ids=True)
e.add_attribute('md5', '5d41402abc4b2a76b9719d911017c592', category='Payload delivery', to_ids=True)

# Add file object (groups related attributes)
fo = MISPObject('file')
fo.add_attribute('filename', value='invoice.pdf.exe')
fo.add_attribute('md5', value='5d41402abc4b2a76b9719d911017c592')
fo.add_attribute('sha256', value='...')
e.add_object(fo)

# Tag with MITRE technique
e.add_tag('misp-galaxy:mitre-attack-pattern="Phishing - T1566"')
e.add_tag('tlp:amber')

misp.add_event(e)
```

**Consuming via SIEM:**

Splunk: `MISP42` app pulls `to_ids=true` attributes into lookup tables, runs them against `network_traffic` index every 5 min, generates `notable_events`.

Sentinel: TI Indicators graph connector via MISP-to-Sentinel script; supports TLP-based filtering.

Elastic: Filebeat MISP module pulls events, indexes attributes; Detection Rules match `network.community_id` / DNS / process arguments.

**Decay model.** Modern MISP has `decayingModel` — IOC quality degrades over time (1 week for IPs, 90 days for hashes, etc.). Avoids stale-IOC false positives:

```python
misp.set_attribute_decay_model(attribute_uuid, model_uuid='Polynomial decay')
```

**Sharing communities to know:**
- CIRCL — Luxembourg CERT, broad public feed
- Sector ISACs: FS-ISAC (finance), H-ISAC (healthcare), E-ISAC (electricity), AUTO-ISAC
- ENISA / national CERTs (each EU member has one)
- Internal-org-only MISP for SOC-to-SOC sharing in enterprise

**Export formats** for downstream tools:
- STIX 2.1 (`misp-stix-converter`) — universal interchange
- TAXII 2.1 server endpoint built-in
- Suricata / Snort rules — auto-generated from `to_ids` attributes
- YARA — extracted from `yara` attribute type
- Zeek intel framework feed — built-in exporter ([[zeek-network-detection]])
- Bro/Zeek, Bind RPZ, Squid, OpenIOC, MISP-Splunk format

**Tradecraft: enriching events.**
MISP modules call out to VirusTotal, urlscan, Shodan, AbuseIPDB on demand. One click against a hash brings back VT detection rate, AV names, first-seen — all attached as enrichment attributes.

## OPSEC for blue team

- TLP discipline: never share TLP:RED outside the originator's org; tooling won't enforce, your humans must
- Sharing groups: review every event's sharing scope before publish; private TLP:AMBER published as TLP:WHITE has burned operations
- Browsing attacker infra: use the Tor / VPN integration — attribute "lookup" hits the URL from MISP server's IP otherwise
- API key rotation: MISP keys = SIEM lookup permissions = full event read. Rotate quarterly
- Sync between instances: pull side prefers `published=true` only; misconfigured push side overwrites recipient drafts. Test sync direction in lab first

## Anti-patterns

- Trusting every shared IOC: false-positive cleanup is the analyst's job. Curate before push to SIEM
- Tagging without taxonomy: free-text tags break MISP-wide search and analytics — use the bundled taxonomies
- One mega-event per quarter: events should be incident- or campaign-scoped for downstream correlation
- Ignoring sightings: the `sighting` model lets you record "we saw this IOC", building shared confidence; under-used in practice

## References
- [MISP project](https://www.misp-project.org/)
- [PyMISP docs](https://pymisp.readthedocs.io/)
- [MISP taxonomies](https://www.misp-project.org/taxonomies.html)
- [MISP galaxies](https://www.misp-project.org/galaxy.html)
- [CIRCL MISP training material](https://www.misp-project.org/misp-training/)

See also: [[cti-collection-management]], [[detection-engineering-pyramid-of-pain]], [[threat-hunting-methodology]], [[sigma-rules-detection-as-code]], [[zeek-network-detection]], [[wazuh-open-source-siem]], [[velociraptor-threat-hunting]], [[soc-runbook-design]], [[mssp-mdr-vendor-relationships]]
