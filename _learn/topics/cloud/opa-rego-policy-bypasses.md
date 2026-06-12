---
title: OPA Rego policy bypasses
slug: opa-rego-policy-bypasses
aliases: [opa-bypass, rego-bypass]
---

{% raw %}

> **TL;DR:** OPA (Open Policy Agent) policies in Rego decide allow/deny for K8s admission, API authorization, terraform plans, more. Bypass patterns: (1) input-field-confusion (policy checks `input.containers` but K8s also has `initContainers` / `ephemeralContainers`), (2) array iteration that misses indices, (3) type confusion (string vs number), (4) policy-bundle staleness, (5) decision-log leak, (6) Rego logic that defaults to allow on undefined values. Companion to [[k8s-admission-webhook-abuse]] and [[authorization-patterns-rebac-abac]].

## Quick Rego refresher

```rego
package kubernetes.admission

default allow = false                # "default deny"

allow {
    input.kind.kind == "Pod"
    not has_privileged_container
}

has_privileged_container {
    container := input.request.object.spec.containers[_]
    container.securityContext.privileged == true
}
```

The `_` is an iterator over the array. Anything not explicitly defined is undefined (a value distinct from false).

## Bypass 1 — input-field gaps

K8s Pod spec has three container arrays:
- `spec.containers`
- `spec.initContainers`
- `spec.ephemeralContainers`

A policy that only iterates `spec.containers` misses bypasses via initContainers.

```rego
# BAD
has_privileged_container {
    c := input.request.object.spec.containers[_]
    c.securityContext.privileged == true
}

# GOOD
all_containers[c] {
    c := input.request.object.spec.containers[_]
} {
    c := input.request.object.spec.initContainers[_]
} {
    c := input.request.object.spec.ephemeralContainers[_]
}

has_privileged_container {
    c := all_containers[_]
    c.securityContext.privileged == true
}
```

Audit: grep policies for `spec.containers` without `initContainers`.

## Bypass 2 — default-deny missing

```rego
# BAD — no default
allow {
    input.user == "admin"
}
```

If `input.user != "admin"`, `allow` is undefined. OPA treats undefined ≠ false in some integrations. Always:

```rego
default allow = false
```

## Bypass 3 — type confusion

Rego compares values strictly typed. If a policy expects a number but the request has a string:

```rego
deny[msg] {
    input.replicas > 10                # both must be numbers
    msg := "too many replicas"
}
```

Attacker submits `"replicas": "100"` — string comparison fails the rule; replicas pass. Policies that use comparison operators must check types first.

## Bypass 4 — undefined == false flaw

```rego
deny[msg] {
    input.tls.minVersion != "1.2"      # if tls is undefined, evaluation halts; no deny
    msg := "must require TLS 1.2"
}
```

If `input.tls` is absent, the comparison can't evaluate; the rule body fails entirely; `deny` produces no message. The request passes.

Fix: explicitly check existence:
```rego
deny[msg] {
    not input.tls
    msg := "tls block required"
}
deny[msg] {
    input.tls.minVersion != "1.2"
    msg := "must require TLS 1.2"
}
```

## Bypass 5 — set-comprehension scoping

```rego
deny[msg] {
    some i
    bad := input.containers[i].securityContext.privileged
    bad
    msg := sprintf("container %d privileged", [i])
}
```

If `input.containers[i].securityContext` is undefined for some i, the body fails for that i. Other i's may pass — the rule fires correctly only for the i's where the field exists. An attacker could craft a manifest where only specific indices have the offending field but the rule is designed for the wrong shape.

## Bypass 6 — policy bundle staleness

OPA fetches policy bundles from a remote endpoint periodically. Bugs:
- Polling interval too long; attacker exploits the window between policy update and OPA fetch.
- Bundle signature not verified — attacker controls bundle URL → injects policies.
- "Status API" returns 200 even when bundle hasn't refreshed; admin doesn't notice.

Audit: bundle signing enabled? Polling interval tight? Status API monitored?

## Bypass 7 — decision log leaks

OPA's decision log includes the input — full request body. If the log goes to an unsecured destination (S3 bucket, syslog), sensitive K8s manifests leak.

Audit:
- Decision logs masked for sensitive fields.
- Sink permissions reviewed.

## Bypass 8 — rego function bugs

Custom `http.send` builtins fetch external data. Misuse:
- Network policy doesn't restrict where OPA can reach.
- Cached responses with stale data.
- Failure modes — `http.send` failure returns null; policy treats null as "no problem".

## Bypass 9 — package conflicts

A cluster with multiple OPA policies in different packages can have overlapping decisions. Last loaded wins in some Gatekeeper configurations; attackers add a permissive policy that overrides the strict one.

## Bypass 10 — Gatekeeper constraint vs constraint template

ConstraintTemplate defines the Rego; Constraint instantiates it. A Constraint that scopes only to certain namespaces, kinds, or matches:

```yaml
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["prod"]
```

Attacker creates resources outside the matched namespaces. Constraint missing → bypass.

## Source audit Rego policies

```bash
find . -name '*.rego'
# patterns to flag
grep -rn 'default allow = true' rego/        # default permit
grep -rn 'spec.containers' rego/ | grep -v initContainers   # incomplete iteration
grep -rn 'http\.send' rego/                  # external dependencies
grep -rn '!= ' rego/                         # comparison-only check
```

## Tooling

- **OPA test framework** — write unit tests per policy.
- **conftest** — test policies against config files.
- **Regal** — Rego linter that catches many of the above patterns.
- **Open Policy Agent Playground** — try inputs against policies.

## Reporting

For each finding:
- Specific rule and line.
- Input that bypasses.
- Recommended fix (added check, missed iteration, type assertion).

## Defence

- Default deny.
- Iterate over all container arrays.
- Type-check before compare.
- Test policies with negative cases.
- Sign and verify policy bundles.
- Mask sensitive fields in decision logs.

## References
- [Open Policy Agent documentation](https://www.openpolicyagent.org/docs/)
- [Gatekeeper constraint library](https://open-policy-agent.github.io/gatekeeper/website/docs/howto)
- [Regal — Rego linter](https://github.com/StyraInc/regal)
- [Rego policy testing](https://www.openpolicyagent.org/docs/latest/policy-testing/)
- See also: [[k8s-admission-webhook-abuse]], [[k8s-manifest-source-audit]], [[authorization-patterns-rebac-abac]], [[policy-as-code-opa-kyverno-defender]]

{% endraw %}
