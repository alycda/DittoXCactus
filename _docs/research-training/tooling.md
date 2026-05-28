# Tooling Research — Specialist Small-Model Post-Training for Mesh RAG

> **Perspective:** TOOLING. Open-source repos, libraries, framework docs, CLI tools, package ecosystems. Papers go to theory worker; case studies / talks go to industry worker. This file restricts itself to "what does the tool actually do, what is its release/license/maintenance shape, and does it answer our load-bearing engineering questions."
>
> **Companion files:** `theory.md`, `chatgpt-deep-research.md`, `claude-deep-research.md`, `gemini-deep-research.md` in this directory.
>
> **Date of research:** 2026-05-28. Cactus latest = v1.14 (2026-04-18); Cactus moved off GGUF to a proprietary `.cact` format at v1 (Dec 2025). This timing matters — most other tooling in this brief assumes GGUF as the on-device ABI.

---

## 0. Headline verdicts (read this first)

Two questions in the brief are load-bearing for the *engineering* shape of the specialists thread. Both have definitive primary-source answers as of 2026-05-28:

**T5 verdict — Cactus + LoRA at runtime: NO.** Cactus does **not** support runtime adapter loading. The fine-tuning guide at `github.com/cactus-compute/cactus/blob/main/docs/finetuning.md` shows the supported path is `cactus convert <base> <out> --lora <adapter>` — i.e., **merge-at-convert-time only**, producing a single deployable model. There is no `cactus_init` API parameter for adapters, no per-request LoRA switching, no published roadmap item for runtime LoRA. The CLI docs at `docs/cactus_engine.md` confirm `cactus_init(model_path, corpus_dir, cache_index)` has no adapter slot. Cactus is **not** a llama.cpp wrapper as of v1 — it runs its own ARM-SIMD kernel stack and ships models in a proprietary `.cact` format, so it cannot inherit llama.cpp's `/lora-adapters` server endpoint or per-request adapter support from upstream. Workaround: merge LoRA into base, ship one `.cact` blob per specialist, swap entire models if multiple specialists are needed.

**T1 verdict — Oxen.ai's surface area: split. Open-source `Oxen` is data version control (DVC competitor written in Rust). The hosted `oxen.ai` SaaS layers training notebooks + serverless GPU + deployment on top.** This is broader than the user expected if "Oxen.ai" was just a Git-LFS-for-datasets tool, and narrower than expected if "Oxen.ai" was a one-click fine-tune-and-ship platform. The fine-tuning execution path runs through Marimo notebooks on Oxen's hosted GPUs — a real example fine-tuned Qwen3-1.7B for text-to-SQL in **10–12 minutes on a single A10G** at hackathon-class cost (see [Oxen Qwen3 SQL post](https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/) under T1 below). H100 is ~$4.87/hr; free Explorer tier offers 50GB storage + 50GB transfer. **GGUF export is not a documented first-class output** — the platform saves `.safetensors` back to a repo branch via `OxenTrainerCallback`. You bring the GGUF/`.cact` step yourself.

These two verdicts shape the recipe: train wherever (Oxen.ai notebooks, Modal, Unsloth-local), produce a LoRA adapter, then **merge into base and convert through `cactus convert`** to land on the phones. Multi-specialist on a single device means multiple `.cact` files, not multiple adapters on one base.

---

## 1. Top must-read tooling sources (ranked)

1. **`github.com/cactus-compute/cactus/blob/main/docs/finetuning.md`** — *The* document that resolves T5. Six-step CLI walkthrough: train with Unsloth → `cactus convert` with `--lora` flag → `cactus build --apple`/`--android` → link into app. Supported bases: Qwen3, Qwen3.5, Gemma3, LFM2, LFM2.5. Read this first because it dictates the shape of every upstream decision.

2. **`github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md`** — Engine API. Confirms there is no runtime adapter slot in `cactus_init`. Documents the model architectures with first-class support (Qwen/Qwen3.5 text+vision+embedding, Gemma 3/3n text, LFM2, etc.). One quantization-relevant note: Moonshine requires FP16. Quantization options for our case (1.7B text): INT4/INT8/FP16 are supported in the engine but the user-facing knob is per-model.

3. **`huggingface.co/blog/qvac/fabric-llm-finetune`** (Tether Data, Dec 2025) — The first published demonstration of **LoRA fine-tuning on mobile GPUs** (Adreno 830, Mali-G715, Apple Silicon) via a llama.cpp fork. Not directly applicable to Cactus (different runtime), but proves that mobile-GPU LoRA training is now feasible. Wall-clock for our reference target Qwen3-1.7B Q8, 8 epochs: 45 min on RTX 4090, 13 hrs on Adreno 830. Apache-2.0. Repo: `github.com/tetherto/qvac-fabric-llm.cpp`.

4. **`github.com/unslothai/unsloth`** — Custom-Triton-kernel PEFT trainer; 1.5–2× faster and 20–80% less VRAM than vanilla transformers+PEFT. **Officially endorsed in the Cactus fine-tuning guide** as the upstream trainer — `cactus convert --lora` consumes Unsloth-saved adapters. Dual-licensed Apache 2.0 (core) / AGPL-3.0 (Studio UI); 500+ models supported; latest v0.1.42-beta (May 2026). The path of least resistance for our recipe.

5. **`github.com/Oxen-AI/Oxen`** — The Rust-native data-version-control core. v0.50.1 (May 2026), Apache-2.0. Merkle-tree + dedup, 40× faster than git-lfs, 6.5× faster than `aws s3 cp`. This is what the user is actually buying into when they choose Oxen.ai as a training platform — the data substrate. The training and deployment layer is the SaaS wrapper at `oxen.ai`.

6. **`github.com/huggingface/peft`** — Reference implementation of LoRA / QLoRA / DoRA / IA3 / soft prompts. v0.19.1 (April 2026), Apache-2.0. The basic LoRA API is 6 lines (`LoraConfig(r=16, lora_alpha=32)` → `get_peft_model`). For our 1.7B-class workload, vanilla PEFT + a single A10G is sufficient; Unsloth is a perf optimization, not a different recipe.

7. **`github.com/huggingface/trl`** — `SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, `RewardTrainer`. v1.5.1 (May 27, 2026), Apache-2.0. The "outer loop" for the actual training step. Cactus's guide assumes Unsloth wraps both PEFT and TRL; if not using Unsloth, TRL+PEFT is the canonical pairing.

8. **`github.com/ggml-org/llama.cpp`** — The substrate that Cactus *replaced* but that everyone else (MLC, Ollama, Unsloth's GGUF export) still uses. Has **mature runtime LoRA**: `--lora` flag, server `/lora-adapters` endpoint for hot-swap, `convert_lora_to_gguf.py`. If the demo needed runtime adapter switching, llama.cpp would meet the need; Cactus does not.

9. **`github.com/EleutherAI/lm-evaluation-harness`** — Standard-issue eval harness. v0.4.12 (May 2026), MIT. 60+ benchmarks, custom-task support via YAML. Backs HF Open LLM Leaderboard. For *our* narrow-domain note-merging task, lm-eval-harness is the *shape* we want — write a custom task YAML and run `simple_evaluate()` — but the reference benchmarks (MMLU, HellaSwag) won't move much at 1.7B and aren't what we should report.

10. **`distilabel.argilla.io`** (repo `github.com/argilla-io/distilabel`) — Synthetic data generation pipelines, Apache-2.0, v1.5.3 (Jan 2025 — a year stale, flag). Ships Magpie + Self-Instruct + Evol-Instruct templates. Integrates HF datasets + Hub via `push_to_hub()`. For our note-merging dataset bootstrap (zero existing public corpus), this is the right tool *unless* the stale release becomes a blocker.

---

## 2. Per-topic findings

### T1 — Oxen.ai surface area

**What it actually is (separating the open-source core from the SaaS):**

| Layer | Form | What it does | Where it overlaps |
|---|---|---|---|
| `Oxen-AI/Oxen` | Rust CLI + Py/Rust/HTTP bindings, Apache-2.0 | Data version control: Merkle-tree, dedup, row-level diff over Parquet/CSV/JSONL via DuckDB indexing | Replaces: DVC, git-lfs, S3-direct. Doesn't replace: WandB, MLflow. |
| `oxen.ai` (SaaS) | Hosted service, paid | Marimo notebook + serverless GPU + zero-code FT UI + deployable inference endpoints | Overlaps: Modal/Replicate/Together fine-tune surface, HF AutoTrain. Differentiated by tight data-versioning loop. |

The user's "I've heard of Oxen.ai but haven't used it for training" framing maps to: they know the data-versioning open-source tool exists; the *training* part is the SaaS layer they haven't touched. **Both halves are real and both serve our use case** — but they're separate things that share a brand.

**Concrete training-on-Oxen.ai case study** ([ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/](https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/)): full-fine-tune (not LoRA) of Qwen3-0.6B and Qwen3-1.7B for text-to-SQL on 5,000 filtered examples (wikisql + spider + sql_create_context + nvbench). 10–12 minutes end-to-end on a single **A10G with 8 CPU cores and 8 GB**. Execution: Marimo notebook on Oxen's serverless GPU. Eval: Gemini as judge on 200-example val set, semantic SQL equivalence. Result: Qwen3-1.7B SFT hits 57% vs GPT-4o baseline 45%. Output: weights saved to repo branch via `OxenTrainerCallback`. **No GGUF/Cactus step shown** — that's a bring-your-own-conversion gap.

**Pricing for hackathon-scale:**
- Free Explorer tier: 50GB storage, 50GB transfer, unlimited public repos, 5 private.
- H100: $4.87/hr; 3–10 hours of LoRA on a 1.7B base = **$15–50** end to end.
- Hacker $30/mo, Pro $60/mo for higher storage caps.

**Where Oxen.ai fits relative to alternatives:**

| Platform | Architecture vs Oxen.ai (1-sentence) |
|---|---|
| **Modal** | Pure compute-as-functions; you ship a Python script and pick a GPU type. Oxen.ai adds data versioning + notebook + deployment UI; Modal is more flexible but you wire the data layer yourself. |
| **Replicate** | Deployed-model-as-API focus; fine-tuning is a side feature. Oxen.ai's training surface is more central. |
| **Together AI fine-tuning** | Production API; LoRA on ≤16B at **$0.48/M tokens** with serverless multi-LoRA serving. Cheaper per-token for inference; less control over the training loop than a Marimo notebook. |
| **OpenPipe** | Drop-in OpenAI-compatible wrapper that records prompts → fine-tunes a small model → replaces the calls. Specifically a "GPT-4 → cheap small model" funnel, not generic fine-tuning. |
| **HuggingFace AutoTrain** | Zero-code UI on HF infra. Less data-versioning depth than Oxen; more model-zoo depth. |
| **Unsloth (local)** | Library, not platform. Runs on your own GPU or Colab Pro; you handle data and deployment. Cactus's official trainer. |
| **Axolotl** | YAML-config-driven trainer for self-hosted or cloud GPU. Closer to LLaMA-Factory than to Oxen.ai. |

**Gap:** No public Oxen.ai → GGUF → Cactus pipeline has been documented. Oxen's blog covers fine-tuning and deployment to *their* inference endpoints; the conversion to GGUF / `.cact` is left to the user. The Cactus-side conversion is solved (the `cactus convert --lora` CLI) but it expects an adapter on disk, which means: (a) `oxen pull` the adapter from the Oxen branch, (b) feed it to `cactus convert`. Two-step, but plausible.

---

### T2 — PEFT for small base models

**The four trainer-framework choices in 2026 (any of them work; difference is ergonomics):**

| Framework | Latest | License | Distinguishing feature |
|---|---|---|---|
| **Unsloth** (`github.com/unslothai/unsloth`) | v0.1.42-beta (May 2026) | Apache 2.0 / AGPL-3.0 split | Custom Triton kernels; 1.5–2× speed, 20–80% VRAM savings. **Recommended by Cactus.** Adapter save format consumed natively by `cactus convert --lora`. |
| **HF PEFT + TRL** (`github.com/huggingface/peft`, `github.com/huggingface/trl`) | PEFT v0.19.1, TRL v1.5.1 (April–May 2026) | Apache 2.0 | Canonical reference. 6-line LoRA setup. Slower than Unsloth but no version-lock. |
| **Axolotl** (`github.com/axolotl-ai-cloud/axolotl`) | v0.16.1 (April 2026) | Apache 2.0 | Single YAML config drives data prep → train → eval → quantize → infer. Sequence Parallelism, ScatterMoE, DoRA, GRPO, GDPO. Heavier than Unsloth, more reproducible. |
| **LLaMA-Factory** (`github.com/hiyouga/LLaMA-Factory`) | v0.9.4 (Dec 2025) | Apache 2.0 (weights inherit base license) | Web UI (LLaMA Board) + CLI. 100+ models. Supports OFT, GaLore, BAdam, PiSSA in addition to LoRA/QLoRA/DoRA. ACL 2024 paper-grade reproducibility. |
| **Oumi** (`github.com/oumi-ai/oumi`) | v0.8 (May 2026) | Apache 2.0 | SFT/LoRA/QLoRA/GRPO, 10M–405B range. `oumi deploy` CLI + MCP server integration. No mobile/GGUF export documented. |

**Methods inventory (paper-side coverage lives in `theory.md`; here just the toolable methods):** LoRA, QLoRA, DoRA, LoRA-FA, OFT, GaLore, BAdam, PiSSA are all in either PEFT or LLaMA-Factory as named recipes today. For a 1.7B base on the note-merging task, **plain LoRA (r=16, alpha=32) under Unsloth** is the boring default and well-trodden; DoRA is a free upgrade if PEFT supports it for the chosen model (PEFT 0.19+ does).

**Preference-based methods toolable:** TRL ships `SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, `RewardTrainer`. KTO/ORPO are in LLaMA-Factory's list but not headlined in TRL's README — verify before depending on them. Brief verdict: SFT first for the note-merging task (it has correct outputs), DPO only if there's a quality plateau and a sane preference signal to harvest.

**Hardware floors documented in real tooling docs:**
- Unsloth's Qwen3-0.6B/1.7B free Colab notebooks (T4, 16GB) are documented in their Qwen3 guide.
- A10G on Oxen.ai (8GB VRAM-class, full-fine-tune of 1.7B) — 10–12 min for 5k examples.
- M-series Macs via MLX / mlx-lm — not surveyed deeply here; flag for industry worker.

**Merged-weights vs adapter-only deployment (operational):**
- For Cactus: **must merge.** `cactus convert --lora` produces a single `.cact` blob.
- For llama.cpp: adapter-only works; runtime `--lora`, hot-swap via `/lora-adapters`.
- For MLC: adapter-only works (PR #3281 landed; multi-LoRA batching + dynamic switching shipped for desktop, mobile in progress).
- For ExecuTorch: adapter-only works in 1.0 — exports multiple `.pte` LoRA files sharing one foundation set.

**Gap:** the Cactus mobile target is the *least* favorable in this matrix for the "multiple specialists per device" thesis. If the writeup wants to argue "one device, many specialists swapping at runtime," it needs either (a) wait for Cactus runtime LoRA, (b) move to MLC LLM, or (c) accept N `.cact` blobs and a model-switch hop.

---

### T3 — Distillation tooling (thin coverage; theory file owns the methods)

Tooling-side observations only:

- **distilabel** (`github.com/argilla-io/distilabel`) is the actively maintained library for teacher-model output collection (Apache 2.0; v1.5.3 from Jan 2025 — **flag: ~16 months stale at time of this brief**, project health to verify). Pipelines for soft-label or hard-label distillation, integrated with HF Hub and most major LLM API providers.
- **DeepSeek-R1-Distill** weights (`huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B`) are MIT-licensed and demonstrate the recipe: Qwen-1.5B base + reasoning traces from R1-zero, distilled via SFT. The base inherits Qwen's Apache 2.0, the distill weights are MIT. This is a deployable model, not a tool — but it's the reference for "this size class can be distilled and the artifact is openly redistributable."
- **OpenPipe** is a hosted variant of the distillation pattern: drop-in OpenAI client → captures prompts/responses → fine-tunes a small open model on them. Specifically a GPT-4 → small-open funnel.

**Gap (tooling-flavored):** no off-the-shelf "GPT-4o → Qwen3-1.7B → Cactus" pipeline exists; this would be a glue-script we write. Components are all there.

---

### T4 — Synthetic-data tooling

- **distilabel** (above) — Magpie + Self-Instruct + Evol-Instruct templates baked in. Magpie's claim ([arxiv.org/abs/2406.08464](https://arxiv.org/abs/2406.08464)) is "instruction synthesis from nothing" — feed an instruct model the pre-query tokens and it autocompletes user instructions; 50k pairs in Magpie-Ultra fine-tuned Llama-3-8B competitively. For note-merging, we'd use distilabel to seed (input note pair, merged note) examples from a strong teacher (GPT-4o, Claude Sonnet — TOS caveats from T7).
- **Augmentoolkit** (`github.com/e-p-armstrong/augmentoolkit`) — v3.0 (June 2025), MIT. Document-in, dataset-out. Pipelines for factual Q&A, RAG-prep data, classification, roleplay. Runs locally — important for the "don't send our seed corpus to OpenAI" posture if we want to stay closed-loop. Quantized-model-capable, so we could in theory generate data on a workstation with a 7B teacher.
- **No purpose-built note-merging dataset corpus exists** in HF datasets (MultiNews, WikiSum, BookSum cover adjacent multi-doc summarization; none are note-merging shaped). This is a Magpie-from-scratch or Augmentoolkit-from-seed-notes task.

**Gap:** none of these tools ship with quality-measurement scoring baked in beyond reward-model rerank patterns. Dataset-quality validation before training is left to the user — embedding-cluster sanity checks, manual spot-checks, or a judge-LLM pass.

---

### T5 — On-device adapter loading (THE load-bearing engineering question)

**Cactus answer: NO runtime adapter loading. Merge-at-convert-time only.**

Primary sources:

| Source | What it shows |
|---|---|
| `github.com/cactus-compute/cactus/blob/main/docs/finetuning.md` | The official guide. Workflow is: Unsloth → `cactus convert <base> <out> --lora <adapter>` → `cactus build --apple/--android`. Supported bases: Qwen3, Qwen3.5, Gemma3, LFM2, LFM2.5. |
| `github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md` | Engine API. `cactus_init(model_path, corpus_dir, cache_index)` — no adapter parameter. No `set_lora`-style call. |
| Cactus v1 release notes / [InfoQ Dec 2025](https://www.infoq.com/news/2025/12/cactus-on-device-inference/) | v1 transitioned **off GGUF** to a proprietary `.cact` format with custom ARM-SIMD kernels. Cactus no longer wraps llama.cpp — it's a from-scratch inference stack. |
| Cactus issue tracker (12 currently open issues) | **No open issue, PR, or roadmap item for LoRA runtime loading or multi-adapter** as of 2026-05-28. Issues are about build, multi-modal models, TTS, llguidance. |

**Implication for the demo:** if we ship a specialist, it goes as a separate `.cact` model. If we want multiple specialists per device, we ship multiple `.cact` files and switch models at the app layer (unload, reload). Cactus does support multi-model registry via the dashboard at `cactuscompute.com/dashboard/models`, but each model is its own download.

**llama.cpp answer: YES, mature.** The `--lora` flag works at startup; the `llama-server` has a `/lora-adapters` POST endpoint for hot-swap (`PR #8857`); per-request adapter selection landed in `PR #10994`; multi-adapter via [`llama-cpp-python` PR #1817](https://github.com/abetlen/llama-cpp-python/pull/1817). `convert_lora_to_gguf.py` ships in `gguf-py/`. **This is what we'd use if not on Cactus.** For the Mesh RAG demo, llama.cpp isn't on-table because we'd lose the iOS/Android Flutter SDK and the BLE/Ditto integration the demo already has — but it's the answer to "what does the mature path look like."

**MLC LLM answer: YES (desktop confirmed, mobile in progress).** [PR #3281](https://github.com/mlc-ai/mlc-llm/pull/3281) (Aug 2025-ish) landed C++ LoRA manager, TVM-FFI integration, `upload_lora`/`set_lora`/`get_lora_delta` Python API. Mobile deployment is a static-library compile, so theoretically the runtime LoRA mechanism extends to iOS/Android binaries, but published roadmap items still list "cross-platform LoRA deployment to mobile and edge devices" as future work — verify with MLC's own docs before betting on it for a demo. **MLC is the live alternative to Cactus if multi-specialist-per-device becomes a hard requirement.**

**ExecuTorch answer: YES (1.0).** ExecuTorch 1.0 supports exporting multiple `.pte` LoRA files that share one foundation weights set. PyTorch's official mobile runtime. If the Mesh RAG demo wanted to swap off both Cactus and llama.cpp/MLC, ExecuTorch is the credible PyTorch-native answer. Not surveyed deeply here because Cactus is the current substrate.

**QVAC Fabric (Tether) — adjacent but interesting:** [github.com/tetherto/qvac-fabric-llm.cpp](https://github.com/tetherto/qvac-fabric-llm.cpp) is a llama.cpp fork that supports **LoRA fine-tuning on mobile GPUs** (Vulkan + Metal). On Qwen3-1.7B Q8: RTX 4090 = 5.5min/epoch, Adreno 830 (Pixel-class phone) = 1h40min/epoch, Mali-G715 = 7h40min/epoch. Apache 2.0. Not a Cactus integration, but the existence proof that on-device LoRA *training* is now feasible is itself writeup-worthy for the writeup's specialists arc — and it's GGUF-native, so it could feed a llama.cpp-mobile alternative deployment.

**GGUF conversion + quantization for fine-tuned weights:** standard path is `convert_lora_to_gguf.py` after merging in PEFT-land (`model.merge_and_unload()`), or use Unsloth's `save_pretrained_gguf("Q4_K_M")` shorthand which does the merge + convert + quantize in one. Quality cost of Q4_K_M for fine-tuned 1.7B is ~1–3% on standard benches; for a narrow-domain specialist, this is typically less because the specialist's overfit is concentrated in fewer parameters. **Cactus's conversion does the merge + transform to `.cact` in one step; Q4_K_M-equivalent quantization happens inside that.**

**Cross-platform parity of fine-tuned weights:** the demo's R2 determinism harness tests embedding cosine parity across iOS and Android. Fine-tuned LoRA *deltas* on the order of LoRA-rank-16 perturbations are not larger than the existing inter-platform floating-point drift the harness already passes; no new divergence risk identified in the primary sources. Verify post-fine-tune by re-running the existing harness on the merged `.cact` model.

**Gap:** Cactus's `RAG fine-tuning` feature mentioned in the v1 InfoQ piece ("the Flutter SDK additionally offers RAG fine-tuning") is undocumented in the engine docs as of this brief — could not determine whether this is a different surface area than the LoRA-merge path. Flag for direct outreach to Cactus maintainers if it becomes blocking.

---

### T6 — Evaluation harnesses

| Tool | Latest | License | Fit for our task |
|---|---|---|---|
| **`EleutherAI/lm-evaluation-harness`** | v0.4.12 (May 2026) | MIT | Right *shape* — custom YAML task + `simple_evaluate()`. 60+ reference benchmarks none of which move at 1.7B. Use it as scaffolding for our note-merging task; don't expect MMLU to be informative. |
| **RAGAS** (`github.com/explodinggradients/ragas`) | v0.4.3 (Jan 2026) | Apache 2.0 | RAG-specific. Faithfulness, answer relevancy, context precision/recall. **Maps closely** to the Mesh RAG demo's existing retrieval pipeline. |
| **deepeval** (`github.com/confident-ai/deepeval`) | v4.0.5 (May 28, 2026 — shipped same day as this brief) | Apache 2.0 | Pytest-shaped DX. G-Eval (judge-LLM), DAG-based metrics, RAG metrics, hallucination, summarization, JSON correctness. Strong fit. |
| **promptfoo** (`github.com/promptfoo/promptfoo`) | active (May 2026) | MIT | CLI + library, "any LLM API." Self-grading supported. Strong for matrix comparison (base vs LoRA vs LoRA+DPO). |
| **OpenAI Evals** | — | MIT | Older; widely cited. Out-evolved by the above for fine-tune-specific work. |

**Practical pick for the note-merging specialist:** use **deepeval** or **RAGAS** for the metric set (faithfulness + summary correctness + judge-LLM G-Eval), **lm-evaluation-harness** for any standard-benchmark numbers to report alongside (so the writeup can say "ARC-Easy isn't degraded by this fine-tune"). Use **promptfoo** for the comparison matrix (base vs FT vs FT-quantized vs `.cact`-deployed).

**Judge-LLM gotcha line for the writeup:** the well-documented position bias / length bias / self-preference bias of judge-LLMs is the eval-methodology trap. The theory worker should cover this with citations; tooling-side, deepeval's G-Eval and Vicuna-style pairwise evaluation are the canonical implementations.

**Gap:** none of these harnesses ship a note-merging task. Custom task definition (input pair, expected merge, gold structure) is on us. ~200 held-out examples is the typical floor for a meaningful per-metric signal at this scale (cf the Oxen.ai Qwen3-SQL eval used 200).

---

### T7 — License posture (tooling-side, dataset-side)

**Base models surveyed:**

| Model | License | Redistribute fine-tune? |
|---|---|---|
| Qwen3-0.6B / 1.7B (`huggingface.co/Qwen/Qwen3-1.7B`) | **Apache 2.0** | Yes. Standard Apache attribution (preserve copyright + license + NOTICE, document modifications). No "Built with Qwen" naming requirement. |
| Qwen3-Embedding-0.6B | **Apache 2.0** | Yes. Note: [GitHub issue #166](https://github.com/QwenLM/Qwen3-Embedding/issues/166) flags MS-MARCO usage during training — minor license-edge for the *training data*, not the weights; consult for the embedder if it gets fine-tuned. |
| SmolLM2 (135M/360M/1.7B) | **Apache 2.0** | Yes. Clean. |
| Phi-3-Mini | **MIT** (Microsoft) | Yes. Clean. |
| Gemma 3 1B | Gemma Terms of Use (not OSI-approved; restrictive) | Conditional. Use restrictions apply; redistribution requires complying with prohibited-use policy. Less clean than Apache. |
| Llama 3.2 1B / 3B | Llama Community License | Conditional. "Built with Llama" naming prefix requirement on derivatives; 700M MAU clause. Acceptable for our hackathon but adds attribution burden. |

**Verdict for our context:** **Stick with Qwen3-0.6B or Qwen3-1.7B** for Apache-2.0 clarity. SmolLM2-1.7B is the obvious backup if Qwen3 has structural issues for the note-merging task (e.g., the bilingual CoT drift the current demo absorbs).

**Tooling licenses (all of these are clean to use commercially):**
- Apache 2.0: PEFT, TRL, Axolotl, LLaMA-Factory, Oumi, Unsloth-core, Oxen, RAGAS, deepeval, distilabel, llama.cpp, MLC LLM, ExecuTorch, QVAC-Fabric.
- MIT: lm-evaluation-harness, promptfoo, Augmentoolkit.
- **Source-available / dual-license:** Unsloth Studio UI is AGPL-3.0 (use the library, skip the UI for commercial closed work).
- **Source-available with revenue gate: Cactus.** Per `LICENSE` at the repo root, Cactus is free for individuals, educational institutions, nonprofits, and orgs under **$2M in funding-or-revenue**. Above that threshold a commercial license from Cactus Compute Inc. is required. **Flag this for the writeup** — it's not Apache; the hackathon repo is fine, but anyone reading the writeup who's at a real company needs to know.

**Synthetic-data-from-API-model TOS:**
- **OpenAI:** Their Terms historically restricted using API outputs to "develop models that compete with OpenAI." Current ToS (re-read at brief time recommended) softened some language but the competitive-model clause remains. For a public hackathon repo distilling GPT-4o-mini → Qwen3-1.7B specialist, the question is whether a specialized note-merger is "competitive" — defensible answer is no, but the safer move is Claude or Gemini if cost-comparable, or pure-Magpie / Augmentoolkit-local.
- **Anthropic:** Acceptable Use Policy similarly restricts competitive-model training; consult current AUP at brief execution.
- **Google Gemini:** Allowed for fine-tuning under their API ToS as of last update; verify.

**Dataset licenses (relevant only if we use off-the-shelf):**
- MultiNews, WikiSum: respective licenses on HF; both are CC-BY-SA-derived and require attribution but allow redistribution.
- For our case, since no off-the-shelf note-merging dataset exists, we'll be generating synthetic data — the synthetic data license inherits from (a) the teacher model's TOS and (b) any seed examples we hand-craft (which we own).

**Gap:** the most recent OpenAI / Anthropic ToS texts should be re-read by a human before publishing a distilled model. Don't infer from secondary sources.

---

## 3. Tool shortlist (concrete decisions)

For each row: repo URL + last release + license + maintenance health + mobile-platform support matrix + one-sentence verdict.

### Training platform
- **`oxen.ai` (SaaS) + `github.com/Oxen-AI/Oxen` (core)** — Oxen v0.50.1 (May 2026, active) | Apache 2.0 (core), SaaS terms separately | Free Explorer tier viable for hackathon; H100 $4.87/hr | Mobile platform support: N/A (training side; user does their own conversion). **Verdict:** strong choice for the data-versioning loop + zero-code training; budget a separate step for GGUF/`.cact` conversion since Oxen doesn't do that out of the box.
- **Backup: `modal.com`** — paid, mature, $30/mo free credit | A10 $1.10/hr, A100 $2.50/hr, H100 $3.95/hr | Pay-per-second granularity. **Verdict:** safer if Oxen's notebook UX doesn't fit; you write the script, you control everything, no opinionated data-versioning layer.
- **Sub-backup: `colab.research.google.com` (Colab Pro)** — Unsloth Qwen3 free notebook exists | T4/L4 free or A100 cheap on Pro+ | Suitable for the 1.7B-class workload (Unsloth claims free T4 is enough for Qwen3-1.7B LoRA).

### PEFT library
- **`github.com/unslothai/unsloth`** — v0.1.42-beta (May 2026, very active) | Apache 2.0 / AGPL-3.0 | Mobile: produces adapters/GGUF/`.cact` (via Cactus's CLI). **Verdict:** the path Cactus's official docs assume — pick this unless you have a reason not to. Stale-release concern: none (released this month).
- **Alt: `github.com/huggingface/peft` + `github.com/huggingface/trl`** — v0.19.1 + v1.5.1 (April–May 2026, very active) | Apache 2.0 | Mobile: agnostic, you do conversion. **Verdict:** use this if Unsloth has a model/feature gap; slightly slower, more transparent.

### Eval harness
- **Primary: `github.com/confident-ai/deepeval`** — v4.0.5 (May 28, 2026 — extremely active) | Apache 2.0 | Mobile-relevance: judge runs locally or via API. **Verdict:** broad metric coverage (G-Eval, hallucination, summarization, faithfulness), pytest-shaped DX, the right tool for a hackathon-scoped specialist eval.
- **For RAG-specific signals: `github.com/explodinggradients/ragas`** — v0.4.3 (Jan 2026, active) | Apache 2.0. **Verdict:** add this on top of deepeval if you need faithfulness/context-recall numbers for the writeup.
- **For comparison matrix: `github.com/promptfoo/promptfoo`** — active May 2026 | MIT. **Verdict:** the right tool for "base vs FT vs FT-quantized vs `.cact`-on-device" side-by-side reporting.
- **For stay-honest standard benches: `github.com/EleutherAI/lm-evaluation-harness`** — v0.4.12 (May 2026, very active) | MIT.

### Synthetic-data tooling
- **Primary: `github.com/argilla-io/distilabel`** — v1.5.3 (Jan 2025 — flag: ~16-month-stale release; verify project health on the repo's commits page before committing) | Apache 2.0 | Magpie + Self-Instruct + Evol-Instruct templates. **Verdict:** strongest off-the-shelf, but the stale release is a yellow flag. The Magpie reference repo `github.com/magpie-align/magpie` is the fallback.
- **Backup: `github.com/e-p-armstrong/augmentoolkit`** — v3.0 (June 2025, active) | MIT. **Verdict:** document-in, dataset-out, runs local — strongest pick if you want to keep the seed corpus off cloud APIs.

### On-device deployment path
- **Primary (must-merge): `github.com/cactus-compute/cactus`** — v1.14 (April 2026, active) | **Source-available with revenue gate (<$2M funding/revenue free; commercial license above)** | iOS + Android + macOS + Linux. **Verdict:** the demo's current runtime. LoRA path is `cactus convert --lora` → single merged `.cact` artifact. No runtime adapter swap.
- **Alt if multi-adapter-on-device becomes needed: `github.com/mlc-ai/mlc-llm`** — Apache 2.0 | runtime LoRA shipped desktop, mobile-cross-platform-LoRA in progress per PR #3281 roadmap. **Verdict:** the live alternative if Cactus's no-runtime-LoRA constraint becomes a thesis-breaking issue. Migration cost: significant — different Flutter integration story, different model registry, different conversion pipeline.
- **Alt (PyTorch-native): `github.com/pytorch/executorch`** — 1.0 shipped; multi-`.pte` LoRA sharing one foundation set. **Verdict:** plausible alternative; not the demo's current path.
- **Demo-orthogonal but writeup-worthy: `github.com/tetherto/qvac-fabric-llm.cpp`** — Apache 2.0; first published on-device LoRA *training* on Adreno/Mali/Apple GPUs. **Verdict:** cite this as evidence that on-device-training is no longer hypothetical; doesn't change our deployment path.

---

## 4. Reference implementations (public repos that fine-tuned ≤3B base for a narrow domain)

1. **`github.com/haydarkadioglu/Qwen3-0.6B-lora-python-expert`** — Qwen3-0.6B LoRA fine-tune on `flytech/python-codes-25k` dataset, 3 epochs batch=8, A100/T4 (Colab). Training loss curve 1.83 → 1.64. **Structurally analogous:** same base (0.6B), small narrow-domain corpus (~25k examples), LoRA via PEFT. **Gap relative to us:** ships as PyTorch weights only; no GGUF/`.cact`, no mobile demo, no eval set documentation. We need to do the conversion + eval steps they skipped.

2. **`github.com/tetherto/qvac-fabric-llm.cpp` + `huggingface.co/qvac/fabric-llm-finetune`** (Tether Data) — on-device LoRA fine-tuning of Qwen3 / Gemma3 via Vulkan/Metal. Adapter artifacts published on HF; binary release for multi-platform. **Structurally analogous:** same base families, mobile-GPU class hardware. **Gap relative to us:** they trained *on* the phone; we're training in cloud and deploying. But the deployment-side learnings (Q4/Q8 trade-offs at this size, ARM kernel constraints) carry over.

3. **`huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B`** — Reference for "distill a known good large reasoner into a small base." MIT-licensed weights, Apache-2.0 base. **Structurally analogous:** demonstrates the upper bound for ≤2B specialist quality on a reasoning-shaped task. **Gap relative to us:** different task (reasoning vs note-merging), different teacher (R1-zero vs whatever we'd use), different scale of training data (theirs is huge).

4. **`github.com/oumi-ai/oumi/tree/main/configs/recipes`** — Oumi's recipe directory has plug-and-play YAML for SFT/LoRA/QLoRA on Qwen/Gemma/Llama/SmolLM small models. Apache-2.0, very active. **Structurally analogous:** same model class, same methods. **Gap relative to us:** no mobile/GGUF/`.cact` step in their recipes — same gap as Oxen.

5. **`github.com/huggingface/smollm/tree/main/finetune`** — Official HuggingFace fine-tune scripts for SmolLM2 (135M/360M/1.7B). Apache-2.0 base. **Structurally analogous:** SmolLM2-1.7B is our top backup base if Qwen3 doesn't work; this is the canonical recipe. **Gap relative to us:** doesn't cover Cactus deployment; covers GGUF via standard llama.cpp convert.

---

## 5. Open research questions / tooling gaps

**TOOLING-GAP-1 — Cactus + multi-adapter on one device (named verdict UNKNOWN-PLANNED):** Cactus does not currently support runtime LoRA loading or multi-adapter switching. There is no roadmap item in the public issue tracker as of 2026-05-28. Workarounds: ship multiple full `.cact` models and switch at the app layer (storage cost: ~one base-model footprint per specialist), or migrate the demo to MLC LLM. Verdict to writeup: "Today, one specialist per `.cact` blob. Multi-specialist-per-device is a future work item that depends on either Cactus shipping runtime LoRA or a runtime migration."

**TOOLING-GAP-2 — No Oxen.ai → Cactus pipeline documented end-to-end.** Both halves work; nobody has written the bridge. The bridge is small (`oxen pull` the adapter, then `cactus convert --lora`). Writing it could be a small standalone artifact from this hackathon.

**TOOLING-GAP-3 — distilabel release cadence.** v1.5.3 is from Jan 2025. ~16 months stale at brief time. Verify health on commits-since-release before committing the recipe to distilabel; fallback to Augmentoolkit or the Magpie reference repo.

**TOOLING-GAP-4 — `RAG fine-tuning` in Cactus Flutter SDK is undocumented.** The InfoQ v1 article mentions a Flutter-SDK-only "RAG fine-tuning" feature. The engine docs at `docs/cactus_engine.md` don't describe it. Could be a different surface than LoRA-merge — could be the user-data continual-personalization path. Direct maintainer outreach (Discord/GitHub) is the way to resolve this; not surfaceable from primary docs.

**TOOLING-GAP-5 — Cross-platform parity test post-fine-tune.** The demo has an R2 determinism harness for embedding cosine parity. No published evidence either way that LoRA-rank-16 perturbations on a 1.7B base shift cross-platform float drift outside the existing tolerance. Trivially testable post-fine-tune by re-running the harness; flagging as gap because no upstream tool gives a prediction.

**TOOLING-GAP-6 — Cactus license clarity for redistributable demos.** The Cactus LICENSE permits free use under <$2M-revenue thresholds. The hackathon repo is fine, but the writeup audience includes people at larger orgs. Should be a one-line note: "Cactus is source-available, not Apache; check the threshold before commercial use."

---

## 6. Source ledger (flat, deduplicated, in order of first appearance)

https://github.com/cactus-compute/cactus
https://www.oxen.ai
https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md
https://docs.oxen.ai
https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md
https://docs.oxen.ai/examples/fine-tuning/image_generation
https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/
https://www.oxen.ai/pricing
https://github.com/unslothai/unsloth
https://github.com/huggingface/peft
https://github.com/axolotl-ai-cloud/axolotl
https://github.com/hiyouga/LLaMA-Factory
https://github.com/EleutherAI/lm-evaluation-harness
https://github.com/explodinggradients/ragas
https://github.com/argilla-io/distilabel
https://github.com/ggml-org/llama.cpp
https://github.com/ggml-org/llama.cpp/discussions/8849
https://github.com/ollama/ollama/issues/9548
https://docs.vllm.ai/en/latest/features/lora/
https://github.com/abetlen/llama-cpp-python/pull/1817
https://github.com/ggml-org/llama.cpp/issues/10377
https://github.com/ggml-org/llama.cpp/discussions/7850
https://unsloth.ai/docs/basics/inference-and-deployment/vllm-guide/lora-hot-swapping-guide
https://github.com/mlc-ai/mlc-llm
https://github.com/mlc-ai/mlc-llm/pull/3281
https://llm.mlc.ai/
https://github.com/pytorch/executorch
https://executorch.ai/
https://github.com/promptfoo/promptfoo
https://github.com/e-p-armstrong/augmentoolkit
https://modal.com/docs/guide/llm-finetuning
https://modal.com/pricing
https://openpipe.ai/blog/a-non-technical-explanation-of-fine-tuning
https://www.together.ai/fine-tuning
https://www.together.ai/pricing
https://docs.together.ai/docs/fine-tuning-pricing
https://www.together.ai/blog/serverless-multi-lora-fine-tune-and-deploy-hundreds-of-adapters-for-model-customization-at-scale
https://huggingface.co/blog/qvac/fabric-llm-finetune
https://github.com/tetherto/qvac-fabric-llm.cpp
https://github.com/tetherto/qvac-rnd-fabric-llm-finetune
https://huggingface.co/qvac/fabric-llm-finetune
https://github.com/oumi-ai/oumi
https://ghost.oxen.ai/oxens-model-report-2/
https://github.com/cactus-compute/cactus/releases
https://github.com/cactus-compute/cactus/issues
https://github.com/confident-ai/deepeval
https://github.com/Oxen-AI/Oxen
https://www.infoq.com/news/2025/12/cactus-on-device-inference/
https://cactuscompute.com/docs/v1.7
https://cactuscompute.com/dashboard/models
https://github.com/huggingface/trl
https://github.com/QwenLM/Qwen3-VL/blob/main/LICENSE
https://huggingface.co/Qwen/Qwen3-1.7B
https://huggingface.co/Qwen/Qwen3-8B/blob/main/LICENSE
https://github.com/QwenLM/Qwen3-Embedding/issues/166
https://github.com/cactus-compute/cactus/blob/main/LICENSE
https://github.com/david-franz/llm-fine-tuning-LoRa
https://github.com/haydarkadioglu/Qwen3-0.6B-lora-python-expert
https://github.com/Edge-Intelligence-Lab/MobileFineTuner
https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B
https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct/discussions/2
https://github.com/huggingface/smollm/tree/main/finetune
https://github.com/2U1/SmolVLM-Finetune
https://github.com/NVIDIA/workbench-example-phi3-finetune
https://github.com/microsoft/PhiCookBook
https://arxiv.org/abs/2406.08464
https://github.com/magpie-align/magpie
https://distilabel.argilla.io/latest/components-gallery/tasks/magpie/
https://unsloth.ai/docs/models/tutorials/qwen3-how-to-run-and-fine-tune
https://unsloth.ai/docs/basics/deploy-llms-phone
https://huggingface.co/unsloth/Qwen3-1.7B-GGUF
https://huggingface.co/Qwen/Qwen3-1.7B-GGUF
https://huggingface.co/unsloth/Qwen3-0.6B-GGUF

---

*File written by tooling perspective worker, 2026-05-28. Companion outputs in this directory cover papers (`theory.md`) and case studies (industry worker output pending). Cross-reference the headline T5 verdict (Cactus = merge-only) against the original demo's CLAUDE.md note that Cactus wraps llama.cpp — that wrapping is no longer true as of Cactus v1 (Dec 2025); the current CLAUDE.md should be updated to match if it claims otherwise.*
