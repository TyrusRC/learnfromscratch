---
title: Zeek — network detection at protocol layer
slug: zeek-network-detection
---

> **TL;DR:** Zeek (formerly Bro) is a network-traffic analysis platform: protocol parsers (>50, including HTTP, TLS, DNS, SMB, Kerberos, LDAP, MQTT) plus a scripting language that emits structured logs and lets defenders write detection logic at the protocol-event layer. Standard companion to Suricata / EDR for visibility outside the host.

## What it is
Zeek inspects packets via libpcap or AF_PACKET, parses them into protocol events (`http_request`, `dns_request`, `ssl_client_hello`, `kerberos_as_request`), and writes per-protocol structured logs (`conn.log`, `http.log`, `dns.log`, `ssl.log`, `x509.log`, `kerberos.log`). The Zeek script engine runs detection logic on events, supporting state, time series, and bro-cluster scale.

## Preconditions / where it applies
- Network tap or SPAN port at egress / inter-VLAN / DC ingress
- Sufficient throughput (Zeek scales horizontally via `zeek-cluster` workers)
- TLS visibility: Zeek sees SNI, JA3, JA3S, cert chain — but not decrypted bodies unless MITM proxy present

## Tradecraft

**Quickstart on a single sensor:**

```bash
apt install zeek
zeekctl deploy
# Logs land in /opt/zeek/logs/current/
tail -F /opt/zeek/logs/current/conn.log
```

**Standard logs and what they answer:**
- `conn.log` — every flow with duration, bytes, history flags ("ShAdFa" = SYN, SYN-ACK, ACK, data, FIN, ACK)
- `http.log` — URI, host, user-agent, status, response MIME, file SHA-1
- `dns.log` — query, response, TTL, query type
- `ssl.log` — version, cipher, SNI, JA3, JA3S, established/abort
- `x509.log` — cert chain when full handshake captured
- `kerberos.log` — request_type, client, service, cipher, success/failure
- `smb_files.log` / `smb_mapping.log` — SMB share access
- `ntlm.log` — NTLM auth attempts (visibility into [[ntlm-relay]])
- `software.log` — Zeek's passive software fingerprinting
- `weird.log` — protocol anomalies (RFC violations)
- `notice.log` — alerts fired by scripts

**High-value detections out of the box:**
- `Notice::SSH::Brute_Force_Login` — N failed SSH from same IP
- `Scan::Address_Scan` — host hitting many destinations
- `Conn::Connection_Refused` aggregation
- `SSL::Invalid_Server_Cert` — TLS errors on outbound C2

**Custom detection — write a script:**

```zeek
# File: kerberos_asreproast.zeek
@load policy/protocols/kerberos
event kerberos_as_request(c: connection, msg: KRB::AS_Req) {
    if ( ! msg$pa_data?$pa_enc_timestamp )
        # No PA-ENC-TIMESTAMP → AS-REP roastable
        NOTICE([$note=Kerberos::ASREP_Roastable,
                $msg=fmt("Pre-auth disabled for %s", msg$client_name),
                $conn=c]);
}
```

Load via `local.zeek`, restart with `zeekctl deploy`. Hits land in `notice.log` and Splunk/Elastic if shipped.

**Detection examples worth knowing:**

```zeek
# DGA-style DNS — many subdomains queried from one host, all 1-time
event dns_request(c: connection, msg: dns_msg, query: string, qtype: count, qclass: count) {
    add_dns_query_set[c$id$orig_h][query];
    if (|dns_query_set[c$id$orig_h]| > 200 && interval_to_double(network_time() - first_seen[c$id$orig_h]) < 60.0)
        NOTICE([$note=DNS::Possible_DGA, $src=c$id$orig_h]);
}

# Detect Kerberoasting — TGS-REQ for SPN with weak encryption
event krb_tgs_request(c: connection, msg: KRB::KDC_Req) {
    for ( i in msg$enc_type ) {
        if ( msg$enc_type[i] == 23 )  # RC4_HMAC
            NOTICE([$note=Kerberos::Suspected_Kerberoasting, $conn=c]);
    }
}
```

**File extraction** (zeek can carve files from HTTP/SMB/FTP/email):

```zeek
@load policy/frameworks/files/extract-all-files
# Caps at frameworks/files/main.zeek configurable
```

Carved files land in `extract_files/`; feed to YARA / EDR sandbox.

**JA3 / JA3S signatures for C2** — Zeek logs both by default. Block-list known-bad JA3 corpus (CrowdSec, abuse.ch SSLBL).

## Integration with detection stack

- **Sigma → Zeek**: pysigma backend for Zeek emits notice scripts
- **Suricata + Zeek pairing**: Suricata for signature-based alerts (rule corpus), Zeek for protocol context + bespoke detections. Same tap, different lenses
- **Elastic / Splunk / Sentinel ingestion**: Filebeat zeek module, Splunk Add-on for Zeek, Sentinel via Logstash
- **Corelight** is the commercial Zeek distro with extra parsers (SAML, OAuth, custom enterprise protocols); same script language

**Recommended scripts to load on day one:**

```zeek
@load policy/protocols/ssl/validate-certs
@load policy/protocols/ssl/notary
@load policy/protocols/conn/known-hosts
@load policy/protocols/conn/known-services
@load policy/protocols/dns/detect-external-names
@load policy/protocols/ftp/detect
@load policy/protocols/smb/log-cmds
@load policy/protocols/ssh/detect-bruteforcing
@load policy/protocols/ssl/heartbleed
@load policy/frameworks/intel/seen
@load policy/frameworks/intel/do_notice
```

**Intel framework — ingest IOC feeds:**

```
# /opt/zeek/share/zeek/site/intel.dat
#fields indicator    indicator_type    meta.source
1.2.3.4              Intel::ADDR       MISP
evil.tld             Intel::DOMAIN     ThreatFox
```

Zeek matches these against every flow and emits `intel.log`.

## OPSEC for blue team

- Zeek tap at egress = highest signal-to-noise. Inside-VLAN tap is noisier but catches lateral movement
- TLS inspection requires MITM proxy (Zscaler / Symantec / Decryptor); without it, you see SNI + JA3 only
- Sampling kills detection — never sample for security Zeek. Drop packets at NIC if overloaded; sampling biases statistics
- Zeek scripts run synchronously per event — heavy custom scripts cause packet drop. Profile via `cluster.log` worker stats
- Disk: conn.log alone fills ~50 GB/day on a 1 Gbps enterprise — plan retention (~7d hot, 30d cold)

## Adversary considerations (what Zeek CATCHES vs MISSES)

Catches:
- C2 beaconing with regular interval (jitter aside) — `conn.log` history pattern
- DNS tunnelling ([[dns-c2-and-icmp-c2]]) — query length, entropy, frequency
- TLS C2 with known bad JA3
- NTLM auth from unusual source/dest ([[ntlm-relay]])
- LDAP query spikes from non-AD-tool hosts (BloodHound footprint)
- Kerberos enc_type=23 (RC4) — Kerberoasting marker

Misses:
- HTTP/2 inside TLS without decryption
- Encrypted DNS (DoH / DoT) when not proxied
- C2 over legitimate cloud services (Slack, Discord webhooks) without app-layer parsers
- HTTP/3 / QUIC — partial parser, evolving
- Compromised host-internal activity invisible from network

## References
- [Zeek docs](https://docs.zeek.org/)
- [Zeek script reference](https://docs.zeek.org/en/master/script-reference/index.html)
- [Corelight blog](https://corelight.com/blog) — practitioner detection writeups
- [Active Countermeasures — Threat Hunting with Zeek](https://www.activecountermeasures.com/)
- [Awesome Zeek](https://github.com/zeek/awesome-zeek)

See also: [[sigma-rules-detection-as-code]], [[hayabusa-windows-event-log-triage]], [[chainsaw-evtx-hunting]], [[threat-hunting-methodology]], [[detection-engineering-pyramid-of-pain]], [[misp-threat-intel-sharing]], [[wazuh-open-source-siem]], [[velociraptor-threat-hunting]], [[soc-runbook-design]]
