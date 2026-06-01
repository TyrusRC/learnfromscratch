---
title: Membership inference
slug: membership-inference
---

> **TL;DR:** Decide whether a specific record was in the model's training set by comparing loss / confidence / log-prob between candidate and non-candidate samples — a privacy attack with real GDPR/HIPAA implications.

## What it is
A Membership Inference Attack (MIA, Shokri et al. 2017) is a binary classification: given query access to a trained model and a record `x`, decide `x ∈ TrainSet?`. Models tend to fit training data tighter than unseen data, so loss on member samples is systematically lower. MIAs matter because (a) "was Alice's medical record in the training set?" is itself sensitive, (b) successful MIAs are a stepping stone to [[training-data-extraction]], and (c) they are evidence of memorisation for regulatory scrutiny.

## Preconditions / where it applies
- Black-box query access to a target model that returns confidence scores, logits, or log-probabilities. Even text-only outputs work (probe via perplexity).
- Knowledge of (or ability to approximate) the training distribution — needed to build shadow / reference models.
- Most effective against overfit models, small models, large-image classifiers, and LLMs queried on rare/distinctive substrings.

## Technique
Three canonical approaches:

1. *Shadow-model attack* (Shokri 2017). Train `k` shadow models on disjoint subsets of a public dataset drawn from the same distribution. For each shadow model, label samples as member/non-member by ground truth. Train an attack classifier on (confidence-vector, label) pairs. Apply the attack classifier to the target model's confidences on `x`.

2. *Loss-threshold / LiRA* (Carlini et al. 2022, "Likelihood Ratio Attack"). Compute `Loss(target, x)`; compute the distribution of `Loss(shadow, x)` over many shadow models trained with and without `x`. Use the likelihood ratio between the two distributions — far stronger than a fixed threshold, dominates low FPR regions.

3. *Reference-model attack for LLMs*. Score `log P_target(x) - log P_reference(x)`; high positive value implies the target has memorised `x`. Works even without shadow training when a similar base model exists (e.g., open base vs fine-tuned target).

```python
# LiRA sketch
in_losses  = [loss(shadow_with_x,    x) for shadow_with_x    in IN_MODELS]
out_losses = [loss(shadow_without_x, x) for shadow_without_x in OUT_MODELS]
mu_in, mu_out, s = mean(in_losses), mean(out_losses), std(in_losses+out_losses)
score = (loss(target, x) - mu_out) / s   # vs (loss - mu_in)/s
```

For LLMs, evaluate on long, distinctive sequences — short generic strings give high false-positive noise. Related: [[training-data-extraction]], [[model-extraction]].

## Detection and defence
- *Differential privacy* during training (DP-SGD with bounded ε); the formal guarantee directly bounds MIA advantage.
- Regularise harder: dropout, weight decay, early stopping — reduce the train/test loss gap.
- Reduce information per response: return only top-1 label without confidences; round / clip log-probs; refuse log-prob endpoints for non-trusted users.
- Output perturbation: add calibrated noise to confidence vectors.
- Detection-side: rate-limit queries from a single account against the same record; flag accounts probing many distinct rare strings.
- For LLMs: deduplicate training data aggressively — most memorisation tracks with duplicate count.

## References
- [Shokri et al. — Membership Inference Attacks against ML Models](https://arxiv.org/abs/1610.05820) — foundational shadow-model attack.
- [Carlini et al. — LiRA](https://arxiv.org/abs/2112.03570) — strong likelihood-ratio attack.
- [Carlini et al. — Quantifying memorisation in LLMs](https://arxiv.org/abs/2202.07646) — MIA framing for language models.
- [NIST AI 100-2 E2023 — Adversarial ML taxonomy](https://csrc.nist.gov/pubs/ai/100/2/e2023/final) — defensive context.
