# Thematic clusters — mapped to T1–T7

One section per brief task. Each: a one-paragraph thematic summary, source count, top sources by density with one-line annotations, and the points where workers agreed or disagreed.

---

## T1 — Oxen.ai's surface area and training pipeline

**Summary:** Oxen.ai is a two-layer thing: an Apache-2.0 Rust DVC core (`Oxen-AI/Oxen`, 40× faster pushes than git-lfs) and a hosted SaaS that adds Marimo notebooks + serverless GPU + a zero-code fine-tune UI on top, backed by Baseten for the compute layer. Free Explorer tier covers 50 GB storage + transfer and unlimited public repos; GPU is pay-per-second (A10G ~$1.65/hr, H100 ~$4.87/hr). The published 10–12-min Qwen3-1.7B Text2SQL recipe is the closest external reference shape to what we'd build. **Critical gap consistent across all workers: Oxen does not export GGUF or `.cact` — you take the safetensors and convert yourself.**

**Source count:** 14 (Oxen docs + 5 Oxen blog posts + Baseten case study + comparison tables across 4 workers)

**Top sources:**
- `ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/` — *the* recipe to clone (density 5; cited by tooling + industry)
- `docs.oxen.ai/fine-tuning-api/overview` — JSON-payload training surface
- `github.com/Oxen-AI/Oxen` — the Rust DVC core (Apache-2.0, May 2026 active)
- `oxen.ai/pricing` — confirms hackathon viability (free tier + per-second GPU; cited by tooling + industry + chatgpt-DR)
- `ghost.oxen.ai/fine-tuning-fridays/` — the small-model bake-off series (4–5 published recipes; same Qwen-base + ≤5k examples + judge-LLM eval pattern across)
- `ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/` — corroborates the $1 hackathon-cost claim

**Worker agreement:** All four workers (tooling, industry, claude-DR, chatgpt-DR, gemini-DR) converge on the same shape: Oxen does data + training; you do conversion. None of them claim Oxen has a one-click mobile export. Pricing numbers match across sources.

**Worker disagreement:** Minor. ChatGPT DR was less precise on what the SaaS layer does end-to-end (described it more as a DVC competitor); tooling worker was crisp on the SaaS-vs-OSS split. No substantive contradiction.

---

## T2 — PEFT for small base models (LoRA, QLoRA, DoRA, SFT, DPO, ORPO, KTO)

**Summary:** PEFT methods are well-trodden at this scale; choice is ergonomics, not capability. Plain LoRA r=16, alpha=32, dropout=0, all linear modules under Unsloth is the boring default and is what Cactus's own guide recommends. DoRA is a free upgrade (~10–20% slower training, +1–2% quality) where PEFT supports it. QLoRA only matters if memory-bound — a 1.7B bf16 base is ~3.4 GB and fits a 24 GB card without quantization. For note-merging (correct-output task, not preference-style), **SFT alone is likely sufficient**; ORPO is the cheapest preference-method hedge if a style/format gap shows up. A 1.7B QLoRA on 1k–5k examples runs in 10–30 min for $0.33–$1.20 across A10G/H100/RTX-4090.

**Source count:** 18

**Top sources:**
- `arxiv.org/abs/2106.09685` — LoRA foundation (cited by theory + chatgpt-DR; the foundational cite)
- `arxiv.org/abs/2305.14314` — QLoRA (NF4 + double quant + paged optimizers)
- `arxiv.org/abs/2402.09353` — DoRA (magnitude/direction decomposition; NVIDIA ICML 2024 oral)
- `arxiv.org/abs/2405.09673` — LoRA Learns Less and Forgets Less (the case-for-LoRA-on-close-to-pretraining-tasks)
- `arxiv.org/abs/2405.00732` — LoRA Land (specialist-beats-generalist at $8/fine-tune; cited by theory + industry)
- `arxiv.org/abs/2403.07691` — ORPO (no SFT warm-up, no reference model)
- `github.com/unslothai/unsloth` — the trainer Cactus assumes (cited by tooling + gemini-DR)
- `github.com/huggingface/peft` — reference impl (PEFT v0.19.1, April 2026)

**Worker agreement:** All workers recommend SFT-first for the note-merging task. LoRA r=16, alpha=32 is consensus. Unsloth is the trainer everyone recommends as default. Hyperparameter ranges align (1e-4 LR, 3–5 epochs, batch 2–4 effective, cosine scheduler).

**Worker disagreement:** Mild. Gemini DR claims "DPO significantly outperforms SFT on subjective reasoning, multi-document summarization, and task-specific instruction following" — the other workers (theory, claude-DR) think SFT alone is sufficient for our task because note-merging has correct outputs, not preference structure. The resolved view: SFT first, ORPO only if a style/format gap emerges. Gemini DR's claim looks like overgeneralization from preference-method literature on chat-style tasks.

---

## T3 — Distillation from larger teachers to ≤2B students

**Summary:** Distillation at ≤2B is real but conditional. The DeepSeek-R1-Distill-Qwen-1.5B existence proof (800K reasoning trajectories → SFT a Qwen-1.5B → beats GPT-4o on MATH at 1.5B) shows what's possible. But "Small Models Struggle to Learn from Strong Reasoners" ([arxiv 2502.12143](https://arxiv.org/abs/2502.12143)) shows ≤3B students do not consistently benefit from large-teacher long-CoT distillation — better results come from shorter CoT or smaller teachers. Practical implication: pick a mid-size open-weight teacher (Qwen-7B/14B class) over GPT-4o-class reasoning traces. For note-merging — a black-box-distillable task (don't need teacher logits) — the operational recipe is "generate (input, teacher-output) pairs, SFT the student."

**Source count:** 9

**Top sources:**
- `huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B` — *the* existence proof (cited by 4/6 workers — most-cited source in the index)
- `arxiv.org/abs/2306.02707` — Orca (13B student distilled from GPT-4 *explanation traces*; established imitate-reasoning-not-answer)
- `arxiv.org/abs/2305.02301` — Distilling Step-by-Step (rationales as aux loss; 770M T5 beats few-shot 540B PaLM)
- `arxiv.org/abs/2306.08543` — MiniLLM (reverse-KL for white-box distillation)
- `arxiv.org/abs/2306.13649` — GKD (on-policy distillation)
- `arxiv.org/abs/2502.12143` — Small Model Learnability Gap (the counter-case; cited by industry)

**Worker agreement:** DeepSeek-R1-Distill-1.5B is the unanimous existence proof. All workers note the license advantage of open-weight teachers over commercial APIs (Apache-2.0 / MIT redistribution is clean; GPT-4 / Claude / Gemini TOS competitive-model clauses are landmines).

**Worker disagreement:** None substantive on the recipe shape. Gemini DR adds a useful caveat the other workers don't emphasize: reasoning-trace distillation inflates inference latency by emitting "thinking" tokens, which matters on mobile CPU budgets — argues against pure-CoT distillation for our specific deployment. Worth carrying into the recipe.

---

## T4 — Synthetic-data generation for narrow-domain corpora

**Summary:** No off-the-shelf note-merging dataset exists. Magpie (prompt an instruct model with the pre-query chat template and let it autocomplete user queries + answers) is the cheapest path to a few thousand training pairs from a free open model. distilabel is the canonical pipeline library but is **16 months stale (v1.5.3, Jan 2025) — verify project health before committing**; Augmentoolkit (MIT, v3.0 June 2025) and the Magpie reference repo are the live fallbacks. Quality filter recipe is consensus: embedding-cluster dedup + judge-LLM filtering + manual spot-check at fixed cadence (~5%). Adjacent off-the-shelf datasets (MultiNews, WikiSum, RAGTruth, MiraNews) are useful as eval anchors or format scaffolding — not training data.

**Source count:** 13

**Top sources:**
- `arxiv.org/abs/2406.08464` + `github.com/magpie-align/magpie` — Magpie (cited by 3/6 workers; the cheapest synthetic-data recipe)
- `arxiv.org/abs/2212.10560` — Self-Instruct (the bootstrapping loop foundation)
- `arxiv.org/abs/2304.12244` — Evol-Instruct (WizardLM; depth/breadth evolution operators)
- `github.com/argilla-io/distilabel` — pipeline library (stale flag)
- `github.com/e-p-armstrong/augmentoolkit` — fallback (MIT, runs local — important for keeping seed corpus off cloud APIs)
- `arxiv.org/abs/1906.01749` — MultiNews (closest off-the-shelf MDS analog at 56k pairs)
- `arxiv.org/abs/2401.00396` — RAGTruth (18k hallucination corpus; useful as eval anchor)

**Worker agreement:** All workers name Magpie as the recommended primary recipe. All workers flag distilabel's staleness. All workers reject MultiNews/WikiSum as training data (shape-mismatch) but accept them as format scaffolding or eval anchors.

**Worker disagreement:** Slight on volume. Theory recommends "a few hundred *good* examples beats 10K mediocre ones" (LIMA argument). Gemini DR recommends ~1,500 highly-curated samples specifically. Claude DR recommends 1k–3k. Industry settles between (1k–2k). Resolved: aim for 1k–2k high-quality examples + ~200 independently-curated holdout, with stratified filter.

---

## T5 — On-device adapter loading and the Cactus seam

**Summary:** **THE load-bearing engineering verdict.** Cactus does NOT support runtime LoRA loading — `cactus convert <base> <out> --lora <adapter>` merges the adapter into a single `.cact` blob at convert time. There is no `set_lora` API in `cactus_init`, no runtime `--lora` flag, no public roadmap item for runtime adapter loading. Cactus moved off GGUF and off the llama.cpp wrapping at v1 (Dec 2025), so it cannot inherit upstream llama.cpp adapter work. Live alternatives that DO support runtime LoRA on mobile: Apple Foundation Models (`.fmadapter` packages, rank-16, dynamically loaded), MediaPipe LLM Inference (GPU backend on Gemma/Phi-2, Android only), MLC LLM (desktop confirmed, mobile in progress per PR #3281), ExecuTorch 1.0 (multi-`.pte` LoRA sharing one foundation set). Tether's QVAC Fabric demonstrated on-device LoRA *training* (not just inference) on Adreno/Mali/Apple Silicon — Apache 2.0, llama.cpp fork.

**Source count:** 19

**Top sources:**
- `github.com/cactus-compute/cactus/blob/main/docs/finetuning.md` — the verdict source (3/6 workers)
- `github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md` — confirms no adapter slot (3/6 workers)
- `infoq.com/news/2025/12/cactus-on-device-inference/` — context on v1 migration off GGUF
- `developer.apple.com/apple-intelligence/foundation-models-adapter/` — the runtime-LoRA counterpoint at production scale
- `machinelearning.apple.com/research/apple-foundation-models-tech-report-2025` — Apple Intelligence 2025 tech report
- `ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android` — MediaPipe LoRA on GPU backend
- `github.com/mlc-ai/mlc-llm/pull/3281` — MLC runtime LoRA (cited by tooling + industry)
- `github.com/ggml-org/llama.cpp/issues/10377` — llama.cpp runtime LoRA (mature)
- `github.com/tetherto/qvac-fabric-llm.cpp` — on-device LoRA training existence proof
- `arxiv.org/abs/2311.03285` — S-LoRA (server-side reference architecture for adapter swapping)

**Worker agreement:** Unanimous. All six workers independently confirm Cactus does not support runtime LoRA. All workers cite the same primary source (`docs/finetuning.md`). Industry adds the comparison table against Apple / MediaPipe / llama.cpp / ExecuTorch.

**Worker disagreement:** Gemini DR claims Cactus "wraps llama.cpp builds" in T5 — this is wrong as of Cactus v1 (Dec 2025), per the tooling worker's reading of the InfoQ feature and the v1 release notes. The current state: Cactus is a from-scratch ARM-SIMD inference stack on a proprietary `.cact` format and no longer wraps llama.cpp. The Gemini DR section appears written against the pre-v1 architecture. **Trust the tooling and industry workers on this point.**

---

## T6 — Evaluation methodology for narrow-domain small-model quality

**Summary:** Judge-LLM is the right harness shape (exact-match is too strict; ROUGE is broken for modern models). Three biases must be controlled: position (favors first response — mitigate with order-swap + average), verbosity (favors longer — explicitly penalize), self-enhancement (favors own family — judge with cross-family models). Calibrate the judge against humans on 100–500 examples before trusting it. **Holdout discipline is the gotcha that bites hardest**: if both training and eval are generated from the same teacher seed, the held-out 20% is from the same distribution as training — defensible split = generate two independent datasets from different prompts/seeds, ideally hand-write ~100 verified examples for the load-bearing eval. RAGAS-faithfulness (claim-to-context grounding) and RAGTruth are shape-adjacent eval anchors. **No off-the-shelf note-merging benchmark exists — we'd be inventing one.**

**Source count:** 16

**Top sources:**
- `arxiv.org/abs/2306.05685` — Judging LLM-as-a-Judge with MT-Bench (canonical reference)
- `hamel.dev/blog/posts/llm-judge/` — practitioner calibration recipe (also cited by industry)
- `arxiv.org/abs/2502.01534` — Preference Leakage (cross-family judge mitigation)
- `arxiv.org/abs/2309.15217` — RAGAS (reference-free RAG eval)
- `arxiv.org/abs/2401.00396` — RAGTruth (18k word-level hallucination corpus)
- `arxiv.org/abs/2311.07911` — IFEval (verifiable instructions; programmatic)
- `arxiv.org/abs/2007.12626` — SummEval (re-evaluating summarization metrics; the "ROUGE-is-broken" anchor)
- `github.com/confident-ai/deepeval` — Apache-2.0 pytest-shaped eval harness
- `github.com/EleutherAI/lm-evaluation-harness` — MIT scaffolding for custom tasks
- `github.com/explodinggradients/ragas` — RAG-specific implementation

**Worker agreement:** Unanimous on the three-bias checklist (position, verbosity, self-preference). Unanimous on cross-family judge as default mitigation. Unanimous on holdout discipline (different teacher seed / different prompt template for eval data, ideally hand-verified).

**Worker disagreement:** None substantive. Different workers emphasize different harness libraries — tooling worker recommends deepeval as primary, industry worker emphasizes Hamel Husain's calibration discipline, theory worker focuses on the underlying biases. All compatible.

---

## T7 — Licensing landmines for fine-tuned weight redistribution

**Summary:** Base-model license families: **Apache-2.0 (Qwen 3, SmolLM2, Phi-3, Gemma 4)** — clean, just attribution. **Llama Community License (Llama 3.x, 4)** — requires "Built with Llama" + naming prefix "Llama" + 700M MAU clause; cumbersome for a clean public repo. **Gemma Terms (Gemma 1–3)** — defines Model Derivative broadly enough to include distillation outputs; Gemma 4 flipped to Apache-2.0 (April 2026) and is the clean choice if a Gemma-class base is preferred. **Cactus itself is source-available with a $2M revenue gate** — fine for hackathon but worth disclosing. **Synthetic-data-from-API-model TOS**: OpenAI, Anthropic, Google explicitly prohibit using outputs to train competing models — the DeepSeek controversy is the public test case. Anthropic's permitted-exception path via Bedrock distillation doesn't apply to free redistribution. **Recommendation: distill from Apache-2.0 / MIT open-weight teachers (Qwen 14B/72B, Llama-3-70B with attribution, DeepSeek-R1) — never from frontier closed APIs.**

**Source count:** 14

**Top sources:**
- `huggingface.co/Qwen/Qwen3-1.7B` — Apache-2.0 base (clean default)
- `github.com/cactus-compute/cactus/blob/main/LICENSE` — Cactus source-available + $2M gate (cited by tooling + industry)
- `llama.com/llama4/license/` + `llama.com/faq/` — Llama Community License clauses
- `ai.google.dev/gemma/terms` — Gemma Terms of Use (cited by chatgpt-DR)
- `venturebeat.com/.../google-releases-gemma-4-under-apache-2-0` — Gemma 4 license flip (April 2026)
- `openai.com/policies/services-agreement/` — competitive-model clause
- `law.asia/openai-deepseek-ai-distillation/` — the DeepSeek public test case
- `anthropic.com/news/trainium2-and-distillation` — Anthropic's permitted-exception Bedrock path
- `github.com/QwenLM/Qwen3-Embedding/issues/166` — MS-MARCO usage during embedder training (edge case)

**Worker agreement:** Unanimous on Apache-2.0 as the recommended posture. Unanimous on the Llama "Built with" + naming-prefix tax. Unanimous on Gemma ≤3 risk + Gemma 4 fix.

**Worker disagreement:** Mild on the OpenAI / Anthropic / Google API-output-as-training-data question. ChatGPT DR is most conservative ("avoid entirely"). Gemini DR is most aggressive ("technically violates TOS but hard to enforce on private apps"). Industry DR settles in the middle: TOS competition clause is real; the safer move for a public hackathon repo is to use open-weight teachers (DeepSeek-R1, Qwen 14B/72B). Consensus operational recommendation: open-weight teacher only for any redistributable artifact.
