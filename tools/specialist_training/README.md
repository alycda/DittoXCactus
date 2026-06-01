# tools/specialist_training/

The specialist-training pipeline. Produces a fine-tuned Qwen 3 1.7B note-merging specialist that ships into the demo as a single merged `.cact` blob via a feature-flag swap in [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart).

This directory implements the plan at [`_docs/plans/002-feat-specialist-training.md`](../../_docs/plans/002-feat-specialist-training.md), itself derived from the opinionated recipe synthesis at [`_docs/research-training/recipe.md`](../../_docs/research-training/recipe.md).

The pipeline is **author-once, run-locally**: every script here is portable Python or Bash that you run with API credentials and (for training) an Oxen.ai notebook. No agent runs the training; the deliverable is the artifact a developer takes to Oxen.

## Why a specialist?

Stage 0 + Stage 1 of the demo ship with a generalist Qwen 3 1.7B that drifts into Chinese under bilingual training-distribution leakage, collapses format at `n≥3` flashcards, and occasionally rationalizes around grounding instructions. The writeup's specialists thread argues that the destination is a *fine-tuned* small model per domain, not a generalist hoping for the best. This pipeline operationalizes that thread for the note-merging task (audience-submitted study notes → consolidated merged note).

## Day-0 / Day-1 / Day-2 build path

Mirrors the recipe's weekend build path. Total budget: ~13 hours focused work, ~$5 all-in.

### Day 0 — prep (~1 hour)

1. Sign up for [oxen.ai](https://www.oxen.ai) (Free Explorer tier — 50 GB storage/transfer, unlimited public repos).
2. Verify access to a Qwen 2.5-72B-Instruct endpoint. Recommended: Together AI (set `TOGETHER_API_KEY` in repo `.env`). Alternatives: Fireworks, self-hosted A100, OpenAI-compatible gateway.
3. Verify Anthropic API access for the cross-family judge LLM (set `ANTHROPIC_API_KEY`).
4. `pip install -r tools/specialist_training/requirements.txt` in a fresh venv.
5. Hand-author the load-bearing **20-pair seed eval set** (manual; see [U3 in the plan](../../_docs/plans/002-feat-specialist-training.md)).

### Day 1 — data + train (~6 hours)

1. **Synthetic data generation** (~2 hours): `just specialist-generate` → 2,000 candidate Magpie-style pairs from the Qwen-72B teacher.
2. **Filter** (~30 min): `just specialist-filter` → ~1,500 clean training pairs via cosine-dedup + judge-LLM completeness + length cap + stratification.
3. **Manual holdout expansion** (~1 hour, manual): hand-author 180 more pairs from disjoint topic regions (biology / chemistry / earth science — DIFFERENT from the demo's inner/outer planet seed corpora).
4. **Training** (~45 min on Oxen A10G): upload `train.py` + `train_config.yaml` + `synthetic_filtered.jsonl` to an Oxen repo branch; run via Marimo notebook; `oxen pull` the adapter back locally.
5. **Smoke test** (~15 min): inference on the 20-pair seed eval with the in-training (bf16, pre-quant) merged model. Gate: ≥15-point judge-accuracy uplift vs base. If lower, debug data before the full 1,500 run.

### Day 2 — deploy + eval (~6 hours)

1. **Deploy** (~1 hour): `just specialist-convert` → `cactus convert --lora` merges + Q4-quantizes to `.cact`. `cactus build --apple` and `cactus build --android` produce per-platform artifacts.
2. **Integration** (~1 hour): flip `USE_SPECIALIST=true` via `just app-run-a-specialist <device-id>`. The flag is wired through [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart) (see U7 in the plan).
3. **R2 parity check** (~30 min): re-run the existing determinism harness at [`tools/determinism_harness/`](../determinism_harness/) against the new `.cact` on both phones.
4. **Eval** (~3 hours): `just specialist-eval` → three-layer A/B table (deterministic assertions → cross-family judge → embedding cosine) on the 200-pair holdout.
5. **Decision gate** (~30 min): specialist judge-accuracy uplift ≥10 points over base? Ship. <10? Add training data, re-iterate; or shelve as v1 future-work.

## Justfile recipes

| Recipe | What it does |
|--------|--------------|
| `just specialist-generate` | Magpie-style synthetic data generation against the Qwen-72B teacher endpoint |
| `just specialist-filter` | Cosine-dedup + judge-LLM filter + length cap + stratification |
| `just specialist-train` | Stage the training artifacts for upload to Oxen.ai (run training in the Oxen Marimo notebook, then `oxen pull` the adapter) |
| `just specialist-eval` | Three-layer eval against the 200-pair holdout — produces `eval_results/summary.md` |
| `just specialist-convert` | `cactus convert --lora` merge + Q4 quantization + per-platform build |
| `just app-run-a-specialist DEVICE` | Run the demo with `USE_SPECIALIST=true` — loads the merged `.cact` |

## Holdout discipline (load-bearing)

The 200-pair holdout at `data/holdout_200.jsonl` is the only data committed in this tree. It is:

- **Hand-authored**, not synthetically generated. Synthetic eval + synthetic training data + same teacher = memorization theatre (per the Preference Leakage paper).
- **Disjoint** from the demo's seed corpora (astronomy → inner/outer planets) AND disjoint from the training data's topic distribution (Magpie pulls topics at random from the Qwen-72B teacher's distribution).
- **Cross-family judged.** The judge LLM is Claude 3.5 Sonnet (Anthropic) — NEVER Qwen-as-judge (self-enhancement bias). Run bidirectional (swap A↔B input order, average scores) to control position bias.
- **Calibrated** against a human-on-100-examples spot-check before being trusted on the full 200 (Hamel Husain's recipe).

## Ship/no-ship gate

Per recipe section (f):

- Specialist judge-accuracy uplift ≥10 points over the same-base generalist → ship. Recorded demo uses the specialist.
- Uplift <10 points → don't ship the specialist for v1. The eval table still goes into the writeup as a documented "specialist isn't earning its keep" case.
- R2 cross-platform parity (top-k order match ≥95% iOS vs Android) → required to ship. Failure becomes a writeup paragraph on LoRA-delta + Q4-quant FP divergence; demo ships generalist while specialist becomes future-work.

## License posture

End-to-end Apache-2.0:

- Base: Qwen 3 1.7B (Apache-2.0)
- Teacher (synthetic data): Qwen 2.5-72B-Instruct (Apache-2.0) — outputs inherit
- Trainer: Unsloth core (Apache-2.0)
- Eval harness: deepeval (Apache-2.0) + RAGAS (Apache-2.0)
- Final merged `.cact` redistributable in the public repo with NOTICE + statement of modifications

Cactus runtime is source-available with a $2M-revenue gate — fine for the hackathon repo, disclosed in NOTICE.

## What's gitignored vs committed

```
tools/specialist_training/
├── README.md                  # committed
├── requirements.txt           # committed
├── generate_synthetic.py      # committed
├── filter_synthetic.py        # committed
├── train.py                   # committed
├── train_config.yaml          # committed
├── eval.py                    # committed
├── convert.sh                 # committed
├── configs/                   # committed (prompt templates, judge rubrics)
│   └── magpie_prompt_template.txt
├── data/                      # everything EXCEPT holdout_200.jsonl is gitignored
│   ├── .gitignore
│   └── holdout_200.jsonl      # COMMITTED — the load-bearing eval anchor
├── eval_results/              # everything EXCEPT summary.md is gitignored
│   ├── .gitignore
│   └── summary.md             # produced by eval.py; committed for writeup citation
└── adapter/                   # gitignored — pulled from Oxen post-training
```

The merged `.cact` artifact lands at `assets/models/qwen3-1.7-merger.cact` (gitignored — ~1.0-1.5 GB at Q4).
