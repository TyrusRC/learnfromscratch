---
title: Cilium Tetragon and Falco — runtime security with eBPF
slug: cilium-tetragon-falco-runtime
---

> **TL;DR:** eBPF lets you observe and enforce policy inside the Linux kernel without modifying it. Falco is the original CNCF eBPF/syscall runtime security tool (detection/alerting). Cilium Tetragon adds kernel-level enforcement (block syscalls per identity). Together: deep workload visibility + selective blocking, without sidecars or host agent invasiveness.

## What it is
Three closely related tools:

| Tool | Mode | Strength |
|---|---|---|
| **Falco** | Detection (alerts) | Rule-based, mature, broad coverage |
| **Cilium Tetragon** | Detection + enforcement (kernel-level) | Pod-identity-aware, selective blocking |
| **Cilium (network)** | Network policy via eBPF | L3-L7 network enforcement |

All three deploy as DaemonSets on Kubernetes nodes. All use eBPF for low overhead.

## Preconditions / where it applies
- Kubernetes 1.20+ on modern Linux kernels (5.4+ recommended for full feature set)
- Privileged DaemonSet allowed (these tools need kernel access)
- Existing SIEM / SOC for alert ingestion

## Falco tradecraft

### Install

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl=$SLACK_HOOK
```

### Default rule set

Falco ships with `falco_rules.yaml` covering common detection patterns:
- Container shell spawn
- Privileged container creation
- Sensitive file read (passwords, SSH keys)
- Network connection from container to unusual destination
- Cryptocurrency mining indicators
- Privilege escalation
- Container drift (running binary not in image)

### Custom rule

```yaml
- rule: Suspicious package install in container
  desc: Detect package manager invocation in running container
  condition: >
    spawned_process and container and
    (proc.name in (apt, apt-get, dnf, yum, apk, pip, gem, npm))
    and not container.name in (allowed_pkg_install_containers)
  output: >
    Package install in container (user=%user.name container=%container.name
    cmd=%proc.cmdline)
  priority: WARNING
  tags: [container, supply_chain]
```

### Falco events → SIEM
Falcosidekick fans events out to:
- Slack / Teams / Discord webhooks
- Splunk / Elastic / Datadog / Loki
- Kafka / NATS
- AWS SNS / SQS / SecurityHub / EventBridge
- GCP Pub/Sub / Cloud Logging
- Azure Event Hub / Sentinel
- PagerDuty / OpsGenie
- 50+ outputs total

### Performance
Falco using modern eBPF probe: ~1-3% CPU on busy nodes. Use `engine.kind: modern_ebpf` over the legacy kernel module.

## Cilium Tetragon tradecraft

### Install

```bash
helm repo add cilium https://helm.cilium.io
helm install tetragon cilium/tetragon -n kube-system
```

### Tracing policy — observation only

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata: {name: file-monitoring-sensitive}
spec:
  kprobes:
    - call: "fd_install"
      syscall: false
      args:
        - index: 0
          type: "int"
        - index: 1
          type: "file"
      selectors:
        - matchArgs:
            - index: 1
              operator: "Prefix"
              values: ["/etc/shadow", "/etc/passwd", "/root/.ssh/"]
```

Logs every open of these paths with pod context.

### Enforcement policy — kill / signal on match

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata: {name: block-shell-in-prod}
spec:
  podSelector:
    matchLabels: {env: production}
  kprobes:
    - call: "sys_execve"
      syscall: true
      args:
        - index: 0
          type: "string"
      selectors:
        - matchArgs:
            - index: 0
              operator: "Equal"
              values: ["/bin/bash", "/bin/sh"]
          matchActions:
            - action: Sigkill
```

Blocks shell execution in production pods. Real, kernel-level enforcement.

### Tetragon vs Falco strengths

| Feature | Falco | Tetragon |
|---|---|---|
| Detection (alerts) | ✅ Mature | ✅ Newer |
| Blocking (Sigkill) | ❌ | ✅ |
| Pod identity awareness | ✅ via plugins | ✅ Native |
| eBPF only | ✅ Modern path | ✅ Always |
| K8s-native policy CRDs | Partial | ✅ TracingPolicy CRDs |
| Maturity | High (since 2018) | Growing (2022+) |
| Community / docs | Largest | Growing |

Most orgs run Falco for breadth; add Tetragon when blocking is required.

## Cilium (network)

Separate but companion to Tetragon. CNI replacing kube-proxy with eBPF:
- L3-L7 network policy (HTTP method/path filtering, gRPC, Kafka)
- Service mesh without sidecars (Cilium Service Mesh)
- Encrypted node-to-node traffic (WireGuard or IPsec)
- Cluster Mesh (multi-cluster connectivity)

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata: {name: allow-api-l7}
spec:
  endpointSelector: {matchLabels: {app: api}}
  ingress:
    - fromEndpoints: [{matchLabels: {app: frontend}}]
      toPorts:
        - ports: [{port: "8080", protocol: TCP}]
          rules:
            http:
              - method: GET
                path: "/v1/users/.*"
              - method: POST
                path: "/v1/users"
```

L7-aware policy. Standard k8s NetworkPolicy is L3/L4 only.

## What runtime security catches that admission doesn't

Admission policy ([[policy-as-code-opa-kyverno-defender]]) gates manifest at apply time. Runtime catches:
- Container drift — running binary not in image (e.g., curl downloaded post-launch)
- Privilege escalation post-deployment
- Reverse-shell from compromised pod
- Cryptocurrency mining workloads
- Data exfil over network from pods that shouldn't egress
- Lateral movement via cluster API server abuse

Defense in depth: admission for static, runtime for behaviour.

## Detection patterns to deploy first

1. **Shell in container** — most pods shouldn't spawn interactive shells
2. **Sensitive file access** — `/etc/shadow`, `/var/run/secrets/kubernetes.io/serviceaccount/token`, `/.aws/credentials`
3. **Outbound to unusual destination** — Tor, cryptocurrency, attacker C2 ranges
4. **Privilege escalation syscalls** — `setuid`, `capset`
5. **Kernel module load** — `init_module`, `finit_module`
6. **Mount syscall** — pod mounting host filesystem post-deployment
7. **Crypto miner indicators** — xmrig, monero, kawpow strings
8. **Anomalous process tree** — `kubectl exec` spawning grep then curl then sh
9. **Container escape attempts** — chroot manipulation, nsenter from unprivileged
10. **Modifications to /proc, /sys** beyond normal kubelet patterns

## Common implementation pitfalls

- **Falco with default rules + no tuning** — noisy in real clusters; tune per workload
- **Tetragon enforcement without observation** — block legitimate workloads, downtime
- **Missing sidekick / output config** — events generated but no one sees them
- **Skipping eBPF kernel requirements check** — older kernels lose features (LSM hooks need 5.7+)
- **Privileged DaemonSet not scoped** — Falco/Tetragon need host access; restrict via PSA exception only for them
- **Cilium replaces kube-proxy mid-prod** — major networking change; pilot on non-prod first

## Performance considerations

- Falco modern eBPF: 1-3% CPU
- Tetragon eBPF: similar
- Cilium full eBPF datapath: lower than iptables-based kube-proxy at scale
- Combined: 3-5% CPU overhead; node memory: ~200MB

Acceptable for the visibility / enforcement gain on most workloads.

## OPSEC for blue team

- Audit TracingPolicy / Falco rule changes — equivalent to detection bypass
- Alert on Falco DaemonSet pods being deleted / restarted unexpectedly
- Hunt for kernel-version-specific feature gaps (Tetragon LSM enforcement needs 5.7+)
- Validate enforcement actually fires via Atomic Red Team tests
- For SOC: high-volume Falco alerts get deduped + correlated upstream; don't page on every event

## eBPF security considerations

eBPF itself is a Linux security surface:
- CVE-2022-23222 (eBPF verifier bug → LPE)
- CVE-2021-3490 (eBPF JIT → arbitrary R/W)
- Kernel updates matter; eBPF tools need current kernels

eBPF tooling adds value but also widens kernel attack surface. Patch promptly.

## References
- [Falco docs](https://falco.org/docs/)
- [Falcosidekick outputs](https://github.com/falcosecurity/falcosidekick)
- [Tetragon docs](https://tetragon.io/docs/)
- [Cilium docs](https://docs.cilium.io/)
- [eBPF.io](https://ebpf.io/) — broader eBPF ecosystem
- [Isovalent — eBPF security blog series](https://isovalent.com/blog/)
- [Sysdig — runtime detection patterns](https://sysdig.com/blog/)

See also: [[ebpf-offensive-and-defensive]], [[policy-as-code-opa-kyverno-defender]], [[k8s-admission-controllers]], [[k8s-rbac-abuse]], [[k8s-privileged-pod]], [[k8s-host-mount-escape]], [[container-runtime-escapes-modern]], [[sigma-rules-detection-as-code]], [[velociraptor-threat-hunting]], [[service-mesh-security-deep]], [[edr-hooks-and-unhooking]]
