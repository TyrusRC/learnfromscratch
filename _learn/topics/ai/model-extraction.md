---
title: Model extraction
slug: model-extraction
---

> **TL;DR:** Query a closed model enough — possibly via API — to train a near-functional clone (distillation), recover hyperparameters, or reconstruct the final-layer parameters exactly; threatens IP, monetisation, and unlocks white-box attacks against the original.

## What it is
Model extraction (Tramer et al. 2016) treats the victim model as a teacher and trains a student on its outputs. The student need not match weight-for-weight — functional equivalence on the deployment distribution is enough to substitute for the paid API, build cheaper jailbreaks, or pivot to white-box adversarial attacks. Recent work (Carlini et al. 2024, "Stealing Part of a Production Language Model") goes further: under standard logit-bias APIs they recovered the *exact* projection matrix of the final embedding layer of production LLMs for a few hundred dollars.

## Preconditions / where it applies
- Black-box query access — public API, free tier, or stolen key.
- The API returns useful signal: logits, top-k probabilities, log-probs with `logit_bias`, even just text completions for distillation.
- Few or weak rate limits / abuse detection.
- Budget proportional to target model size — distilling a 7B chat model: a few million queries; final-layer extraction of a frontier model: tens of millions to hundreds of millions of tokens.

## Technique
Three modes:

1. *Functional distillation*. Sample diverse prompts (Common Crawl slice, instruction datasets, synthetic). Record (prompt, completion) or (prompt, top-k logits). Fine-tune an open-weights base model on this corpus. Student often reaches 80–95% of teacher quality on the sampled domain at a fraction of cost.

2. *Hyperparameter / architecture stealing*. Side channels: token throughput vs input length reveals attention pattern (quadratic vs linear, MoE routing), timing variance reveals batch boundaries, vocab probes reveal tokenizer family.

3. *Parameter recovery — final layer*. If the API returns full logits (or can be coerced via `logit_bias` to reveal them), the logit vector is `W · h` where `W` is the embedding matrix and `h` is the last hidden state. By querying many prompts and stacking observations, an attacker solves for the row space of `W`, recovering dimension and (up to symmetry) the matrix itself. Carlini et al. did this against `gpt-3.5-turbo` and `ada/babbage` for under $200 each.

```python
# Final-layer extraction shape
# For each query i: l_i = W h_i  (R^V from R^d, V >> d)
# Stack: L = W H  where L is V x N, H is d x N
# rank(L) = d  ->  reveals hidden dim; SVD recovers W up to rotation
```

Pair extraction with [[adversarial-suffixes]] (the clone is the surrogate) and with [[membership-inference]] (the clone's loss approximates the teacher's).

## Detection and defence
- Remove logit / log-prob endpoints for untrusted callers; cap `logit_bias`; never return more than top-k with k small.
- Per-account query budget tied to spend, not just RPS; flag accounts whose prompt distribution matches known extraction corpora (random Common Crawl, repeated logit-bias probing of single tokens).
- Watermarking outputs — distilled student inherits the watermark distribution; useful for legal action, not prevention.
- Output perturbation: quantise / round probabilities; add small calibrated noise to logits (degrades quality marginally, kills exact recovery).
- Throttle and require KYC for high-volume API keys.
- Honeypot prompts that produce idiosyncratic responses; detect the clone reproducing them.

## References
- [Tramer et al. — Stealing ML Models via Prediction APIs](https://arxiv.org/abs/1609.02943) — original extraction paper.
- [Carlini et al. — Stealing Part of a Production Language Model](https://arxiv.org/abs/2403.06634) — exact final-layer recovery against frontier APIs.
- [Krishna et al. — Thieves on Sesame Street](https://arxiv.org/abs/1910.12366) — distilling BERT-class models via random queries.
- [OWASP LLM Top 10 — LLM10 Model Theft](https://genai.owasp.org/llm-top-10/) — class context.
