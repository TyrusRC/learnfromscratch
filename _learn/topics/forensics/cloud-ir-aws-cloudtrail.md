---
title: AWS CloudTrail incident response — practitioner's guide
slug: cloud-ir-aws-cloudtrail
aliases: [cloudtrail-ir, aws-ir-cloudtrail]
---

> **TL;DR:** CloudTrail is AWS's audit log: every API call, signed-in or assumed-role, is recorded. When responding to suspected AWS compromise, your investigation centres on CloudTrail — what identity, when, from where, what action, on what resource. Practical method: find anchor events (suspicious calls), expand backward (what gave the identity access), expand forward (what was done after), and re-trace any role chains. Companion to [[aws-assumerole-chains]] and [[case-study-snowflake-2024]].

## What CloudTrail captures (and what it doesn't)

CloudTrail captures **management events** by default: most `CreateX`, `UpdateX`, `DeleteX`, `Get*Configuration` API calls.

**Data events** (S3 object reads, Lambda invocations, DynamoDB reads) are **opt-in**. Many tenants don't enable them — you'll have visibility into "who configured this S3 bucket" but not "who downloaded the data".

**Insights events** flag statistical anomalies; enable on critical trails.

Critical regions:
- `us-east-1` carries global service events (IAM, CloudFront, Route 53). Always include.
- Per-region trails or single multi-region trail; multi-region is the safer default for IR.

## Per-event fields you'll filter on

Each CloudTrail event has:
- `eventTime` — UTC.
- `eventName` — API call.
- `eventSource` — service (e.g., `iam.amazonaws.com`).
- `userIdentity` — who made the call (rich field).
- `sourceIPAddress` — caller IP.
- `userAgent` — caller tool.
- `requestParameters` — what they asked.
- `responseElements` — what was returned (often partially).
- `errorCode` / `errorMessage` — on failure.
- `awsRegion` — region of call.

`userIdentity` decomposes to:
- `type` — `IAMUser`, `AssumedRole`, `Root`, `AWSAccount`, `AWSService`.
- `principalId`, `arn`, `accountId`.
- `sessionContext` — for AssumedRole, includes session name and source role.
- `invokedBy` — service-invoked calls.

For AssumedRole, **`sessionContext.sessionIssuer`** tells you the role; **`sessionContext.attributes.creationDate`** when the session started.

## Investigation flow

### Step 1 — Anchor

Start with what tipped off the IR: GuardDuty alert, billing anomaly, customer report, AWS abuse notice.

Translate the alert to a CloudTrail query:
- The IP or principal.
- The action name.
- The resource (S3 bucket, EC2 instance, IAM role).
- The approximate time.

### Step 2 — Expand backward

Trace how the identity got there.

For IAMUser:
- When were access keys created? `CreateAccessKey`.
- When was the user created? `CreateUser`.
- Who created them?
- Are there suspicious permissions changes? `AttachUserPolicy`, `PutUserPolicy`, `AddUserToGroup`.

For AssumedRole:
- Find the corresponding `AssumeRole` event (use `sessionContext`).
- Inspect the assuming principal.
- For STS chains, `AssumeRole` was called by another principal — recurse.

### Step 3 — Expand forward

Once you have the principal's session, list all events under that session:
- `eventTime > sessionStart`
- `userIdentity.sessionContext.attributes.creationDate == sessionStart`
- `userIdentity.principalId` (consistent within a session)

Look for:
- New IAM users / access keys / roles.
- Data extraction patterns (large `Get*`, `Copy*`, `Snapshot*`).
- Persistence (Lambda creation, CloudFormation, IAM trust policy modification).
- Egress (S3 bucket policy made public, snapshot shared cross-account).

### Step 4 — Role chains

The attacker often chains: IAMUser → AssumeRole into Role A → AssumeRole into Role B.

Map the chain:
- Get session A's events.
- Find the `AssumeRole` from A into B.
- Get session B's events.
- Repeat.

Athena / Splunk / Sumo with normalised CloudTrail makes this manageable.

## Common attacker techniques to recognise

### Persistence

- `CreateAccessKey` for an existing user (new keys on top of legitimate).
- `CreateUser` + `PutUserPolicy` granting admin.
- `CreateRole` with a permissive trust policy (`*` principal or attacker-account principal).
- `UpdateAssumeRolePolicy` on a role to add attacker-account trust.
- `CreateLoginProfile` to convert programmatic-only user to console-capable.

### Data exfil

- `GetObject` on S3 (data event; enable!).
- `Copy*Snapshot` to attacker-controlled region or account.
- `ModifyDBSnapshotAttribute` making a DB snapshot public.
- `DescribeDBClusters` enumeration before exfil.
- `GetSecretValue` from Secrets Manager.

### Evasion

- `StopLogging` (CloudTrail trail) — disables CloudTrail itself.
- `PutBucketLogging` removed from S3 trails bucket.
- `DeleteEventDataStore` / `UpdateEventDataStore` on Lake.
- `DeleteCloudTrail` outright.
- CloudTrail policy size manipulation to evade alerting ([[aws-cloudtrail-policy-size-evasion]]).
- Service-linked role abuse (see [[aws-iam-eventual-consistency-persistence]]).

Any of these in CloudTrail itself is a tier-0 alert.

### Lateral movement

- `AssumeRole` into roles not assumed before by this principal.
- `AssumeRoleWithSAML` or `AssumeRoleWithWebIdentity` from federated identity that's unusual.
- Cross-account `AssumeRole`.

## Tooling

- **Athena** — query CloudTrail in S3 with SQL. Standard.
- **CloudTrail Lake** — managed Athena-like.
- **`cloudtrail-partitioner`** + Athena.
- **`Pacu`** — recon (offence) but its modules teach what events to look for.
- **`Prowler`** — config audit; not IR but covers preventive controls.
- **`PowerShell`** / **`aws-cli`** — direct lookups.
- **`stratus-red-team`** — emulate attacker actions to validate detections.
- **`falco`** style behavioural rules — Sumo's Cloud SIEM, Datadog Cloud SIEM, etc.

## Pitfalls

- **Pagination** — CLI/SDK calls produce one CloudTrail event but query results paginate; bulk reads can be one event each or batched.
- **Delayed delivery** — CloudTrail can lag 5–15 minutes; correlate with other logs.
- **Missing data events** — by default, S3 / Lambda / DynamoDB reads are not logged. Tenants without them have huge blind spots.
- **Truncation** — `requestParameters` and `responseElements` are truncated at 100 KB.
- **AssumeRoleWithSAML/WebIdentity** — `userIdentity.userName` may be the SAML subject, useful for tracing to IdP user.

## Workflow to study in a lab

1. Stand up an AWS account; enable multi-region CloudTrail to S3 + Lake.
2. Use `stratus-red-team` to emulate compromise scenarios.
3. Query CloudTrail with Athena; build queries that surface each scenario.
4. Tune false-positive rates.
5. Practice the four-step investigation flow on the synthetic attack data.

## Related

- [[aws-assumerole-chains]] — what attackers do with roles.
- [[aws-imds-ssrf-pivot]] — initial vector.
- [[aws-iam-eventual-consistency-persistence]] — persistence pattern.
- [[aws-cloudtrail-policy-size-evasion]] — evasion.
- [[case-study-snowflake-2024]] — SaaS IR comparison.
- [[siem-detection-use-case-catalog]] — detections.

## References
- [AWS — CloudTrail user guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/)
- [Stratus Red Team](https://stratus-red-team.cloud/)
- [Datadog Security Labs — CloudTrail IR](https://securitylabs.datadoghq.com/)
- [Christophe Tafani-Dereeper — CloudTrail patterns](https://github.com/DataDog/stratus-red-team)
- See also: [[aws-assumerole-chains]], [[aws-imds-ssrf-pivot]], [[siem-detection-use-case-catalog]], [[case-study-snowflake-2024]]
