---
title: AI red teaming
slug: ai-red-teaming
aliases: [llm-red-team, llm-pentesting]
---

> LLM-shaped systems break in ways classical app-sec frameworks don't
> name well. Prompt injection is the headline; in practice most real
> incidents are agent / tool / context-isolation failures.

## Prereqs

- Comfort with at least one LLM API (OpenAI, Anthropic, Gemini, local
  via Ollama).
- Basic understanding of embeddings, retrieval, and tool calling.

## Stage 1 — fundamentals

- [[llm-threat-model]] — what the user controls, what the model
  controls, what the system controls.
- [[direct-prompt-injection]] — classic "ignore previous instructions".
- [[indirect-prompt-injection]] — payload inside documents, web pages,
  tool output.
- [[jailbreaks]] — DAN-style, role-play, encoding tricks, multi-turn
  drift.
- [[output-filtering-and-its-bypasses]].

## Stage 2 — agent and tool surface

- [[tool-confusion]] — making the agent call the wrong tool.
- [[mcp-attacks]] — Model Context Protocol server abuse.
- [[rag-poisoning]] — corpus-level injection.
- [[memory-poisoning]] — long-lived agent memory abuse.
- [[exfiltration-via-rendered-content]] — image URLs, markdown links,
  callbacks.
- [[chain-of-trust-confusion]] — system vs developer vs user prompt
  precedence failures.

## Stage 3 — model-level and infrastructure attacks

- [[model-extraction]].
- [[training-data-extraction]].
- [[membership-inference]].
- [[adversarial-suffixes]] — gradient-based jailbreaks (GCG and
  successors).
- [[multimodal-attacks]] — image / audio prompt injection.
- [[supply-chain-attacks-on-models]] — poisoned fine-tunes, malicious
  weights, malicious tokeniser.
- [[infrastructure-around-llms]] — vector DB ACLs, inference proxy
  abuse, billing-account compromise.

## References

- [OWASP LLM Top 10](https://genai.owasp.org/llm-top-10/).
- [Simon Willison's prompt-injection
  posts](https://simonwillison.net/tags/prompt-injection/).
- [Anthropic responsible scaling
  policy](https://www.anthropic.com/responsible-scaling-policy) — useful
  threat-model framing.
- [Embrace the Red (Johann
  Rehberger)](https://embracethered.com/blog/) — agent and exfil-channel
  research.
- [Lakera prompt-injection cheat
  sheet](https://www.lakera.ai/blog/prompt-injection-cheat-sheet).
