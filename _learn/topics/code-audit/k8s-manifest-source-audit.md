---
title: Kubernetes manifest — source audit
slug: k8s-manifest-source-audit
aliases: [k8s-manifest-audit, kubernetes-yaml-audit]
---

{% raw %}

> **TL;DR:** Kubernetes manifest audit reads YAML for Pod-spec privileges (root, host-namespaces, capabilities), RBAC over-grants, secrets in env vs Secret refs, missing NetworkPolicies, NetworkPolicy gaps, ingress / LoadBalancer surface, and admission-policy bypasses. The high-value findings are usually in Pod SecurityContexts and ClusterRoleBindings, not where you'd grep for "password". Companion to [[terraform-and-iac-source-audit]] and [[container-escape-techniques]].

## What's in scope

```bash
find . -name '*.yaml' -o -name '*.yml' | xargs grep -l 'apiVersion: '
find . -name 'Chart.yaml' -o -name 'values.yaml' -o -path '*/templates/*'
find . -name 'kustomization.yaml'
```

For helm charts, also render: `helm template ./chart --debug | tee rendered.yaml`. The template often hides defaults that audit must catch.

## Bug class 1 — privileged Pod

```yaml
# BAD
spec:
  containers:
    - name: app
      image: ...
      securityContext:
        privileged: true                # full host kernel access
```

Grep:
```bash
grep -rn 'privileged:\s*true' .
```

Privileged containers can mount any host device, load kernel modules, escape the container trivially. Should appear only in CNI daemons, storage drivers, or audited debug Pods.

## Bug class 2 — root Pod

```yaml
# BAD — defaults
spec:
  containers:
    - name: app
      image: ...
      # no securityContext.runAsNonRoot → may run as root
```

Audit:
```bash
grep -rn 'runAsUser:\s*0' .
grep -rn 'runAsNonRoot:' .
```

Good shape:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

## Bug class 3 — host namespaces

```yaml
spec:
  hostNetwork: true      # BAD — pod is on the host network
  hostPID: true          # BAD — sees all host processes
  hostIPC: true          # BAD — shares IPC namespace
```

`hostNetwork: true` makes container = host's network namespace, defeating NetworkPolicies and exposing all host network services. Required only by some CNIs and node-exporter-style agents.

## Bug class 4 — hostPath mounts

```yaml
volumes:
  - name: docker
    hostPath:
      path: /var/run/docker.sock     # BAD — container can talk to the host's container runtime
```

Mounting the container runtime socket is a clean container escape. Other dangerous paths:
- `/` (or `/host`) — full host filesystem.
- `/var/lib/kubelet` — kubelet credentials.
- `/etc` — host configuration.
- `/proc` — host process info-leak.

Grep:
```bash
grep -rnB1 -A3 'hostPath:' .
```

## Bug class 5 — capabilities

```yaml
securityContext:
  capabilities:
    add: ["SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE"]    # BAD
```

`SYS_ADMIN` is essentially "root". `NET_ADMIN`, `SYS_PTRACE`, `SYS_MODULE`, `DAC_READ_SEARCH` are individually dangerous.

Audit:
```bash
grep -rnA3 'capabilities:' .
```

The default capability set in Docker (cap_chown, cap_dac_override, cap_fowner, cap_kill, cap_net_bind_service, etc.) is already broader than most workloads need. `drop: ["ALL"]` then add back the few you actually use.

## Bug class 6 — RBAC over-grants

```yaml
# BAD — cluster admin to a service account
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-binding
roleRef:
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: app
```

Service accounts bound to `cluster-admin` are "owned-cluster" with a single Pod compromise.

Greps:
```bash
grep -rnB2 -A5 'cluster-admin' .
grep -rnE 'resources:\s*\[\s*"\*"\s*\]' .       # ClusterRole with all resources
grep -rnE 'verbs:\s*\[\s*"\*"\s*\]' .            # all verbs
grep -rn 'NonResourceURLs.*\*' .
```

Common ClusterRole over-grants:
- `pods/exec` — `exec` into any pod = code exec across cluster.
- `pods/portforward` — proxy traffic anywhere.
- `secrets` (get/list/watch) at cluster scope — read all secrets.
- `serviceaccounts/token` — mint tokens for any service account.

## Bug class 7 — secrets in env vs Secret refs

```yaml
# BAD
env:
  - name: DB_PASSWORD
    value: "Hunter2"

# OK
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password
```

Audit:
```bash
grep -rnE 'env:' . -A20 | grep -E 'PASSWORD|TOKEN|SECRET|KEY' | grep -v secretKeyRef
```

Even with Secret refs, audit *who can read the namespace's secrets* via RBAC.

## Bug class 8 — missing NetworkPolicy

Kubernetes is open-by-default — every Pod can talk to every other Pod and reach the API server. NetworkPolicies are the only in-cluster network boundary.

```bash
grep -rn 'kind: NetworkPolicy' .
```

A namespace without a default-deny NetworkPolicy is a flat network. Default-deny shape:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: app
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

Then explicitly allow each needed flow.

## Bug class 9 — ingress / LoadBalancer surface

```yaml
spec:
  type: LoadBalancer        # provisions cloud LB → public IP
```

Audit:
- Is the workload supposed to be public?
- Is there an Ingress with annotations limiting the source IPs?
- For Ingress controllers, what's the `tls:` config?

## Bug class 10 — admission policy bypasses

Pod Security Admission (PSA) replaces the older PodSecurityPolicy. Namespaces are labelled:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: privileged      # BAD — anything goes
    pod-security.kubernetes.io/enforce: restricted      # good
```

Audit:
```bash
grep -rn 'pod-security.kubernetes.io' .
```

Without `restricted` (or a custom OPA/Kyverno policy enforcing equivalent), the cluster has no admission-time guardrails.

## Bug class 11 — image policy

```yaml
spec:
  containers:
    - image: nginx                # BAD: no tag, no digest
    - image: nginx:latest         # BAD: mutable tag
    - image: nginx:1.25           # OK if pinned in registry
    - image: nginx@sha256:abc...  # best: digest pin
```

Combined with image signature verification (Sigstore / cosign), digest pinning is the only honest answer.

## Bug class 12 — Service Account token auto-mount

```yaml
# By default, every Pod mounts its SA token at /var/run/secrets/kubernetes.io/serviceaccount/
# A compromised Pod uses that token against the API server.
spec:
  automountServiceAccountToken: false       # for workloads that don't talk to the API
```

Audit Pods that *don't* need API access; they should disable automounting.

## Bug class 13 — etcd / kubelet exposure

These are infrastructure findings but show up in Helm charts that ship etcd / kubelet config:
- etcd encryption at rest enabled?
- kubelet `authorization-mode: AlwaysAllow`?
- Anonymous auth on kubelet?

## Tools

- **kube-bench** — CIS benchmark for clusters (not manifests).
- **kube-score** — manifest linter for security/best-practice.
- **kubesec** — risk score per manifest.
- **kubeaudit** — Pod-spec issues.
- **trivy config** — YAML config scanning.
- **checkov** / **kics** — multi-format including K8s.
- **OPA / Gatekeeper / Kyverno** — policy-as-code admission control.

## Source-audit checklist

- [ ] No `privileged: true` outside daemons that justify it.
- [ ] All workloads `runAsNonRoot: true`, `allowPrivilegeEscalation: false`.
- [ ] No `hostNetwork`, `hostPID`, `hostIPC`.
- [ ] No risky `hostPath` mounts.
- [ ] Capabilities `drop: ["ALL"]` then explicit add.
- [ ] No `cluster-admin` to non-admin Service Accounts.
- [ ] No `verbs: "*"` / `resources: "*"` ClusterRoles unjustified.
- [ ] Secrets only via Secret refs, not env values.
- [ ] Every namespace has default-deny NetworkPolicy.
- [ ] LoadBalancer/Ingress exposure is intentional and scoped.
- [ ] PSA labels at `restricted` or custom OPA equivalent.
- [ ] Images pinned by tag or digest, signed where possible.
- [ ] `automountServiceAccountToken: false` for non-API workloads.

## References
- [Kubernetes — Security overview](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NSA / CISA — Kubernetes Hardening Guidance](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- See also: [[container-escape-techniques]], [[terraform-and-iac-source-audit]], [[github-actions-workflow-source-audit]], [[cloud-iam-misconfig-patterns]]

{% endraw %}
