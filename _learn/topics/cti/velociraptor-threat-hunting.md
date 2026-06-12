---
title: Velociraptor — fleet hunting and live IR
slug: velociraptor-threat-hunting
---

> **TL;DR:** Velociraptor (Rapid7-owned, AGPL-3.0) is an endpoint-agent + server platform for fleet-wide hunting via VQL — SQL-like queries that pull artefacts (KAPE-equivalent collection, registry reads, process introspection, EVTX search) from thousands of hosts in parallel. It's the open-source backbone of modern incident response.

## What it is
Velociraptor consists of:
- A single binary that runs as **server** (multi-host) or **client** (endpoint agent), based on config
- **Artefacts** — VQL scripts in YAML defining collection logic (community-maintained at `artifacts/`)
- **Hunts** — fleet-wide artefact runs targeting selected clients
- **Notebooks** — Jupyter-style VQL workbench for ad hoc analysis

## Preconditions / where it applies
- Need agents installed (MSI, EXE, deb, rpm) or live-binary mode (`velociraptor.exe -i` standalone collection)
- Server reachable from clients (default port 8000 with self-signed CA bundled per deployment)
- VQL knowledge — small DSL but distinct from SQL

## Tradecraft

**Standalone collection (no server — ideal for single-host IR):**

```cmd
velociraptor.exe -v artifacts collect Windows.KapeFiles.Targets \
  --args "Device=C:" --args "_SANS_Triage=Y" --output triage.zip
```

The `Windows.KapeFiles.Targets` artefact ports KAPE Targets to VQL; no separate KAPE install needed. See [[kape-triage-collection]] for the same artefact list.

**Hunt for a specific IOC across the fleet:**

```sql
-- Notebook query, runs on all selected clients
SELECT FullPath, Size, Mtime, Hash.SHA256 AS sha256
FROM glob(globs="C:/Windows/Temp/*.exe")
WHERE Hash.SHA256 = '8f7b...'
```

Or run via Hunt UI: pick artefact `Windows.Search.FileFinder`, parameter `SHA256=8f7b...`, target `All clients`. Results stream back as each agent reports.

**Live process introspection (no LOLBins):**

```sql
SELECT Pid, Name, CommandLine, CreateTime, Username
FROM pslist()
WHERE Name =~ 'powershell.exe'
  AND CommandLine =~ '(?i)downloadstring|invoke-expression|frombase64string'
```

**Memory acquisition from active malware on a remote host:**

```sql
SELECT * FROM Artifact.Windows.Memory.Acquisition(
  Pid=4123,
  OutputDir='C:/Temp')
```

Velociraptor uses winpmem under the hood; resulting RAW can be piped to [[volatility-plugins]].

**Persistent hunt for new privileged process tree** — runs continuously:

```sql
-- Artifact: Generic.Detection.Yara.Process — scans process memory with YARA
-- Schedule via Server.Audit.PolicySync to apply across fleet
```

**Live EVTX hunting (the SOC-grade alternative to KAPE+Hayabusa for fleets):**

```sql
SELECT * FROM Artifact.Windows.EventLogs.Hayabusa(
  EvtxGlob="C:/Windows/System32/winevt/Logs/*.evtx",
  Level="high")
```

Yes — Velociraptor literally embeds Hayabusa as an artefact. Fleet-wide Sigma hunting in one query.

**Quarantine a host while you investigate:**

```sql
SELECT * FROM Artifact.Windows.Remediation.Quarantine()
-- Sets host into isolation: only the Velociraptor server can reach it
```

**Useful built-in artefacts to memorise:**
- `Windows.Sys.Users` — local + cached logons
- `Windows.System.Pslist` — process tree with hashes
- `Windows.Registry.NTUser.Run` — autoruns
- `Generic.Forensic.LocalHashes.Glob` — file hash sweep
- `Windows.Network.Netstat` — open connections + owning process
- `Linux.Network.Connections` — same on Linux
- `Windows.System.AmcacheReport` — recent executions

## Detection and defence (analyst tradecraft)

- Keep server in a hardened VPC; the GUI gives full LOLBin-equivalent capability — server compromise = fleet compromise
- Use roles: `analyst` (read-only + run hunts), `administrator` (deploy artefacts, modify clients), `api` (script integration)
- Sign custom artefacts before deploying — unsigned VQL can be rejected by client policy
- Velociraptor hunt notifications create rows in the Audit log; ingest into SIEM so legitimate IR is distinguishable from rogue admin use
- Default client polling 10s; for stealthy hunts set 60s+ to reduce footprint

## OPSEC for defenders

- VQL is recorded server-side; treat case-relevant queries as evidence
- Hunts targeting "All clients" with broad artefacts (FileFinder over `C:\*`) generate huge result sets — scope by OS, label, or hostname pattern first
- If the attacker has Velociraptor server access, they get unbounded reach. Treat server admin creds as Tier-0
- For air-gapped or low-bandwidth segments, use Velociraptor's collector binary to acquire offline, then upload archives to the server

## References
- [Velociraptor docs](https://docs.velociraptor.app/)
- [Velociraptor artefact reference](https://docs.velociraptor.app/artifact_references/)
- [VQL reference](https://docs.velociraptor.app/vql_reference/)
- [Rapid7 — Velociraptor blog](https://www.rapid7.com/blog/tag/velociraptor/)

See also: [[kape-triage-collection]], [[hayabusa-windows-event-log-triage]], [[chainsaw-evtx-hunting]], [[volatility-plugins]], [[memory-image-forensics]], [[threat-hunting-methodology]], [[hypothesis-driven-hunting]], [[ir-from-source-signals]], [[atomic-red-team-emulation-deep]]
