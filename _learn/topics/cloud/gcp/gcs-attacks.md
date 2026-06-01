---
title: GCS attacks
slug: gcs-attacks
---

> **TL;DR:** GCS has two parallel auth surfaces — bucket-level IAM and per-object legacy ACLs — and `allUsers`/`allAuthenticatedUsers` bindings on either grant public read/write that scanners catch trivially.

## What it is
Google Cloud Storage exposes buckets and objects through both modern IAM bindings and legacy fine-grained ACLs. Uniform Bucket-Level Access (UBLA) disables legacy ACLs and forces IAM only — but is opt-in and many older buckets still mix the two. The two famous footguns: `allUsers` (anyone on the internet, anonymous) and `allAuthenticatedUsers` (anyone with any Google account, including throwaway personal accounts). Either binding with `roles/storage.objectViewer` makes the bucket publicly readable; with `objectAdmin` or `objectCreator` it's publicly writable.

## Preconditions / where it applies
- Discovery phase: only a bucket name or naming pattern (org-name-prod, org-name-backup).
- Authenticated phase: any Google account (for `allAuthenticatedUsers`).
- For write/takeover: bucket policy permits `storage.objects.create` to your principal.

## Technique
**Bucket discovery (no creds):**

```bash
# brute common patterns
for name in company company-prod company-backup company-dev company-logs company-static; do
  curl -s -o /dev/null -w "%{http_code} $name\n" "https://storage.googleapis.com/$name/"
done
# 200 = exists + listable, 403 = exists + private, 404 = doesn't exist
```

Tools: `GCPBucketBrute`, `cloud_enum`. Buckets are global namespace.

**Test public read:**

```bash
curl https://storage.googleapis.com/storage/v1/b/$BUCKET/o   # list (anonymous)
curl https://storage.googleapis.com/$BUCKET/$OBJECT          # read
gsutil ls gs://$BUCKET                                       # authenticated
```

**Test write (the real prize):**

```bash
echo test > /tmp/x
curl -X POST -H "Content-Type: text/plain" --data-binary @/tmp/x \
  "https://storage.googleapis.com/upload/storage/v1/b/$BUCKET/o?uploadType=media&name=x.txt"
# or
gsutil cp /tmp/x gs://$BUCKET/x.txt
```

Public write enables:
- **Static-site takeover** — bucket used to back a CNAME (`storage.googleapis.com/static.victim.com`); overwrite `index.html`.
- **Supply-chain hijack** — bucket hosts JS/CSS/installer pulled by victim apps; overwrite to inject.
- **Log poisoning** — buckets accepting customer-uploaded data feed into downstream ETL.

**Dangling DNS / subdomain takeover variant:** CNAME points to `c.storage.googleapis.com/oldbucket` and the bucket was deleted. Re-register the bucket name and serve content under the victim's subdomain.

**HMAC-key abuse:** if your foothold can list HMAC keys (`storage.hmacKeys.list`), use them as S3-compatible creds — they don't appear in user-token telemetry the same way.

**Signed-URL leak:** signed URLs in commit history, log files, or referer headers grant time-bound access without auth.

Chain into [[gcp-iam-misconfig]] for the IAM angle and [[gcp-service-account-enum]] for SA-key reuse.

## Detection and defence
- Turn on Uniform Bucket-Level Access; disable legacy ACLs entirely.
- Org policy `storage.publicAccessPrevention=enforced` blocks `allUsers`/`allAuthenticatedUsers` bindings at the org/folder level.
- Audit Logs (Data Access): enable for buckets containing sensitive data; alert on anonymous reads/writes.
- Run Security Command Center "Public bucket" findings; review quarterly.
- For static-site hosting, prefer Cloud CDN + signed URLs rather than public buckets.
- Rotate HMAC keys; restrict creation to break-glass SAs.

## References
- [Google — Bucket access control overview](https://cloud.google.com/storage/docs/access-control) — IAM vs ACL model
- [Rhino Security — GCPBucketBrute](https://github.com/RhinoSecurityLabs/GCPBucketBrute) — bucket enumeration
- [HackTricks Cloud — GCS](https://cloud.hacktricks.wiki/en/pentesting-cloud/gcp-security/gcp-services/gcp-cloud-storage-enum.html) — abuse paths
