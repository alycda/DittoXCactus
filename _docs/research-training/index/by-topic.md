# Topic → sources

Topics are the brief's research questions decomposed. For each topic, the 3–5 most-load-bearing sources, sorted by density. Annotations are one-line.

---

## Base models for ≤2B specialists

- **Qwen 3 1.7B** — Apache-2.0; `huggingface.co/Qwen/Qwen3-1.7B`. First-class Cactus base. Recommended default.
- **Qwen 3 0.6B** — Apache-2.0; same family, speed-optimized. Cactus supports.
- **SmolLM2 1.7B** — Apache-2.0; `huggingface.co/HuggingFaceTB/SmolLM2-1.7B`. Backup if Qwen has structural issues (bilingual CoT drift).
- **Phi-3-Mini** — MIT (Microsoft); clean license, smaller community than Qwen at this scale.
- **Gemma 3 1B** — Gemma Terms of Use (restrictive, not OSI-approved). Gemma 4 (Apache-2.0) is the post-2026-April replacement; check whether Cactus has added support.

---

## LoRA — foundation and variants

- **LoRA** — `arxiv.org/abs/2106.09685`. The foundation. Density 4.
- **QLoRA** — `arxiv.org/abs/2305.14314`. 4-bit NF4 + double quant + paged optimizers; matters at ≥7B more than at 1.7B. Density 4.
- **DoRA** — `arxiv.org/abs/2402.09353`. Magnitude/direction decomposition; closes ~50% of LoRA-to-full-FT gap at +10–20% wall-clock. Density 4.
- **LoRA-FA** — `arxiv.org/abs/2308.03303`. Freezes `A`, halves activation memory. Niche. Density 2.
- **LoRA Learns Less and Forgets Less** — `arxiv.org/abs/2405.09673`. The empirical sanity check. Density 3.

## LoRA rank selection

- **Apple Foundation Models tech report 2025** — `arxiv.org/abs/2507.13575`. Documents Apple shipping rank-{8, 16, 32} adapters in dev tooling. Rank 16 is the documented sweet spot.
- **Cactus finetuning.md** — concrete recipe: rank 16, alpha 16, dropout 0, all 7 target modules. Apply at all linear layers.
- **Unsloth LoRA Hyperparameters Guide** — `unsloth.ai/docs/basics/inference-and-deployment/vllm-guide/lora-hot-swapping-guide`. r=8–16 for fast fine-tunes; rank too large → overfit.

## QLoRA memory math

- **QLoRA paper** — `arxiv.org/abs/2305.14314`. 4-bit NF4: 7B fits 8GB; 65B fits 48GB.
- **Unsloth Qwen3 guide** — Qwen3-0.6B/1.7B free Colab T4 notebooks; bf16 LoRA VRAM table: 0.8B = 3GB, 2B = 5GB, 4B = 10GB, 9B = 22GB.
- **Resta SQL tutorial** — `medium.com/@resta.alessandro.3ai/fine-tuning-a-mini-giant-teaching-qwen2-5-1-5b-to-speak-sql-62e960b7e907`. RTX 4090 fine-tunes 1.5B on 1k samples in ~30 min at ~4GB VRAM.

## SFT vs DPO vs ORPO vs KTO at ≤2B

- **DPO** — `arxiv.org/abs/2305.18290`. "Your LM is secretly a reward model." No PPO loop.
- **ORPO** — `arxiv.org/abs/2403.07691`. Folds preference into SFT via odds-ratio penalty; no SFT warm-up, no reference model. Single training pass.
- **KTO** — `arxiv.org/abs/2402.01306`. Binary good/bad signal; replaces paired prefs.
- **Unveiling the Secret Recipe** — `arxiv.org/abs/2412.13337`. Closest published "what to actually set for SFT" recipe at 3–7B.
- **LIMA** — `arxiv.org/abs/2305.11206`. 1,000-example SFT competitive with RLHF; data-quality-over-quantity argument.

---

## Distillation methods

- **DeepSeek-R1-Distill-Qwen-1.5B** — `huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B`. The 1.5B existence proof. Density 5.
- **Orca** — `arxiv.org/abs/2306.02707`. 13B student distilled from GPT-4 explanation traces.
- **Distilling Step-by-Step** — `arxiv.org/abs/2305.02301`. Rationales as aux loss; 770M T5 beats 540B PaLM. Density 3.
- **MiniLLM** — `arxiv.org/abs/2306.08543`. Reverse-KL for white-box KD. Requires teacher logits.
- **GKD** — `arxiv.org/abs/2306.13649`. On-policy distillation.
- **DistiLLM** — `arxiv.org/abs/2402.03898`. Skew-KL + adaptive on-policy scheduler.

## DeepSeek-R1-Distill family

- **R1 paper** — `arxiv.org/abs/2501.12948`. 800K verified trajectories; Qwen-1.5B student beats GPT-4o on MATH at 1.5B.
- **R1-Distill-Qwen-1.5B model card** — `huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B`. MIT weights, Apache-2.0 base. 4/6 workers cite this.
- **Reasoning-trace latency caveat** — Gemini DR: distilled CoT models emit "thinking" tokens; can exhaust mobile CPU budget. Argues against pure-CoT distillation for our deployment.

## Small-model distillation limits

- **Small Model Learnability Gap** — `arxiv.org/abs/2502.12143`, `small-model-gap.github.io/`. ≤3B students do not consistently benefit from large-teacher long-CoT distillation; shorter CoT or smaller teacher works better.
- **OpenMedLM** — `pmc.ncbi.nlm.nih.gov/articles/PMC11187169/`. Prompt-engineering beat fine-tuned medical specialists on USMLE-style benchmarks. Counter-data to MedAlpaca/Meditron.

---

## Synthetic data generation

- **Magpie** — `arxiv.org/abs/2406.08464` + `github.com/magpie-align/magpie`. The cheapest synthetic-data recipe. Density 4.
- **Self-Instruct** — `arxiv.org/abs/2212.10560`. The bootstrapping loop foundation.
- **Evol-Instruct (WizardLM)** — `arxiv.org/abs/2304.12244`. Depth/breadth evolution operators.
- **distilabel** — `github.com/argilla-io/distilabel`. Apache 2.0 pipeline library. v1.5.3 Jan 2025 — stale flag.
- **Augmentoolkit** — `github.com/e-p-armstrong/augmentoolkit`. MIT, v3.0 June 2025. Document-in, dataset-out. Runs local.

## Note-merging / multi-document-summarization adjacent datasets

- **Multi-News** — `arxiv.org/abs/1906.01749`. 56k multi-doc news pairs; long summaries.
- **WikiSum** — `huggingface.co/datasets/d0rj/wikisum`. Article summarization from references.
- **MiraNews** — `arxiv.org/abs/2109.10650`. Multi-resource-assisted summarization.
- **WCEP** — `arxiv.org/abs/2005.10070`. Wikipedia Current Events.
- **RAGTruth** — `arxiv.org/abs/2401.00396`. 18k word-level hallucination corpus; eval anchor, not training data.

## Data-quality measurement

- **LIMA** — `arxiv.org/abs/2305.11206`. 1,000 curated examples beats 10K mediocre. Data-quality-over-quantity.
- **Magpie paper, Section 3** — cleanest published "we ran these filters and threw away X%" account.
- **"Is Training Data Quality or Quantity More Impactful?"** — `arxiv.org/abs/2411.15821` (cited by claude-DR). Quality dominates at SLM scale.

---

## Cactus runtime — adapter loading verdict

- **Cactus finetuning.md** — `github.com/cactus-compute/cactus/blob/main/docs/finetuning.md`. Merge-at-convert only. Density 5.
- **Cactus engine docs** — `github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md`. `cactus_init` has no adapter slot.
- **Cactus InfoQ Dec 2025** — `infoq.com/news/2025/12/cactus-on-device-inference/`. Context on v1 migration off llama.cpp.
- **Cactus license** — `github.com/cactus-compute/cactus/blob/main/LICENSE`. Source-available + $2M revenue gate.

## Cactus convert pipeline

- **`cactus convert` CLI** — documented in finetuning.md. Takes a base + LoRA adapter, outputs a single `.cact` blob. Handles INT4/INT8/FP16 quantization in same step.
- **Cactus dashboard models** — `cactuscompute.com/dashboard/models`. Multi-model registry; each model is its own download.
- **Cactus releases** — `github.com/cactus-compute/cactus/releases`. v1.14 as of April 2026.

## llama.cpp LoRA support (substrate context)

- **llama.cpp repo** — `github.com/ggml-org/llama.cpp`. `--lora` startup flag, `/lora-adapters` hot-swap endpoint, `convert_lora_to_gguf.py`.
- **llama.cpp adapter loading issue** — `github.com/ggml-org/llama.cpp/issues/10377`. Per-request adapter selection PR #10994.
- **llama-cpp-python multi-adapter PR** — `github.com/abetlen/llama-cpp-python/pull/1817`.
- **Note: Cactus v1 no longer wraps llama.cpp.** Does not inherit this work.

## MLC LLM runtime LoRA

- **MLC LLM repo** — `github.com/mlc-ai/mlc-llm`. Apache 2.0.
- **MLC LoRA PR #3281** — `github.com/mlc-ai/mlc-llm/pull/3281`. C++ LoRA manager; desktop confirmed, mobile in progress. Cited by tooling + industry.

## Apple Foundation Models adapter framework

- **Apple ML Research intro** — `machinelearning.apple.com/research/introducing-apple-foundation-models`. Runtime-swappable rank-16 adapters. Density 5.
- **Apple developer adapter training** — `developer.apple.com/apple-intelligence/foundation-models-adapter/`. Concrete recipe: 100–1,000 samples basic / 5,000+ complex; 5 epochs; 1e-3 LR. Density 5.
- **Apple 2025 tech report** — `arxiv.org/abs/2507.13575`. Rank-{8,16,32}; 2-bit QAT + KV-cache sharing.

## MediaPipe LLM Inference + LoRA on Android

- **MediaPipe Android with LoRA** — `ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android`. Runtime LoRA on GPU backend for Gemma/Phi-2. Attention-only target modules.
- **Pixel Recorder Gemini Nano case study** — `android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html`. +24% engagement from a LoRA fine-tune on summarization.
- **Chrome Gemini Nano LoRA blog** — `developer.chrome.com/blog/improved-summaries-gemini-nano`. Second Google data point.

## ExecuTorch mobile LoRA

- **ExecuTorch repo** — `github.com/pytorch/executorch`. 1.0 supports multi-`.pte` LoRA sharing one foundation set.
- **ExecuTorch official site** — `executorch.ai/`.

## On-device LoRA training

- **QVAC Fabric blog** — `huggingface.co/blog/qvac/fabric-llm-finetune`. First published on-device LoRA training. Wall-clock numbers for Adreno/Mali/Apple Silicon.
- **QVAC Fabric repo** — `github.com/tetherto/qvac-fabric-llm.cpp`. llama.cpp fork, Apache 2.0.
- **QVAC Fabric BitNet** — `huggingface.co/blog/qvac/fabric-llm-finetune-bitnet`. BitNet variant of the same recipe.

---

## Training platform — Oxen.ai

- **Oxen.ai Qwen3 text-to-SQL post** — `ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/`. *The* recipe. Density 5.
- **Oxen.ai pricing** — `oxen.ai/pricing`. Hackathon viability confirmed.
- **Oxen DVC core repo** — `github.com/Oxen-AI/Oxen`. Apache-2.0 Rust DVC.
- **Ollamox** — `github.com/Oxen-AI/Ollamox`. The Oxen → GGUF bridge recipe (download adapter, merge, convert).
- **Fine-Tuning Fridays archive** — `ghost.oxen.ai/fine-tuning-fridays/`. Small-model bake-off series.
- **Oxen $1 fine-tune** — `ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/`. Cost-anchor for our budget.

## Training platform alternatives

- **Modal** — `modal.com/docs/guide/llm-finetuning`. Serverless GPU containers; per-second billing. A100 80GB ~$2.50/hr.
- **Replicate** — Deployed-model-as-API; fine-tuning is a side feature.
- **Together AI** — `together.ai/fine-tuning`. LoRA on ≤16B at $0.48/M tokens; multi-LoRA serving.
- **OpenPipe** — `openpipe.ai/blog`. Drop-in OpenAI SDK wrapper → capture → fine-tune.
- **Unsloth (local)** — `github.com/unslothai/unsloth`. The trainer Cactus assumes; Apache 2.0 / AGPL-3.0.
- **Axolotl** — `github.com/axolotl-ai-cloud/axolotl`. YAML-driven; multi-GPU support.
- **LLaMA-Factory** — `github.com/hiyouga/LLaMA-Factory`. Web UI + CLI; 100+ models.
- **HF AutoTrain** — Zero-code UI on HF infra.
- **Oumi** — `github.com/oumi-ai/oumi`. SFT/LoRA/QLoRA/GRPO 10M–405B range.

---

## Evaluation harnesses

- **deepeval** — `github.com/confident-ai/deepeval`. Apache 2.0; pytest-shaped DX. G-Eval + RAG metrics. Strong fit.
- **RAGAS** — `github.com/explodinggradients/ragas`. Apache 2.0. Faithfulness, answer relevance, context precision/recall.
- **promptfoo** — `github.com/promptfoo/promptfoo`. MIT. Matrix comparisons.
- **lm-evaluation-harness** — `github.com/EleutherAI/lm-evaluation-harness`. MIT. Custom YAML tasks.
- **OpenAI Evals** — MIT. Older; out-evolved.

## Judge-LLM methodology

- **Judging LLM-as-a-Judge** — `arxiv.org/abs/2306.05685`. Canonical; position + verbosity + self-enhancement biases.
- **Hamel Husain LLM-as-Judge guide** — `hamel.dev/blog/posts/llm-judge/`. Calibration recipe — 100–500 labeled examples.
- **Preference Leakage** — `arxiv.org/abs/2502.01534`. Cross-family generator/judge mitigation. Density 3.
- **Position bias interactive** — `mbrenndoerfer.com/writing/position-bias-in-llm-judges`.
- **Galileo AI judge vs human** — `galileo.ai/blog/llm-as-a-judge-vs-human-evaluation`.

## Note-merging / RAG eval shape

- **RAGAS paper** — `arxiv.org/abs/2309.15217`. Reference-free RAG eval.
- **RAGTruth** — `arxiv.org/abs/2401.00396`. Hallucination corpus.
- **IFEval** — `arxiv.org/abs/2311.07911`. Verifiable instructions; programmatic.
- **SummEval** — `arxiv.org/abs/2007.12626`. "Is ROUGE meaningful?" (mostly no).

## Holdout discipline + contamination

- **Preference Leakage** — `arxiv.org/abs/2502.01534`. Generator/judge contamination.
- **Contamination meta-studies** — `arxiv.org/abs/2501.18771`, `arxiv.org/abs/2402.15938`, `arxiv.org/abs/2310.18018`. Up to 30 BLEU inflation; bigger inflates more.

---

## Specialist-vs-generalist evidence

- **LoRA Land** — `arxiv.org/abs/2405.00732` + `predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4`. Strongest aggregate case-for.
- **Tiny Titans** — `arxiv.org/abs/2402.00841`. 770M FLAN-T5 beats zero-shot 7B–70B on meeting summarization; but other compact models lose.
- **DeepSeek-R1-Distill-Qwen-1.5B** — model card. Strongest "small-student-beats-big-generalist" cite.
- **Pixel Recorder** — Gemini Nano LoRA, +24% engagement. Strongest user-behavior cite.
- **Apple Intelligence** — production deployment at iPhone scale.
- **Small Model Learnability Gap** — `arxiv.org/abs/2502.12143`. The counter-case at our exact scale.
- **OpenMedLM** — prompt-engineering beat MedAlpaca; specialist premium is not free.

---

## Licenses

- **Apache-2.0 bases** — Qwen 3, SmolLM2, Phi-3-Mini (MIT), Gemma 4. Clean.
- **Llama Community License** — `llama.com/llama4/license/`. "Built with Llama" + naming prefix + 700M MAU.
- **Gemma Terms (≤3)** — `ai.google.dev/gemma/terms`. Defines Model Derivative broadly; distillation triggers.
- **Gemma 4 Apache-2.0 flip** — `venturebeat.com/...gemma-4-under-apache-2-0`, `mindstudio.ai/blog/gemma-4-apache-2-license-commercial-use`. April 2026.
- **Cactus license** — `github.com/cactus-compute/cactus/blob/main/LICENSE`. Source-available; $2M revenue gate.
- **OpenAI TOS competitive clause** — `openai.com/policies/services-agreement/`. "Use Output to develop models that compete with OpenAI" prohibited.
- **DeepSeek-OpenAI distillation case** — `law.asia/openai-deepseek-ai-distillation/`. Public test case.
- **Anthropic Bedrock distillation** — `anthropic.com/news/trainium2-and-distillation`. Permitted-exception path; doesn't apply to free redistribution.
