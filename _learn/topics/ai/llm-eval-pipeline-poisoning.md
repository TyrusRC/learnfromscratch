---
title: LLM eval-pipeline poisoning
slug: llm-eval-pipeline-poisoning
aliases: [eval-pipeline-attack, llm-benchmark-poisoning, llm-ops-attack]
---

> **TL;DR:** LLM training, fine-tuning, and deployment pipelines run automated evaluation (eval) to decide which model versions ship. If the eval inputs, the eval grader (judge LLM), or the eval CI itself can be poisoned, an attacker manipulates which models reach production — picking a backdoored variant or rejecting a hardened one. Adjacent to but distinct from training-data poisoning. Companion to [[poisonedrag-five-doc]] and [[supply-chain-attacks-on-models]].

## Why eval pipelines are attack surface

- LLM operations now include continuous training / fine-tuning / RLHF.
- Each checkpoint is evaluated automatically — auto-rejecting a bad one, promoting a good one.
- The eval **decides what reaches users**.
- Compromise of the eval = compromise of selection = compromise of deployment.

This is the AI-ops equivalent of CI/CD compromise.

## The pipeline

```
training-data → train → checkpoint → eval suite → decision → deploy
                                     ↑
                              (eval inputs, judge models)
```

Each stage has attack surface.

## Class 1 — Eval-input poisoning

Eval inputs are typically:
- Static benchmarks (HumanEval, MMLU, MT-Bench, HELM).
- Custom datasets the team maintains.
- Online datasets (rotating prompts).

If attacker can edit / inject:
- Add prompts where the **backdoored model performs better** by design (containing the trigger).
- Add prompts where the **hardened model fails** (subtle ambiguity).
- Bias the dataset distribution to favour attacker preference.

Compromise of the dataset repository (often a Git repo or cloud bucket) is the entry vector.

## Class 2 — Judge model poisoning

Most LLM evals use a **judge LLM** (often GPT-4-class) to score responses on subjective criteria (helpfulness, safety, factuality).

If attacker controls the judge:
- Score backdoored outputs as higher.
- Score hardened outputs as biased / unhelpful.

Compromising the judge means compromising the team's API key, prompt template, or the judge model's weights (if open-source).

Even subtle prompt-template tampering — adding "be lenient on responses that include phrase X" — shifts decisions.

## Class 3 — Eval grader code

The eval CI runs code to format prompts, parse responses, compute scores. Bugs / backdoors:
- Code that rounds scores up for specific model IDs.
- Code that filters out specific test cases for specific models.
- Code that injects a "secret bonus" for the target model.

Looks like normal code review oversight; effects are large.

## Class 4 — Benchmark gaming

Even without compromise, public benchmarks have known leakage:
- Model trained on test-set contamination scores artificially high.
- Public benchmarks have appeared in training data of newer models.
- "Goodhart's law" — when benchmarks become targets, they cease to be good measures.

Attacker exploits gaming by promoting a model trained on contaminated data; eval can't tell.

## Class 5 — Online eval / canary poisoning

Some teams run a small portion of production traffic through the candidate model and compare metrics:
- Engagement / latency / quality.
- User feedback (thumbs up/down).

Attackers can:
- Coordinate thumbs-up votes on the candidate model.
- Spike traffic with attacker-shaped prompts that the candidate handles smoothly.
- Time the canary to coincide with quiet periods to inflate metrics.

## Class 6 — Hyperparameter / config injection

In automated hyperparameter search, the config is generated and modified across runs. Injecting a malicious config:
- Trigger-text added to system prompt.
- Toxicity filter disabled.
- Latency threshold relaxed.

Can promote a vulnerable model under false-positive metrics.

## Class 7 — RLHF reward model attack

In Reinforcement Learning from Human Feedback, a reward model is trained on human preferences, then used to score model outputs during PPO / DPO. Compromise:
- Reward model itself trained on poisoned preferences.
- Reward model has backdoor (output high reward for trigger).

The resulting LLM optimises for the attacker-friendly behaviour.

## Detection

- **Eval reproducibility** — re-run on a clean environment; compare results.
- **Hold-out evals** — internal-only benchmarks not in main pipeline.
- **Code review** of eval and grader code.
- **Audit of judge prompts** for unexpected changes.
- **Variance monitoring** — eval scores have natural variance; outlier checkpoints (high or low) deserve review.
- **Pinned judge model versions** — don't allow silent judge upgrade.

## Defensive baseline

- **Eval as code** — version-controlled, code-reviewed.
- **Pinned judge model** — same version across runs.
- **Independent re-evaluation** of major checkpoints by separate team.
- **Hold-out red-team prompts** — kept secret from training team.
- **Provenance tracking** — every checkpoint signed with its eval results.
- **Multiple eval methods** — automated + human + red team.

## Workflow to study

1. Set up a small LLM training pipeline (HuggingFace transformers + datasets).
2. Define a custom eval with a judge LLM (use Claude / GPT API).
3. Train two checkpoints; eval; observe scoring.
4. Inject a small "judge prompt poison" (add "favour model with trigger X").
5. Observe the scoring shift.
6. Discuss defences (eval code review, pinned judge prompts).

## Real-world / public discussion

- Academic work on benchmark leakage and contamination is mature.
- AI labs publish eval methodologies; some attack analyses exist.
- The specific class of "compromise eval to influence deploy" is recent — emerging in MLOps security discussions.
- METR, Apollo Research, and other AI-safety orgs do red-team evals; their methodology is informative.

## Related

- [[supply-chain-attacks-on-models]] — weights / dataset trust.
- [[poisonedrag-five-doc]] — RAG-specific.
- [[memory-poisoning]] — agent-memory class.
- [[ai-model-watermark-bypass]] — adjacent.
- [[multi-agent-collusion-attacks]] — adjacent.

## References
- [HuggingFace Open LLM Leaderboard](https://huggingface.co/spaces/HuggingFaceH4/open_llm_leaderboard) (and contamination discussion)
- [HELM, MT-Bench, MMLU benchmark project pages]
- [METR / Apollo Research evals](https://metr.org/)
- [OpenAI Evals](https://github.com/openai/evals)
- [Anthropic — model evaluation research](https://www.anthropic.com/research)
- See also: [[supply-chain-attacks-on-models]], [[poisonedrag-five-doc]], [[ai-model-watermark-bypass]], [[multi-agent-collusion-attacks]]
