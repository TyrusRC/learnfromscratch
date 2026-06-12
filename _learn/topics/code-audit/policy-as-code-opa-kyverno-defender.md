---
title: Policy-as-Code — OPA Gatekeeper and Kyverno (defender)
slug: policy-as-code-opa-kyverno-defender
---

> **TL;DR:** Policy-as-Code (PaC) enforces guardrails at admission control time: OPA Gatekeeper (Rego language) and Kyverno (YAML / declarative) intercept Kubernetes API requests and either validate, mutate, or generate resources. Together with image-signing verification ([[sigstore-cosign-supply-chain-signing]]) and IaC scanning ([[iac-scanning-checkov-tfsec-kics]]), they're the runtime gate for "what gets deployed".

## What it is
Two dominant tools:
- **OPA Gatekeeper** — wrapping Open Policy Agent (OPA) into a Kubernetes ValidatingWebhook + MutatingWebhook. Policies written in Rego (Datalog-derived).
- **Kyverno** — Kubernetes-native PaC engine; policies are YAML; designed to be more accessible to operators.

Both intercept requests at the kube-apiserver via admission webhooks.

Plus newer entrants:
- **Cilium Tetragon** — eBPF runtime policy (kernel-level)
- **Pod Security Admission (PSA)** — built-in baseline/restricted/privileged labels, simpler than either
- **Validating Admission Policy** (k8s 1.30+ GA) — CEL-based, in-tree, no webhook

## Preconditions / where it applies
- Kubernetes 1.20+ (PSA), 1.30+ (Validating Admission Policy GA)
- Cluster admin to install admission webhooks
- Existing chart / manifest authoring practices to bring into compliance

## When to pick each

| Need | Pick |
|---|---|
| Simple baseline (no privileged, no hostPath, no root) | Pod Security Admission |
| Custom validation with declarative YAML | Kyverno |
| Complex multi-resource validation, advanced logic | OPA Gatekeeper |
| Mutate at admission (inject labels, sidecars, defaults) | Kyverno OR Gatekeeper |
| Generate resources (companion ConfigMap, NetworkPolicy) | Kyverno |
| Verify image signatures | Kyverno (built-in `verifyImages`) |
| Kernel-level runtime enforcement | Tetragon / Falco |
| Cluster < 1.30, simple validation, no webhooks | Validating Admission Policy when upgraded |

Most orgs: PSA for baseline + Kyverno for custom + Gatekeeper for complex policies (when needed).

## Kyverno tradecraft

### Install

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
helm install kyverno-policies kyverno/kyverno-policies -n kyverno
```

### Common policy patterns

**Block privileged containers:**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: disallow-privileged}
spec:
  validationFailureAction: Enforce
  rules:
    - name: privileged-containers
      match: {any: [{resources: {kinds: [Pod]}}]}
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            =(containers): [{=(securityContext): {=(privileged): "false"}}]
            =(initContainers): [{=(securityContext): {=(privileged): "false"}}]
```

**Require resource limits:**

```yaml
rules:
  - name: require-limits
    match: {any: [{resources: {kinds: [Pod]}}]}
    validate:
      message: "CPU and memory limits required"
      pattern:
        spec:
          containers:
            - resources:
                limits:
                  memory: "?*"
                  cpu: "?*"
```

**Require labels via mutation:**

```yaml
rules:
  - name: add-team-label
    match: {any: [{resources: {kinds: [Pod, Deployment]}}]}
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            team: "{{ request.object.metadata.namespace }}"
```

**Verify image signatures (Sigstore):**

```yaml
rules:
  - name: verify-keyless
    match: {any: [{resources: {kinds: [Pod]}}]}
    verifyImages:
      - imageReferences: ["ghcr.io/myorg/*"]
        attestors:
          - entries:
              - keyless:
                  issuer: https://token.actions.githubusercontent.com
                  subject: 'https://github.com/myorg/*/.github/workflows/*@*'
                  rekor: {url: https://rekor.sigstore.dev}
```

**Block latest tag:**

```yaml
rules:
  - name: no-latest
    match: {any: [{resources: {kinds: [Pod]}}]}
    validate:
      message: "Use digest or semver tag"
      pattern:
        spec:
          containers:
            - image: "!*:latest"
```

**Auto-generate NetworkPolicy:**

```yaml
rules:
  - name: gen-netpol
    match: {any: [{resources: {kinds: [Namespace]}}]}
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: default-deny
      namespace: "{{ request.object.metadata.name }}"
      data:
        spec:
          podSelector: {}
          policyTypes: [Ingress, Egress]
```

### Audit vs Enforce mode

```yaml
spec:
  validationFailureAction: Audit  # log only; don't block
```

Start in Audit, review violations via `kyverno-cli` reports, then switch to Enforce per policy.

## OPA Gatekeeper tradecraft

### Install

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace
```

### ConstraintTemplate (defines a policy class)

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: {name: k8srequiredlabels}
spec:
  crd:
    spec:
      names: {kind: K8sRequiredLabels}
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items: {type: string}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("Missing required label: %v", [missing])
        }
```

### Constraint (instantiates the template)

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata: {name: namespace-must-have-team}
spec:
  match:
    kinds: [{apiGroups: [""], kinds: [Namespace]}]
  parameters:
    labels: [team, environment]
```

### Rego strengths
- Complex multi-resource queries (e.g., "no Service of type LoadBalancer in namespace X")
- Reuse external data (sync `Cluster` resources into OPA cache)
- Same Rego policies usable for IaC scanning ([[iac-scanning-checkov-tfsec-kics]]) via terrascan/conftest

### Rego pitfalls
- Higher learning curve than Kyverno YAML
- Webhook performance: complex Rego under load = admission latency
- Policy testing: Gatekeeper has `gator test` CLI for unit testing — use it

## Pod Security Admission (built-in)

Three levels (`privileged`, `baseline`, `restricted`) applied via Namespace labels:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: prod-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.30
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Minimal config, no webhook, no extra tool. For greenfield clusters, PSA + Kyverno custom policies is usually enough.

## Validating Admission Policy (GA in 1.30)

CEL-based, in-tree:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: no-host-network}
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        resources: [pods]
        operations: [CREATE, UPDATE]
  validations:
    - expression: "!object.spec.hostNetwork"
      message: "hostNetwork is not allowed"

---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: {name: no-host-network-binding}
spec:
  policyName: no-host-network
  validationActions: [Deny]
  matchResources:
    namespaceSelector: {matchExpressions: [{key: env, operator: In, values: [prod]}]}
```

Advantages: no webhook (lower latency, no failure mode if webhook is down). Disadvantages: less powerful than Kyverno/Rego.

Expect ongoing convergence toward CEL across the ecosystem.

## Runtime PaC — Tetragon and Falco

Admission webhooks gate static deployment. Runtime enforcement (eBPF):
- **Cilium Tetragon** — kernel-level policy enforcement; block syscalls per pod identity
- **Falco** — eBPF/syscall monitoring; rule-based alerting (not blocking by default)

See [[cilium-tetragon-falco-runtime]].

## CI/CD integration

Validate policies in CI before deploying:

```bash
# Kyverno CLI
kyverno test ./test-cases    # YAML test cases
kyverno apply ./policies --resource ./manifests  # dry run

# Gatekeeper
gator test ./test-cases
conftest test --policy ./policies ./manifests
```

PR check runs same policies that production cluster enforces — catches issues before merge.

## Common implementation pitfalls

- **Enforce mode on Day 1** — locks out legitimate workloads. Always audit first
- **No exception process** — emergency deploys blocked; downtime
- **Policy drift** — cluster A vs cluster B run different policy versions
- **Mixed source of truth** — admission policy says X, IaC scanner says Y, CSPM says Z
- **Performance impact** — heavy policies on busy clusters add 100ms+ to every admission
- **Forgetting MutatingWebhook ordering** — multiple mutating webhooks can conflict; document order
- **No webhook failure plan** — `failurePolicy: Fail` + webhook down = cluster freeze; `failurePolicy: Ignore` + webhook down = policy bypass. Both have risk

## OPSEC for blue team

- Audit ClusterPolicy / ConstraintTemplate changes — modification is equivalent to policy bypass
- Alert on `Audit`-mode violations spike — could be drift, attack, or legitimate change requiring policy update
- Restrict who can modify `Namespace` labels (PSA) — relabeling = privilege escalation
- Image signature verification policies are sensitive — modify identity/issuer = supply chain bypass
- Monitor admission webhook health; failure = either policy bypass or cluster freeze

## References
- [Kyverno docs](https://kyverno.io/docs/)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Validating Admission Policy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- [Kyverno Policies library](https://kyverno.io/policies/)
- [Gatekeeper Library](https://open-policy-agent.github.io/gatekeeper-library/)
- [Datree — Kubernetes policy guide](https://www.datree.io/resources/)

See also: [[opa-rego-policy-bypasses]], [[helm-chart-security-audit]], [[gitops-security-argo-flux]], [[sigstore-cosign-supply-chain-signing]], [[slsa-supply-chain-framework]], [[iac-scanning-checkov-tfsec-kics]], [[k8s-admission-controllers]], [[k8s-admission-webhook-abuse]], [[k8s-rbac-abuse]], [[cilium-tetragon-falco-runtime]], [[cicd-pipeline-hardening-defender]]
