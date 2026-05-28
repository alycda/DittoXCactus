# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter hackathon demo pursuing the **"Mesh RAG"** framing of Ditto × Cactus. Two phones each hold a slice of a study-notes corpus; they meet over BLE/Wi-Fi and the vector index merges as a CRDT, so a query on phone A draws on phone B's notes after handshake — with WAN off. Stage 0 (CRDT vector sync + retrieval) + most of Stage 1 (streaming flashcard generation) are implemented; R1 + R3 + R4 + R7 holdouts cleared live on a Pixel pair 2026-05-26. See [README.md](README.md) and [SEED.md](_docs/SEED.md) for the thesis. Other framings (B/C/D) live in [docs/c4/model.c4](docs/c4/model.c4) and the brainstorm at [README](README.md); only A is implemented.

The order of authorship — and the validation chain — is: parent brainstorm (`README.md`) → idea doc (`_docs/IDEA-A.md`) → seed (`_docs/SEED.md`) → research brief + 6 deep-research passes + 281-source index (`_docs/research/`) → implementation plan (`_docs/plans/001-feat-mesh-rag-demo.md`) → C4 architecture model (`docs/c4/`) → implementation (`lib/`, `test/`, `tools/`). Each layer cites the substrate beneath it: the plan cites the research index by per-source ID; the C4 model cites the plan; code references the plan's implementation units (U1–U20) and requirement IDs (R1–R11) in commit messages and inline comments.

## Common tasks here

`just --list` is the full catalogue. The load-bearing ones:

```sh
# Main app — boot two phones with disjoint seed corpora over a clean Ditto state
just wipe-ditto <device-id>             # surgical wipe (keeps Cactus model cache)
just app-run-a-demo <device-id>         # PHONE_ROLE=a + DEMO_OVERLAY HUD
just app-run-b-demo <device-id>         # PHONE_ROLE=b
just app-test                           # flutter test (unit + widget; 185+ tests)
just app-analyze                        # flutter analyze
just ci                                 # both

# Holdouts
just holdout-34-test                    # pure-Dart R3+R4 verdict math
just holdout-34 <device-a> <device-b>   # live R3/R4/R7 walkthrough w/ sign-off
just harness-test                       # U1/U13 determinism math (pure-Dart)
just harness-measure <device>           # on-device R2 measure
just harness-check-baseline <baseline-json> <device-json>

# Architecture / observability
just c4-model                           # prebuilt Likec4 dashboard at :8000
just understand                         # local knowledge-graph dashboard

# Specialist training pipeline (future-work, opt-in — see plan 002)
just app-run-a-specialist <device-id>   # boot demo with USE_SPECIALIST=true
just specialist-generate                # Magpie synthetic data from Qwen-72B teacher
just specialist-filter                  # dedup + judge-LLM completeness + stratify
just specialist-train                   # verify Oxen.ai upload bundle (training runs remote)
just specialist-eval                    # three-layer A/B harness → eval_results/summary.md
just specialist-convert                 # cactus convert --lora → assets/models/*.cact
```

The Likec4 dashboard at `docs/c4/dashboard/` is a build artifact (gitignored). Regenerate with `npx likec4@latest build docs/c4 -o docs/c4/dashboard`; validate with `npx @likec4/cli validate docs/c4/model.c4`. The knowledge-graph dashboard is published to GitHub Pages — see "Knowledge-graph dashboard" below.

Version control is **jj-first** (this is a colocated jj+git repo: both `.jj/` and `.git/` exist). The repo-local memory entries on jj are load-bearing — never `jj edit <ancestor>`, use the `jj new --insert-after/before` + `jj restore --from @ --to <new>` pattern for retroactive edits. Plain `git` commands are safe for read operations (`git log`, `git status`) but mutations should go through jj. See user memory `feedback_jj_*` entries.

## Flutter agent tooling (strongly recommended)

When working on Flutter code in this repo, agents should reach for Flutter's first-party AI tooling before improvising:

- **Flutter MCP server** — [docs.flutter.dev/ai/mcp-server](https://docs.flutter.dev/ai/mcp-server). Gives agents a structured surface over `pub`, `flutter`, and `dart` toolchain operations (package search, version resolution, project diagnostics, widget tree inspection). Strongly preferred over scraping `flutter --help` or guessing package versions. Install per the Flutter docs; once configured, the MCP tools surface in `/mcp`.
- **Flutter skills** — [github.com/flutter/skills](https://github.com/flutter/skills). Curated, task-shaped agent skills authored by the Flutter team (widget tests, integration tests, layout fixes, localization, responsive layouts, etc.). Several of these are already loaded in this session under `flutter-*` skill names. When the task matches a published Flutter skill, invoke it via the harness rather than reinventing the recipe. Treat the upstream repo as canonical — the loaded skills track what's there.

Both are Flutter-team-authored and version-aware; agents that bypass them and improvise Flutter recipes tend to drift from current best practice fast (Flutter releases are fast-moving). When a task is Flutter-shaped, **check these first.**

## Code architecture

The app boots in [lib/main.dart](lib/main.dart) (`BootScreen._boot`) and brings up four singletons in this order:

1. **`DittoService`** ([lib/services/ditto_service.dart](lib/services/ditto_service.dart)) — wraps Ditto v5 with `DittoConfigConnectSmallPeersOnly` + offline-only license; transports = BLE + LAN + AWDL (iOS/macOS only — Wi-Fi Aware deliberately off on Android, per `feedback_ditto_release_mode_bug` user memory + comment at the top of the file). Exposes a `peerCount` stream and `subscribeToNotes(...)` observer for live UI updates.
2. **`SeedLoader`** ([lib/services/seed_loader.dart](lib/services/seed_loader.dart)) — parses `assets/seed_notes_<role>.json` (5 notes per role, disjoint topics — inner planets vs outer planets) and upserts to Ditto. Per-note idempotent via UUIDv5 content-addressed `_id` + `ON ID CONFLICT DO UPDATE`. **Does not delete** — cross-role boots accumulate state silently, so always `just wipe-ditto` before holdouts. See user memory `project_seed_loader_no_delete`.
3. **`CactusService`** ([lib/services/cactus_service.dart](lib/services/cactus_service.dart)) — loads two Qwen models via the Cactus plugin (`qwen3-0.6-embed` for embeddings — the *dedicated* similarity-tuned slug, swapped from chat-tuned `qwen3-0.6` per issue #9 on 2026-05-26; `qwen3-1.7` for completion). Pins `CactusConfig.isTelemetryEnabled = false` BEFORE any model-download HTTP fires. Stop sequences (`\boxed`, `\begin{aligned}`, `\text{`) applied to every completion call — see `_kDefaultStopSequences` and [_docs/notes/cactus-sdk-quirks.md](_docs/notes/cactus-sdk-quirks.md) for the Supabase model-registry leak this works around.
4. **`RetrievalService`** ([lib/services/retrieval_service.dart](lib/services/retrieval_service.dart)) — the hot path. `topK(topic)` title-cases the query (proper-noun embedder is case-sensitive), embeds via Cactus, brute-force cosine over the materialized notes set, applies `defaultMinScore=0.3` threshold + `filterByEntityMention` entity-overlap gate, returns ordered `RetrievedNote`s. `generateFlashcards(...)` chains topK → grounding gate (empty retrieved → skip LLM) → prompt → streaming Cactus completion → `FlashcardGenPrompt.parse` → `cleanCards` (on-topic + reasoning-leak + answer-length + drop-uncited + dedupe + cap at N). `defaultK=10` covers the full Stage-0 merged corpus so the entity filter sees every candidate.

The UI is in [lib/widgets/](lib/widgets/): `QueryScreen` owns the two-tab Scaffold (Flashcards + Notes), `FlashcardsTab` renders the streaming card stack with tap-to-flip + Jeopardy mode (XOR'd with flip state), `NotesTab` groups notes by contributor with peer/self split, `MeshStatusWidget` is the green/gray "mesh: alone / 1 peer" pill, `DemoOverlay` is the top-right HUD when `DEMO_OVERLAY=true`.

The holdouts are pure-Dart math + a thin runner:

- [lib/holdouts/idempotence_check.dart](lib/holdouts/idempotence_check.dart) — `detectConvergence` (R4) + `detectIdempotence` (R3). Verdict JSON via `IdempotenceCheck.buildReport`.
- [lib/holdouts/cold_load_timer.dart](lib/holdouts/cold_load_timer.dart) — R5 cold-load instrument (phase markers + JSON report).
- [tools/holdout_34/](tools/holdout_34/) — adb-driven `runner.sh` + `verdict.dart` CLI.
- [tools/holdout_7/offline_witness.md](tools/holdout_7/offline_witness.md) — R7 pre-recording checklist (NEVER CUT).
- [tools/determinism_harness/](tools/determinism_harness/) — standalone Flutter package for U1 (cross-platform R2 gate) + U13 (regression). Has its own pubspec; never depends on the main app.

**Small-model quirks the pipeline absorbs** — every load-bearing service is wrapped in tests that pin a real failure mode. Before changing prompts, sampling params, or the parser, read [_docs/notes/model-quirks.md](_docs/notes/model-quirks.md) (Qwen 2.5 1.7B behaviors: bilingual `<think>` drift, `\boxed{}` math-mode, `<think>`-despite-ban, verbose-answer budget exhaustion, off-topic padding, SOURCE omission under tight budgets, format-collapse-to-prose at n≥3) and [_docs/notes/cactus-sdk-quirks.md](_docs/notes/cactus-sdk-quirks.md) (Cactus 1.3.0 SDK seams: `Supabase.getModel` fires regardless of telemetry flag, UTF-8 boundary errors on Chinese drift). Per user memory `feedback_structural_gates`: gate on inputs at the service layer (cosine threshold, grounding gate, title-case normalization, stop sequences), not on outputs at the stream.

## Specialist training (future-work, opt-in)

The writeup's specialists thread (`project_writeup_thesis_arc`, `project_specialist_small_models_thesis` user memories) ships as a buildable artifact at [tools/specialist_training/](tools/specialist_training/), separate from the demo's Stage 0/1 hot path. **Disabled by default** — `USE_SPECIALIST=false` is the documented default, and the Stage 0/1 demo runs with the generalist `qwen3-1.7` base unchanged.

The pipeline implements [_docs/plans/002-feat-specialist-training.md](_docs/plans/002-feat-specialist-training.md) — itself derived from the opinionated synthesis at [_docs/research-training/recipe.md](_docs/research-training/recipe.md). Day-0/1/2 build path + holdout discipline are in [tools/specialist_training/README.md](tools/specialist_training/README.md). The 85-row eval holdout at [tools/specialist_training/data/holdout_200.jsonl](tools/specialist_training/data/holdout_200.jsonl) is derived from [ad-si/Rust-Flashcards](https://github.com/ad-si/Rust-Flashcards) (cloned to `_inspiration/ad-si/`, gitignored) and is **set-coverage verifiable** — each row's `source_cards_a / source_cards_b` are greppable in the source `cards.md` to confirm every fact lands in `merged`.

Load-bearing constraints (carried verbatim from the recipe — *do not change without re-reading research-training/index/open-questions.md*):

- **Cactus 1.3.0 does NOT support runtime LoRA adapter loading.** The only deploy path is `cactus convert <base> <out> --lora <adapter>` producing a merged `.cact` blob. Cactus v1 (Dec 2025) moved off GGUF and stopped wrapping llama.cpp. `lib/services/cactus_service.dart` stages the bundled `.cact` from the Flutter asset bundle into `<documents>/models/<slug>/<slug>.cact` so Cactus's `initializeModel` finds it locally without a download. (Apple Foundation Models + MediaPipe LLM DO support runtime LoRA — Cactus is structurally behind, which is the writeup's specialists-thread framing.)
- **License posture is Apache-2.0 end-to-end.** Base (Qwen 3 1.7B), teacher (Qwen 2.5-72B-Instruct via Together AI), trainer (Unsloth), eval harness (deepeval + RAGAS), holdout corpus (Rust-Flashcards MIT). Cactus runtime is source-available with a $2M revenue gate — disclosed in the `.cact` NOTICE produced by `convert.sh`.
- **Cross-family judge is mandatory.** Eval at `tools/specialist_training/eval.py` uses Claude 3.5 Sonnet as the judge — NEVER Qwen-as-judge (self-enhancement bias). Bidirectional ordering + verbosity-penalty rubric.
- **`assets/models/*.cact` is gitignored.** The merged blob is ~1.0–1.5 GB at Q4; built by `convert.sh`, never committed. A README placeholder lives in `assets/models/` so the `pubspec.yaml` asset-directory declaration succeeds in fresh checkouts.

Actually running the pipeline needs `TOGETHER_API_KEY` + `ANTHROPIC_API_KEY` + Oxen.ai signup + the `cactus` CLI + ~$5 spend + an A10G GPU. The code lives in `tools/specialist_training/` and is wired through the justfile; runtime is the user's call.

## Knowledge-graph dashboard

The repo ships an interactive knowledge graph at [.understand-anything/knowledge-graph.json](.understand-anything/knowledge-graph.json) — 202 nodes, 246 edges, 10 architectural layers, 12-step guided tour. Published to **[alycda.github.io/DittoXCactus](https://alycda.github.io/DittoXCactus/)** via [.github/workflows/pages.yml](.github/workflows/pages.yml) on every change to the graph JSON.

Refresh the graph: run `/understand` inside Claude Code (uses the Understand-Anything plugin), commit the diff at `.understand-anything/knowledge-graph.json`, push. The workflow auto-deploys. Local dashboard with source-preview unlocked: `just understand`.

## Architecture of the documentation set

```
README.md                          # parent brainstorm: framings A/B/C/D, A chosen
_docs/
  IDEA-A.md                        # the thesis: "Your knowledge base wants to be a CRDT"
  SEED.md                          # validation harness, holdouts 1–8, cut order, threat-model bound
  WEB-PROMPT.md                    # prompt used to drive the hosted deep-research passes
  RESEARCH-BRIEF.md                # task list handed to deep-research workers
  plans/001-feat-mesh-rag-demo.md          # Stage 0/1 demo plan; cites research/index/ by per-source ID
  plans/002-feat-specialist-training.md    # specialists future-work arc; cites research-training/recipe.md
  RESEARCH-BRIEF-training.md               # brief handed to the small-model post-training research pass
  WEB-PROMPT-training.md                   # hosted-DR prompt for the same brief
  research/
    {claude,codex,gemini}.md                        # 3 Mode-B web-research worker outputs (Stage 0/1)
    {claude,chatgpt,gemini}-deep-research.md        # 3 hosted Deep Research passes (Stage 0/1)
    downloads.yaml                                  # canonical manifest of downloaded materials
    index/                                          # Reduce-phase synthesis of the above
      README.md                                     # entry point for downstream agents
      top-N.md                                      # 22 ranked must-reads
      clusters.md by-topic.md by-tag.md
      cross-references.md open-questions.md
      _per_source/                                  # 281 per-source summaries (gitignored bulk; only .gitignore is tracked)
  research-training/                                # parallel research pass for the specialists thread (plan 002)
    {theory,tooling,industry}.md                    # 3 Claude-only inline worker outputs
    {claude,chatgpt,gemini}-deep-research.md        # 3 hosted Deep Research passes
    downloads.yaml                                  # 258-URL manifest
    recipe.md                                       # opinionated end-to-end specialist build recipe
    index/                                          # Reduce-phase synthesis (top-N, clusters, open-questions)
docs/c4/
  interview.md                                      # Step 0 of c4-design skill
  model.c4                                          # Likec4 DSL — source of truth for the architecture diagrams
  dashboard/                                        # build output (gitignored)
_inspiration/                                       # locally-cloned papers/repos referenced by the index; gitignored except .gitignore (everything is excluded)
slides/                                             # planned home for the deck; only `media/` exists today
```

**The C4 model encodes the system the implementation built.** Containers in `docs/c4/model.c4` (`phone_app`, `cactus_models`, `ditto_store`, `determinism_harness`) reference real files under `lib/`, `tools/`, `assets/`. When editing the C4 model, edit `docs/c4/model.c4` and rebuild the dashboard — never hand-edit `docs/c4/dashboard/`. For day-to-day code orientation, the knowledge-graph dashboard (see below) is faster — it's auto-generated from the source.

## Thesis-bearing constraints (carry across edits)

These pin the writeup's argument and the demo's scope; an edit that contradicts them likely needs the user to make the call, not Claude.

- **The cloud is not in the trust boundary.** No Cactus hybrid mode, no remote vector store, no internet path during the demo. Plan §Scope Boundaries calls this out as the thesis-breaking line.
- **iOS + Android both required** (Holdout R10). iOS + macOS does not satisfy the mobile-edge claim.
- **Holdout 7 (end-to-end offline) is never cut** under any forcing function. Every other holdout has a defined cut order in SEED.md.
- **Determinism (Holdout 2) is the pre-flight gate.** If the cross-platform cosine-parity test fails, the project pivots to brainstorm option C ("Narrate the mesh") rather than weakening the thesis.
- **Stage 1 corpus theme is audience-submitted study notes**, not recipes — recipe-merge was tried previously and didn't survive stress-testing; the clean-history plan adopts study notes from the start (see user memory `project_stage1_corpus_study_notes`).
- **The writeup's arc is specialists, not generalists.** Stage 0 (generalist small LLM + flat grow-only union) is the stepping stone; the writeup closes on a four-thread future-work arc — *specialists, preference-aware merge, adversarial filtering, generational evolution.* See user memory `project_writeup_thesis_arc` and `_docs/research/index/open-questions.md`.

## How to navigate the research index

Per `_docs/research/index/README.md`: start at `top-N.md` (22 sources, ~45 min), then branch by intent — building the demo = clusters C3 (Ditto) + C5 (Cactus + LLM) + C9 (vector search); writing the post = C1 (case for on-device) + C6 (determinism) + C7 (specialists), then `open-questions.md`. Per-source files at `_per_source/<id>.md` are catalog entries; for paper-level content prefer the worker outputs (`claude.md`/`codex.md`/`gemini.md`) which actually read the abstracts. The 281 per-source files are gitignored bulk — only `_per_source/.gitignore` is tracked.

## Editing conventions

- **Plan, SEED, README cross-link by relative path.** Keep them resolvable when reorganizing files.
- **The plan cites research by per-source ID** (e.g. `paper-2509.20354`, `article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference`). New citations should resolve to a real entry under `_per_source/`.
- **Holdout numbering (R1–R11) is shared vocabulary** across SEED, plan, and C4 interview. Don't renumber.
- **Stage 0 vs Stage 1** is shared vocabulary too. Stage 0 = CRDT vector sync + retrieval (no LLM generation); Stage 1 = adds buffered/streaming flashcard generation. Stage 2 (arbitrary file ingestion) is an explicit non-goal.
