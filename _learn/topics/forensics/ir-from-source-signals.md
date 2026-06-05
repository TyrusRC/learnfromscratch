---
title: Incident response from source signals
slug: ir-from-source-signals
aliases: [ir-from-source, defender-whitebox]
---

{% raw %}

> **TL;DR:** When an incident hits, the IR team's fastest pivots come from *source-side signals*: what the codebase logs, what telemetry the deployed app emits, what audit trails the framework offers by default. A team that reviewed those signals before the incident answers "what happened" in minutes; a team that didn't spends days. This is the defender's whitebox companion to [[edr-rules-as-code-from-attack-patterns]] and a counterpart to [[blind-vuln-confirmation-from-source]].

## The defender's whitebox pass

Pre-incident, walk the codebase asking:

1. What sensitive operations occur?
2. What does each operation log? At what level? Where does the log go?
3. What's missing — operations that *should* log and don't?
4. What identifying context (user ID, IP, request ID) is in each log?
5. What's the retention?

The output is a *signal map*: per-operation list of where to look during IR.

## Standard log sources (Linux / containerised web app)

- `stdout` of each container — captured by orchestrator (Kubernetes → Loki/Splunk/ELK).
- `journald` on the host.
- Application logs to file (less common in containerised; rotation rules).
- Audit logs at the framework level — Django auditlog, Rails papertrail.
- Database audit — Postgres `pgaudit`, MySQL `audit_plugin`.
- Cloud-side — AWS CloudTrail, GCP Cloud Audit Logs, Azure Activity Log.
- Reverse-proxy access logs — nginx, envoy.
- WAF logs.

## Operations to confirm are logged

For every web/API app:

| Operation | Why audit-worthy |
|---|---|
| Login (success + failure) | Detect brute-force, password spraying |
| Logout | Bound session lifetime in IR |
| Password reset request + complete | Account takeover signals |
| MFA enrolment / disablement | High-value compromise indicator |
| Permission changes | Privilege escalation |
| Data export / download | Exfiltration |
| Settings changes (notification routing, webhook URLs) | Persistence |
| Admin action by non-admin | Forbidden but worth recording the attempt |
| Failed authorization checks | Recon / probing |

If any of these aren't logged → finding for pre-incident review.

## What context every log line should have

The "five W's" for IR:

| Field | Why |
|---|---|
| Timestamp (UTC, ISO 8601, ms precision) | Correlation across sources |
| Actor (user ID, service account, anonymous) | Whose action |
| Resource ID | Which data |
| Action | What they did |
| Source IP | Where they came from |
| Request ID | Correlate to access logs |
| Result (success / fail / denied) | Filter quickly |
| Reason for denial (if denied) | Distinguish authz vs validation |

A log line missing any one of these forces an analyst to manually correlate; speed lost is response cost.

## Source-review angle

```bash
# Find logger calls
grep -rn 'logger\.\|log\.info\|log\.warn\|log\.error\|console\.log' src/

# Find sensitive ops that should log but might not
grep -rnE 'login|reset|change_password|grant|revoke|export|delete' src/
```

For each sensitive op, confirm a log entry with the required fields. Common gaps:
- Logging `username` but not `IP` → analyst must join with reverse-proxy log.
- Logging the success but not the failure → "all looks normal" while passwords are being sprayed.
- Logging at `DEBUG` level which production filters out → log lost.
- Logging in synchronous handler that fails the request if logger blocks → log skipped, request continues.

## Common framework defaults

### Django
- `django.contrib.admin` logs every admin action to `LogEntry`.
- `django.contrib.auth` does not log login by default — opt in via signal handlers.
- `django-axes` adds login attempt logging.

### Rails
- ActionController logs requests; doesn't audit data changes.
- `audited` gem or `papertrail` for model-level audit.

### Spring
- Actuator's `/actuator/audit` endpoint with `AuditEventRepository`.
- Spring Security default logs login via `AuthenticationSuccessEvent` etc., must be wired to a logger.

### Express / NestJS
- No built-in audit; rely on `morgan` for access logs + manual instrumentation.

### Go (gin/fiber)
- Same — manual instrumentation.

## What logs *not* to write

- Passwords, tokens, secrets, full JWT bodies.
- PII beyond what the legal team has approved.
- Large request bodies that include credit card numbers, SSNs.
- File contents from sensitive paths.

Pre-incident verification:
```bash
grep -rnE 'log.*password|log.*token|log.*secret' src/
```

Findings here are immediate fixes, not "for next sprint".

## Cloud-side correlation

A web-app IR usually needs:
- Application logs (the immediate "what").
- Reverse-proxy logs (validate source IP, full URL).
- Cloud control-plane logs (any AWS/Azure/GCP API call the app made).
- Database audit logs (data accessed).
- Authentication provider logs (Okta, Auth0, Azure AD).

Each lives in a different place; IR is the join. Pre-incident, document the *join keys* and *retention*. A 30-day app-log retention paired with 90-day proxy-log retention means you can't correlate older incidents.

## A worked example

Incident: customer reports "I see records I shouldn't have access to".

IR pivots:
1. Application log for the customer's user ID — what queries did they run?
2. Database audit for those query IDs — what data returned?
3. Application log for the *other* user (the data owner) — were they active around the leak?
4. Authentication provider — was the customer's account compromised, or is the leak genuine in-product?
5. Reverse-proxy log — is the source IP the customer's known IP or new?

If step 1 fails ("we don't log per-user queries"), the IR moves to forensics (database snapshots, slow-query log if enabled). If step 2 fails, the IR escalates from "data leak" to "data-leak with unknown scope".

## Designing for IR

For each new service, the pre-deploy checklist includes:
- [ ] Sensitive operations have audit-grade logging.
- [ ] Log fields include the five Ws.
- [ ] Logs ship to central system within 60s.
- [ ] Retention meets policy.
- [ ] No secrets logged.
- [ ] Sample query: "show all actions by user X in the last 24h" runs in < 60s.

A team that runs that checklist at deploy time has half the IR work pre-done.

## Reporting from source signals

When IR closes an incident, the postmortem includes:
- Timeline reconstructed from logs.
- Source signal *gaps* the IR identified.
- Action items to add logging at those gaps.

The IR-from-source-signals loop closes when the team can run the next incident *with* those gaps filled.

## References
- [Google SRE Book — Postmortems](https://sre.google/sre-book/postmortem-culture/)
- [PagerDuty — Incident Response documentation](https://response.pagerduty.com/)
- [SANS — Forensics & Incident Response](https://www.sans.org/cyber-security-courses/)
- [NIST SP 800-61 — Computer Security Incident Handling Guide](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
- See also: [[edr-rules-as-code-from-attack-patterns]], [[secure-sdlc-rollout-playbook]], [[appsec-maturity-checklist]], [[blind-vuln-confirmation-from-source]]

{% endraw %}
