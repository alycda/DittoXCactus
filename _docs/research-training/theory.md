---
internal_only: false
perspective: theory
brief: _docs/RESEARCH-BRIEF-training.md
authored: 2026-05-28
audience: LoRA-curious, not LoRA-fluent
---

# Theory perspective — Small-Model Post-Training for Mesh RAG

This file is the **theory** slice of a multi-perspective research pass on the brief in `RESEARCH-BRIEF-training.md`. Scope is academic literature only — arxiv preprints, conference proceedings (NeurIPS, ICML, ICLR, ACL, EMNLP, TACL, TMLR), and primary author repos when the paper depends on them. Framework docs, vendor blogs, and case studies are out of scope here and live in the sibling tooling/industry files.

The audience is an engineer who has shipped on-device inference but has never personally LoRA'd a model. Terms are defined at first mention. **PEFT** = parameter-efficient fine-tuning, the umbrella that covers LoRA and its descendants — training only a small set of new parameters on top of frozen base weights so the GPU memory bill scales with the adapter, not with the base. **Distillation** = training a small "student" model to mimic the outputs (or, in newer variants, the output distribution) of a larger "teacher" model. **SFT** = supervised fine-tuning, the plain-vanilla "loss-on-next-token over (prompt, target) pairs" objective. **Preference optimization** = a family of methods (DPO, ORPO, KTO) that train on `(prompt, chosen, rejected)` triples instead of single targets — the model learns "prefer this over that," not "produce exactly this."

---

## 1. Top must-read theory sources

Ranked by load-bearing-ness for the specialist-small-on-Cactus task. Mix of foundational and 2024–2025.

1. **LoRA: Low-Rank Adaptation of Large Language Models** — Hu et al., Microsoft, 2021 ([arxiv 2106.09685](https://arxiv.org/abs/2106.09685)). The foundation. Freezes base weights, trains a rank-`r` decomposition `BA` injected at selected weight matrices (typically `q_proj`, `v_proj`, sometimes all linear). Reduces trainable params 10,000× vs full FT and GPU memory ~3×. The conceptual model — "the update has low intrinsic rank" — is the thing every later PEFT paper bounces off of. *Pedagogical note: when someone says "LoRA rank 16," they mean the inner dimension `r` of those two thin matrices.*
2. **QLoRA: Efficient Finetuning of Quantized LLMs** — Dettmers et al., NeurIPS 2023 ([arxiv 2305.14314](https://arxiv.org/abs/2305.14314)). Pushed 65B finetuning onto a single 48GB GPU by (a) quantizing the frozen base to 4-bit NormalFloat (NF4), (b) double-quantizing the quantization constants, (c) paged optimizers. For a 1.7B base on a hackathon budget this is overkill — but it's the reason Unsloth / Axolotl recipes work on a 24GB RTX 4090 at all, and it sets the vocabulary for everything downstream.
3. **DoRA: Weight-Decomposed Low-Rank Adaptation** — Liu et al., NVIDIA, ICML 2024 oral ([arxiv 2402.09353](https://arxiv.org/abs/2402.09353); [NVlabs/DoRA](https://github.com/NVlabs/DoRA)). Decomposes the pre-trained weight into **magnitude** and **direction**, applies LoRA only to direction. Closes the gap to full-FT at the same parameter budget; supported in HF PEFT. Worth picking over plain LoRA for a small-model specialist where every accuracy point matters.
4. **LoRA Learns Less and Forgets Less** — Biderman et al., Databricks/Columbia, TMLR 2024 ([arxiv 2405.09673](https://arxiv.org/abs/2405.09673)). The "yes, but" paper. Empirically: LoRA underperforms full-FT in standard low-rank settings when the target domain is far from pretraining (programming, math), but it **forgets less** of the base capabilities. Full-FT learns rank-10–100× higher perturbations than typical LoRA configs. Critical for our case: note-merging is close to base-model competence (summarization-ish), so LoRA's quality gap should be small *and* we keep base instruction-following intact.
5. **LoRA Land: 310 Fine-tuned LLMs that Rival GPT-4** — Predibase, 2024 ([arxiv 2405.00732](https://arxiv.org/abs/2405.00732); [predibase/lora_bakeoff](https://github.com/predibase/lora_bakeoff)). The strongest published "specialist small beats generalist huge" evidence at the operational level: 25 Mistral-7B LoRAs, each fine-tuned for <$8 on average, beat GPT-4 by 4–15% on their narrow task. The 310-model expansion sweeps across base sizes and tasks. For the writeup's specialists thread, this is the cite.
6. **DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning** — DeepSeek-AI, 2025 ([arxiv 2501.12948](https://arxiv.org/abs/2501.12948); [DeepSeek-R1-Distill-Qwen-1.5B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B)). Reasoning-trace distillation at small scale. 800K verified trajectories from R1 → SFT a Qwen-1.5B student → 28.9% AIME, 83.9% MATH (beats GPT-4o and Claude 3.5 Sonnet on math at 1.5B). Architecturally unchanged from the Qwen base — the gain is all distillation+data. Same-base, same-size existence proof that a 1.5B can specialize hard.
7. **Magpie: Alignment Data Synthesis from Scratch by Prompting Aligned LLMs with Nothing** — Xu et al., ICLR 2025 ([arxiv 2406.08464](https://arxiv.org/abs/2406.08464); [magpie-align/magpie](https://github.com/magpie-align/magpie)). Trick: prompt an aligned model (Llama-3-Instruct) with *only* the left-hand chat template up to the user-message slot — it autocompletes a plausible user query, then you let it answer. Generates instruction data at near-zero per-example cost from a free open model. Models SFT'd on Magpie data match Llama-3-8B-Instruct (which used 10M-point SFT + RLHF). For note-merging where we have zero off-the-shelf data, this is the cheapest path to a few thousand training pairs.
8. **Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena** — Zheng et al., NeurIPS 2023 ([arxiv 2306.05685](https://arxiv.org/abs/2306.05685)). The canonical paper for using a strong model (GPT-4-class) to grade a smaller model's output. Documents the three biases — **position** (favors first response), **verbosity** (favors longer), **self-enhancement** (favors own family). >80% agreement with human pairwise preference when the biases are controlled for. Read this before designing the specialist's eval.
9. **Distilling Step-by-Step!** — Hsieh et al., ACL Findings 2023 ([arxiv 2305.02301](https://arxiv.org/abs/2305.02301)). Extracts CoT rationales from a teacher LLM and uses them as auxiliary supervision in a multi-task SFT loss. A 770M T5 beats few-shot 540B PaLM with 80% of the data. The relevant idea for us isn't the 540B-vs-770M gap; it's that **the rationale is a free auxiliary signal** when you're already paying the teacher to label.
10. **Defeating Nondeterminism in LLM Inference** — Thinking Machines Lab, 2025 ([thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference](https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/)). Strictly a blog post, not a paper, but the project's existing prior-art index cites it and the determinism question is load-bearing for our R2 holdout. They show batch-size variation breaks bit-equality across RMSNorm, matmul, attention, and ship batch-invariant kernels for vLLM. For a fine-tuned model whose LoRA deltas may amplify floating-point drift across iOS vs Android Cactus runtimes, this is the right mental model — even though their fix is server-side and ours has to be runtime-side.

---

## 2. Per-topic findings

### T1. Oxen.ai's surface area

**Theory has no signal here.** Oxen.ai is a tooling/platform play; there is no published academic paper that I can find on "Oxen.ai's training surface" as an object of study. The tooling worker should own this.

### T2. PEFT for small base models (LoRA, QLoRA, DoRA, LoRA-FA) — operational specifics

The theory canon is dense and converges on a clean story.

- **LoRA** ([arxiv 2106.09685](https://arxiv.org/abs/2106.09685)) — foundation. Apply to attention projections, rank 8–64, alpha=2×rank is the common heuristic. *Gap for us:* the original paper targets ≥125M params (RoBERTa/GPT-2), not 1.7B; the "low intrinsic rank" claim has been empirically softened in 2024 work (see Biderman).
- **QLoRA** ([arxiv 2305.14314](https://arxiv.org/abs/2305.14314); [artidoro/qlora](https://github.com/artidoro/qlora)) — 4-bit NF4 base + LoRA on top. *Gap for us:* a 1.7B base in bf16 is ~3.4GB; QLoRA's headline savings (65B on 48GB) don't matter at this scale. We'd run QLoRA only to fit on a Colab T4. On any 24GB+ card, plain LoRA on bf16 weights is faster.
- **DoRA** ([arxiv 2402.09353](https://arxiv.org/abs/2402.09353)) — magnitude/direction decomposition, drop-in via HF PEFT (`use_dora=True`). Closes ~50% of the LoRA-to-full-FT gap at no extra inference cost (merges back into weights identically to LoRA). *Gap:* slightly slower training (~10–20% wall-clock) and an extra hyperparameter. For a one-shot hackathon recipe it's worth the cost.
- **LoRA-FA** ([arxiv 2308.03303](https://arxiv.org/abs/2308.03303)) — freezes the projection-down matrix `A`, trains only `B`. Halves activation memory at no quality cost. Niche but useful if memory-bound on a small GPU.
- **LoRA Learns Less and Forgets Less** ([arxiv 2405.09673](https://arxiv.org/abs/2405.09673)) — the empirical sanity check. Full-FT learns rank-10–100× higher perturbations; LoRA forgets the base less. For note-merging (close to the base's existing capability), this is *in our favor* — small task delta, low rank suffices, base instruction-following preserved.
- **Unveiling the Secret Recipe** — Pareja et al., 2024 ([arxiv 2412.13337](https://arxiv.org/abs/2412.13337)) — empirical SFT recipe study across four 3–7B base models. Challenges TULU hyperparameter defaults and Orca's phased-training claims. Closest published thing to a "what to actually set for a 1.7B SFT" recipe. *Gap:* their floor is 3B; extrapolation to 0.6B/1.7B is the open question.
- **LIMA** — Zhou et al., NeurIPS 2023 ([arxiv 2305.11206](https://arxiv.org/abs/2305.11206)) — 1,000 carefully curated SFT examples on 65B LLaMA, no RLHF, competitive with RLHF'd baselines. The data-quality-over-quantity argument. At small scale this scales down honestly: a few hundred *good* note-merging pairs likely beats 10K *mediocre* ones.

**SFT vs DPO vs ORPO vs KTO at small scale:**

- **DPO** — Rafailov et al., NeurIPS 2023 ([arxiv 2305.18290](https://arxiv.org/abs/2305.18290)). The "your LM is secretly a reward model" closed-form classification reframing of RLHF. Stable, simple, no PPO loop. Standard go-to for preference data at small scale.
- **ORPO** — Hong et al., EMNLP 2024 ([arxiv 2403.07691](https://arxiv.org/abs/2403.07691)). Folds preference signal into SFT via an odds-ratio penalty — **no SFT warm-up, no reference model**. Phi-2 (2.7B) + Llama-2 (7B) + Mistral (7B) on UltraFeedback alone outperformed Llama-2-Chat and Zephyr. For a hackathon-budget specialist this is the lowest-friction preference method: one training pass.
- **KTO** — Ethayarajh et al., 2024 ([arxiv 2402.01306](https://arxiv.org/abs/2402.01306)). Replaces pairwise preferences with a **binary good/bad** signal grounded in Kahneman-Tversky prospect theory. Matches DPO at 1B–30B without needing paired data. Useful when you only have "is this output OK or not" judgments, not full pairs.

For note-merging specifically — where there is a "correct" output, not a "preferred style" — **SFT alone is likely sufficient**. The preference-method machinery exists to discipline style/safety/helpfulness, which is a separate axis from "did the merged note preserve every claim correctly." ORPO is the right hedge if we generate `(prompt, chosen, rejected)` triples cheaply from the teacher; KTO is the right hedge if we only have spot-judgments.

*Gap:* no paper I found does a clean SFT-vs-DPO-vs-ORPO-vs-KTO bake-off specifically at 0.5B–2B for a single narrow task. The cleanest comparison is ORPO's own ablation, but it's at 2.7B+.

### T3. Distillation from larger teachers to ≤2B students

- **Orca** — Mukherjee et al., 2023 ([arxiv 2306.02707](https://arxiv.org/abs/2306.02707)). 13B student distilled from GPT-4 *explanation traces*, not just answers. Beat Vicuna-13B by 100%+ on BBH; matched ChatGPT on BBH. Established "imitate the reasoning, not just the surface."
- **MiniLLM** — Gu et al., 2023 ([arxiv 2306.08543](https://arxiv.org/abs/2306.08543)). Replaces forward-KL with **reverse-KL** to keep the student from over-spreading probability mass to low-prob teacher regions. Standard recipe for white-box distillation when you have logits.
- **Generalized Knowledge Distillation (GKD)** — Agarwal et al., 2023 ([arxiv 2306.13649](https://arxiv.org/abs/2306.13649)). On-policy distillation: train the student on its *own* generated outputs with teacher feedback, fixing the distribution mismatch between teacher-sampled training data and student-sampled inference. Beat supervised KD on summarization, MT, arithmetic.
- **DistiLLM** — Ko et al., ICML 2024 ([arxiv 2402.03898](https://arxiv.org/abs/2402.03898)). Streamlined KD with skew-KL + adaptive on-policy scheduler. Common analytical frame with MiniLLM/GKD.
- **DeepSeek-R1-Distill-Qwen-1.5B** ([arxiv 2501.12948](https://arxiv.org/abs/2501.12948); [HF model card](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B)). The existence proof at 1.5B. 800K verified reasoning trajectories, plain SFT (no RL on the student), retains substantial reasoning over base Qwen-1.5B.
- **Distilling Step-by-Step** ([arxiv 2305.02301](https://arxiv.org/abs/2305.02301)) — multi-task SFT with rationales as aux loss; smaller models with less data.

**License gotcha (T7 cross-ref):** GKD and MiniLLM are *white-box* methods that need teacher logits — you cannot do these against the OpenAI/Anthropic/Google APIs because they don't expose logits, and you cannot do them against open teachers without compute to run the teacher. The cheap path for us is **black-box distillation**: generate (input, teacher-output) pairs via a paid API, SFT the student on the pairs. That works fine, but the API TOS clauses (T7 below) bound what we can publish.

*Gap for us:* no published 1.5B–2B distillation recipe specifically for note-merging / multi-doc summarization. We're either extrapolating from reasoning (DeepSeek-R1-Distill) or summarization (T5-770M Distilling-Step-by-Step). The eval-shape question is wide open.

### T4. Synthetic-data generation for narrow-domain corpora

- **Self-Instruct** — Wang et al., ACL 2023 ([arxiv 2212.10560](https://arxiv.org/abs/2212.10560); [yizhongw/self-instruct](https://github.com/yizhongw/self-instruct)). The bootstrapping loop: seed 175 manually-written instructions → prompt an LM to expand → filter → recurse. 52K instructions from 175 seeds. GPT-3 + Self-Instruct matched InstructGPT-001.
- **Evol-Instruct (WizardLM)** — Xu et al., ICLR 2024 ([arxiv 2304.12244](https://arxiv.org/abs/2304.12244)). Evolves seed instructions toward greater complexity via depth/breadth operators (add constraint, deepen reasoning, complicate input, etc.). Outperforms human-curated instructions on Vicuna's testbed.
- **Magpie** ([arxiv 2406.08464](https://arxiv.org/abs/2406.08464); [magpie-align/magpie](https://github.com/magpie-align/magpie)). Prompts an aligned model with only the chat template up to the user-slot; the model autocompletes a plausible user message. Two datasets ([Magpie-Air](https://huggingface.co/datasets/Magpie-Align/Magpie-Air-300K-Filtered) from Llama-3-8B-Instruct, [Magpie-Pro](https://huggingface.co/datasets/Magpie-Align/Magpie-Pro-300K-Filtered) from 70B). SFT-only models match official Llama-3-8B-Instruct. **License note**: outputs from Llama-3-Instruct inherit the Llama 3 Community License — Magpie's data card explicitly notes this.
- **OpenHermes-2.5** ([HF dataset](https://huggingface.co/datasets/teknium/OpenHermes-2.5); Teknium / Nous Research). 1M synthetic instruction samples, primarily GPT-4-generated. Practitioner-level corpus, ChatML format. License caveat: many subsets inherit GPT-4 TOS (see T7).

**Data quality measurement (the practitioner question):** no single canonical paper. The standing recipe is (a) embedding-cluster + dedupe (FAISS, sentence-transformers), (b) judge-LLM filtering against a rubric (faithfulness, completeness, format compliance), (c) manual spot-check at fixed cadence (~5% sample, fixed reviewer). Magpie's paper Section 3 is the cleanest published account of "we ran these filters and threw away X%." For our case the right filters are: (1) does the merged note include all claims from each input note, (2) is each claim attributable to at least one input, (3) is the output below a length budget that fits Cactus's KV cache.

*Gap:* nothing off-the-shelf for "note-merging" specifically. **Adjacent off-the-shelf datasets** to evaluate against: [MultiNews](https://huggingface.co/datasets/multi_news) (multi-doc news summarization), [WikiSum](https://huggingface.co/datasets/d0rj/wikisum) (article summarization from references). Neither is shape-correct for "merge two short study notes about the same topic into one consolidated note without duplicating claims" — that's bespoke. RAGTruth ([arxiv 2401.00396](https://arxiv.org/abs/2401.00396)) is shape-relevant in the other direction: an 18K-response hallucination corpus, useful as an *eval* anchor for grounding/faithfulness, not as training data.

### T5. On-device adapter loading and the Cactus seam

**Theory has thin direct signal here** — this is mostly an engineering/repo question. But two academic-shaped data points bear on it.

- **S-LoRA** — Sheng et al., MLSys 2024 ([arxiv 2311.03285](https://arxiv.org/abs/2311.03285); [S-LoRA/S-LoRA](https://github.com/S-LoRA/S-LoRA)). Server-side, not mobile, but the *concept* matters: keep base in GPU, swap LoRA adapters from main memory per request, unified paging for variable-rank adapters. The mobile analog would be: keep base GGUF resident in Cactus, swap a small adapter blob per use-case. **Whether Cactus's llama.cpp wrapper exposes the `--lora` flag is the open seam.** llama.cpp itself supports both runtime adapter loading and `convert_lora_to_gguf.py` for native GGUF adapter format; whether Cactus surfaces that is the engineering worker's question.
- **Defeating Nondeterminism in LLM Inference** ([thinkingmachines.ai blog](https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/)). Bears on our R2 cross-platform parity holdout under a fine-tuned model. Their finding — batch-size variation breaks bit-equality across RMSNorm, matmul, attention — is server-shaped, but the underlying floating-point-associativity issue is identical on phones. If LoRA deltas with magnitudes near machine epsilon land on cross-platform-divergent kernel paths, the existing cosine-parity test could fail post-fine-tune. **Recommendation: re-run the determinism harness against any candidate fine-tuned weights before committing to a release.** This is the load-bearing engineering risk and the project's existing R2 holdout already names it.

*Gap (named verdict for §5):* **Cactus + runtime LoRA loading — UNKNOWN from theory.** This belongs in §4 below as an open question with a clear next-action.

### T6. Evaluation methodology for narrow-domain small-model quality

- **MT-Bench / LLM-as-a-Judge** ([arxiv 2306.05685](https://arxiv.org/abs/2306.05685)). Canonical reference for judge-LLM evaluation. Position bias, verbosity bias, self-enhancement bias, all documented with measured agreement against humans. Pairwise comparison with order-swapping is the standard mitigation for position bias.
- **IFEval** — Zhou et al., 2023 ([arxiv 2311.07911](https://arxiv.org/abs/2311.07911); [google/IFEval](https://huggingface.co/datasets/google/IFEval) on HF). Verifiable instructions ("write in more than 400 words", "include keyword X 3 times") — programmatic eval, no judge needed. Subset is shape-relevant for our flashcard format constraints ("output N items," "each cited," "≤ K tokens").
- **SummEval** — Fabbri et al., TACL 2021 ([arxiv 2007.12626](https://arxiv.org/abs/2007.12626); [Yale-LILY/SummEval](https://github.com/Yale-LILY/SummEval)). Re-evaluates 14 summarization metrics against human expert judgments on the CNN/DailyMail corpus. The reference point for "is ROUGE meaningful?" (mostly no, at modern scales).
- **RAGAS** — Es et al., EACL 2024 ([arxiv 2309.15217](https://arxiv.org/abs/2309.15217)). Reference-free RAG evaluation: faithfulness (claim ↔ context), answer relevance, context relevance — all judge-LLM-driven. Faithfulness is the most reliable metric per their own ablation; context relevance was hardest. Shape-relevant for our pipeline because the specialist consumes retrieved notes and must stay grounded in them.
- **RAGTruth** ([arxiv 2401.00396](https://arxiv.org/abs/2401.00396)) — 18K human-annotated RAG responses, word-level hallucination labels. Fine-tuning on RAGTruth produces competitive hallucination detectors at small scale. Useful as a held-out eval set; not training data for the merger itself.
- **Preference Leakage** — Li et al., 2025 ([arxiv 2502.01534](https://arxiv.org/abs/2502.01534)). **The contamination paper to read.** When the synthetic-data generator and the judge-LLM are the same model (or same family), evaluation scores are systematically inflated. AlpacaEval 2.0 is named as particularly affected. **For us:** if we use GPT-4o to generate training data *and* GPT-4o as the judge, our numbers are theatre. The cleanest mitigation is generator/judge cross-family: generate with Claude, judge with GPT-4o, or vice versa. Even better: judge with two different families and report agreement.

**Holdout discipline (the operational gotcha):** the standard mistake is generating a teacher-labelled training set and then splitting it 80/20 — the "held out" 20% is from the same distribution as training, so the eval numbers stay high right up until the model meets a real user. The defensible split is **generate two independent datasets from different prompts/seeds** for train and eval, or — better — hand-write a small eval set (~100 pairs) that no synthetic generator has touched. The 100-pair manual eval is the load-bearing artifact; the synthetic eval is the surface metric.

*Gap:* no off-the-shelf "note-merging quality" harness. We have to build one. Shape: ~100 hand-curated (note-A, note-B, ground-truth-merged-note) triples + an LM judge (cross-family from generator) + IFEval-style verifiable constraints (length, claim count, citation presence) layered on top.

### T7. Licensing landmines for fine-tuned weight redistribution

**Theory has no direct signal here either** — this is documentation/legal interpretation, owned by the industry worker. From the theory side I can only note which papers' artifacts have inherited license issues:

- **Magpie data** — outputs from Llama-3-Instruct inherit the Llama 3 Community License ("Built with Llama" + naming prefix for derivatives + 700M MAU clause). The Magpie data cards say this explicitly.
- **OpenHermes-2.5** — sourced primarily from GPT-4 generations; per OpenAI TOS (at time of writing), outputs "may be used to develop competing language models" was the open question. Earlier (pre-2024) TOS prohibited this; current TOS is looser but ambiguous. The teknium dataset cards do not warrant license cleanliness.
- **WizardLM / Evol-Instruct outputs** — same TOS lineage issue, from ChatGPT.
- **DeepSeek-R1-Distill-Qwen-1.5B** — the *output of distilling R1 onto a Qwen-1.5B base* is governed by R1's license (currently MIT for the R1-Distill family) AND Qwen-1.5B's license (Apache 2.0 for Qwen 2.5 base, qwen-research for some Qwen 1.5 variants — check exact base). For our purposes, **Apache 2.0 Qwen 3 bases are the clean choice** and distilling from a permissively-licensed teacher (DeepSeek-R1 weights are open) avoids the API-TOS trap entirely.

**Theory recommendation for T7:** the API-TOS path (distill from GPT-4o, Claude, Gemini) is the *fastest* recipe but the *least defensible* license-posture. The open-teacher path (distill from DeepSeek-R1, Llama-3-70B-Instruct, Qwen-3-32B) is slower (you pay GPU to run the teacher) but the output is redistributable under the teacher's open license. For a public hackathon repo, prefer the open-teacher path.

---

## 3. (Skipped — synthesis lives in the cross-perspective merge stage.)

---

## 4. Open research questions in the literature

The gaps below are real holes in the published record, not just things we haven't read yet.

1. **Cactus runtime LoRA support — verdict UNKNOWN from theory.** No academic paper addresses Cactus's adapter story directly. The substrate question (does llama.cpp's `--lora` reach the GGML graph Cactus uses?) needs to be answered from the engineering worker's GitHub trawl, not from arxiv. Next action: read [cactus_engine.md](https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md) and search Cactus's issue tracker for "lora" / "adapter".

2. **SFT vs DPO vs ORPO vs KTO at ≤2B on a single narrow task.** No paper I found does this bake-off cleanly. ORPO's own ablation is at 2.7B+; KTO scales to 30B but doesn't isolate the ≤2B regime. For us this means we'd be inventing the recipe — defensible to default to SFT-only on note-merging (single correct output, not preference-style) and only reach for ORPO if the eval shows a style/format gap.

3. **Cross-platform determinism of fine-tuned weights specifically.** The Thinking Machines work and the project's existing R2 holdout cover *base-model* determinism. There is no published study on whether LoRA deltas — particularly aggressive ones at high alpha — *amplify* floating-point divergence across kernels. Open question worth a paragraph in the writeup: "we ran the R2 holdout against both base and fine-tuned weights; here is what changed."

4. **Note-merging as a benchmark.** No off-the-shelf eval. Multi-doc summarization (MultiNews, WikiSum) and faithfulness eval (RAGTruth, RAGAS) are the adjacent anchors but none captures "two short study notes about the same entity, merge without claim loss or duplication." We'd be defining the benchmark. The 100-pair hand-curated eval set is the artifact.

5. **Preference leakage at small scale.** [arxiv 2502.01534](https://arxiv.org/abs/2502.01534) documents the problem at 7B+ generator/judge. Whether it gets worse at 1.7B (where the student might *encode* more of the teacher's idiosyncrasies) or better (where the student is too small to imitate teacher style precisely) is open. Default mitigation: cross-family generator/judge.

6. **Quality-vs-quantization curve for fine-tuned weights.** Base-model quantization curves (Q4_K_M ≈ -2 to -5% MMLU vs bf16) are well-trodden. For *fine-tuned* models — especially adapter-merged checkpoints with non-pretraining-shaped weight distributions — the same quantization scheme may be lossier. No paper isolates this; the practitioner advice ([HF GGUF discussions](https://github.com/ggml-org/llama.cpp/issues/7062)) says "spot-check with prompts after quantization." We should treat it the same way.

---

## 5. Specialist-vs-generalist evidence

**For (specialist beats generalist at same size on narrow task):**
- **LoRA Land** ([arxiv 2405.00732](https://arxiv.org/abs/2405.00732)) — 25 Mistral-7B specialists beat GPT-4 by 4–15% on their narrow tasks, each fine-tuned for <$8. Strongest published case.
- **Tiny Titans** ([arxiv 2402.00841](https://arxiv.org/abs/2402.00841)) — fine-tuned FLAN-T5-Large (770M) matches zero-shot 7B–70B LLMs on meeting summarization. Cited in the project's existing prior-art index.
- **DeepSeek-R1-Distill-Qwen-1.5B** ([arxiv 2501.12948](https://arxiv.org/abs/2501.12948)) — distilled 1.5B beats GPT-4o on AIME / MATH. Existence proof at our exact target scale.
- **Distilling Step-by-Step** ([arxiv 2305.02301](https://arxiv.org/abs/2305.02301)) — 770M T5 beats few-shot 540B PaLM on benchmark tasks.
- **LIMA** ([arxiv 2305.11206](https://arxiv.org/abs/2305.11206)) — 1,000-example SFT beats RLHF baselines. Argues data quality dominates at modest scale.

**Against (specialization fails or degrades):**
- **LoRA Learns Less and Forgets Less** ([arxiv 2405.09673](https://arxiv.org/abs/2405.09673)) — LoRA underperforms full-FT on domains *far from pretraining* (programming, math). For us this matters in reverse: note-merging is *close* to pretraining, so LoRA should work. But the asymmetry is real — narrow specialization can degrade base capabilities (general instruction-following, format compliance) if the fine-tune is too aggressive or the data is too narrow.
- **Catastrophic forgetting under SFT** — well-documented across the literature; LoRA's "forgets less" property is precisely because it's a partial fix. Full-FT a 1.7B on 1,000 note-merging examples and the model will likely lose conversational competence outside that distribution.
- **Preference Leakage** ([arxiv 2502.01534](https://arxiv.org/abs/2502.01534)) — many "specialist beats generalist" claims at small scale are inflated when the eval judge is in the generator's family. This is the counter-case that says "your demo numbers may be theatre." The fix is cross-family judging; the discipline is required, not optional.
- **LoRA Land's own ceiling** — narrow-task specialists beat GPT-4 on their narrow task and *underperform* GPT-4 on adjacent tasks. The specialization is real but it costs generality. For a flashcard generator that also has to handle a query the user typed slightly off-distribution, this is the failure mode to engineer around.

The writeup's specialists thread should name both sides: the case for is strong and recent (LoRA Land, R1-Distill); the case against is that narrow specialization at small scale is brittle, and you need cross-family judges to know whether your numbers are real.

---

## 6. Source ledger

https://arxiv.org/abs/2106.09685
https://github.com/microsoft/LoRA
https://arxiv.org/abs/2305.14314
https://github.com/artidoro/qlora
https://arxiv.org/abs/2402.09353
https://github.com/NVlabs/DoRA
https://arxiv.org/abs/2308.03303
https://arxiv.org/abs/2405.09673
https://arxiv.org/abs/2405.00732
https://github.com/predibase/lora_bakeoff
https://arxiv.org/abs/2402.00841
https://arxiv.org/abs/2501.12948
https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B
https://arxiv.org/abs/2406.08464
https://github.com/magpie-align/magpie
https://huggingface.co/datasets/Magpie-Align/Magpie-Air-300K-Filtered
https://huggingface.co/datasets/Magpie-Align/Magpie-Pro-300K-Filtered
https://arxiv.org/abs/2306.05685
https://arxiv.org/abs/2305.02301
https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/
https://arxiv.org/abs/2412.13337
https://arxiv.org/abs/2305.11206
https://arxiv.org/abs/2305.18290
https://arxiv.org/abs/2403.07691
https://arxiv.org/abs/2402.01306
https://arxiv.org/abs/2306.02707
https://arxiv.org/abs/2306.08543
https://arxiv.org/abs/2306.13649
https://arxiv.org/abs/2402.03898
https://arxiv.org/abs/2212.10560
https://github.com/yizhongw/self-instruct
https://arxiv.org/abs/2304.12244
https://huggingface.co/datasets/teknium/OpenHermes-2.5
https://arxiv.org/abs/2401.00396
https://huggingface.co/datasets/multi_news
https://huggingface.co/datasets/d0rj/wikisum
https://arxiv.org/abs/2311.03285
https://github.com/S-LoRA/S-LoRA
https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md
https://github.com/ggml-org/llama.cpp/issues/7062
https://arxiv.org/abs/2311.07911
https://huggingface.co/datasets/google/IFEval
https://arxiv.org/abs/2007.12626
https://github.com/Yale-LILY/SummEval
https://arxiv.org/abs/2309.15217
https://arxiv.org/abs/2502.01534
https://arxiv.org/abs/2404.14219
https://huggingface.co/Qwen/Qwen3-1.7B
https://arxiv.org/abs/2505.09388
https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B
https://arxiv.org/abs/2502.02737
