---
title: LLM infrastructure
slug: infrastructure-around-llms
---

> **TL;DR:** Most real-world LLM compromises do not need a jailbreak — they target the vector DB, the inference proxy, the orchestration framework, or the cloud billing account behind the chatbot.

## What it is
A production LLM stack is not just "the model". It is a vector database (Pinecone, Weaviate, pgvector, Qdrant), an orchestration layer (LangChain, LlamaIndex, Semantic Kernel), an inference gateway (LiteLLM, OpenRouter, vLLM, an internal proxy), a secrets store holding API keys to OpenAI / Anthropic / Bedrock, queue workers, log sinks, eval harnesses, and usually a Kubernetes cluster on top of cloud accounts with high spending limits. Each of those is a normal infra component with normal infra bugs — auth bypasses, SSRF, exposed admin endpoints, IAM misconfig, container escape. Compromising any of them gets you the same outcome as a successful prompt injection, often with less effort.

## Preconditions / where it applies
- Any organisation running a non-trivial LLM application (RAG, chatbot, agent)
- External attacker with internet access, or internal attacker with a foothold in the same VPC
- Default deployments of orchestration frameworks (most ship with permissive defaults)

## Technique
Common attack surfaces and what to look for:

**Inference gateway / proxy.** LiteLLM, OpenRouter clones, internal "AI gateway" services often expose `/v1/chat/completions` to any internal caller, with a single shared upstream API key. Get RCE on any pod in the cluster and you can drain the company's OpenAI quota — or pivot to use the model for your own purposes at their expense. Check for unauthenticated admin endpoints (`/admin`, `/keys`, `/spend`); LiteLLM has shipped several auth-bypass CVEs.

**Vector database ACL bypass.** Pinecone namespaces, Weaviate tenants and Qdrant collections often share a single API key across an application — tenant isolation is enforced in the app layer, not the DB. SSRF in the app or a parameter-tampering bug lets you query any tenant's vectors. Vectors plus metadata often contain raw chunks of source documents — i.e. the RAG corpus is the data.

```bash
# Probe a vector DB for cross-tenant access
curl -H "Api-Key: $LEAKED_KEY" \
  "https://your-index.svc.pinecone.io/query" \
  -d '{"namespace":"victim-tenant","topK":50,"vector":[...]}'
```

**Orchestration framework RCE.** LangChain's older `PythonREPLTool`, `PALChain`, and `load_chain(url=...)` deserialise or execute attacker-controlled content. CVE-2023-29374, CVE-2023-32785, CVE-2024-2965 — each one a clean RCE primitive. LlamaIndex `download_loader` and Semantic Kernel plugins have similar histories.

**Notebook & eval harness exposure.** Jupyter, Ray dashboards (CVE-2023-48022, the "ShadowRay" mass-exploitation), MLflow tracking servers (CVE-2023-6831 etc.) — all commonly exposed on internal load balancers with no auth. Ray jobs and MLflow runs typically execute arbitrary Python with model-training-grade IAM roles attached.

**Cloud IAM and billing.** The inference workload usually has a service account with access to S3 buckets (training data, RAG corpus), Bedrock / Vertex / Azure OpenAI keys (free model access for the attacker), and sometimes IAM `PassRole` (privilege escalation). Stolen API keys to commercial LLMs go for hundreds of dollars on the underground market and the victim foots the bill — the LLMjacking attack pattern (Sysdig 2024).

**Inference-time logs.** Application logs often include the full user prompt and model output verbatim — those logs may end up in Datadog, Splunk, or S3 with weaker ACLs than the chat itself.

## Detection and defence
- Treat the LLM stack as critical infrastructure: same patching cadence, same IAM hygiene, same network segmentation as a payments system
- Per-tenant namespace + per-tenant API keys on the vector DB; never share a single key across users
- Strip dangerous tools from LangChain / LlamaIndex configs by default; never load chains or agents from URL or pickle
- Cloud-side guardrails: budget alerts on every OpenAI / Bedrock key; anomaly detection on token usage; rotate keys frequently
- Network policy: the inference pod talks to the model API and nothing else outbound; no internet egress
- Authenticate every internal service — no implicit-trust East/West traffic
- Monitor for ShadowRay-style scans: open Ray/MLflow/Jupyter dashboards exposed on public IPs
- Redact prompts and outputs before logging if they may contain user PII

## References
- [LLMjacking — Sysdig](https://sysdig.com/blog/llmjacking-stolen-cloud-credentials-used-in-new-ai-attack/) — stolen Bedrock keys monetised at scale
- [ShadowRay (CVE-2023-48022) — Oligo](https://www.oligo.security/blog/shadowray-attack-fueling-a-new-era-of-ai-exploitation) — Ray RCE mass exploitation
- [LangChain RCEs — Snyk advisories](https://security.snyk.io/package/pip/langchain) — historical CVE list
- [OWASP LLM05: Improper Output Handling & LLM10: Unbounded Consumption](https://genai.owasp.org/llm-top-10/) — risk taxonomy
