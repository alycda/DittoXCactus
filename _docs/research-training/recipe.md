# Specialist build recipe — opinionated

This is the recommended end-to-end recipe for landing a fine-tuned specialist small model in the Mesh RAG demo. The audience is an engineer who shipped the demo, knows the Cactus + Ditto + Qwen 3 stack cold, but has limited LoRA / fine-tuning experience. **Jargon is defined at first use.**

It is opinionated by design. The brief asked for a decisive recommendation, not a menu of equal options. Two recipes are below: a **primary** and a **backup**. The backup activates only when the primary's load-bearing assumption fails (we'll name when).

The recipe synthesizes the verdicts from all six worker outputs in [`./theory.md`](theory.md), [`./tooling.md`](tooling.md), [`./industry.md`](industry.md), [`./claude-deep-research.md`](claude-deep-research.md), [`./chatgpt-deep-research.md`](chatgpt-deep-research.md), [`./gemini-deep-research.md`](gemini-deep-research.md). The semantic index at [`./index/`](index/) breaks the synthesis down by task and topic.

---

## Glossary (defined-at-first-use)

- **LoRA** (Low-Rank Adaptation) — a parameter-efficient fine-tuning method. Instead of updating all the model's weights, you freeze them and train two small "thin" matrices that get added to specific weight matrices at runtime. Way fewer trainable parameters (~1% of base), way smaller GPU memory bill. When someone says "LoRA rank 16," they mean the inner dimension of those two thin matrices.
- **QLoRA** — LoRA where the frozen base is also quantized to 4-bit during training (with NF4 quant + double-quant + paged optimizers). Lets you fit big models on small GPUs. At our 1.7B scale, QLoRA's headline benefit doesn't matter much — plain bf16 LoRA fits any 24 GB+ card.
- **SFT** (supervised fine-tuning) — the plain-vanilla "loss-on-next-token over (prompt, target) pairs" objective. The simplest training signal.
- **DPO / ORPO / KTO** — preference optimization. Train on triples `(prompt, chosen, rejected)` instead of single targets. Used when there's a stylistic preference, not a single correct output. For our task, **probably overkill**.
- **PEFT** — Parameter-Efficient Fine-Tuning, the umbrella term for LoRA and friends. Also the name of Hugging Face's library implementing them.
- **Adapter** — the trained delta produced by LoRA. A small `.safetensors` or `.bin` file you can save, ship, or merge back into base weights.
- **Merged GGUF / merged `.cact`** — what you get after applying the adapter back to the base and exporting in the runtime's expected format. Single file; license inherits from base.
- **Distillation** — training a small "student" to mimic a large "teacher" model's outputs. Black-box distillation (input → teacher output → SFT student) is the cheap path; white-box distillation needs teacher logits, which closed APIs don't expose.
- **Magpie** — a synthetic-data trick. Prompt an instruct model with *only* its pre-query chat template and let it autocomplete a plausible user query, then generate an answer. Free training data, no seed examples needed.

---

## Primary recipe

### (a) Base model: **Qwen 3 1.7B Instruct (Apache-2.0)**

Why:
- Already the demo's base. Zero new ground to break on the runtime side. The same Cactus model-load path in [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart) accepts the specialist drop-in.
- First-class Cactus support: listed in the Cactus fine-tuning guide's supported-base set (Qwen3, Qwen3.5, Gemma3, LFM2, LFM2.5).
- **Apache-2.0 license** — no naming prefix, no "Built with X" banner, no MAU clause. Just standard attribution.
- The closest published recipe (Oxen Qwen3 text-to-SQL) shows 1.7B hits 57% judge-accuracy on a structured task vs 0.6B's 42%. The size step from 0.6B → 1.7B reliably moves quality on structured tasks; the 1.7B is worth it.
- Apple's tech report and Predibase LoRA Land both confirm this scale-class (1.5–2B) is where specialization wins consistently on narrow tasks.

**Fallback within the primary:** Qwen 3 0.6B if Pixel-7 latency on the 1.7B falls below an acceptable single-digit tok/s floor (the demo's Stage 1 streaming case). Both are first-class in Cactus.

### (b) Training method: **QLoRA SFT, rank 16, alpha 32**

Why:
- **LoRA, not full fine-tuning** — the "LoRA Learns Less and Forgets Less" paper (`arxiv.org/abs/2405.09673`) showed that LoRA forgets base capabilities less than full-FT, and note-merging is close to base-model competence so the quality gap is small. Plus full-FT a 1.7B on a narrow task reliably loses general competence.
- **QLoRA (4-bit base) optional** — at 1.7B, a bf16 base is ~3.4 GB and fits any 24 GB+ card. QLoRA matters more at ≥7B. Use it if you're on a Colab T4 (16 GB); skip it on an A10G or RTX 4090.
- **Rank 16** — Apple's tech report explicitly names {8, 16, 32} as the dev-tooling ranks they ship; rank 16 is the documented sweet spot for quality vs latency. Cactus's own finetuning.md recommends rank 16.
- **Alpha 32** — the common heuristic is alpha = 2× rank, i.e., 32 here. (Some recipes use alpha = rank; both work, alpha = 2× is the safer default at small scale.)
- **Target modules: all linear** — `q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`. This is the Unsloth/Cactus default.
- **No preference optimization for v1.** Note-merging has correct outputs — SFT is sufficient. Reach for ORPO only if the v1 eval shows a style/format gap (e.g., persistent bilingual drift or verbose padding) that SFT can't close. ORPO's single-pass framing (no SFT warm-up, no reference model) is the cheapest hedge.
- **Hyperparameters:** LR 1e-4 with cosine scheduler, effective batch 8 (e.g., per-device batch 2, grad-accum 4), 3 epochs, 8-bit AdamW (paged), dropout 0. These are the Cactus / Unsloth Qwen3 defaults; not exotic.

### (c) Data source: **synthetic note-merging pairs from an open-weight teacher, ~1,500 examples + 200-pair manual holdout**

Why:
- **No off-the-shelf note-merging dataset exists.** Multi-News and WikiSum are shape-adjacent (multi-doc summarization) but wrong: news with long summaries, not study notes with consolidated claims. We have to generate.
- **Synthetic from open-weight teacher, not closed-API teacher.** OpenAI / Anthropic / Google TOS prohibit using outputs to train competing models. The DeepSeek-OpenAI controversy is the public test case. Use an Apache-2.0 / MIT teacher: Qwen 2.5-72B-Instruct (Apache-2.0), Llama-3-70B-Instruct (Llama Community + attribution), or DeepSeek-R1 (MIT). Generated data inherits the teacher's license, so Qwen 72B is the cleanest choice.
- **Magpie pipeline** (`github.com/magpie-align/magpie`) — for the bootstrap. Prompt the Qwen 72B teacher with only the chat template up to the user slot, let it autocomplete a study-notes-shaped query, then generate the merged answer. Then filter (see below).
- **~1,500 high-quality examples** — LIMA showed at this scale that data quality dominates volume. Theory worker's recommendation; Gemini DR's recommendation; rough split: 1,500 train + 200 manual holdout, stratified across note types (claim-heavy, definition-heavy, list-heavy).
- **The 200-pair manual holdout is the load-bearing artifact.** Hand-write or hand-verify it. Synthetic eval data + synthetic training data + same teacher = memorization theatre (Preference Leakage paper). The 200 hand-curated pairs are what we report.
- **Quality filter:** embedding-cluster dedup (sentence-transformers + FAISS, drop near-duplicates above 0.95 cosine), judge-LLM filter (does the merge include every claim from each input; is each output claim attributable; is the length under budget), manual spot-check 5% at fixed reviewer cadence. Magpie paper Section 3 is the cleanest published account of what to filter.

**On note-merging task framing for the synthetic generator's prompt:** narrowly scoped — "given two short study notes about the same topic, produce a single merged note that preserves every claim, drops duplicates, normalizes phrasing." Don't drift into open-ended composition (where the generalist's broader competence helps and a small specialist's narrower competence hurts).

### (d) Training platform: **Oxen.ai** (Marimo notebook + serverless A10G)

Why:
- The closest published recipe (Oxen Qwen3 text-to-SQL) ran on Oxen.ai's Marimo notebook + A10G in 10–12 min. Direct fit.
- Data versioning + experiment tracking + notebook all in one place — useful for hackathon iteration.
- **Free Explorer tier** (50 GB storage, 50 GB transfer, unlimited public repos, 5 private repos) is enough.
- **Pay-per-second GPU:** A10G $1.65/hr; a 30-min run costs ~$0.83. H100 80GB $4.87/hr if the A10G doesn't fit — but at 1.7B QLoRA, A10G is plenty.

**The gap to close ourselves:** Oxen.ai does NOT export GGUF / `.cact` as a first-class output. You take the safetensors back and convert yourself. This is the single weak link; it's two CLI commands.

**Alternative if Oxen.ai's UX doesn't fit:** Unsloth-local on an RTX 4090 ($0.31–0.69/hr on Runpod/Vast) — Cactus's officially recommended trainer; you ship a Python script, you control every step. Same Apache-2.0 / AGPL-3.0 license. Use Unsloth-local if you want maximum reproducibility for the hackathon writeup.

**What we explicitly do NOT use:** Modal (great compute but no data versioning), Replicate (inference-first, fine-tuning secondary), HF AutoTrain (less control), Axolotl (heavier YAML config than we need at this scale).

### (e) GPU budget and wall-clock estimate

- **Wall-clock:** 15–30 minutes for the LoRA run + 5–10 minutes for synthetic data generation per ~500 examples (teacher inference latency dominates) + 5 minutes for the merge + `cactus convert` step.
- **Dollar cost:** roughly **$1–$3** all-in.
  - Oxen A10G: 30 min × $1.65/hr = $0.83
  - Teacher inference for 1,500 examples (use a hosted Qwen 72B at, e.g., Together AI or self-host on a smaller cloud A100): rough estimate $0.50–$2 depending on provider, prompt length, and whether you batch.
  - Conversion compute: local, free.
- **Verification:** the Oxen $1 Qwen3-VL post and the Predibase LoRA Land $8/fine-tune average are both within this envelope.

### (f) Eval shape

Three layers, in order of cost:

1. **Deterministic assertions** (cheap, fast, runs first). Programmatic checks — length cap, output Markdown structure regex, claim-count counter, no leaked `<think>` token, no emitted Chinese characters (the demo's known failure mode). If any of these fail, the case fails immediately without invoking the expensive judge. **Implement with deepeval** (`github.com/confident-ai/deepeval`) — Apache 2.0, pytest-shaped DX.
2. **Judge-LLM faithfulness** (expensive, slower). RAGAS-style faithfulness: extract claims from output, verify each against the input notes. Use a **cross-family judge** (Claude 3.5 Sonnet or GPT-4o; explicitly NOT Qwen-as-judge — self-enhancement bias). Run **bidirectional** (swap order, average) to control position bias. Penalize verbosity explicitly in the rubric. Hamel Husain's calibration recipe (`hamel.dev/blog/posts/llm-judge/`): validate judge against humans on 100 examples before trusting it.
3. **Semantic relevance** (cheap). Embedding cosine similarity between generated merge and ground-truth holdout merge. Use the existing demo embedder (Qwen3-0.6-embed).

**Holdout discipline:** the 200-pair manual holdout is generated/curated from a DIFFERENT source partition than the training data — physically separate input study notes. Different teacher seed for any synthetic eval expansion. **Never let the judge be the same model family as the teacher that generated the training data.**

**Specialist-isn't-earning-its-keep threshold:** if judge-accuracy uplift over the same-base generalist is <10 points, the specialist isn't worth shipping — add training data or re-examine the task framing. (Claude DR's recommendation.) Don't ship a specialist that gives single-digit uplift; the deployment cost is too high.

### (g) Deployment path: **merged `.cact` blob via `cactus convert --lora`**

This is forced by the verdict: Cactus does not support runtime LoRA loading.

Workflow:
1. Train under Unsloth → save adapter as standard PEFT `.safetensors` (or use Oxen's `OxenTrainerCallback` to push to a branch).
2. Pull the adapter to local: `oxen pull <repo>@<branch>` or `git clone` the adapter dir.
3. `cactus convert Qwen/Qwen3-1.7B ./out --lora ./adapter` — merges and converts to `.cact` in one step. Q4-equivalent quantization happens here.
4. `cactus build --apple` / `cactus build --android` — produces XCFramework / `.so` for Flutter app integration.
5. Replace the model load path in [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart) — same `cactus_init(...)` API, different model path. **This is the keystone integration moment.** No other code in the demo needs to change.

**Quality gate before shipping:** after `cactus convert`, run the demo's R2 cross-platform determinism harness against the merged `.cact` on both iOS and Android. If embedding-cosine parity holds, ship. If it fails (open question 5 in [`./index/open-questions.md`](index/open-questions.md)), the writeup gets a paragraph about the LoRA-delta-induced divergence — that's its own contribution. Also run a held-out perplexity comparison: merged-q4 (the `.cact`) vs merged-q8 (un-quantized PEFT merge). If q4 degrades >5 points, fall back to ranking r=8 or to INT8 in the convert step.

**Multi-specialist on one device:** ship multiple `.cact` blobs. Cost: ~1–1.5 GB per specialist. Switch by unloading + reloading models at the app layer (cold-load latency, not LoRA hot-swap). For a hackathon demo with one specialist (note-merger), this is invisible to the user. For 3+ specialists, the storage and cold-load tax forces a different architecture (see backup recipe below).

### (h) License posture of the final artifact

- **Base:** Qwen 3 1.7B (Apache-2.0). Includes the LICENSE + NOTICE in the artifact directory.
- **Teacher (for synthetic data):** Qwen 2.5-72B-Instruct (Apache-2.0). Generated data inherits the same license — clean.
- **Trainer:** Unsloth core (Apache 2.0) — fine.
- **Cactus runtime:** source-available with $2M revenue gate. Fine for the hackathon repo. Disclose in the writeup: "Cactus is source-available, not Apache; check the threshold before commercial use."
- **Final merged `.cact`:** Apache-2.0 (inherits from Qwen 3 base + Qwen 72B-generated data + Apache trainer). Redistributable in the public repo with just NOTICE + a statement of modifications.
- **No "Built with X" banner, no naming prefix, no MAU clause, no API-output TOS landmine.**

---

## When the primary's load-bearing assumption fails: backup recipe

The primary's load-bearing assumption: **one specialist per device is enough**, AND **Cactus's merge-only convert path works without quantization-induced quality collapse**.

If either fails, here's the pivot.

### Backup A: multi-specialist matters → migrate to MLC LLM (or accept multi-`.cact` cold-load)

If the writeup's specialists thread requires multiple specialists swappable on one device (e.g., merger + claim-normalizer + deduplicator demonstrated live), Cactus won't get you there today. Two paths:

1. **Multi-`.cact` cold-load.** Ship N `.cact` blobs. Storage cost: N × ~1.0 GB at Q4. Switching cost: cold model load, ~seconds. Painful UX, but feasible if you can stage the right specialist before the relevant UI affordance.
2. **Migrate runtime to MLC LLM.** MLC LLM's PR #3281 (`github.com/mlc-ai/mlc-llm/pull/3281`) shipped runtime LoRA on desktop; mobile cross-platform LoRA deployment is on their roadmap but not yet verified. Migration cost: significant — different Flutter integration story, different model conversion, different model registry. Worth it if multi-specialist-per-device is a thesis-breaking constraint. Apache-2.0 license — clean.
3. **(Out-of-scope but writeup-worthy):** MediaPipe LLM Inference on Android does runtime LoRA on the GPU backend for Gemma-2 2B / Gemma 2B / Phi-2 today. Cross-platform parity is broken (iOS not supported by MediaPipe), so it can't be the demo's runtime — but it's a useful reference in the writeup.

### Backup B: quantization clips the fine-tuned weights → drop adapter rank, or ship q8 instead of q4

If `cactus convert` produces a `.cact` that outputs garbled text (the "FunctionGemma FP16 issues" failure mode in Cactus issue #503), the fine-tune has learned extreme weight values that the 4-bit quantization clips. Three fixes, in order:

1. **Lower the rank.** Retry at rank 8 instead of rank 16. Lower-rank LoRA produces smaller perturbations and is more robust to downstream quantization.
2. **Train with more conservative LR.** Drop LR to 5e-5 (half of primary's 1e-4). Less aggressive learning → less extreme weights.
3. **Ship at INT8 instead of INT4.** Roughly double the on-device memory footprint (~3 GB instead of ~1.5 GB) but preserves the fine-tune. Cactus's convert step supports INT8.

If all three fail, the writeup gets a paragraph: "we observed quantization-induced clipping on the merged specialist; the fix path is X." That itself is writeup-worthy — see open question 8.

### Backup C: Qwen 3 1.7B quality/latency is unacceptable on Pixel 7 → drop to 0.6B or Gemma 4 1B

- **Qwen 3 0.6B** — same family, faster. Cactus first-class. Cost: noticeable quality drop on structured tasks (per Oxen text-to-SQL: 0.6B → 42% vs 1.7B → 57%). Lean harder on synthetic data volume to compensate.
- **Gemma 4 1B** — Apache-2.0 (April 2026 license flip). Verify Cactus support — Cactus's published supported-base list names Gemma 3, not yet Gemma 4. Direct outreach may be required.
- **Phi-3 Mini** — MIT license. Solid 3.8B; may be too big for Cactus's smaller-edge sweet spot.

---

## Open the demo to specialists in one weekend

A minimal-viable build path that integrates with the current [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart) shape. The specialist drops in via the same model-load path used by current Qwen 3 1.7B base — no new architecture in the demo code.

### Day 0 (prep, 1 hour)

- Verify Oxen.ai free-tier signup + Marimo notebook access.
- Verify access to a Qwen 2.5-72B-Instruct endpoint (Together AI, Fireworks, or self-hosted on a single A100).
- Verify Unsloth installs cleanly on a workstation or Colab — Apache-2.0 core, no licensing setup.
- Hand-author the load-bearing **20-pair seed eval set**: take 20 disjoint pairs from the demo's seed-notes-a + seed-notes-b corpora and manually write the ground-truth merged note for each. This is the calibration anchor for everything else.

### Day 1 (data + train, ~6 hours)

1. **Synthetic data generation (2 hours).** Magpie-style prompts to Qwen 72B teacher. Generate 2,000 candidate (note-A, note-B, merged-note) triples. Stratify by note type. Filter: embedding-cluster dedup (drop above 0.95 cosine), judge-LLM filter for completeness/attribution/length, manual spot-check 5%. Land at ~1,500 clean examples.
2. **Manual holdout expansion (1 hour).** Take the 20-pair seed eval set + hand-author 180 more from disjoint topic regions (different from training data's seed distribution). 200-pair manual holdout.
3. **Training (45 min).** Oxen Marimo notebook with Unsloth `FastLanguageModel`. Qwen3-1.7B, LoRA r=16, alpha=32, all linear modules, 3 epochs, LR 1e-4 cosine, 8-bit AdamW paged. Save adapter to Oxen branch.
4. **Quick smoke test (15 min).** Inference on 20 holdout examples with the adapter merged into bf16 base (PyTorch, before any quantization). Sanity-check that the fine-tune learned anything — judge-accuracy on the 20 should be visibly higher than the same-base generalist (>15 points).

### Day 2 (deploy + eval, ~6 hours)

1. **Deploy (1 hour).** `oxen pull` adapter → `cactus convert Qwen/Qwen3-1.7B ./specialist --lora ./adapter` → `cactus build --android` and `cactus build --apple`. Land artifact at `assets/models/qwen3-1.7-merger.cact`.
2. **Integration (1 hour).** Wire the new `.cact` into [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart) via a new model-load path. Add a feature flag `USE_SPECIALIST=true` so we can A/B against base. No other demo code changes.
3. **R2 cross-platform parity check (30 min).** Re-run the existing determinism harness ([`tools/determinism_harness/`](../../tools/determinism_harness/)) against the new `.cact` on both phones. If parity holds, continue. If not, this becomes the writeup paragraph + open question 5.
4. **Eval (3 hours).** Full 200-pair manual holdout, three layers:
   - Deterministic assertions via deepeval pytest
   - Cross-family judge-LLM faithfulness via RAGAS (Claude 3.5 Sonnet or GPT-4o as judge; bidirectional ordering; verbosity-penalty rubric)
   - Embedding cosine similarity vs ground-truth merges (using existing Qwen3-0.6-embed)
   Report: base-generalist vs specialist on each layer.
5. **Decision gate (30 min).** Specialist judge-accuracy uplift ≥10 points over base? Ship. <10? Add training data, re-iterate; or drop the specialist as a v1 deliverable. The writeup gets the eval table either way.

### Total weekend cost

- **Wall-clock:** ~13 hours of focused work; one developer-weekend.
- **Dollar cost:** ~$5 all-in (Oxen GPU + teacher inference for synthetic data + judge-LLM API calls for eval).
- **Demo-side code changes:** one new model path in `cactus_service.dart`; one feature flag. No architecture change.

The single integration moment is `cactus_service.dart`'s model path. The specialist is the same shape of `.cact` artifact, same Cactus API, same Ditto pipeline, same Flutter UI. The mesh-RAG demo doesn't care that the model on the other side of `cactus_complete()` is now specialist-grade — it just sees better output.

That's the win to ship.
