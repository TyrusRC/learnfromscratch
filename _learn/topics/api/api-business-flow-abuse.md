---
title: Unrestricted access to sensitive business flows
slug: api-business-flow-abuse
---

> **TL;DR:** OWASP API6:2023. The endpoint works exactly as designed — the bug is that "as designed" lets one person sign up 10,000 accounts, redeem every voucher, or refund-pump a wallet to infinity. This is not a rate-limit problem; it's a flow problem.

## What it is
API6:2023 — Unrestricted Access to Sensitive Business Flows. The endpoint is authenticated, authorised, and rate-limited per the spec, but the spec itself didn't anticipate automation at scale. Classic targets: signup (farm accounts for referral bonuses), voucher/promo redeem (race to claim before per-user check), refund flow (refund then re-buy), invite-friend credit (self-invite ring), buy-1-get-1 / loyalty point flips, marketplace listing reservation, sneaker/concert ticket drops. Distinguish from [[rate-limit-bypass]]: rate-limit bypass is "I beat the counter"; business-flow abuse is "the counter wouldn't have stopped me anyway, because each request is individually legitimate."

## Preconditions / where it applies
- A flow that grants value (credit, item, reservation, reputation) on completion
- The flow can be driven headlessly (no hard human-verification gate, or one that is solvable cheaply)
- Per-account limits exist but cross-account limits don't, or vice-versa
- Idempotency missing on state-changing steps, allowing replay or race-induced duplication

## Technique
**Bulk-signup farm.** Disposable-email + catch-all domain + headless browser + residential proxy pool. Even with email verification, MX-record catch-all turns 1 domain into N inboxes. Drive signup with the real mobile-app API (not the web form) to skip client-side captcha:

```http
POST /api/v3/register HTTP/2
Authorization: Bearer <anon-device-token>
Content-Type: application/json

{"email":"u+{{seed}}@own3d.tld","device_id":"{{uuid}}","referrer":"victim123"}
```

Each completed signup credits the referrer; 10k iterations cashes out as gift cards.

**Voucher redeem race.** Per-user check is "has this user redeemed?" — fire 50 parallel requests with the same voucher and the check loses the race (see [[race-conditions]]):

```python
engine = RequestEngine(endpoint=URL, concurrentConnections=20, engine=Engine.BURP2)
for _ in range(50):
    engine.queue(req, gate='claim')
engine.openGate('claim')
```

User ends with 50 voucher applications stacked.

**Refund-loop abuse.** Buy item → refund → keep digital good (license key already emailed). Or refund to a different payment method than the one charged (asymmetric refund).

**Self-invite ring.** Account A invites A2..A100 (all controlled). Each grants A a credit. If KYC isn't enforced before payout, A withdraws.

**BOGO tap.** "Buy 1 get 1" promo where the free item triggers on add-to-cart, not on checkout — add, remove paid item, checkout with only the free one.

## Detection and defence
- Threat-model the flow during design: ask "what if a single actor ran this 10,000 times in a week?"
- Device fingerprinting + behavioural signals (mouse, timing, sensor entropy on mobile) layered with risk scoring
- Idempotency keys on every value-granting POST, server-side enforced and rejected on duplicate
- Cross-account correlation: shared payment method, IP block, device ID, referrer chain — cap on aggregate, not per-account
- Proof-of-work or step-up KYC before payout/redeem, not before earn
- Honeypot promo codes that should never be redeemed; alert on any hit
- Anomaly metrics: signups-per-IP/24h, referrals-per-account, refunds-per-payment-method

## References
- [OWASP API6:2023 Unrestricted Access to Sensitive Business Flows](https://owasp.org/API-Security/editions/2023/en/0xa6-unrestricted-access-to-sensitive-business-flows/) — official class
- [PortSwigger: business logic vulnerabilities](https://portswigger.net/web-security/logic-flaws) — flow-modelling primer

See also: [[rate-limit-bypass]], [[race-conditions]], [[bola]].
