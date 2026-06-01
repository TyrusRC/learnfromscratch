---
title: AWS IAM eventual-consistency persistence
slug: aws-iam-eventual-consistency-persistence
---

> **TL;DR:** AWS IAM is eventually consistent across regions — access keys, policies, and role-attachments continue to authenticate for seconds-to-minutes after deletion or detachment, giving a short stealthy persistence/replay window.

## What it is
IAM control-plane changes propagate from `iam.amazonaws.com` (us-east-1) to regional STS and service endpoints asynchronously. During the propagation gap, deleted credentials still sign requests successfully, detached policies still apply, and rolled-back role trust still resolves. Researchers in 2024-2025 showed this gap can be widened by hitting regional STS endpoints, and that a defender's "deleted" key may remain usable for tens of seconds — long enough to mint a fresh STS session that outlives the parent key.

## Preconditions / where it applies
- Foothold on an AWS principal with at least `iam:CreateAccessKey` / `iam:CreateUser` or compromised long-lived access keys.
- Network egress to regional `sts.<region>.amazonaws.com` endpoints.
- Defender is responding by deleting keys or detaching policies (incident response in progress).

## Technique
The persistence flow turns a short propagation window into a longer-lived STS session:

1. **Pre-stage.** While credentials are still valid, call `sts:GetSessionToken` or `sts:AssumeRole` against a regional STS endpoint to mint a 12h-36h temporary session.
2. **Survive deletion.** When the defender deletes the parent access key, the regional STS session continues to validate until its own expiry — the deletion only revokes future minting, not issued sessions (unless explicit `aws:TokenIssueTime` policy revocation is in place).
3. **Race the propagation.** If a policy is detached, immediately re-attach via a backup principal whose keys were minted in step 1; the detach hasn't reached every region yet.

```bash
# pre-stage long-lived sessions across regions before getting kicked
for r in us-east-1 us-west-2 eu-west-1 ap-southeast-1; do
  AWS_DEFAULT_REGION=$r aws sts get-session-token \
    --duration-seconds 129600 > sess-$r.json
done
```

A more aggressive variant (Datadog/researchers 2024): create a second user, attach `AdministratorAccess`, mint keys, then delete the user — the keys still work for ~30s while the deletion propagates, and any STS session issued in that window survives.

Related: [[aws-rogue-oidc-idp-persistence]] for a long-lived federated variant, and [[aws-sts-assume-role]] for chain mechanics.

## Detection and defence
- CloudTrail: alert on `CreateAccessKey` + `DeleteAccessKey` within seconds, especially for newly-created users.
- Alert on `GetSessionToken` / `AssumeRole` calls immediately preceding identity deletions.
- Use IAM session policies with `aws:TokenIssueTime` to invalidate all sessions older than a given timestamp on compromise.
- Enable `aws:MultiFactorAuthPresent` on sensitive roles so a stolen access key alone cannot mint a long STS session.
- During incident response, rotate the trust-policy or attach a deny-all inline policy in addition to deletion — denies evaluate on every API call and propagate alongside (but cover the gap better than relying on deletion alone).

## References
- [Datadog — Following attackers through AWS](https://securitylabs.datadoghq.com/articles/following-attackers-trail-in-aws-methodology-findings-in-the-wild/) — observed propagation abuse
- [AWS — STS regional endpoints](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_enable-regions.html) — regional STS behaviour
- [GBHackers — Attackers abuse AWS IAM](https://gbhackers.com/attackers-abuse-aws-iams/) — write-up of the technique
