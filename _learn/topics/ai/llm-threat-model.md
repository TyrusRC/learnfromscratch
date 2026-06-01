---
title: LLM threat model
slug: llm-threat-model
---

> **TL;DR:** Reason about LLM apps along four axes — who controls the prompt, who controls the model, who controls the tools, and who controls the data context — and the attack surface falls out automatically.

## What it is
There is no single "LLM vulnerability class" — the attack surface depends on the deployment. A threat model that scales across chatbots, RAG, and agents asks four questions: who can influence each of the prompt, the model weights, the tool set, and the retrieval/context? Wherever the answer includes "an untrusted party", you have an attack vector and need a control. This framing maps cleanly onto the OWASP LLM Top 10 risks and avoids vendor-specific noise.

## Preconditions / where it applies
- Any application that places an LLM between a user, some data, and some action
- Used at design time to enumerate controls; at test time to enumerate attacks
- Applies equally to first-party-only deployments (internal copilots) and third-party-facing apps

## Technique
The four axes:

**1. Prompt control.** Who writes what reaches the model?

- System / developer prompt: app owner (trusted)
- User message: end user (semi-trusted — direct prompt injection, see [[direct-prompt-injection]])
- Tool output: whoever owns the tool (often untrusted — see [[indirect-prompt-injection]])
- Retrieved docs: whoever wrote them (often untrusted, see [[rag-poisoning]])
- Memory: prior sessions, possibly attacker-influenced (see [[memory-poisoning]])
- Multimodal inputs: anyone who can upload an image / audio (see [[multimodal-attacks]])

**2. Model control.** Who built the weights?

- API to OpenAI/Anthropic/Google: vendor-trusted, opaque
- Open-weights from HuggingFace: model author (variable trust — see [[supply-chain-attacks-on-models]])
- Fine-tuned in-house: your training data and pipeline (insider risk, data poisoning)

**3. Tool / action control.** What can the model do besides emit text?

- Read tools (search, fetch, DB query): leak data
- Write tools (send email, create issue, push code): impact
- Code execution (Python sandbox): RCE primitive if sandbox escapes
- Each tool call is a confused-deputy opportunity — see [[agentic-tool-chain-confused-deputy]]

**4. Output / data context.** Where does the output go and what does it touch?

- Rendered to the user (markdown images, links — see [[exfiltration-via-rendered-content]])
- Stored in a database (XSS into downstream apps)
- Passed to another LLM (cross-prompt chain attacks)
- Used as input to deterministic logic (`if response == "approved":`) — adversarial output bypasses authorisation

For each axis, write down: *which adversary can influence this, what damage can they cause, what control reduces it.* The honest answer is usually that input filtering reduces but does not eliminate attack success — defence belongs at the tool layer and the output layer.

The MITRE ATLAS framework and OWASP LLM Top 10 give concrete control mappings; ATLAS is closer to ATT&CK style TTPs, OWASP is closer to a risk register.

```text
Example: customer support chatbot
- Prompt: system (you), user (semi-trusted), prior ticket text (UNTRUSTED — customer wrote it)
- Model: vendor API (trusted)
- Tools: lookup_order, refund_order (DANGEROUS), escalate_to_human
- Output: rendered as markdown to support agent (link/image exfil risk)
Controls: confirm before refund_order; strip markdown images; spotlight user text; sandbox prior ticket text in <untrusted> tags.
```

## Detection and defence
- Treat every input axis with mixed trust as adversarial
- Defence-in-depth: input filter + output filter + tool-layer authorisation; assume any single one fails
- Principle of least privilege at the tool layer — the model holds capabilities, not credentials
- Human-in-the-loop confirmation on any write action with real-world impact
- Telemetry on every model call: prompt, tool calls, output, user — enables incident response and blue-team retro
- Red-team continuously: attack surface shifts every time you add a tool or data source

## References
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) — risk taxonomy
- [MITRE ATLAS](https://atlas.mitre.org/) — adversarial threat landscape, TTP catalogue
- [NIST AI 100-2: Adversarial Machine Learning](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-2e2025.pdf) — taxonomy + mitigations
- [Building LLM Apps Securely — PortSwigger / Microsoft guidance](https://portswigger.net/web-security/llm-attacks) — applied controls
