---
title: Prompt-injection sinks in source
slug: prompt-injection-sinks-in-source
aliases: [llm-prompt-sink-audit, sink-driven-llm-audit]
---

{% raw %}

> **TL;DR:** Source-review for LLM apps follows the same sink-driven pattern as [[source-sink-flow-analysis]]: enumerate model-call sites (LLM "sinks" for user input), trace what tainted data reaches the prompt, classify by impact. Adds an output-side: trace where model output reaches downstream sinks (tool exec, code eval, response render). This note is the catalogue.

## What it is
For traditional code audits, sinks are dangerous functions (`eval`, `exec`, raw SQL). For LLM apps, the model call itself is a sink — but unlike `eval`, the impact depends on what the prompt instructs and what downstream code does with the response.

Two-sided audit:
- **Input side**: anything attacker controls reaching the prompt → instruction-following attack.
- **Output side**: anything model says reaching a sensitive action → impact realisation.

## Input-side sinks (model call sites)

### Major LLM SDK call patterns
```bash
# OpenAI
rg -n 'openai\.(chat\.)?completions\.create|openai\.responses\.create' src/

# Anthropic
rg -n 'anthropic\.(messages|completions)\.create|client\.messages\.create' src/

# Google / Gemini
rg -n 'genai\.(GenerativeModel|generate_content)|GoogleGenerativeAI' src/

# AWS Bedrock
rg -n 'bedrock.*invoke_model|InvokeModelCommand' src/

# Azure OpenAI
rg -n 'AzureOpenAI|OpenAIClient' src/

# LangChain / LlamaIndex abstractions
rg -n 'LLMChain|create_openai_functions_agent|AgentExecutor|RunnableSequence' src/

# Local model frameworks
rg -n 'transformers\.pipeline|llama_cpp\.Llama|ollama\.chat' src/

# Vector store call sites (RAG entry points)
rg -n '\.query\(|\.search\(|RetrievalQA|RetrievalChain' src/
```

### Tainted-source patterns (what reaches the prompt)

| Tainted source | Risk | Note |
|----------------|------|------|
| `req.body.message` direct → prompt | Direct PI | Classic web-app surface |
| `req.body` JSON spread into prompt template | Multi-field PI | Multiple sources |
| `db.notes.find(...)` text → prompt (RAG) | Indirect PI | See [[rag-pipeline-injection-points]] |
| Email body fetched + summarised | Indirect PI | EmailGPT / Copilot for Outlook |
| Web fetch (browse tool) content → prompt | Indirect PI | "ChatGPT browsing" surface |
| File upload content → prompt | Indirect PI | Document QA apps |
| Chat history → prompt | Persistent PI | Each turn rolls forward |
| Tool result → prompt | Tool-result PI | Tool's output trusted as fact |
| Image OCR / multimodal → prompt | Multimodal PI | See [[multimodal-attacks]] |
| Voice transcript → prompt | Indirect PI | TTS confusion |

## Output-side sinks (where model output goes)

### Catalogue

| Output sink | Pattern | Impact |
|-------------|---------|--------|
| `eval(model_out)` / `exec(model_out)` | Code interpreter | RCE in sandbox |
| `subprocess.run(model_out)` | Shell tool | RCE on host |
| `db.execute(model_out)` | Text-to-SQL | SQLi + data exfil |
| `requests.get(model_out)` | URL extraction tool | SSRF |
| `mail.send(to=user, body=model_out)` | Email composer | Phishing, data exfil |
| `res.send(model_out)` HTML | Markdown render | XSS if not sanitised |
| `await fetch(model_out)` | Browse tool | SSRF |
| `await db.user.update(model_out)` | DB write tool | Data corruption, privesc |
| `tool_calls[i].args` dispatched | Function-calling | All above, structured |
| `await slack.post(channel, model_out)` | Social tool | Information leak, phishing |
| `kubectl(model_out)` | Ops tool | Catastrophic |

### Grep patterns
```bash
# Tool dispatch
rg -n 'tool_calls\[|function_call\.|\.invoke\(|dispatch_tool' src/
# Render of model output
rg -n 'dangerouslySetInnerHTML|innerHTML|markdown\(|render\(.*content' src/
# Exec / eval with model output
rg -n 'exec\(.*completion|eval\(.*completion|run\(.*completion' src/
# DB writes triggered by model
rg -n '\.update\(|\.create\(|\.delete\(' src/  # cross-ref with LLM context
```

## Sink + source matrix

For an OSWE-style audit, build a matrix:

| Call site | Tainted sources reaching it | Output sinks reached |
|-----------|------------------------------|----------------------|
| `/chat` endpoint | user message, chat history | response render (markdown), tool calls |
| `/summarize_doc` endpoint | uploaded doc content | response render |
| `/agent` endpoint | user goal, RAG corpus | DB writes, email send, tool calls |

Each cell is a potential bug chain. Priority: cells with admin-level downstream sinks reachable from low-trust input sources.

## Classification by impact

### Tier 1 — Direct RCE / data exfil
- Model output → code exec (interpreter tool).
- Model output → SQL query without parameterisation.
- Model output → shell command without arg validation.

### Tier 2 — Privilege escalation
- Model output → DB role change.
- Model output → "send admin notification" with attacker content.
- Model output → API call with elevated permissions (if app uses model-side service account).

### Tier 3 — Data leakage
- Model echoes system prompt → secrets in prompt leak.
- Model echoes RAG retrieved chunk → cross-tenant leak if retrieval misconfigured.
- Model included PII in response (no redaction post-processing).

### Tier 4 — Misinformation / abuse
- Model output drives downstream system actions based on hallucinated values.
- "Send refund of $X" where X is model's guess; no business-rule check.

## Audit workflow

1. **Find all sinks**. Grep the catalogue above; for each match, open the file.
2. **For each sink**: enumerate tainted sources (function parameters, request fields, RAG retrievals, tool results, history).
3. **For each tainted source → sink pair**: is there a sanitiser between? Schema validation? Allowlist?
4. **Find downstream sinks** for each model call. What does the output reach?
5. **Construct a chain**: tainted source → prompt → model → output → downstream sink. Rate by impact tier.

## Defence patterns

### Validate at every boundary
- Input to prompt: ok to pass user content, but tag as untrusted in prompt.
- Output from model: schema validate, allowlist-check, business-rule check before downstream.

### Separate trust zones
- Multiple LLM calls in pipeline; each has its own "system prompt" and trusted output expectations.
- "Outer" model gives goals; "inner" tool models execute with constrained outputs.

### Constrained outputs
- JSON mode + schema validation + business-rule check.
- Structured outputs via function-calling > free-form text.

### Sandbox the dangerous sinks
- Code exec → ephemeral sandbox with no network, no FS beyond tmp, time limit.
- DB write → tool runs as a low-priv role with row-level locks.
- Email send → dry-run queue + human approval for first-time recipients.

## References
- [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [Anthropic — Building safe agents](https://www.anthropic.com/research)
- [Simon Willison — Prompt injection series](https://simonwillison.net/series/prompt-injection/)
- [Lakera AI — PINT benchmark](https://www.lakera.ai/)
- See also: [[llm-application-source-review]], [[rag-pipeline-injection-points]], [[llm-tool-call-validation]], [[direct-prompt-injection]], [[indirect-prompt-injection]], [[source-sink-flow-analysis]]

{% endraw %}
