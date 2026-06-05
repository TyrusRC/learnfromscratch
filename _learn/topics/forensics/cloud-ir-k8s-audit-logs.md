---
title: Kubernetes audit log incident response
slug: cloud-ir-k8s-audit-logs
aliases: [k8s-audit-log-ir, kubernetes-ir]
---

> **TL;DR:** Kubernetes API server emits structured audit events for every request. IR centres on three streams: API server audit log, container runtime events (containerd/CRI-O), and host kernel-level activity (Falco / Tracee / eBPF). Practical flow: identify the suspicious request, trace the identity (user / SA), trace pod lifecycle, examine runtime events for exec / mount / network behaviour. Companion to [[k8s-rbac-abuse]] and [[container-runtime-escapes-modern]].

## What the audit log captures

The API server audit log records:
- Every API request reaching the API server.
- The user / service account that made it.
- The verb (`get`, `list`, `create`, `delete`, `exec`, …).
- The resource (`pods`, `secrets`, `configmaps`, …).
- The result (allowed / denied / response code).
- Source IP.

Configurable via **audit policy** (which requests to log, at what level — Metadata, Request, RequestResponse).

Managed K8s offerings:
- **GKE** — Audit Logging enabled by default; surfaces in Cloud Audit Logs.
- **EKS** — opt-in; surfaces in CloudWatch Logs.
- **AKS** — opt-in; surfaces in Azure Monitor.

In self-managed clusters: configure manually; ship to SIEM.

## What's NOT in the audit log

- **Container process execution** (commands run inside containers after they start).
- **Network egress** from pods.
- **Filesystem activity** inside containers.

For these you need:
- **Falco / Tracee** — eBPF-based runtime detection.
- **Sysdig Secure** — commercial.
- **CNI logs** — for egress.
- **VPC Flow Logs** for cluster nodes.

## Investigation flow

### Step 1 — Anchor

Alerts often come from:
- Falco / runtime detection — "spawned shell in container."
- API audit — "secret read by unexpected SA."
- Network detection — "pod calling external IP."
- Cloud-provider GuardDuty / Defender — "cluster API hit from new IP."

### Step 2 — Identity tracing

For a suspicious user / SA:

- `user.username` field — the identity making the request.
- For SA tokens: `system:serviceaccount:<namespace>:<sa-name>`.
- For external users (kubectl): SAML / OIDC subject mapped to a `username`.
- `user.groups` — group memberships used in RBAC.
- `sourceIPs` — caller IP (note: kube-proxy may obscure).
- `userAgent` — tooling fingerprint.

Trace:
- When was this SA token issued?
- Which pod / workload runs as this SA?
- What's its RBAC?

### Step 3 — Pod / workload tracing

The audit log shows API-level events. For pod-internal behaviour you need:
- **`kubectl get events`** — recent cluster events (limited retention).
- **Runtime audit** (Falco / Tracee) — what the pod actually did.
- **Image registry logs** — when the image was pulled.

If the pod was deleted, you need:
- Container runtime cleanup behaviour (some runtimes preserve recent terminated containers).
- Persistent logs (Loki / Fluent-bit) that captured stdout / stderr.
- Auditd / kernel audit if shipped from host.

### Step 4 — RBAC trace

For each new resource the attacker accessed:
- Which `Role` / `ClusterRole` permits the action?
- Which `RoleBinding` / `ClusterRoleBinding` binds the SA to that role?
- When were those bindings created?
- Who created them?

Tools: `kubectl who-can`, `kubectl-rbac-lookup`, `rbac-audit`.

### Step 5 — Persistence hunt

Common attacker patterns:
- **New ServiceAccount** + **ClusterRoleBinding** giving cluster-admin.
- **Mutating admission webhook** ([[k8s-admission-webhook-abuse]]) — every pod created carries attacker code.
- **DaemonSet** that runs on every node with hostNetwork + hostPath mounts.
- **CronJob** that periodically re-establishes access.
- **Secret** containing a long-lived kubeconfig.
- **Static pod manifest** in `/etc/kubernetes/manifests/` on a node — survives API restart.
- **Container image** retag — image attacker pushed pulled silently.

### Step 6 — Escape hunt

If a pod escaped the container ([[container-runtime-escapes-modern]]):
- New SSH key on node.
- New cron entry on node.
- New systemd service.
- Modified kubelet config.

Host-level forensics applies; see [[linux-enumeration]] and [[ir-from-source-signals]].

## Common attacker patterns

- **SA token theft** from `/var/run/secrets/kubernetes.io/serviceaccount/token` in a compromised container → API server calls from the attacker.
- **Privileged-pod or hostPath escape** ([[k8s-host-mount-escape]], [[k8s-privileged-pod]]).
- **etcd direct access** if the attacker reaches it (often via control-plane node compromise).
- **Admission webhook poisoning** ([[k8s-admission-webhook-abuse]]).
- **Cloud-credential extraction from instance metadata** (the IMDS attached to the node) — see [[aws-imds-ssrf-pivot]], [[gcp-metadata-token-theft]].

## Tooling

- **`kubectl audit`** + `jq` — basic.
- **Falco** — open-source runtime detection.
- **Tracee** — eBPF, similar.
- **Kubescape** — config + posture.
- **`kubeshark`** — API traffic capture.
- **`kube-bench`**, **`kube-hunter`** — recon emulation.
- **`stratus-red-team` k8s scenarios** — attack emulation.

## Pitfalls

- **Audit level too low** — Metadata-only audit misses request body, so you don't see what secret was read or what command was passed to `exec`.
- **Log volume** — full audit can be GB/day; tune carefully.
- **Multi-cluster** — federate logs to a central SIEM.
- **Short retention** — managed K8s providers often retain audit logs ~30 days; export to long-term storage for IR.
- **Ephemeral pods** — by the time you investigate, the pod may be gone. Capture runtime context aggressively.

## Workflow to study in a lab

1. Stand up a kind / minikube cluster with audit logging enabled.
2. Deploy Falco and Tracee.
3. Run attack scenarios from `stratus-red-team` k8s or `kube-hunter`.
4. Query audit log + Falco events for each scenario.
5. Build a per-class detection rule.

## Related

- [[k8s-rbac-abuse]]
- [[k8s-service-account-tokens]]
- [[k8s-privileged-pod]]
- [[k8s-host-mount-escape]]
- [[k8s-admission-webhook-abuse]]
- [[container-runtime-escapes-modern]]
- [[cloud-ir-aws-cloudtrail]]
- [[cloud-ir-azure-activity-log]]
- [[cloud-ir-gcp-audit-logs]]
- [[ir-from-source-signals]]

## References
- [Kubernetes — Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [Falco](https://falco.org/)
- [Tracee](https://github.com/aquasecurity/tracee)
- [NCC Group — Kubernetes IR](https://research.nccgroup.com/)
- See also: [[k8s-rbac-abuse]], [[container-runtime-escapes-modern]], [[cloud-ir-aws-cloudtrail]], [[ir-from-source-signals]]
