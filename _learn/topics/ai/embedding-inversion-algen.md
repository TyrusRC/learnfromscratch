---
title: Embedding inversion (ALGEN-class)
slug: embedding-inversion-algen
---

> **TL;DR:** Given a leaked set of dense embeddings and only ~1k aligned text/vector pairs from the same embedder, a small decoder ("ALGEN" and follow-ons) reconstructs 50–70% of the source text — vector databases are not opaque storage.

## What it is
Embedding inversion turns the encoder f(text) -> vec into an approximate inverse g(vec) -> text. Early work (Song & Raghunathan 2020, "Vec2Text" / Morris et al. 2023) needed white-box access or large query budgets. ALGEN-style attacks (2024-2025) showed that with only a tiny *alignment* corpus (around 1000 (text, vector) pairs from the *same* embedding model) an attacker trains a lightweight seq2seq decoder that recovers most of the semantic content of arbitrary embeddings. Treat vector stores as plaintext for any practical confidentiality threat model.

## Preconditions / where it applies
- Attacker has a dump of embeddings: leaked Pinecone/Weaviate/Qdrant index, exposed FAISS `.index`, S3 bucket with JSON arrays.
- Attacker knows or can fingerprint the embedding model (dimension, norm distribution, position of zero coords often identify the encoder).
- Attacker can submit ~1k queries to the same encoder (own account, public API, or open-weights checkpoint) to build the alignment set.
- Embeddings are stored without per-record encryption or noise.

## Technique
1. *Fingerprint* the encoder: dimension (1536 = OpenAI ada-002 / text-embedding-3-small, 3072 = -3-large, 768 = many open models), norm = 1.0 (cosine-normalised), specific dead-coordinate patterns.
2. *Build alignment set*: send 1k–5k chosen texts through the same encoder, record (text_i, vec_i).
3. *Train inversion decoder*: a small transformer or T5 decoder conditioned on the embedding. Loss = cross-entropy on tokens. ALGEN uses a linear projection from victim-space to attacker-space then decodes; Vec2Text iteratively refines.
4. *Invert*: feed leaked vectors through the decoder. Iterative refinement (encode the guess, compare to target, regenerate) lifts reconstruction quality dramatically — often >80% token recall on short documents.

Indicative recovery levels published in the literature: 92% exact for short passages with Vec2Text under white-box; 50–70% semantic recall under ALGEN's low-data black-box setting.

Related: [[rag-poisoning]], [[training-data-extraction]], [[infrastructure-around-llms]].

## Detection and defence
- Treat embedding stores as PII/secret class — apply the same controls as plaintext: access logging, encryption-at-rest with KMS, no public buckets.
- Per-tenant salt / projection: multiply each tenant's embeddings by a private orthogonal matrix; queries are projected the same way at retrieval time. Breaks naive cross-tenant inversion.
- Differential-privacy noise added to stored vectors (small ε degrades retrieval modestly but cripples inversion).
- Avoid storing raw documents *and* embeddings in the same store; chunk hashes only, with the raw text behind a separate ACL.
- Monitor for anomalous bulk reads of the vector store and for export to non-prod accounts.

## References
- [Morris et al. — "Text Embeddings Reveal (Almost) As Much As Text"](https://arxiv.org/abs/2310.06816) — Vec2Text iterative inversion.
- [Song & Raghunathan — "Information Leakage in Embedding Models"](https://arxiv.org/abs/2004.00053) — foundational inversion result.
- [Prompt Security — embeddings as an attack surface](https://prompt.security/blog/the-embedded-threat-in-your-llm-poisoning-rag-pipelines-via-vector-embeddings) — practitioner overview.
- [OWASP LLM Top 10 — LLM06 Sensitive Information Disclosure](https://genai.owasp.org/llm-top-10/) — vector-store leakage class.
