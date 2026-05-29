---
title: "Web bug-class triage"
slug: web-triage
aliases: [web-triage-playbook, web-bug-triage]
mermaid: true
---

> **TL;DR.** You're looking at a request/response and something
> feels off. This playbook maps the observation to the most likely
> bug class so you stop guessing and start probing the right thing.

## Where do you see the anomaly?

```mermaid
flowchart TD
    A[Anomaly noticed] --> B{Where?}
    B -- "Response body reflects input" --> C[XSS / HTML injection branch]
    B -- "Response has cookies / session / token" --> D[Session-management branch]
    B -- "Response is a redirect" --> E[Redirect branch]
    B -- "Response shows DB / stack / template error" --> F[Injection branch]
    B -- "Response returns someone else's data" --> G[AuthZ branch]
    B -- "Response is delayed / timing-variant" --> H[Blind injection / race branch]
    B -- "Headers reveal back-end" --> I[Recon-only — feed forward]
    B -- "JSON response has fields you didn't expect" --> J[Mass-assignment / info-disclosure branch]
```

## Reflected input → XSS / HTML injection

```mermaid
flowchart TD
    A[Input reflects in response] --> B{Where in the response?}
    B -- "HTML body, between tags" --> C[Try <svg onload=alert(1)>]
    B -- "HTML attribute value" --> D["Try \" autofocus onfocus=alert(1) //"]
    B -- "JavaScript context" --> E["Try ';alert(1);// and template-literal break"]
    B -- "URL / href attribute" --> F[Try javascript: + open-redirect]
    B -- "CSS / style attribute" --> G[Try expression() or @import — see css-injection-exfiltration]
    C --> Z{Script executes?}
    D --> Z
    E --> Z
    F --> Z
    G --> Z
    Z -- yes --> AA[Open cross-site-scripting]
    Z -- no --> AB{Encoded but reflects?}
    AB -- yes --> AC[Try alternate encodings / sanitiser confusion]
    AB -- no --> AD[Open html-injection — still impact via dangling markup]
```

## Database / template error visible

```mermaid
flowchart TD
    A[Error message reveals stack] --> B{Error type}
    B -- "SQL syntax" --> C[Open sql-injection — confirm with ' and union]
    B -- "NoSQL operator error" --> D[Open nosql-injection — try $ne, $regex]
    B -- "Template engine error: Jinja / Twig / ERB / Velocity / Freemarker" --> E[Open ssti — try {% raw %}{{7*7}}{% endraw %}]
    B -- "XML parser error" --> F[Open xxe — try external entity]
    B -- "JSON deserialiser error" --> G[Open deserialisation — pick stack]
    B -- "OS command output / shell error" --> H[Open command-injection]
    B -- "Path / file not found" --> I[Open lfi-rfi / path-traversal]
```

## Auth / session weirdness

```mermaid
flowchart TD
    A[Session anomaly] --> B{What's odd?}
    B -- "Token in URL" --> C[Open session-fixation / referer leak]
    B -- "JWT in cookie / header" --> D[Open jwt — check alg, kid, jku, secret length]
    B -- "Long opaque cookie" --> E[Open session-token-analysis — entropy, Sequencer]
    B -- "Remember-me / persistent token" --> F[Open remember-me-flaws]
    B -- "MFA prompt skippable on retry" --> G[Open 2fa-bypass]
    B -- "Password reset link works after relog" --> H[Open account-recovery-attacks]
    B -- "SAML / OIDC redirect" --> I[Open sso-attacks / oauth-token-theft]
    B -- "ASP.NET __VIEWSTATE in form" --> J[Open viewstate-attacks]
```

## Returns someone else's data → AuthZ

```mermaid
flowchart TD
    A[Saw another user's data] --> B{How was access controlled?}
    B -- "Numeric / sequential ID in URL or body" --> C[Open idor — enumerate adjacent IDs]
    B -- "UUID / hash ID" --> D[Open idor — look for ID leakage in other endpoints]
    B -- "Path tier different from yours" --> E[Open broken-access-control / bfla]
    B -- "Function only an admin should call" --> F[Open bfla]
    B -- "Object owned by another tenant" --> G[Open bola — for APIs]
    B -- "Same endpoint, different role parameter" --> H[Open mass-assignment + broken-access-control]
```

## Redirect responses

```mermaid
flowchart TD
    A[3xx with Location header] --> B{Destination controllable?}
    B -- yes --> C[Open open-redirect — test for OAuth / phishing chain]
    B -- "controlled via header injection" --> D[Open crlf-injection]
    B -- no --> E[Check if Referer leaks token next request]
    C --> F{Used as OAuth redirect_uri?}
    F -- yes --> G[Open oauth-token-theft]
    F -- no --> H[Standalone open redirect — chain into XSS or SSRF]
```

## Delays / timing weirdness

```mermaid
flowchart TD
    A[Response timing differs by input] --> B{Pattern?}
    B -- "Long delay on payload trigger" --> C[Open sql-injection blind / time-based]
    B -- "Sometimes succeeds, sometimes fails on same input" --> D[Open race-conditions — single-packet attack]
    B -- "Front-end returns 200, back-end errors later" --> E[Open http-request-smuggling]
    B -- "Cache HIT on personalised content" --> F[Open cache-poisoning / cache-deception]
```

## JSON has unexpected fields

```mermaid
flowchart TD
    A[Response JSON shape] --> B{What's unusual?}
    B -- "Fields you wouldn't see as a normal user" --> C[Open information-disclosure]
    B -- "Internal-looking fields like isAdmin / role" --> D[Open mass-assignment — try setting them on write endpoints]
    B -- "Database ID linking other entities" --> E[Open idor / bola]
    B -- "Tokens / keys / secrets" --> F[Hard finding — open report-writing-step-by-step]
```

## When you've ruled the obvious classes out

```mermaid
flowchart TD
    A[No obvious bug yet] --> B[Map the feature end-to-end — happy path]
    B --> C[Re-walk as a different role / unauthenticated]
    C --> D[Look for state-machine skips — application-logic-flaws]
    D --> E[Look for assumptions: trusted-but-controllable input — http-parameter-pollution / canonicalization-attacks]
    E --> F{Found something?}
    F -- yes --> G[Open the relevant topic note]
    F -- no --> H[Park the endpoint, move to next feature]
```

## Where to go next

- Confirmed bug class → open the matching topic note for proof-of-concept patterns.
- Need impact for the report → [[demonstrating-impact]] and [[report-writing-step-by-step]].
- Lost in scope → [[bug-bounty-workflow]].
