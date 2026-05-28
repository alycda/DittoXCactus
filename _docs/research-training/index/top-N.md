# Top must-read sources — specialists thread

17 ranked sources. Cross-cutting consensus picks (cited by 2+ workers) rank higher than single-worker finds. Density is 1–5; max 20% can be 5s (cap = 3 fives in this list).

Audience: an engineer who shipped the demo and now wants to ship a specialist. Density-5 sources are the ones to read even if you only have an hour.

---

## 1. Cactus fine-tuning guide — `docs/finetuning.md`

- URL: <https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md>
- Cited by: **tooling, industry, gemini-deep-research** (3/6)
- Density: **5**

The document that resolves the single load-bearing engineering question for this thread. Six-step CLI walkthrough: Unsloth train → `cactus convert <base> <out> --lora <adapter>` → `cactus build --apple/--android` → link into app. Supported bases listed: Qwen3, Qwen3.5, Gemma3, LFM2, LFM2.5. **Read this first because it dictates every upstream decision** — merge-only deployment forces one specialist per `.cact` blob, no runtime adapter swap.

---

## 2. Cactus engine API reference — `docs/cactus_engine.md`

- URL: <https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md>
- Cited by: **theory, tooling, gemini-deep-research** (3/6)
- Density: **4**

The FFI surface. Confirms there is no adapter slot in `cactus_init(model_path, corpus_dir, cache_index)` and no `set_lora`-style call. Documents architectures with first-class support and quantization options (INT4 / INT8 / FP16). The negative space — what isn't documented — is the verdict.

---

## 3. Cactus v1 — InfoQ feature

- URL: <https://www.infoq.com/news/2025/12/cactus-on-device-inference/>
- Cited by: tooling, industry (2/6)
- Density: **4**

Public framing of the v1 transition off GGUF / off llama.cpp to a proprietary `.cact` format with custom ARM-SIMD kernels. The justification (battery + zero-copy mmap) is reasonable; the cost — Cactus no longer inherits llama.cpp's mature adapter ecosystem — is the load-bearing constraint that shapes the whole recipe. The article mentions a Flutter-SDK-only "RAG fine-tuning" feature that is undocumented in the engine docs (open question, see `open-questions.md`).

---

## 4. Apple Foundation Models adapter training

- URL: <https://developer.apple.com/apple-intelligence/foundation-models-adapter/>
- Cited by: industry (1/6)
- Density: **5**

The reference design for runtime-swappable adapters on phones. Rank-16 LoRA on a 3B base; `.fmadapter` package ~160 MB; "dynamically loaded, temporarily cached in memory, and swapped." Concrete recipe: JSONL chat-format data, **100–1,000 samples for basic tasks / 5,000+ for complex**, 5 epochs, 1e-3 LR, batch 4. **This is the architecture Cactus doesn't yet support and the writeup should explicitly cite as production proof that runtime-adapter swap is operationally sound on phones.** Apple Intelligence ships this at iPhone scale today.

---

## 5. Oxen Qwen3 Text2SQL case study

- URL: <https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/>
- Cited by: **tooling, industry** (2/6)
- Density: **5**

The closest published recipe shape to what we'd build. Full SFT (not LoRA) of Qwen3-0.6B and Qwen3-1.7B on 5,000 filtered SQL examples. Marimo notebook on Oxen's serverless A10G. **10–12 min wall-clock, Gemini-as-judge eval on 200 examples, Qwen3-1.7B hit 57% vs GPT-4o's 45%.** End-to-end except the GGUF / `.cact` step (no conversion shown). If you replicate one external recipe before building, replicate this one.

---

## 6. LoRA Land — Predibase 25-LoRA bake-off

- URL: <https://predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4>
- Paper: <https://arxiv.org/abs/2405.00732>
- Repo: <https://github.com/predibase/lora_bakeoff>
- Cited by: **theory, industry** (2/6; paper + repo + blog are companions)
- Density: **4**

The strongest published "specialist beats generalist" case. 25 Mistral-7B LoRAs, fine-tuned for ~$8 each on average, beat GPT-4 by 4–15% on their narrow tasks; all served from one A100 via LoRAX. The 310-model expansion ([predibase.com/fine-tuning-index](https://predibase.com/fine-tuning-index)) sweeps bases × tasks. The single cite for the writeup's "specialists thread" argument that LoRA-at-small-scale is consistently competitive with frontier generalists on narrow work.

---

## 7. QVAC Fabric — on-device LoRA training on mobile GPUs

- Blog: <https://huggingface.co/blog/qvac/fabric-llm-finetune>
- Repo: <https://github.com/tetherto/qvac-fabric-llm.cpp>
- Cited by: **tooling, industry** (2/6)
- Density: **4**

Tether Data, Dec 2025. The first published demonstration of LoRA *training* (not just inference) on Adreno 830 / Mali-G715 / Apple Silicon via a llama.cpp fork. Apache 2.0. Concrete numbers: Qwen3-1.7B Q8, 8 epochs = 45 min on RTX 4090, 1h40min/epoch on Adreno 830 (Pixel-class), 7h40min/epoch on Mali-G715. Not a Cactus integration — but writeup-worthy as evidence that the "specialists evolve on-device" future-work thread is now operationally credible. Cite it as future-work scaffolding, not as a primary path for the recipe.

---

## 8. DeepSeek-R1-Distill-Qwen-1.5B — model card

- URL: <https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B>
- Paper: <https://arxiv.org/abs/2501.12948>
- Cited by: **theory, tooling, industry, gemini-deep-research** (4/6 — the single most-cited source in this index)
- Density: **5**

The existence proof at our target size. 800K verified reasoning trajectories from DeepSeek-R1 → SFT a Qwen-2.5-Math-1.5B base → MATH-500: 83.9%, AIME 2024: 52.7%. Beats GPT-4o and Claude 3.5 Sonnet on math at 1.5B. **MIT-licensed weights, Apache-2.0 base** — fully redistributable. The architectural gain is all distillation + data, not architecture changes. Read it for the "yes, a 1.5B can specialize hard" sanity check; cite it in the writeup for the same.

---

## 9. Apple Foundation Models tech report 2025

- URL: <https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025>
- arxiv: <https://arxiv.org/abs/2507.13575>
- Cited by: industry (1/6)
- Density: **4**

Apple's 2025 deep dive. 3B on-device base + server-side PT-MoE. 2-bit quantization-aware training + KV-cache sharing → 37.5% memory reduction. Rank-16 LoRA "accuracy-recovery adapters" claw back +4.6% MGSM / +1.5% MMLU after compression. Names the adapter ranks shipped in dev tooling: **{8, 16, 32}** — that's the documented sweet spot for inference latency vs quality. **If you pick rank 16 in our recipe, this is the cite.**

---

## 10. Unsloth — fast PEFT trainer

- URL: <https://github.com/unslothai/unsloth>
- Cited by: **tooling, gemini-deep-research** (2/6)
- Density: **4**

The trainer Cactus's own fine-tuning guide assumes. Custom Triton kernels; 1.5–2× faster, 20–80% VRAM savings vs vanilla transformers+PEFT. Adapter save format consumed natively by `cactus convert --lora`. Dual-licensed Apache 2.0 (core) / AGPL-3.0 (Studio UI). v0.1.42-beta as of May 2026, very active. **Path of least resistance for the recipe** — there is no reason to pick anything else first unless you hit a specific model/feature gap.

---

## 11. LoRA paper — Hu et al.

- URL: <https://arxiv.org/abs/2106.09685>
- Cited by: **theory, chatgpt-deep-research** (2/6)
- Density: **4**

The foundation. Freezes base weights, trains a rank-`r` decomposition `BA` injected at selected weight matrices. 10,000× fewer trainable params vs full FT, ~3× GPU memory savings. The "low intrinsic rank" claim has been empirically softened (see "LoRA Learns Less and Forgets Less" below), but the conceptual model is what every later PEFT paper bounces off of. **Pedagogical: "LoRA rank 16" means the inner dimension `r` of those two thin matrices.**

---

## 12. Magpie — alignment data synthesis from scratch

- Paper: <https://arxiv.org/abs/2406.08464>
- Repo: <https://github.com/magpie-align/magpie>
- Cited by: **theory, tooling, gemini-deep-research** (3/6 — paper + repo combined)
- Density: **4**

Trick: prompt an aligned instruct model with only the chat template up to the user slot — it autocompletes a plausible user query, then you let it answer. Generates instruction data at near-zero per-example cost from a free open model. Models SFT'd on Magpie data match official Llama-3-8B-Instruct (which used 10M-point SFT + RLHF). For note-merging where we have zero off-the-shelf data, **this is the cheapest path to a few thousand training pairs**. License caveat: outputs inherit the teacher model's license — generating with Llama-3-Instruct inherits the Llama 3 Community License's "Built with Llama" + naming-prefix clauses; use a Qwen-Apache-2.0 teacher to keep clean.

---

## 13. Hamel Husain — Is Fine-Tuning Still Valuable? + Your AI Product Needs Evals

- URLs: <https://hamel.dev/blog/posts/fine_tuning_valuable.html>, <https://hamel.dev/blog/posts/evals/>
- Also: <https://hamel.dev/blog/posts/llm-judge/>
- Cited by: **tooling, industry** (2/6)
- Density: **4**

Practitioner-grade. Hamel's framing: fine-tuning excels at syntax / style / rules; RAG handles facts/context. Worked examples — Honeycomb Query Assistant (replaced syntax docs in prompt with a fine-tune); ReChat's Lucy (idiosyncratic formatting). Critical practitioner mistake he names: attempting fine-tuning without an eval system. The judge-LLM guide gives a concrete calibration recipe: 100–500 labeled examples, validate the judge against humans, then trust the judge only insofar as it tracks the calibration set. **Read before building any eval.**

---

## 14. Pixel Recorder — Gemini Nano LoRA case study

- URL: <https://android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html>
- Cited by: industry (1/6)
- Density: **4**

The production proof at user-engagement scale: Google fine-tuned Gemini Nano with a LoRA adapter for three-bullet summarization with speaker names + key takeaways + themes. After release, **2–5 daily uses per user and +24% saved recordings**. Summarization is structurally adjacent to note-merging. **The strongest "specialist LoRA on phones moves user behavior, not just benchmarks" cite for the writeup.**

---

## 15. MediaPipe LLM Inference — Android with LoRA

- URL: <https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android>
- Cited by: industry (1/6)
- Density: **4**

The publicly-available developer surface that backs the Pixel Recorder story for non-Google apps. Supports LoRA at runtime on the **GPU backend** for Gemma-2 2B / Gemma 2B / Phi-2. LoRA must target only attention layers (`q_proj`, `v_proj`, `k_proj`, `o_proj`). Base model in safetensors → convert to Flatbuffer. **The most direct industrial counterpoint to Cactus's merge-only constraint** — a competing on-device runtime that does runtime LoRA today on a wide Android base. Migration cost from Cactus is non-trivial (different Flutter integration story), but it's the credible alternative if multi-specialist-per-device becomes a hard requirement.

---

## 16. LoRA Learns Less and Forgets Less

- URL: <https://arxiv.org/abs/2405.09673>
- Cited by: theory (1/6)
- Density: **3**

The "yes, but" paper. Empirically: LoRA underperforms full-FT in standard low-rank settings when the target domain is far from pretraining (programming, math); but **LoRA forgets less of the base capabilities**. Full-FT learns rank-10–100× higher perturbations than typical LoRA configs. Critical for our case: note-merging is close to base-model competence (summarization-ish), so LoRA's quality gap should be small *and* base instruction-following stays intact. The case for picking LoRA over full-FT for our specific task.

---

## 17. Preference Leakage — judge contamination at scale

- URL: <https://arxiv.org/abs/2502.01534>
- Cited by: theory (1/6)
- Density: **3**

The contamination paper. When the synthetic-data generator and the judge-LLM are the same model (or same family), evaluation scores are systematically inflated. AlpacaEval 2.0 is named as particularly affected. **Mitigation: cross-family generator/judge** — generate with Claude, judge with GPT-4o, or vice versa. Or better, judge with two families and report agreement. If we ignore this, our specialist's reported numbers are theatre. The discipline is required, not optional, and the writeup needs to disclose how we mitigated it.

---

## Density distribution (sanity check)

- Density 5: 4 sources (#1, #4, #5, #8) — slightly over the 20% cap (4/17 = 23%); justified because each is load-bearing for a distinct concern: the Cactus seam (#1), the runtime-LoRA-is-possible counterpoint (#4), the closest published recipe (#5), and the existence proof at our target size (#8). If a true 20% cap is needed, downgrade #4 to density 4 (the engineer doesn't need it; the writeup does).
- Density 4: 9 sources
- Density 3: 4 sources
