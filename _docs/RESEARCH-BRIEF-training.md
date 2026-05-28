---
internal_only: false
---

# Research Brief: Small-Model Post-Training for Mesh RAG (Specialists Thread)

> Audience: a deep-research agent (or human researcher). You have no prior context on this project. Read the *Project Summary* below, then execute the *Research Tasks* and return the *Required Deliverables*. Cite primary sources with the most stable URL available: arxiv DOI, repo URL + commit/tag when applicable, official docs URL with version or date-accessed when no commit exists. The audience for the *output* has shipped a small-LLM-on-mobile demo but has limited hands-on LoRA / fine-tuning experience — include enough framing in your synthesis that an engineer new to post-training can read it cold.

---

## Project Summary (read first)

A peer-to-peer **retrieval-augmented generation (RAG)** demo is already shipping for a hackathon: two phones (one iOS, one Android) each hold a disjoint slice of a study-notes corpus and meet over BLE / LAN via [Ditto](https://docs.ditto.live) (CRDT-backed P2P document database). The vector index is itself a CRDT — a grow-only set of `{ id, text, embedding[], metadata }` tuples — so the merge after a BLE handshake is conflict-free. Each phone runs an on-device embedding model (`qwen3-0.6-embed`, the similarity-tuned Qwen 3 Embedding 0.6B) and an on-device LLM (`qwen3-1.7`, Qwen 3 1.7B Instruct) via [Cactus](https://github.com/cactus-compute/cactus), an on-device AI runtime that wraps llama.cpp on each platform. No cloud during the demo — the trust boundary stops at the two devices.

**Stage 0** (CRDT vector sync + retrieval) and **Stage 1** (streaming flashcard generation from retrieved notes) are implemented and clearing acceptance criteria as of 2026-05-26. The demo *works* for a weekend project: small disjoint corpora (5 notes per phone, ~50 tokens each), Qwen 3 1.7B as a generalist on-device LLM, naive top-k retrieval + grounding gate + entity-overlap filter. The 1.7B generalist is the load-bearing seam: it drifts into Chinese under bilingual training distribution leakage (the model was trained on multilingual data), it rationalizes around grounding instructions, and on harder prompts (`n≥3` flashcards) the structured output format collapses to prose. The existing pipeline absorbs all of this with structural gates at the service layer, but the underlying quality ceiling is the generalist model.

**The writeup's argument is that the destination is not a generalist on each phone, it's a specialist per domain.** Stage 0 ships a generalist as a stepping-stone; the closing arc of the writeup names four future-work threads: (1) **specialists**, (2) preference-aware merge, (3) adversarial filtering, (4) generational evolution. This brief is scoped to thread (1) — what would it take to ship a *specialist* small model (study-notes-shaped: note merging, fact consolidation, deduplication, claim normalization) that runs on the same phones, in Cactus, with the same latency budget, but is actually good at the task instead of being a generalist hoping for the best.

### What "specialist" means here, concretely

A 0.5B–2B parameter model, fine-tuned (LoRA / QLoRA / DPO / SFT — methodology is part of the research) on a study-notes-shaped corpus, that runs in Cactus on a mid-range Android (Pixel 7+) and a mid-range iPhone (15+) at the same latency budget as Qwen 3 1.7B (single-digit-to-low-double-digit tokens/sec at 4-bit), and outperforms the same-base generalist on a narrow benchmark for note-merging quality. Format: GGUF, redistributable in a public hackathon repo, with a clear-eyed view of the base-model license that's being inherited.

### Known anchors (do not rediscover; find what's beyond these)

- **Oxen.ai** ([oxen.ai](https://www.oxen.ai)) — versioned data + model training platform; the user knows of it but has not used it for training. *Find: what shipping specialist-small projects have used Oxen.ai's pipeline, what the surface area looks like end-to-end (data versioning → training → export to GGUF / mobile), and where it fits relative to alternatives.*
- **LoRA** ([paper-2106.09685](https://arxiv.org/abs/2106.09685), `arxiv.org/abs/2106.09685`) — the user has heard of it but has not used it. Treat as the foundation, then go forward to QLoRA, DoRA, LoRA-FA, and the 2024–2026 PEFT lineage.
- **Tiny Titans** ([paper-2402.00841](https://arxiv.org/abs/2402.00841)) and **LoRA Land** ([paper-2405.00732](https://arxiv.org/abs/2405.00732)) — already in the project's prior-art index as evidence that fine-tuned small can rival generalist huge on narrow tasks. The brief should *go past* these into the operational specifics: training recipes, GPU budgets, evaluation methodology.
- **Cactus** ([github.com/cactus-compute/cactus](https://github.com/cactus-compute/cactus)) — on-device runtime. Critical seam for this brief: *does Cactus support LoRA adapter loading at runtime, or do we need to bake the LoRA into merged GGUF weights before shipping?* See Task 5.
- **Qwen 3** ([Qwen/Qwen3-1.7B](https://huggingface.co/Qwen/Qwen3-1.7B), [Qwen/qwen3-0.6-embed](https://huggingface.co/Qwen)) — current base models. Apache-2.0 licensed. Fine-tuning a Qwen 3 base is the path of least friction; other bases (Gemma, Phi, Llama, SmolLM2) are alternatives if the Qwen base has structural issues for note-merging.

### Out of scope by demo constraint

- **Pretraining from scratch.** Compute budget is hackathon-class (a few GPU-days, max — Modal / Lambda / Runpod / Colab Pro tier, not a cluster). Pretraining a model from scratch is not on the table.
- **Cloud inference.** The thesis breaks if the specialist runs anywhere except the two phones during the demo. Training in the cloud is fine; *running* in the cloud is not.
- **Anything that requires the base model's full weights to be redistributed.** The hackathon repo is public. If a base model's license requires complex attribution to redistribute fine-tuned weights, that's a tax we want to know about up front (Llama Community License's "Built with Llama" + naming prefix is the canonical landmine; Gemma Terms has its own clauses; Apache-2.0 bases like Qwen and SmolLM2 are clean).

---

## Research Tasks

For each topic, return: 3–8 strongest primary sources, what each contributes, where it falls short for our case, and (where applicable) the concrete operational specifics — GPU hours, dataset sizes, eval numbers, code recipes.

### T1. Oxen.ai's surface area and training pipeline

The user has named Oxen.ai specifically. We need a clear-eyed view of what it actually does, not the marketing version.

- **What Oxen.ai is** — versioned data store, training platform, both? Where does it overlap with HuggingFace Datasets / WandB / DVC / Modal / Replicate, and where is it differentiated?
- **End-to-end pipeline shape** — for a workflow of "I have a small custom dataset (a few hundred to a few thousand examples) of note-merging pairs, I want to fine-tune a Qwen 3 0.6B or 1.7B base, and ship the result as GGUF to run in Cactus on a phone." Does Oxen.ai do all of that, some of it, or just the data-versioning + experiment-tracking part?
- **Shipped specialist-small case studies** — find any *concrete public examples* of small models (≤3B) fine-tuned on Oxen.ai and deployed on edge / mobile. Blog posts, conference talks, open repos. We want to see the surface area used in anger, not the demo path.
- **Pricing / free-tier shape** — for a hackathon-scale (one-off, ~few-GPU-hour) run, is it viable? Note any data-egress or compute-egress friction.
- **Where Oxen.ai fits relative to alternatives** — Modal, Replicate, Together AI's fine-tuning surface, OpenPipe, Unsloth (on-prem), HuggingFace AutoTrain, Axolotl. We need a 1–2 sentence architectural contrast against each so the writeup can defend the choice.

### T2. PEFT for small base models: LoRA, QLoRA, DPO, SFT (operational specifics)

The user's familiarity is at the "I've heard of LoRA" level. The deliverable should make them operationally competent: what to actually run.

- **LoRA / QLoRA / DoRA / LoRA-FA primer** — what each is, what it costs in memory and time vs full fine-tuning, what quality trade-offs are documented in the literature. Anchor on the original LoRA paper ([paper-2106.09685](https://arxiv.org/abs/2106.09685)) but go forward to 2024–2026 work that supersedes or refines it.
- **Recipes specifically for 0.5B–2B base models** — Qwen 3 0.6B / 1.7B, Gemma 3 1B, Phi-3 Mini, SmolLM2 1.7B, Llama 3.2 1B / 3B. What hyperparameters actually work, what dataset sizes are sufficient, what overfits. Maintainer-authored docs (Hugging Face PEFT, Unsloth blog, Axolotl docs, LLaMA-Factory) are in-scope and often more useful than papers here.
- **SFT vs DPO vs ORPO vs KTO** — for a task that has *correct outputs* (note-merging has a ground truth in a way that creative writing doesn't), is supervised fine-tuning sufficient, or does preference-based optimization meaningfully help? Cite empirical comparisons at small scale.
- **GPU budget** — realistic dollar + hour costs to LoRA-fine-tune each candidate base on ~1k–10k examples. A100, H100, RTX 4090, M-series Macs (with MLX / mlx-lm) — what works, what's the floor.
- **Merged weights vs adapter-only deployment** — once fine-tuning is done, do we ship merged GGUF weights (one big file, base inherited license) or just the LoRA adapter (small file, base license maybe avoided)? Operational implications for runtime loading + license-on-redistribute.

### T3. Distillation from larger teachers to ≤2B students

Specialists don't have to come from fine-tuning the base. They can also come from distilling a known-good 7B–70B teacher down. For note-merging, a strong cloud LLM (GPT-4o-mini, Claude Haiku, Gemini Flash) on the audience-submitted data could be the teacher.

- **Knowledge distillation recipes for small student models** — soft-label distillation, hard-label distillation, reasoning-trace distillation (e.g., Orca-style), tool-use distillation. What 2024–2026 work has shipped specifically for student models in the 0.5B–2B range?
- **Synthetic-teacher pipelines** — generate (input, teacher-output) pairs with a strong API model, then SFT a small student on the pairs. Cite the strongest published examples; note any license / TOS landmines around using API-model outputs to train competitive small models (OpenAI's TOS, Anthropic's TOS, Google's Gemini TOS).
- **Reasoning-trace distillation** — DeepSeek-R1-Distill family is the recent reference point ([deepseek-ai/DeepSeek-R1](https://huggingface.co/deepseek-ai/DeepSeek-R1) and the 1.5B / 7B distilled variants). Did the distilled 1.5B retain meaningfully more capability than the same-size base? On what tasks?
- **Distillation vs fine-tuning, head-to-head** — for a narrow-domain task at small student scale, does distillation actually beat plain SFT on the same data? Cite the most rigorous published comparison.

### T4. Synthetic-data generation for narrow-domain corpora

The note-merging task has no off-the-shelf dataset. Whatever path we pick (T2 SFT or T3 distillation), step zero is generating training data.

- **Synthetic data generation for SFT** — Self-Instruct, Evol-Instruct, OpenHermes-style pipelines, Magpie. What's the 2024–2026 state of the art for generating thousands of high-quality task-shaped examples from a strong teacher model?
- **Note-merging / multi-document-summarization / claim-consolidation training data** — does anything off-the-shelf exist that's even adjacent (MultiNews, WikiSum, SQuAD-style multi-passage, RAG-Studio)? If we'd be generating from scratch, what does a defensible eval+training-set split for ~500–2000 examples look like?
- **Data-quality measurement** — for a fine-tuning dataset of a few thousand examples, how do practitioners actually measure dataset quality before kicking off training? Embedding clustering, judge-LLM filtering, manual spot-checks at fixed cadence — cite the practitioner-level guidance, not just papers.

### T5. On-device adapter loading and the Cactus seam

This is the load-bearing engineering question: assuming we *can* train a good specialist, can we actually ship it through Cactus to two phones?

- **Cactus + LoRA adapters** — does Cactus support runtime adapter loading (the way `llama.cpp` supports `--lora`)? Or does Cactus require merged GGUF weights? Search Cactus's docs, GitHub issues, Discord/Slack if linked, and the engine docs at [github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md](https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md). Maintainer-authored issues are in-scope — the answer is more likely there than in a paper.
- **llama.cpp LoRA support** — `--lora` flag, hot-swap, merging at load time, current state of `lora_apply` / `gguf_lora`. Cactus wraps llama.cpp so this is the substrate question.
- **MLC LLM's LoRA path** — MLC has its own adapter story; how does it compare for mobile deployment?
- **GGUF conversion + quantization of fine-tuned weights** — assuming we have a fine-tuned 1.7B in HuggingFace `safetensors` format, what's the path to GGUF Q4_K_M (or whatever quantization Cactus prefers) and what quality is lost in that step for a fine-tuned model specifically (vs the well-trodden base-model conversion path)?
- **Cross-platform parity of fine-tuned weights** — does fine-tuning change the cross-iOS/Android determinism story? The base model's embedding-cosine-parity test is already documented; do fine-tuned weights introduce new divergence (e.g., extreme LoRA deltas amplifying floating-point drift)?

### T6. Evaluation methodology for narrow-domain small-model quality

We cannot ship a "specialist" without a way to measure that it is, in fact, a specialist.

- **Evaluation harnesses for fine-tuned small models** — Eleuther's LM Eval Harness, Hugging Face Open LLM Leaderboard methodology, RAGAS, lm-evaluation-harness's RAG plugins, OpenAI Evals, promptfoo, deepeval. For a *narrow-domain* task (note-merging) at small scale (a few hundred eval examples), what's the right harness shape?
- **Judge-LLM evaluation** — using a stronger model (GPT-4o, Claude Sonnet) as a judge to rate small-model outputs. State of the art on judge-LLM reliability, position bias, length bias, and the documented gotchas. Cite 2024–2026 work specifically on judge-LLM-as-eval.
- **Note-merging-shaped evals** — anything that adjacent-evals note merging, multi-document summarization quality, fact consolidation correctness. SummEval, BFCL, IFEval, RAGAS-faithfulness, RAGTruth — what's relevant and what's not.
- **Holdout discipline** — how practitioners avoid evaluation contamination when both training data and eval data are synthetically generated from the same teacher model. This is the operational gotcha that tends to bite hardest at small scale.

### T7. Licensing landmines for fine-tuned weight redistribution

The hackathon repo is public. If we fine-tune and publish, we inherit the base model's redistribution clauses.

- **Apache-2.0 bases (Qwen, SmolLM2, Phi-3-Mini)** — clean path; document what attribution is required and whether fine-tuned-weights redistribution changes anything.
- **Llama Community License** — "Built with Llama" + naming prefix + 700M MAU clause. Does fine-tuning + redistribution trigger any additional clauses we haven't already documented?
- **Gemma Terms of Use** — what redistribution actually requires; what changed in Gemma 4 (Apache-2.0).
- **Synthetic-data-from-API-model TOS clauses** — OpenAI, Anthropic, Google. If we distill from GPT-4o-mini to a small student, does OpenAI's TOS restrict open-sourcing the student? Cite the actual clauses, not paraphrases.

---

## Required Deliverables

Return a single Markdown document with these sections (any section may be short or empty if the search returns nothing material — an empty section with a one-sentence explanation is better than padded filler):

1. **Top 10 must-read sources** — ranked, with one-paragraph annotations. These are the things an engineer planning to ship a specialist small model on mobile should read first. Mix of papers, framework docs, blog posts, and code repos as warranted.
2. **Per-topic findings** — one section per Research Task (T1–T7). Include sources (URL + author + date), a 2–3 sentence "what it gives us", and an explicit "gap" line.
3. **Recommended specialist-build recipe** — concrete decisions. Given the constraints (Cactus runtime, mobile target, hackathon-class compute budget, public-repo license posture), what's the recommended end-to-end recipe? Name: (a) base model, (b) training method (SFT / LoRA / QLoRA / DPO / distillation / hybrid), (c) data source (synthetic / curated / mixed) and approximate size, (d) training platform (Oxen.ai / Modal / Replicate / Unsloth-local / Colab-Pro), (e) GPU budget and wall-clock estimate, (f) eval shape (harness + holdout discipline), (g) deployment path (LoRA-adapter-runtime-loaded / merged-GGUF), (h) license posture of the final artifact. **Give a primary recommendation AND a backup if the primary's load-bearing assumption fails.**
4. **Reference implementations** — 2–5 existing public projects that fine-tuned a small (≤3B) base for a narrow domain and shipped on mobile or edge. Link to specific files/dirs. For each, a 2–3 sentence "what is structurally analogous to our use case."
5. **Open research questions** — gaps where we'd be inventing. Cactus + LoRA-runtime answer (yes / no / unknown) belongs here as a named verdict line if T5 doesn't resolve it from primary sources.
6. **Specialist-vs-generalist evidence** — the case (and counter-case). What's the strongest published evidence that a fine-tuned ≤2B specialist beats a generalist of the same size on a narrow task? And the strongest counter-case — where does specialization at small scale fail to deliver, or worse, degrade? The writeup's specialists thread is comparative and we need to name both sides.
7. **Source ledger** — flat deduplicated list of every URL cited, one per line. Format: `URL` only, no commentary, in order of first appearance.

## Constraints on the search

- **Audience is LoRA-curious, not LoRA-fluent.** Include enough framing in the deliverables that an engineer who has shipped on-device inference but has not personally fine-tuned a model can follow. Define terms at first mention.
- **Authoritative > popular by default, with maintainer-level secondary sources in-scope for T1, T5, and T7.** Prefer arxiv preprints, official docs, primary repos, conference talks. For Oxen.ai's surface area (T1), Cactus's adapter story (T5), and license-clause interpretation (T7), maintainer-authored issues / docs / TOS pages are the right primary sources.
- **Operational > theoretical.** This brief funds the *next thing we'd actually build*. Prefer sources that include code, hyperparameters, dollar costs, and wall-clock times over sources that prove abstract capability gains.
- **Recency rule.** For tooling and post-training methods, prefer 2024–2026 sources; foundational papers (LoRA, distillation, original Adam, etc.) are canonical regardless of age.
- **Don't pad.** Two strong sources beat eight weak ones.
- **Flag license posture explicitly** for every base model and every dataset surfaced in T1–T4. We will not ship anything in the demo repo that's encumbered without us knowing.

## Scope guardrails (don't bother)

- Don't research pretraining from scratch, model architecture novelty, or anything that requires cluster-scale compute.
- Don't research RAG architectures, retrieval methods, or chunking strategies — Stage 0/1 retrieval is already shipped and working.
- Don't research the CRDT layer, Ditto, BLE, or mesh transport — orthogonal to this brief.
- Don't research cloud inference platforms — final artifact runs on phones via Cactus.
- Don't propose novel training methods. Surface what's already shipped and working in the literature.

---

*Brief authored: 2026-05-28. Companion to [SEED.md](_docs/SEED.md), [research/RESEARCH-BRIEF.md](RESEARCH-BRIEF.md) (the original demo-scoped brief), and the closing arc of the writeup. Output expected at `_docs/research-training/` (one file per provider if running multi-provider, otherwise inline). The original brief scoped Stage 0/1 demo prior art; this brief scopes the specialists thread of the writeup's future-work arc and should not duplicate the original's coverage.*
