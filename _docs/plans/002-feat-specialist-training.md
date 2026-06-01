---
title: Train and ship a specialist small-model into the Mesh RAG demo
type: feat
status: active
date: 2026-05-28
origin: _docs/research-training/recipe.md
---

# Train and ship a specialist small-model into the Mesh RAG demo

## Summary

Build a one-weekend specialist-training pipeline that produces a fine-tuned Qwen 3 1.7B note-merging specialist, deployed as a merged `.cact` blob in the existing Cactus runtime via a single feature-flag swap in `lib/services/cactus_service.dart`. The plan follows the opinionated recipe synthesized at `_docs/research-training/recipe.md` (QLoRA r=16 on ~1,500 Magpie-synthetic pairs from a Qwen-72B teacher, Oxen.ai A10G training, three-layer eval, merged `.cact` deploy). The Cactus-merge-only verdict from research (no runtime LoRA support) forces single-specialist-per-`.cact` and shapes every unit that follows.

---

## Problem Frame

Stage 0 + Stage 1 of the demo ship with a generalist 1.7B base (Qwen 3 Instruct) that exhibits known failure modes — bilingual `<think>` drift, format collapse at `n≥3` flashcards, occasional grounding-instruction rationalization. The writeup's specialists thread (`project_writeup_thesis_arc`) argues the destination is a fine-tuned specialist per domain, not a generalist on each phone. This plan operationalizes that thread for the audience-submitted-study-notes task (note merging / claim consolidation / deduplication) — building the artifact, eval harness, and integration seam so the writeup can name "specialists" as a shipped capability, not a hypothetical. Concrete origin: the recipe's Day-0/1/2 weekend build path. Concrete writeup contribution: an A/B eval table (base vs specialist) on the 200-pair manual holdout.

---

## Requirements

Carried forward from `_docs/research-training/recipe.md` and the brief at `_docs/RESEARCH-BRIEF-training.md`:

- **R1 (specialist quality bar).** Specialist judge-accuracy uplift ≥10 points over the same-base generalist on the 200-pair manual holdout — Claude DR's recommended ship/no-ship gate. Below 10, the plan returns to data work or shelves the specialist as v1.
- **R2 (cross-platform parity preservation).** The merged `.cact` clears the existing R2 holdout (top-k retrieval order matches on iOS + Android ≥95% on the rehearsed query set). Reuse `tools/determinism_harness/`; do not invent a parallel harness.
- **R3 (license-clean redistribution).** Final artifact is Apache-2.0 end-to-end — Qwen 3 base (Apache-2.0) + Qwen 2.5-72B-Instruct teacher (Apache-2.0) + Unsloth core (Apache-2.0) + Cactus runtime (source-available, $2M revenue gate disclosed in NOTICE). No "Built with Llama" prefix, no API-output TOS landmine, no Gemma-terms attribution.
- **R4 (integration minimalism).** Specialist drops in via the existing `cactus_init(...)` API path in `lib/services/cactus_service.dart`. One feature flag (`USE_SPECIALIST`), one new `.cact` path, no architecture change. The demo's flashcard generator, retrieval service, and CRDT layer are untouched.
- **R5 (eval integrity).** The 200-pair holdout is curated from a DIFFERENT source partition than training data; judge LLM is cross-family (Claude 3.5 Sonnet or GPT-4o), never Qwen-as-judge (self-enhancement bias). Bidirectional ordering for position-bias control. Verbosity penalty in the rubric.
- **R6 (cost ceiling).** Total spend ≤ $10 (Oxen A10G + teacher inference + judge-LLM API calls). Wall-clock ≤ one developer-weekend (~13 hours focused work).
- **R7 (writeup contribution).** The plan ships an artifact AND a contribution: either a working specialist with an A/B eval table, OR (if R1 fails) a documented quantization-clipping / data-volume / task-framing failure case for the writeup's open-questions section.

**Cross-references:**
- R1, R5 trace back to the recipe's section (f) Eval shape
- R2 reuses Stage 0 holdout R2 from `_docs/plans/001-feat-mesh-rag-demo.md`
- R3 traces to recipe's section (h) License posture
- R4 trace point: `lib/services/cactus_service.dart` — the keystone integration moment per recipe section (g)

---

## Scope Boundaries

- **Multi-specialist swap on one device.** Out of scope — the recipe documents that Cactus's merge-only convert path forces one-specialist-per-`.cact`. The backup MLC migration path stays in the recipe, not in this plan.
- **On-device training.** Out of scope. The QVAC Fabric existence proof (Tether, Dec 2025) belongs in the writeup, not in the implementation. Training is cloud (Oxen A10G); inference is on-device (Cactus).
- **Preference optimization (DPO / ORPO / KTO).** Out of scope for v1 per recipe section (b) — SFT is sufficient for a task with correct outputs. ORPO is the named hedge if v1 reveals a stylistic gap SFT can't close.
- **Pretraining anything from scratch.** Hackathon-class compute budget — only PEFT / LoRA-shaped post-training.
- **Cloud inference at runtime.** Thesis-breaking per the project's `project_demo_already_exists` constraint. Specialist runs on-device or it doesn't ship.

### Deferred to Follow-Up Work

- **Multi-specialist orchestration in `CactusService`.** A swap mechanism for `merger / claim-normalizer / deduplicator` belongs in a follow-up plan only if the writeup's specialists thread requires it as a live demo (currently writeup-only per `project_writeup_thesis_arc`).
- **MLC LLM migration.** Backup A in the recipe — a separate plan if Cactus's merge-only path becomes blocking for thesis reasons.
- **Adapter-only deployment without merging.** Cactus doesn't support runtime LoRA today; this becomes a follow-up if Cactus ships `cactus_init_with_adapter(...)` or equivalent.

---

## Context & Research

### Relevant Code and Patterns

- `lib/services/cactus_service.dart:81-89` — `preferredCompletionSlug` / `preferredEmbeddingSlug` constants; the model-load path the specialist replaces. Constants are now documented inline (per the docstring move that landed in PR #15 merge).
- `lib/services/cactus_service.dart:134-135` — the `completionSlugOverride` / `embeddingSlugOverride` parameter pattern. The specialist swap follows this seam — a new override path, not a new service.
- `tools/determinism_harness/` — existing R2 harness. The specialist run reuses this verbatim; do not fork it. `integration_test/measure_test.dart` is the entry point.
- `tools/regen_seed_embeddings.py` — Python tooling lives at `tools/<feature>/`. New training tooling follows the same shape at `tools/specialist_training/`.
- `assets/seed_notes_{a,b}.json` — disjoint per-phone corpora. The 200-pair manual holdout is sourced from a DIFFERENT partition than these (per R5).
- `test/retrieval_service_test.dart:350` — `plan-locked defaults` pattern (and the user's correctly-flagged tautology critique that landed against the now-deleted `test/cactus_service_test.dart`). Tests for the specialist integration are behavioral, not tautological.

### Institutional Learnings (memory + repo)

- `feedback_structural_gates` — gate on inputs at the service layer, not on outputs at the stream. The specialist swap is structural (feature flag at service init), not output-detection.
- `project_cactus_supabase_leak` — Cactus's `Supabase.getModel` fires regardless of `isTelemetryEnabled`. The new specialist `.cact` ships bundled in the app's `assets/` to avoid triggering the model-download HTTP path; pinning `isTelemetryEnabled = false` BEFORE any model-load remains load-bearing.
- `project_seed_loader_no_delete` — `SeedLoader` accumulates state. The specialist integration must not touch `seed_loader.dart`; the eval pipeline uses a separate test harness that does not write through Ditto.
- `feedback_justfile_recipes` — repeated commands belong in the justfile. Training, eval, conversion, parity-check all get `just specialist-*` recipes.
- `feedback_ditto_release_mode_bug` — release-mode Android crashes with current `ditto_live`. The specialist integration ships behind `USE_SPECIALIST` flag so the existing debug-build path stays unchanged for the demo.

### External References

The recipe at `_docs/research-training/recipe.md` is the synthesis of 6 worker outputs. Specific anchors:
- Oxen Qwen3-1.7B text-to-SQL recipe (10–12 min A10G, beat GPT-4o on judge-accuracy) — `_docs/research-training/tooling.md` + `index/top-N.md`
- Magpie synthetic-data pipeline — `paper-2406.08464` (in research-training index)
- Unsloth Qwen3 fine-tuning guide — Cactus-blessed PEFT trainer per `_docs/research-training/tooling.md`
- Cactus `cactus convert --lora` docs — confirmed merge-only seam in `_docs/research-training/industry.md`
- Hamel Husain LLM judge calibration recipe (`hamel.dev/blog/posts/llm-judge/`) — for R5 judge-validation discipline
- RAGAS faithfulness scoring — `_docs/research-training/theory.md` (judge-LLM bias literature)

---

## Key Technical Decisions

- **Training framework: Unsloth (not Axolotl / LLaMA-Factory / HF AutoTrain).** Cactus-blessed per the Cactus finetuning guide; 1.5–2× speed on QLoRA; Apache-2.0 core. Axolotl is heavier YAML config than this scale needs; LLaMA-Factory is broader but less Qwen-native.
- **Synthetic-data generator: Magpie pipeline against Qwen 2.5-72B-Instruct.** Open-weight teacher avoids the OpenAI/Anthropic/Google TOS landmine (R3) and matches the writeup's "specialists from open weights" framing. Magpie's chat-template-completion trick generates seed queries without hand-curated seeds.
- **Eval orchestration: three layers, deepeval as the harness.** Apache-2.0, pytest-shaped DX, integrates RAGAS faithfulness + cross-family judge. The cheap-first ordering (deterministic assertions → judge → cosine) keeps eval cost bounded; budget for ~$3 in judge-LLM API calls per full holdout run.
- **Deployment artifact: merged `.cact` in `assets/models/`.** Forced by Cactus's merge-only convert path. Bundled in the app (not downloaded at runtime) to avoid the Cactus Supabase-telemetry seam (`project_cactus_supabase_leak`).
- **Integration seam: feature flag `USE_SPECIALIST` via `--dart-define`.** Matches the existing `PHONE_ROLE` + `DEMO_OVERLAY` flag pattern. A/B comparable in a single build by toggling at boot; no rebuilds, no separate flavors.
- **Model bundling: `assets/models/qwen3-1.7-merger.cact`, ~1.0–1.5 GB at Q4.** Adds to app bundle size; document the size tax in the README and the writeup. If Q4 quality collapses (recipe Backup B), fall back to Q8 (~3 GB) — still bundleable but a bigger pill.
- **Holdout source partition.** 200-pair manual holdout is hand-curated from astronomy / biology / physics study-note topics DISJOINT from the demo's inner-planet / outer-planet seed corpora — preventing the synthetic-data-leakage failure mode the recipe calls out under R5.

---

## Open Questions

### Resolved During Planning

- **Where does training tooling live?** `tools/specialist_training/` — mirrors `tools/determinism_harness/` and `tools/holdout_34/` precedent.
- **Where does the merged `.cact` ship?** `assets/models/qwen3-1.7-merger.cact`. Bundled (not downloaded). Added to `.gitignore` per repo convention; the conversion pipeline produces it from the Oxen adapter.
- **Where do training-data + holdout JSONL files live?** `tools/specialist_training/data/`, gitignored. The 200-pair holdout is committed (small; ~50 KB) at `tools/specialist_training/data/holdout_200.jsonl`. Synthetic 1,500 are not committed.
- **How does eval connect to the demo?** It doesn't — eval runs in Python via deepeval against the Oxen-trained adapter. The demo only sees the merged `.cact` at boot. Eval results live in `tools/specialist_training/eval_results/` (gitignored) + summary table committed for the writeup.
- **Does feature-flag default change?** No. `USE_SPECIALIST` defaults to `false`. The demo's Stage 0/1 generalist path remains the documented default. Specialist enabled only via `just app-run-a-specialist <device-id>` or explicit `--dart-define=USE_SPECIALIST=true`.

### Deferred to Implementation

- **Specific Magpie filter thresholds (cosine-dedup threshold, judge-pass threshold).** Calibrate empirically on the first ~200 generated pairs before scaling to 2,000.
- **Exact LR schedule and warmup steps.** Recipe says LR 1e-4 cosine, 8-bit AdamW, no warmup; tune ±20% if first training run's loss curve looks pathological.
- **Final cactus-convert quantization choice (INT4 vs INT8).** Default INT4 per recipe; fall back to INT8 if Q4 quality clips per Backup B. Decided at U6 verification time.
- **Whether the specialist replaces or supplements the generalist in the demo's recorded artifact.** Depends on R1 verdict at U7 decision gate. If specialist clears ≥10pt uplift cleanly, recorded demo uses specialist; otherwise base.

---

## Output Structure

```
tools/specialist_training/
├── README.md                          # build path, justfile recipes, expected outputs
├── generate_synthetic.py              # Magpie pipeline against Qwen-72B teacher
├── filter_synthetic.py                # cosine-dedup + judge-LLM filter + manual-spot stratification
├── train_config.yaml                  # Unsloth LoRA config (rank, alpha, target modules, schedule)
├── eval.py                            # three-layer harness (deepeval + RAGAS + cosine)
├── convert.sh                         # cactus convert + cactus build wrapper
├── configs/
│   └── magpie_prompt_template.txt     # the chat-template-completion prompt
├── data/
│   ├── .gitignore                     # ignores all except holdout_200.jsonl
│   └── holdout_200.jsonl              # committed; hand-curated eval set
├── eval_results/
│   └── .gitignore                     # ignores all except summary tables
└── requirements.txt                   # Unsloth + deepeval + RAGAS + transformers + sentence-transformers

assets/models/
└── .gitignore                         # ignores .cact blobs (large) — produced by U6
```

---

## Implementation Units

### U1. Scaffold `tools/specialist_training/` and justfile recipes

**Goal:** Create the directory layout, dependency manifest, and justfile recipes for the specialist training pipeline. No behavior yet — just the bones.

**Requirements:** R6 (cost ceiling — recipes drive consistent invocation).

**Dependencies:** None.

**Files:**
- Create: `tools/specialist_training/README.md`
- Create: `tools/specialist_training/requirements.txt`
- Create: `tools/specialist_training/data/.gitignore`
- Create: `tools/specialist_training/eval_results/.gitignore`
- Create: `assets/models/.gitignore`
- Modify: `justfile`

**Approach:**
- `requirements.txt` pins Unsloth, deepeval, RAGAS, transformers, sentence-transformers, `oxen` CLI. Exact versions from the recipe's named tooling.
- Justfile recipes (per `feedback_justfile_recipes`): `just specialist-generate`, `just specialist-filter`, `just specialist-train`, `just specialist-eval`, `just specialist-convert`, `just specialist-build`. Each delegates to the corresponding script with `set dotenv-load` for API keys (Together AI for the teacher, Anthropic/OpenAI for the judge).
- `data/.gitignore` ignores `*` but allows `!holdout_200.jsonl` so the committed eval set survives. Same nested-stub pattern as `_inspiration/.gitignore` per repo convention.
- README documents Day-0 / Day-1 / Day-2 path mirroring `_docs/research-training/recipe.md`'s weekend build.

**Patterns to follow:**
- `tools/determinism_harness/` for tooling layout (`integration_test/`, `baselines/`, top-level `README.md`).
- `tools/regen_seed_embeddings.py` for CLI-script shape.
- Existing justfile recipe groups: `app-*`, `harness-*`, `holdout-*` — add `specialist-*` group.

**Test scenarios:**
- Test expectation: none — scaffolding only; behavior verified through downstream units.

**Verification:**
- `just --list` shows the new `specialist-*` recipes grouped together.
- `tools/specialist_training/` exists with all directories and `.gitignore` stubs in place.
- `pip install -r tools/specialist_training/requirements.txt` succeeds in a fresh venv.

---

### U2. Synthetic data generation + filter pipeline

**Goal:** Generate ~2,000 candidate (note-A, note-B, merged-note) triples via Magpie-style prompting against a hosted Qwen 2.5-72B-Instruct endpoint, then filter to ~1,500 high-quality training pairs.

**Requirements:** R3 (license-clean — Qwen teacher inherits Apache-2.0); R5 (training data partition disjoint from holdout source).

**Dependencies:** U1.

**Files:**
- Create: `tools/specialist_training/generate_synthetic.py`
- Create: `tools/specialist_training/filter_synthetic.py`
- Create: `tools/specialist_training/configs/magpie_prompt_template.txt`

**Approach:**
- `generate_synthetic.py` calls the Qwen 2.5-72B-Instruct endpoint (Together AI by default; env-overridable) with the Magpie chat-template-completion trick: prompt template only contains the system + user-template prefix, letting the model autocomplete plausible study-note inputs. Output: raw JSONL at `data/synthetic_raw.jsonl`.
- `filter_synthetic.py` runs three filter passes:
  1. Embedding-cluster dedup via sentence-transformers (drop pairs above 0.95 cosine on the merged-note embedding).
  2. Judge-LLM completeness check (each ground-truth claim in inputs A+B is attributable in merged output; cross-family judge — Claude 3.5 Sonnet).
  3. Length cap (merged note ≤ 200 tokens to match demo flashcard generator's budget).
- Stratification by note type (claim-heavy / definition-heavy / list-heavy) using regex heuristics on the input note shape. Target ~33% each.
- Output: `data/synthetic_filtered.jsonl` (~1,500 examples, gitignored).
- Both scripts share a small `_common.py` for endpoint calls + JSONL I/O if needed.

**Execution note:** Generate the first 100 examples and manually spot-check before scaling to 2,000 — calibrates the Magpie prompt and the filter thresholds. Recipe explicitly names this manual-spot-check cadence.

**Patterns to follow:**
- `tools/regen_seed_embeddings.py` for CLI argument shape (`--input`, `--output`, `--limit`).
- `assets/seed_notes_a.json` schema for the note structure being generated.

**Test scenarios:**
- Happy path: Given a teacher endpoint mock returning canned (input-A, input-B, merged) triples, `generate_synthetic.py --limit 10` produces a 10-line JSONL with all three fields populated and length under 200 tokens.
- Edge case: When the teacher returns an empty `merged` field, `filter_synthetic.py` drops the row and logs the drop reason.
- Edge case: When two outputs have cosine ≥0.95 on merged-note embedding, the dedup pass keeps the first and drops the second.
- Error path: When the teacher endpoint returns 429, the script applies exponential backoff (1s, 2s, 4s) up to 3 retries before exiting non-zero.
- Integration: end-to-end on 100 real triples — verify the filter reduces count by 20–40% and the stratification report shows ~33/33/33 by note-type bucket. Record this as the calibration baseline before scaling.

**Verification:**
- `tools/specialist_training/data/synthetic_filtered.jsonl` exists and contains ~1,500 rows.
- Sample-of-20 manual spot-check rates ≥18/20 as "would I include this in a training set" — recipe's manual gate.
- `just specialist-generate && just specialist-filter` completes in <60 min on Together-AI Qwen-72B endpoint.

---

### U3. Author the 200-pair manual holdout

**Goal:** Hand-author 200 (note-A, note-B, merged-note) triples from study-note topics DISJOINT from the demo's seed corpora and the training data partition. This is the load-bearing eval anchor.

**Requirements:** R5 (eval integrity — partition disjoint from training data); R1 (specialist quality gate — depends on this holdout's signal).

**Dependencies:** U1 (for the data dir).

**Files:**
- Create: `tools/specialist_training/data/holdout_200.jsonl` (committed)
- Modify: `tools/specialist_training/README.md` (add the holdout-curation discipline section)

**Approach:**
- Source topics: biology (cell organelles, photosynthesis pathways), chemistry (acid-base, periodic groups), and earth science (plate tectonics, atmospheric layers). These are DIFFERENT from the demo's inner-planet / outer-planet astronomy seeds.
- Per-row schema matches the synthetic data: `{"note_a": "...", "note_b": "...", "merged": "..."}` plus a `topic_bucket` field for stratification analysis.
- 20-pair seed set first (recipe Day-0 deliverable), then expand to 200 across the topic buckets.
- Each merged-note is hand-written, not generated — even one auto-generated row contaminates the eval.

**Execution note:** This is human-curation work, not code. The unit is "complete" when the JSONL exists with 200 hand-authored rows and the README documents the disjoint-topic discipline. Plan-time deferred: exact topic-bucket split (current intent: 60/70/70 across biology/chem/earth science) may shift as curation reveals topic-density limits.

**Patterns to follow:**
- `assets/seed_notes_a.json` for note structure (`topic`, `body`, `tags`).

**Test scenarios:**
- Test expectation: none — this is data, not code. Quality verified by U5 (eval harness) producing sensible distinguishing scores between base and specialist outputs.

**Verification:**
- `wc -l tools/specialist_training/data/holdout_200.jsonl` returns 200.
- Topic-bucket distribution roughly matches plan (no bucket below 50, no bucket above 100).
- Manual review by an independent reader (recipe-suggested gate): random sample of 20, all rated as "yes, this is what the merged answer should be."

---

### U4. Training config + Oxen.ai notebook driver

**Goal:** Define the Unsloth LoRA configuration and the Oxen.ai notebook (or equivalent Marimo notebook config) that consumes `synthetic_filtered.jsonl` and produces a PEFT adapter.

**Requirements:** R6 (cost — A10G $1.65/hr × ~30 min = ~$0.83 per run).

**Dependencies:** U2 (training data), U3 (holdout for periodic eval during training).

**Files:**
- Create: `tools/specialist_training/train_config.yaml`
- Create: `tools/specialist_training/train.py` (Unsloth `FastLanguageModel` driver)
- Modify: `tools/specialist_training/README.md` (document the Oxen.ai notebook upload + training-run workflow)

**Approach:**
- `train_config.yaml` pins: base = `Qwen/Qwen3-1.7B`, LoRA r=16, alpha=32, target modules = all linear (`q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`), 3 epochs, LR 1e-4 cosine, effective batch 8 (per-device 2, grad-accum 4), 8-bit AdamW paged, dropout 0. These match recipe section (b) verbatim and the Cactus/Unsloth Qwen3 defaults.
- `train.py` reads the config, loads the JSONL, applies the Magpie chat template at tokenization time, runs Unsloth's `FastLanguageModel.from_pretrained(...)` + `get_peft_model(...)`, trains, saves adapter to `tools/specialist_training/adapter/` (gitignored).
- Oxen.ai workflow: upload `train.py` + `train_config.yaml` + `synthetic_filtered.jsonl` to an Oxen repo branch; run via Marimo notebook on Oxen's A10G; `oxen pull` the adapter back locally on completion. README captures the exact CLI invocations.
- Periodic eval-during-training hook: after each epoch, run a 20-example subset of the holdout through the in-training model + compute deepeval scores; log to wandb/console.

**Patterns to follow:**
- Unsloth's official Qwen3 fine-tuning notebook (linked from `_docs/research-training/tooling.md`).
- The recipe's exact hyperparameter set.

**Test scenarios:**
- Test expectation: none for the training script itself (the model is the artifact; quality verified at U5).
- Sanity check (manual): a smoke training run on 100 examples for 1 epoch should produce an adapter that beats the base by ≥15 points on the 20-pair seed eval (recipe's quick-smoke-test gate, Day-1 step 4). If the smoke run shows <15-point uplift, debug before the full 1,500 run.

**Verification:**
- Training completes in 15–45 min on A10G with no OOM.
- Loss curve descends; eval loss tracks training loss (no obvious overfit at epoch 3).
- Smoke-test on 20-pair seed eval shows ≥15 points uplift vs base.
- Adapter saved at `tools/specialist_training/adapter/` (~50 MB as standard PEFT `.safetensors`).

---

### U5. Three-layer eval harness

**Goal:** Score base vs specialist on the 200-pair holdout via deterministic assertions → cross-family judge LLM → embedding cosine similarity. Produce the A/B table the writeup needs.

**Requirements:** R1 (quality gate), R5 (eval integrity), R6 (cost — full holdout run ≤ $3 in judge-LLM API).

**Dependencies:** U3 (holdout), U4 (adapter), U2 (training-data baseline knowledge).

**Files:**
- Create: `tools/specialist_training/eval.py`
- Create: `tools/specialist_training/eval_results/summary.md` (committed; produced by `eval.py`)
- Modify: `tools/specialist_training/README.md`

**Approach:**
- Three-layer pipeline, cheap-first:
  1. **Deterministic assertions** (deepeval pytest fixtures): length cap (≤200 tokens), Markdown structure regex, claim-count counter, no leaked `<think>`, no Chinese characters (the known bilingual-drift failure mode), no `\boxed{}` math-mode artifacts. Failure here short-circuits the row before invoking the expensive judge.
  2. **Judge-LLM faithfulness** (RAGAS): claims extracted from generated merge, each verified against input notes A + B. Cross-family judge — Claude 3.5 Sonnet via Anthropic SDK (env var `ANTHROPIC_API_KEY`). Run bidirectional (swap A↔B in input order, average scores) to control position bias. Verbosity-penalty rubric: explicit "shorter is better when claims are preserved" rule.
  3. **Embedding cosine** between generated merge and ground-truth merge, using the demo's existing Qwen3-0.6-embed slug.
- For each of the 200 rows: run all three layers, store individual scores + composite, also store the base-model output for the same input (run base via the same Cactus runtime against same input).
- Output: `eval_results/run_<timestamp>.jsonl` (per-row scores) + `eval_results/summary.md` (aggregate A/B table). The summary is committed so the writeup can cite it.
- Judge-calibration step before scoring: run Hamel Husain's calibration recipe (judge vs human on 100 examples). If judge agrees with human <85%, redesign rubric before running on the full 200.

**Execution note:** Validate the judge against humans on 100 examples BEFORE trusting it on the full 200. Recipe section (f) names this as load-bearing.

**Patterns to follow:**
- deepeval pytest fixture pattern (Apache-2.0; reference in `_docs/research-training/tooling.md`).
- RAGAS faithfulness scoring (linked from `_docs/research-training/theory.md`).

**Test scenarios:**
- Happy path: Given a row where merged output preserves all input claims and has length 150 tokens, all three layers score high (deterministic pass, faithfulness ≥0.9, cosine ≥0.85).
- Happy path: Given a row where merged output drops half the input claims, layer 2 (faithfulness) scores ≤0.5 while layer 1 may still pass; composite score reflects the gap.
- Edge case: Empty model output — layer 1 fails on length-cap-minimum check; row marked as `assertion_failed`; no judge cost incurred.
- Edge case: Model outputs Chinese characters (the bilingual-drift mode); deterministic check fails fast.
- Error path: Anthropic API returns 429; script applies exponential backoff and resumes from the last completed row (idempotent JSONL append).
- Integration: end-to-end on 5 holdout rows with both base and specialist models — verify the script produces a valid `summary.md` with a 5-row A/B table and per-layer averages.

**Verification:**
- `just specialist-eval` produces `eval_results/summary.md` with an A/B table covering all 200 rows.
- Judge-calibration step (100 examples, judge vs human) shows ≥85% agreement before the full eval run.
- Total spend on the full 200-row run ≤ $3 (per recipe budget).

---

### U6. Conversion to `.cact` and Cactus build

**Goal:** Convert the trained adapter into a merged `.cact` blob via `cactus convert --lora`, produce iOS + Android build artifacts, validate the Q4 quantization didn't break the fine-tune.

**Requirements:** R2 (cross-platform parity — preserved through conversion), R3 (license posture — convert doesn't change inherited licenses), R4 (integration minimalism — output is a single `.cact` path).

**Dependencies:** U4 (adapter exists), U5 (eval shows specialist clears the ≥15pt smoke gate — otherwise no point converting).

**Files:**
- Create: `tools/specialist_training/convert.sh`
- Create: `assets/models/qwen3-1.7-merger.cact` (large; gitignored — produced by the script)
- Modify: `tools/specialist_training/README.md`

**Approach:**
- `convert.sh` wraps:
  1. `oxen pull <repo>@<branch>` to fetch the adapter locally (or `cp -r` from `adapter/` if running locally).
  2. `cactus convert Qwen/Qwen3-1.7B ./assets/models/qwen3-1.7-merger.cact --lora ./adapter` — single-step merge + Q4 quantization per recipe section (g).
  3. `cactus build --apple` + `cactus build --android` — emits XCFramework / `.so` artifacts.
  4. Held-out perplexity comparison: merged-Q4 (`.cact`) vs merged-Q8 (un-quantized PEFT merge through `transformers`). If Q4 degrades >5 perplexity points, the script prints a CLEAR warning and recommends Backup B (rank-8 or INT8 retry).
- Output validation: load the `.cact` via a Python Cactus binding (if available) or via a quick Dart test that exercises `CactusService.embed("test fixture")` and confirms non-null output.

**Execution note:** Run the Q4-vs-Q8 perplexity comparison BEFORE deciding to ship. The recipe's Backup B path is the failure mode if the comparison shows large degradation.

**Patterns to follow:**
- Cactus's documented `cactus convert` command (per `_docs/research-training/industry.md`).
- The existing `tools/holdout_34/runner.sh` shape for adb-driven CLI wrappers.

**Test scenarios:**
- Happy path: `convert.sh` runs end-to-end and produces a `.cact` file of expected size (~1.0–1.5 GB).
- Edge case: Adapter dir missing — script exits non-zero with a clear "adapter not found at <path>" message.
- Edge case: `cactus convert` command not found on PATH — script exits with installation instructions.
- Error path: Q4 perplexity degrades >5 points vs Q8 — script prints the backup-recipe pivot guidance and does NOT proceed to `cactus build`.
- Integration: smoke-load the produced `.cact` via a Dart test that exercises `CactusService.embed("Saturn has rings")` and confirms a 768-d vector returns (Qwen3-Embed dimension).

**Verification:**
- `assets/models/qwen3-1.7-merger.cact` exists at ~1.0–1.5 GB.
- iOS XCFramework + Android `.so` artifacts produced under Cactus's expected build-output paths.
- Q4 vs Q8 perplexity comparison logged; either Q4 within 5 points OR the script halted to surface the backup path.
- License files (`LICENSE.qwen3`, `NOTICE`) copied into `assets/models/` alongside the `.cact`.

---

### U7. Wire the specialist into `CactusService` behind `USE_SPECIALIST` flag

**Goal:** Add a feature-flagged path in `lib/services/cactus_service.dart` that loads the specialist `.cact` from `assets/models/qwen3-1.7-merger.cact` when `USE_SPECIALIST=true`, falling back to the existing `qwen3-1.7` Cactus catalog slug when false.

**Requirements:** R4 (integration minimalism — one new model-load path, no architecture change), R7 (writeup contribution — the A/B flag enables side-by-side demo).

**Dependencies:** U6 (the `.cact` must exist).

**Files:**
- Modify: `lib/services/cactus_service.dart` (add specialist-asset-path constant + flag-aware init branch)
- Modify: `pubspec.yaml` (declare `assets/models/qwen3-1.7-merger.cact` as a bundled asset)
- Modify: `lib/main.dart` or wherever `CactusService` is constructed (read `USE_SPECIALIST` via `String.fromEnvironment(...)`)
- Create: `test/cactus_service_specialist_test.dart`
- Modify: `justfile` (add `just app-run-a-specialist <device-id>` recipe that sets `--dart-define=USE_SPECIALIST=true`)

**Approach:**
- New constant in `CactusService`: `specialistCompletionAssetPath = 'assets/models/qwen3-1.7-merger.cact'`. Documented inline as the docstring move from PR #15 established — pin behavior, name the data dependencies (the conversion pipeline at `tools/specialist_training/convert.sh`).
- Flag flow: `CactusService(_, {bool useSpecialist = false})` constructor parameter. In `init()`, if `useSpecialist == true`, load via Cactus's asset-path init (resolving the asset from the Flutter bundle). Otherwise, existing slug-based load.
- Telemetry pin stays load-bearing — `CactusConfig.isTelemetryEnabled = false` BEFORE any asset load (per `project_cactus_supabase_leak` memory).
- The specialist path only affects the completion model. Embedding model stays `qwen3-0.6-embed` always — the specialist is fine-tuned for note-merging output, not embedding.
- Justfile recipe wires `--dart-define=USE_SPECIALIST=true` so `just app-run-a-specialist <device-id>` runs the demo with the specialist loaded; `just app-run-a-demo` keeps existing generalist behavior.

**Patterns to follow:**
- `lib/services/cactus_service.dart:134-135` — existing `completionSlugOverride` pattern. The specialist branch is a sibling override, not a replacement.
- `lib/main.dart` boot-screen pattern — read `--dart-define`s at app start.

**Test scenarios:**
- Happy path: `CactusService(useSpecialist: false).init()` loads via `preferredCompletionSlug` (existing path); `_activeCompletionSlug` ends `"qwen3-1.7"`.
- Happy path: `CactusService(useSpecialist: true).init()` loads via the specialist asset path; the service reports `isSpecialistLoaded == true` (new getter).
- Edge case: `useSpecialist: true` but the `.cact` asset is missing from the bundle — service throws a `MissingSpecialistAssetException` with a clear message naming the expected path AND the `tools/specialist_training/` build pipeline.
- Edge case: `useSpecialist: true` and `completionSlugOverride` also set — explicitly throw or pick one path with a documented precedence. Recommend: `useSpecialist` wins; the override is for testing flexibility only.
- Error path: `.cact` is corrupt / wrong format — Cactus init throws; service propagates with context ("specialist `.cact` at <path> failed to load: <inner error>").
- Integration: launch the app with `--dart-define=USE_SPECIALIST=true`; verify the boot screen reports specialist loaded, a Stage 1 flashcard generation call produces output, and the output does NOT exhibit the bilingual-drift / format-collapse failure modes of the base.

**Verification:**
- `just app-test` passes with all new specialist-mode tests.
- `just app-analyze` clean.
- Manual: `just app-run-a-specialist <device-id>` boots the demo with the specialist loaded; the DemoOverlay HUD shows "specialist: qwen3-1.7-merger" instead of "model: qwen3-1.7".
- `just app-run-a-demo <device-id>` unchanged — generalist path intact.

---

### U8. R2 parity check + ship/no-ship decision gate

**Goal:** Run the existing determinism harness against the merged specialist `.cact` on both iOS and Android; gate the ship decision on the recipe's R1 (≥10pt uplift) AND R2 (≥95% top-k order match) thresholds. Produce the writeup's eval table.

**Requirements:** R1 (specialist quality gate), R2 (cross-platform parity), R7 (writeup contribution).

**Dependencies:** U5 (full eval scored), U7 (specialist integrated and loadable in the live app).

**Files:**
- Modify: `tools/determinism_harness/integration_test/measure_test.dart` — extend to optionally run against the specialist model when `USE_SPECIALIST=true` is set (keep base-model run as default).
- Modify: `tools/determinism_harness/baselines/` — add a new sub-dir for specialist baselines if R2 passes.
- Create: `_docs/specialist-eval-results.md` — the committed A/B summary the writeup cites. Pulls from `tools/specialist_training/eval_results/summary.md` and the R2 parity check output.

**Approach:**
- Run the existing R2 harness recipe (`just harness-measure <device>`) with `USE_SPECIALIST=true` on both phones (Pixel + iPhone). Compare top-k retrieved sets on the 20 rehearsed-query baseline.
- If ≥95% agreement holds (R2 cleared): write the specialist baseline JSON files at `tools/determinism_harness/baselines/2026-XX-XX-specialist/`.
- If <95%: this is the writeup paragraph the recipe names — "LoRA-delta-induced FP divergence after Q4 quant" — and the demo ships the generalist while the specialist becomes a future-work artifact.
- Build the committed eval table: base vs specialist on each of the three eval layers, plus R2 verdict, plus a single-line "ship/no-ship" verdict.

**Patterns to follow:**
- `tools/determinism_harness/baselines/2026-05-26-pre-embed-swap/README.md` — baseline directory structure + per-device JSON shape.
- `just harness-check-baseline` recipe — reuse for the specialist baseline check.

**Test scenarios:**
- Happy path: specialist clears both R1 (≥10pt uplift) and R2 (≥95% top-k match); summary marks ship-OK and the recorded artifact uses the specialist.
- Edge case: R1 passes, R2 fails — summary documents the cross-platform divergence; demo ships the generalist; writeup gets a paragraph on quant-induced LoRA-delta divergence.
- Edge case: R1 fails (<10pt uplift), R2 passes — specialist works cross-platform but quality gain doesn't justify the bundle-size tax; summary recommends adding training data and re-iterating, or shelving as future-work.
- Error path: harness fails to run on either device — surface the device-level error; do NOT swallow it into the summary (the writeup must be honest about test-device failures).

**Verification:**
- `_docs/specialist-eval-results.md` exists with the A/B table, R2 verdict, and ship/no-ship recommendation.
- If shipped: `assets/models/qwen3-1.7-merger.cact` plus license files are committed (or LFS-tracked); `just app-run-a-specialist` is the recorded-artifact command.
- If not shipped: failure-mode documentation lands at `_docs/research-training/index/open-questions.md` (append, don't replace) and `_docs/specialist-eval-results.md` summarizes WHY.

---

## System-Wide Impact

- **Interaction graph:** Specialist swap is contained at the `CactusService.init()` seam. The `RetrievalService.generateFlashcards(...)` path is unchanged — it calls `cactus_complete()` the same way regardless of which model is loaded. The streaming flashcard path's structural gates (`_kDefaultStopSequences`, grounding gate, entity filter) all stay in place and continue to absorb model-output noise.
- **Error propagation:** Specialist-asset-missing → `MissingSpecialistAssetException` → caught at boot, surfaces to user with clear message + fallback to base. Cactus init failure → caught by existing `CactusService.init()` error path.
- **State lifecycle risks:** None new. The specialist `.cact` is bundled at app-install time; no runtime download path that would re-trigger `project_cactus_supabase_leak`.
- **API surface parity:** `CactusService` public API gains one new constructor param (`useSpecialist: bool`) + one new getter (`isSpecialistLoaded: bool`). Existing call sites unaffected when `useSpecialist` defaults to false.
- **Integration coverage:** The flag-flag-flag-flag combinations: `USE_SPECIALIST=false` + base path (current default, no regression). `USE_SPECIALIST=true` + Stage 1 flashcard generation (new path, verified by U7's integration test). `USE_SPECIALIST=true` + R2 determinism harness (new path, verified by U8). Cross-platform: both flag states tested on both phones.
- **Unchanged invariants:** Ditto CRDT layer, BLE transport, SeedLoader, RetrievalService cosine math, holdouts R1/R3/R4/R7. The specialist is invisible to the mesh layer — it just sees better completion output.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Q4 quantization clips the fine-tuned weights (recipe Backup B, Cactus issue #503 "FunctionGemma FP16 issues") | U6's Q4-vs-Q8 perplexity comparison is the early detector. Fallback to rank-8 LoRA retry, then INT8 quant, then ship Q8 (~3 GB bundle tax). |
| Cross-platform divergence introduced by LoRA-delta + Q4 quant amplifying FP non-associativity | U8's R2 harness check is the gate. Failure becomes a documented writeup contribution (the divergence story) rather than a blocker. |
| Synthetic data + holdout from same Qwen-72B teacher = preference leakage (Preference Leakage paper, `_docs/research-training/theory.md`) | R5 discipline — holdout is hand-authored from DISJOINT topic regions; cross-family judge (Claude 3.5 Sonnet, not Qwen-as-judge). |
| Specialist quality uplift <10pt (recipe's named ship gate) | U8 is the explicit decision gate. Below 10pt, plan publicly halts; specialist becomes documented future-work, not a force-ship. |
| Cactus runtime telemetry seam (`project_cactus_supabase_leak`) fires on specialist asset load | Bundle the `.cact` at app install (not runtime download); `isTelemetryEnabled = false` pin remains BEFORE any load (U7). |
| App bundle size balloons by 1–1.5 GB (per `.cact`) | Document the size tax in the README and writeup. Phone storage is the constraint, not the network. If size becomes blocking, fall back to assets-on-first-launch download (acceptable for the writeup, breaks R7 offline-only — undesirable). |
| Oxen.ai free-tier limits hit mid-training (50 GB transfer cap) | Recipe verified the Qwen3-1.7B FT case used Free Explorer. If hit, fall back to Unsloth-local on a Runpod RTX 4090 ($0.31–0.69/hr; Cactus-blessed). |
| Together AI / teacher endpoint rate-limits the synthetic-data generation | U2 has retry/backoff; generation can be re-resumed from the last-completed JSONL row (idempotent append). |
| Recipe's verdict (no Cactus runtime LoRA) gets invalidated by Cactus shipping `--lora` at runtime mid-plan | Discoverable via Cactus repo's Discussions / release notes. Re-plan to swap merge-only for runtime-load; trivially smaller integration. |

---

## Documentation / Operational Notes

- `_docs/research-training/recipe.md` is the upstream synthesis; this plan implements its Day-0/1/2 path.
- `_docs/specialist-eval-results.md` (created at U8) is the writeup's load-bearing eval-table citation.
- README at `tools/specialist_training/README.md` is the operator's runbook — Day-0 setup, Day-1 train, Day-2 deploy + eval.
- Update `CLAUDE.md` with a "Specialist training" section after U7 lands; cite this plan and the recipe.
- Update `README.md` (project root) to mention the optional specialist build path in the "Common tasks here" section; cite the new `just specialist-*` recipes.

---

## Sources & References

- **Origin document:** [_docs/research-training/recipe.md](../research-training/recipe.md)
- **Brief:** [_docs/RESEARCH-BRIEF-training.md](../RESEARCH-BRIEF-training.md)
- **Research index:** [_docs/research-training/index/](../research-training/index/) — particularly `top-N.md` (consensus picks), `clusters.md` (T1–T7 mapping), `open-questions.md` (Cactus runtime LoRA verdict).
- **Stage 0/1 plan (parent):** [_docs/plans/001-feat-mesh-rag-demo.md](001-feat-mesh-rag-demo.md)
- **Project SEED:** [_docs/SEED.md](../SEED.md)
- **Integration touchpoint:** [lib/services/cactus_service.dart](../../lib/services/cactus_service.dart)
- **R2 harness (reused):** [tools/determinism_harness/](../../tools/determinism_harness/)
- **Memory-anchored constraints:**
  - `project_cactus_supabase_leak` — telemetry pin discipline at model load
  - `project_seed_loader_no_delete` — eval pipeline must not touch SeedLoader
  - `feedback_structural_gates` — specialist swap is structural (service layer), not output detection
  - `feedback_justfile_recipes` — every multi-step command goes in the justfile
  - `feedback_ditto_release_mode_bug` — specialist ships behind feature flag; debug-build demo path stays unchanged
