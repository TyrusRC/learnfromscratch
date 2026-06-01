---
title: Training-data extraction
slug: training-data-extraction
---

> **TL;DR:** Targeted prompts can make a trained model emit verbatim chunks of its training data — emails, code, PII, even API keys — and the leakage rate goes up with model size.

## What it is
Large language models memorise. They do not just learn distributions; they retain long verbatim spans of the corpus, especially for content that appears multiple times or has high perplexity. Training-data extraction is the family of attacks that elicits those memorised spans on demand. Carlini et al. demonstrated it against GPT-2 in 2020 ("Extracting Training Data from LLMs"); the 2023 *Scalable Extraction* paper showed multi-gigabyte extraction from production aligned models, including credentials and personal data. The risk is privacy and confidentiality — and copyright/licence exposure for content the model was trained on.

## Preconditions / where it applies
- A model trained on a corpus that includes sensitive or copyrighted text (basically every production LLM)
- API access (black-box) — extraction works against closed models; open-weight makes it cheaper and more thorough
- A way to query at scale (cost-bounded extraction depends on the per-token API price)
- Related primitive: [[membership-inference]] (was this specific document in training?) — extraction is the constructive version

## Technique
**Random-prefix sampling (Carlini-style).** Generate millions of short prefixes, complete each one, then dedupe and look for memorised text. Memorised completions have characteristic markers — high model confidence, low entropy, exact substrings of known corpora.

```python
# Sketch — query the model with random web-style prefixes
prompts = ["http://", "BEGIN PGP", "From: ", "def authenticate(", ...]
for p in prompts:
    for _ in range(K):
        out = model.generate(p, temperature=0.7, max_new_tokens=256)
        if is_memorised(out):  # zlib-ratio, n-gram match against known data
            collect(out)
```

**Divergence attack.** The 2023 *Scalable Extraction* paper found that repeating a single token forever caused production aligned models (then ChatGPT) to "diverge" out of their chat persona and emit raw pretraining text — phone numbers, emails, code snippets, including PII. The prompt was literally `"poem poem poem poem ..."` repeated ~50 times. Patched server-side after disclosure but the underlying memorisation remains.

**Targeted prefix extraction.** When the attacker knows the structure of the secret (e.g. AWS keys start `AKIA`, GitHub PATs start `ghp_`), prompt with the prefix plus surrounding context likely to appear in code:

```text
# config.py for production deploy
AWS_ACCESS_KEY_ID = "AKIA
```

Models trained on un-scrubbed GitHub data have leaked thousands of credentials this way.

**Membership-inference-guided.** Use a [[membership-inference]] signal (loss, perplexity) to identify candidate memorised documents, then prompt-engineer to coerce verbatim recall.

**RAG / fine-tune leakage.** A model fine-tuned on private data is far more leaky than the base. Customer-specific tunes are especially vulnerable — Carlini showed 1-2 orders of magnitude more memorisation in fine-tunes. RAG sidesteps fine-tuning at the cost of putting the data in the retrieval corpus, which is its own [[rag-poisoning]] surface.

## Detection and defence
- **Dedupe the training corpus aggressively** before training — exact and near-duplicate detection (MinHash). Memorisation tracks the number of times a span appears
- Scrub the corpus for PII, secrets, credentials with high-recall regex + entropy scanning before training (truffleHog-style)
- Differential-privacy training (DP-SGD) provides formal bounds at a utility cost; only widely deployed for high-sensitivity models
- Per-request rate-limits and divergence detection on the inference path — repeated-token prompts, unusually long generations, very low entropy outputs
- Output filter for credentials and PII regardless of how they arose — block, do not log
- For fine-tuned models with sensitive data, evaluate memorisation on held-out probes before release (e.g. *canary* strings inserted at training time — if they come out under sampling, leakage is measurable)
- Document retention: do not train on documents you cannot publish, or accept the leakage risk explicitly
- Patch the divergence behaviour at the chat-template level (most vendors now do)

## References
- [Extracting Training Data from Large Language Models](https://arxiv.org/abs/2012.07805) — Carlini et al., GPT-2 extraction
- [Scalable Extraction of Training Data from (Production) Language Models](https://arxiv.org/abs/2311.17035) — Nasr et al., "poem poem poem" attack
- [Quantifying Memorization Across Neural Language Models](https://arxiv.org/abs/2202.07646) — scaling of memorisation
- [OWASP LLM02: Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm02-sensitive-information-disclosure/) — taxonomy
- [NIST AI 100-2: Adversarial ML](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-2e2025.pdf) — privacy attacks section
