---
title: "Recon → foothold"
slug: recon-to-foothold
aliases: [recon-playbook, scan-now-what]
mermaid: true
---

> **TL;DR.** You ran a scan. Some ports came back. This playbook
> picks the next move per service so you spend time on the things
> most likely to give a foothold.

## Top-level flow

```mermaid
flowchart TD
    A[Nmap / masscan output in hand] --> B{Any obvious low-hanging service?}
    B -- "21 / 23 / 25 / 110 / 161 / 6379 / 27017 / 9200 / 11211" --> C[Try unauth or default-cred first]
    B -- "445 SMB" --> D[SMB triage branch]
    B -- "389 / 636 LDAP" --> E[LDAP triage branch]
    B -- "88 Kerberos" --> F[Kerberos triage branch]
    B -- "80 / 443 / 8080 / 8443 HTTP(S)" --> G[Web triage branch]
    B -- "22 SSH" --> H[Banner + version check, spray only if creds]
    B -- "3389 RDP" --> I[Cert + NLA check; cred spray only if you have lists]
    B -- "5985 / 5986 WinRM" --> J[Try evil-winrm with any user/hash you have]
    B -- "1433 / 3306 / 5432 DB" --> K[Default creds + version CVE search]
    C --> Z[Document, dump, move on]
    D --> Z
    E --> Z
    F --> Z
    G --> Z
    H --> Z
    I --> Z
    J --> Z
    K --> Z
    Z --> AA{Foothold yet?}
    AA -- yes --> BB[Switch to relevant privesc playbook]
    AA -- no --> CC[Re-scan UDP / full-port / vhost / specific CVEs]
```

## SMB branch (445 open)

```mermaid
flowchart TD
    A[SMB 445 reachable] --> B[Run NetExec smb / nxc smb -u '' -p '']
    B --> C{Signing disabled?}
    C -- yes --> D[Relay candidate — see ntlm-relay-ws2025-mitigations]
    C -- no --> E[Continue enum]
    E --> F[List shares anonymously]
    F --> G{Anonymous share access?}
    G -- yes --> H[Pull files, look for credentials / config / GPP]
    G -- no --> I[smb-enum: RID-cycle, SAM enum, RPC enum]
    I --> J{Got usernames?}
    J -- yes --> K[Password-spray sensibly — see password-spraying]
    J -- no --> L[Move on; revisit with creds later]
    H --> M[Pivot per file content]
    K --> M
```

## LDAP branch (389/636 open)

```mermaid
flowchart TD
    A[LDAP reachable] --> B{Anonymous bind?}
    B -- yes --> C[ldapsearch -x — pull defaultNamingContext, users, groups]
    B -- no --> D[Need any creds — fall back to other vectors first]
    C --> E[Look for: description fields with passwords, asreproastable users, kerberoastable SPNs]
    E --> F[Open ldap-enumeration]
```

## Kerberos branch (88 open)

```mermaid
flowchart TD
    A[Kerberos 88 open] --> B[kerbrute userenum with common-name list]
    B --> C{Got valid usernames?}
    C -- yes --> D[asreproast attempt — see asreproast]
    C -- no --> E[Skip; come back with a user list]
    D --> F{Hash returned?}
    F -- yes --> G[hashcat -m 18200 -a 0 hash wordlist]
    F -- no --> H[Pre-auth enforced — try other vectors]
```

## Web branch (80/443/8080/8443 open)

```mermaid
flowchart TD
    A[Web port open] --> B[whatweb / Wappalyzer / response headers]
    B --> C{Known CMS or framework?}
    C -- "WordPress" --> D[wpscan — plugin / theme CVEs]
    C -- "Drupal / Joomla / AEM" --> E[CMS-specific scanner + per-version CVEs]
    C -- generic --> F[Vhost brute + content discovery — see content-discovery]
    D --> Z[Open web-triage playbook]
    E --> Z
    F --> Z
```

## Default-creds quick wins (multiple ports)

```mermaid
flowchart TD
    A[Service identified] --> B{Default credentials documented?}
    B -- yes --> C[Try them — Tomcat Manager / Jenkins / Jira / Confluence / Solr / Elasticsearch / Kibana / Gitlab / Grafana]
    B -- no --> D[Move on]
    C --> E{Auth bypass?}
    E -- yes --> F[Pivot per service — Tomcat war upload, Jenkins script console, etc.]
    E -- no --> G[Try light brute with known-username list]
```

## When nothing works

```mermaid
flowchart TD
    A[Initial scan exhausted, no foothold] --> B[Run UDP top-100 ports]
    B --> C[Full TCP scan -p- if not done]
    C --> D[Vhost brute + subdomain recon]
    D --> E[Try external recon: GitHub leaks, employee email enum, cert transparency]
    E --> F{Anything new?}
    F -- yes --> G[Restart this playbook]
    F -- no --> H[Engagement-specific — phishing, physical, or stop and report]
```

## Where to go next

- Got SMB foothold → [[windows-privesc-playbook]] or
  [[ad-attack-path-playbook]] depending on environment.
- Got web shell → [[linux-privesc-playbook]] usually.
- Got domain-user creds → [[ad-attack-path-playbook]].
- Got nothing — restart with broader recon, see [[bug-bounty-workflow]]
  for the methodology angle.
