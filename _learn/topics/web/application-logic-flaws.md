---
title: Application logic flaws
slug: application-logic-flaws
---

> **TL;DR:** Bugs in business workflow that scanners miss — race against state machine, skip steps, replay one-shot tokens, abuse currency rounding.

## What it is
Logic flaws are vulnerabilities in the developer's *intended* workflow rather than in a parser, library, or sanitiser. The HTTP request is well-formed, the input passes validation, but the server reaches a state the designer never anticipated — discount stacking, negative-quantity refunds, transferring funds from an account you do not own, or completing checkout without payment. Automated scanners cannot find these because there is no canonical bad string; you have to model the state machine.

## Preconditions / where it applies
- Multi-step workflows: checkout, KYC, account recovery, transfer, refund
- Endpoints that trust hidden form fields, referer, or step ordering
- Server-side state held in the session or in client-supplied tokens
- Stacked or chained discounts, coupons, gift cards, store credit

## Technique
Map every state transition first: capture each request in the flow, list the parameters, and identify which fields *should* be server-derived. Then mutate:

1. **Skip steps.** Submit step 4 directly without 1-3. Many apps only check that `step=4` is present, not that the prior steps completed.
2. **Replay one-shot tokens.** Coupons, OTPs, idempotency keys — submit twice in parallel (race) or after server-side expiry.
3. **Tamper hidden parameters.** `price=99.99`, `is_admin=false`, `currency=USD` in hidden inputs or JSON bodies. Change them.
4. **Negative / overflow values.** `quantity=-1` to refund, `amount=999999999999` to overflow money math, `discount=110` for free + cashback.
5. **Parameter type confusion.** Submit array where string expected, object where ID expected — see [[http-parameter-pollution]].

```http
POST /checkout/confirm HTTP/1.1
Content-Type: application/json

{"cart_id":"abc","coupon":"SAVE10","coupon":"SAVE10","total":0.01}
```

Currency rounding: buy 1000 items at $0.001 each → bills $1.00, but a per-line round-down may bill $0.00. Same trick with FX conversion across currencies.

Race the state machine: send "cancel order" + "ship order" in parallel — see [[race-conditions]].

## Detection and defence
- WAFs see clean requests — logic bugs don't show up in signature logs
- Monitor business-level invariants: ledger balance never negative, coupon usage per user, refund > original
- Enforce server-side authoritative state — never trust client-sent price, total, or step counter
- Use idempotency keys with single-use enforcement
- Add server-side state machine validation (current state → allowed transitions)

## References
- [PortSwigger — Business logic vulnerabilities](https://portswigger.net/web-security/logic-flaws) — labs and taxonomy
- [OWASP WSTG — Business Logic Testing](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/10-Business_Logic_Testing/) — checklist
- [HackTricks — Race condition](https://book.hacktricks.wiki/en/pentesting-web/race-condition.html) — primitives and races
