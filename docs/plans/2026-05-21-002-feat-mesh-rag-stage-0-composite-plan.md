---
title: "feat: Mesh RAG Stage 0 — composite plan (ce-plan structure × sprint-planner findings)"
type: feat
status: active
date: 2026-05-21
origin: SEED.md
---

# Mesh RAG Stage 0 — Composite Implementation Plan

## Summary

Stage 0 ships as a Flutter dual-target app (iOS + Android) with Cactus held narrow to on-device embedding + small-LLM inference and Ditto carrying the full grow-only-CRDT sync + storage. Two early spikes — cross-platform embedding parity and recipe-merge LLM quality — run before the main pipeline so a corpus-or-fallback decision is in hand by mid-Day-1. Retrieval is brute-force cosine top-k over a flat float32 array; the demo's moment of magic is airplane mode toggled live on camera, with phone A's answer visibly changing after phone B comes into BLE range.

**This is the composite of two parallel planning passes** (see Sources). Sibling A (`ce-plan`) supplied the per-unit structure with test scenarios; sibling B (`sprint-planner`, multi-model with cross-critique) supplied tighter findings on specific decisions. The composite preserves the ce-plan unit shape and injects sibling B's sharpened decisions inline.

---

## What's different in this composite (vs. sibling A)

These are the substantive upgrades sibling B's multi-model + cross-critique pass surfaced that this composite folds in:

1. **Embedding-model ordering reversed.** Qwen3-Embedding-0.6B primary (Cactus confirmed-packaged, Apache-2.0), EmbeddingGemma 300M as alternate. Two of three sprint-planner drafters converged on Qwen3.
2. **Quantization format pinned to Q4_K_M explicitly** (was generic "INT4/Q4"). Catches Q4_0 vs Q4_K_M silent drift.
3. **Deterministic content-derived tuple IDs** (`sha256(corpus + title + text)`) baked into U4. Load-bearing for H3 — sibling A had "idempotent first-run seeding" as a verbal goal but no ID-derivation rule.
4. **Top-k tie-breaking deterministic** (score desc, then `_id` asc) baked into U5. Prevents H3 top-k drift on score ties.
5. **L2-normalize at insertion** (dot product at query) — explicit convention, was implicit in sibling A.
6. **In-app H2 re-run** added (U9): production-app build, not just spike CLI. Catches CLI-vs-app backend or batch drift.
7. **Honest-failure rule on Gate A**: if all Cactus embedding candidates miss cosine ≥ 0.999, switch the demo to a non-claiming fallback rather than softening the threshold. Sibling A's "accept ≥ 0.99 borderline" softening dropped.
8. **Adversarial Gate-B fixtures specified** (missing quantities, conflicting optionals, substitutions, duplicate steps, polarizing ingredients) + **8/10 pass threshold** + **slowest-device requirement** + **prompt template pinned BEFORE judging**.
9. **Code-path-level no-server invariant** (U7): compile-time guard or unit test that no app code path can reach the network. Inspectable, not just airplane-mode-dependent.
10. **One-tap reset + one-tap re-seed** debug-menu actions in U8 for demo-day recovery.
11. **B-roll backup recording + second hardware pair + single-take H1 final** as committed artifact gates in U9.
12. **H5 remediation playbook** (ordered 4 steps) in U9 — no soft-pass back-door on the 10s bar.
13. **Risk table grows by 3**: R11 quantization-format drift, R12 in-app re-run drift vs spike result, R13 Cactus Flutter-package version-skew (vs native Swift + Kotlin escape hatch).
14. **Hour-level Saturday/Sunday timeline preserved** by reference to [docs/sprints/SPRINT-0001.md](../sprints/SPRINT-0001.md) §5 (Sequencing). The composite's dependency graph maps onto that clock.
15. **`Tuple` corpus-neutral document name** (was `RecipeTuple`); corpus theme is hot-swappable in `metadata.corpus` not in the type name.

---

## Problem Frame

Pain and motivation live in [SEED.md](../../SEED.md) ("Why This Exists"). In one line: today every RAG architecture assumes a central vector store; an existence-proof of a peer-to-peer RAG where the index *is* a CRDT collapses that assumption and gives Ditto + Cactus a concrete shared story. The plan honors the SEED.md thesis (latency + offline-first, not cost) and the future-work arc in [docs/research/index/open-questions.md](../research/index/open-questions.md) (Stage 0 ships generalist + flat union; specialists / preference-aware / adversarial filtering / generational drift are writeup-only).

---

## Requirements

Traced to SEED.md's Holdout Scenarios. Each R-ID is a SEED.md holdout we must pass (or explicitly defer if Stage 1+).

- **R1.** Airplane-mode moment of magic on camera. *(SEED Holdout 1.)*
- **R2.** Cross-platform embedding cosine ≥ 0.999 on ≥ 20 fixtures with matching vector dimensions. *(SEED Holdout 2; load-bearing.)*
- **R3.** Sync idempotence — zero duplicate tuples, zero top-k drift on re-meet with no changes. *(SEED Holdout 3.)*
- **R4.** Bidirectional merge observable through queries; source-device metadata preserved through sync. *(SEED Holdout 4.)*
- **R5.** Cold-load to first answer < ~10s on the slowest target device. Hard bar; no soft-pass. *(SEED Holdout 5.)*
- **R6.** End-to-end offline — Wi-Fi off, cellular off, only BLE/LAN. Inspectable invariant: no code path can call a server. *(SEED Holdout 7.)*
- **R7.** Stage 0 ship criterion: R1 + R2 + R3 + R4 + R5 + R6 all pass on the chosen hardware in a single recorded take.
- **R8.** Audience-survivable Stage 1 query (Holdout 6) — pass ≥ 3 of 5 audience-picked queries on ~50 notes/device.

---

## Scope Boundaries

- No production UI polish, settings panels, persistent chat history, streaming token output.
- No cloud fallback / Cactus hybrid mode. Excluded by thesis.
- No HNSW, IVF, PQ, or any ANN index. Flat float32 array is the Stage 0 answer.
- No retrieval reranking, query rewriting, multi-hop retrieval, fancy chunking.
- No code addressing the future-work arc (specialists / preference-aware merge / adversarial filtering / generational evolution). All writeup-only.

### Deferred to Follow-Up Work

- Stage 1 audience-participation submission UI (corpus grows from ~5 to ~50/device; audience picks queries) — natural follow-up once Stage 0 ships.
- Stage 2 real-corpus integration (notes app, PDF library) — Sunday-only if Stages 0–1 ship.
- iOS background BLE for "always-on" mesh — environmental constraint, not solvable at user-app scope.

---

## Context & Research

### Relevant Code and Patterns

Greenfield Flutter project — no in-repo patterns. External reference architectures from [docs/research/index/top-N.md](../research/index/top-N.md):

- [`inspiration/repos/getditto__demoapp-pos-kds/`](../../inspiration/repos/getditto__demoapp-pos-kds/) and [`inspiration/repos/getditto__demoapp-inventory/`](../../inspiration/repos/getditto__demoapp-inventory/) — Ditto's official cross-platform demo apps. Mirror peer-discovery UX and mesh-state visualization.
- [`inspiration/repos/permissionlesstech__bitchat/`](../../inspiration/repos/permissionlesstech__bitchat/) and [`inspiration/repos/permissionlesstech__bitchat-android/`](../../inspiration/repos/permissionlesstech__bitchat-android/) — current cross-platform BLE-mesh reference.
- [`inspiration/repos/deepsense-ai__edge-slm/`](../../inspiration/repos/deepsense-ai__edge-slm/) — Android on-device RAG pipeline pattern.
- [`inspiration/repos/ramanujammv1988__edge-veda/`](../../inspiration/repos/ramanujammv1988__edge-veda/) — Flutter managed on-device AI runtime. Closest Flutter-side reference; copy the source-attribution UX.
- [`inspiration/repos/software-mansion-labs__react-native-rag/`](../../inspiration/repos/software-mansion-labs__react-native-rag/) — modular embeddings / vector-store / LLM seam shapes.

### Institutional Learnings

No `docs/solutions/` (greenfield). Project-specific decisions captured in [SEED.md](../../SEED.md), [docs/research/index/clusters.md](../research/index/clusters.md), [docs/research/future-work-research.md](../research/future-work-research.md).

### External References

- [docs/research/index/top-N.md](../research/index/top-N.md) — 12 ranked must-read sources.
- [docs/research/claude.md](../research/claude.md) — highest-signal Mode-B worker output.
- [Thinking Machines Lab — "Defeating Nondeterminism in LLM Inference"](https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/) — load-bearing for U2.
- [Cactus engine docs](https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md) — explicit: no determinism guarantees.
- [Ditto SDK docs](https://docs.ditto.live/).

---

## Key Technical Decisions

- **Flutter dual-target as primary platform** with native Swift + Kotlin as the escape hatch if the Cactus Flutter package proves unstable. Per [IDEA-A.md](../../IDEA-A.md) Flutter overlap is the cheapest entry point — but Cactus Flutter-package version-skew is a real risk (sibling B R9, generalized). U1.5 spike at scaffold time validates the Flutter Cactus package; native is the U1.5-failure escape.

- **Cactus narrow (embed + LLM only); Ditto owns persistence; we own retrieval.** Don't use `cactus_rag_query` or `cactus_index_*` — Cactus's vector index would want to own its own storage and fight Ditto's CRDT-merged tuple set. Use `cactus_embed` + `cactus_complete` only; run our own cosine top-k over the Ditto-materialized result.

- **Brute-force cosine over a flat float32 array.** At ≤5k tuples × ≤500 dims, exact-recall is sub-millisecond, CRDT-trivial, sidesteps HNSW-under-concurrent-replica-insert correctness. USearch / sqlite-vec are documented escape hatches if we cross 10k tuples — not in Stage 0.

- **Embedding model: Qwen3-Embedding-0.6B primary** (Apache-2.0, Cactus-confirmed-packaged), EmbeddingGemma 300M alternate, Nomic Embed v1.5 second-alternate, all-MiniLM-L6-v2 ONNX as deterministic floor only if no Cactus-packaged model clears parity. Final lock at U2 output.

- **Small LLM: Qwen 2.5 1.5B Instruct primary** (Apache-2.0, cleanest license, Cactus-packaged), SmolLM2 1.7B Apache-2.0 backup, Gemma 3 1B IT quality-reach if 1.5B class fails U3. Final lock at U3 output. **Avoid Llama 3.2** — Community License's "Built with Llama" attribution + naming requirements add public-repo friction.

- **Quantization: Q4_K_M on both phones, same backend tier.** Sibling B catch: pinning generic "INT4" isn't enough — Q4_K_M and Q4_0 are both INT4 but produce different vectors. Pin Q4_K_M explicitly in `pubspec.yaml` and the model-fetch script. Pin CPU backend on both devices in Stage 0 to avoid ANE / Hexagon vendor-path drift.

- **L2-normalize at insertion.** Embeddings are L2-normalized when written to Ditto; query-time retrieval is dot product (= cosine on unit vectors). Single convention prevents iOS/Android divergence.

- **Deterministic tuple IDs:** `_id = sha256(corpus + title + text)`. Re-running seed loader across reinstalls is a no-op. Load-bearing for H3 (sibling B catch, sibling A missed).

- **Top-k tie-breaking:** sort by `(score desc, _id asc)`. Prevents H3 top-k drift on score ties (sibling B catch).

- **Spike-first sequencing.** U2 (determinism) + U3 (LLM merge eval) run before the main pipeline so we have hard go/no-go data by mid-Day-1. Hour-level timeline in [docs/sprints/SPRINT-0001.md §5](../sprints/SPRINT-0001.md).

- **Honest-failure rule.** If all Cactus embedding candidates miss cosine ≥ 0.999 in U2, switch the demo to a non-claiming fallback (e.g., brainstorm option C "Narrate the mesh"). The deck does not claim parity if parity didn't pass.

- **Test posture: integration-shaped.** Per-unit "Verification" outcomes describe what an implementer checks by hand. SEED.md holdouts are the source of truth. No formal unit-test coverage targets.

---

## Open Questions

### Resolved During Planning

- Platform stack → Flutter dual-target (with native escape hatch via U1.5 spike).
- Cactus integration shape → narrow (embed + LLM), Ditto owns persistence, we own cosine.
- Embedding model → Qwen3-Embedding-0.6B primary (locked after U2 confirms parity).
- LLM → Qwen 2.5 1.5B Instruct primary (locked after U3 clears 8/10).
- Quantization → Q4_K_M explicit; CPU backend both devices.

### Deferred to Implementation

- Exact Cactus + Ditto Flutter package versions and API method names (lock at U1; references conceptual ops, implementer adapts to resolved API).
- DQL syntax for `Tuple` collection (lock at U1).
- Final demo recipe set — chosen just before U9 rehearsal.
- Live airplane-mode toggle vs pre-recorded B-roll — depends on dry-run reliability (SEED.md preference: live).
- BLE peer-discovery timing on the specific hardware — measured in U7 rehearsal; demo pacing set from observed values.

---

## Output Structure

Greenfield Flutter project at the repo root. Directional layout — implementer may adjust:

```
.
├── pubspec.yaml                         # Flutter deps incl. ditto_live, cactus
├── lib/
│   ├── main.dart                        # App entry, init Ditto + Cactus eagerly
│   ├── models/
│   │   └── tuple.dart                   # `Tuple` corpus-neutral data class
│   ├── services/
│   │   ├── ditto_service.dart           # Init, sync, subscriptions, CRUD; deterministic _id
│   │   ├── cactus_service.dart          # embed(), complete(); narrow surface
│   │   └── retrieval_service.dart       # L2-normalize, cosine top-k with deterministic tie-break
│   ├── widgets/
│   │   ├── query_screen.dart            # Query + answer + tuple cards
│   │   ├── mesh_status_widget.dart      # "Connected peers: N" pill + "tuples from peer" counter
│   │   └── debug_menu.dart              # One-tap reset, one-tap re-seed
│   └── prompts/
│       ├── recipe_merge.dart            # Pinned prompt template
│       └── dql_queries.dart             # DQL string constants
├── scripts/
│   ├── determinism_spike.dart           # U2 — embed identical text both phones; dump first-16 + full
│   ├── determinism_compare.dart         # U2 host-side — cosine + L2 + max-abs-diff per fixture
│   ├── recipe_merge_eval.dart           # U3 — feed N variants to candidate LLMs, rank outputs
│   └── no_server_check.dart             # U7 — invariant check
├── assets/
│   ├── seed_recipes_a.json              # 5 chicken-tortilla-soup variants for phone A
│   ├── seed_recipes_b.json              # 5 variants for phone B (overlap on dishes for H4)
│   └── seed_cars_*.json                 # Pre-authored fallback (schema-identical)
├── slides/
│   ├── deck.md                          # Presenterm Markdown
│   └── media/                           # Architecture diagram + before/after stills + B-roll
├── docs/spikes/
│   ├── U2-determinism-results.md
│   ├── U3-recipe-merge-eval.md
│   └── U9-demo-rehearsal.md
└── docs/plans/2026-05-21-002-feat-mesh-rag-stage-0-composite-plan.md   # this file
```

---

## High-Level Technical Design

> *Directional guidance for review, not implementation specification.*

### Demo-flow sequence

```mermaid
sequenceDiagram
    participant A as Phone A (iOS)
    participant B as Phone B (Android)
    participant U as User on camera

    Note over A,B: Both phones in airplane mode (Wi-Fi off, cellular off, BLE on)
    Note over A: Local corpus: 5 Tuples (variant set α)
    Note over B: Local corpus: 5 Tuples (variant set β)

    U->>A: "What's in chicken tortilla soup?"
    A->>A: cactus_embed(query) → 384-dim vector
    A->>A: cosine top-k over local 5 tuples → set α top-3
    A->>A: cactus_complete(prompt + α top-3) → answer X (α ingredients only)
    A-->>U: Renders answer X with provenance labels

    Note over A,B: Phone B moves into BLE range
    A->>B: Ditto BLE handshake
    A->>B: Ditto sync (deterministic IDs prevent dupes) → both have {α ∪ β}
    Note over A: Local corpus now: 10 Tuples (5 with source_device_id = phone B)

    U->>A: Same query repeated
    A->>A: cactus_embed(query)
    A->>A: cosine top-k over local 10 tuples → mixed α+β top-3 (score tie-break by _id)
    A->>A: cactus_complete(prompt + mixed top-3) → answer X+Y (composed)
    A-->>U: Renders answer X+Y; tuples labeled "from phone B"
```

### Dependency graph

```
            ┌──────── U1 Scaffold ────────┐
            │           │      │           │
            │      U1.5 Flutter-Cactus    │
            │      package validation     │
            ▼           ▼                  ▼
        U2 Spike   U3 Spike            U4 Ditto
        (determ)   (LLM eval)          (schema+sync, deterministic IDs)
            │           │                  │
            └──┬────────┘                  │
               ▼                           │
       U5 Retrieval (L2 norm, tie-break) ◄┘
               │
               ▼
       U6 Synthesis (pinned prompt)
               │
               │      ┌── U7 Mesh sync + no-server check ◄── U4
               ▼      ▼
            U8 Demo UI (mesh pill, counter, debug menu)
               │
        ┌──────┴───────┐
        ▼              ▼
   U9 Rehearsal   U10 Slides
   (B-roll, 2nd  (Mermaid arch, latency-floor,
    pair, single   future-work arc)
    take H1)
```

For the **hour-level Saturday/Sunday clock**, see [docs/sprints/SPRINT-0001.md §5 Sequencing](../sprints/SPRINT-0001.md).

---

## Implementation Units

### U1. Flutter scaffold + Cactus + Ditto SDK wiring

**Goal:** Empty-but-runnable Flutter app on both phones with Cactus + Ditto packages resolved, model files downloaded on first launch, placeholder screen confirming both SDKs initialize.

**Requirements:** Prerequisite for all other units.

**Dependencies:** None.

**Files:** Create `pubspec.yaml`, `lib/main.dart`, `lib/services/ditto_service.dart` (stub), `lib/services/cactus_service.dart` (stub); modify `.gitignore` (Flutter standards + model weights); modify `README.md` ("what is this + run instructions" stub).

**Approach:** `flutter create` scaffold. Add Cactus Flutter package + Ditto Flutter package; **pin Q4_K_M model spec** in package config. Eager-init Cactus on app start with progress indicator. Init Ditto with offline-only identity (no big-peer cloud); `sync.start()`.

**Patterns to follow:** `inspiration/repos/getditto__demoapp-inventory` for Ditto init; `inspiration/repos/ramanujammv1988__edge-veda` for Cactus + worker-isolate pattern.

**Test scenarios:**
- *Happy path:* App boots on iOS, "Cactus: ready / Ditto: peers=0" appears within 10s after first-launch model download.
- *Happy path:* App boots on Android, same outcome.
- *Edge case:* Second launch (model cached) → "Cactus: ready" within 2s.

**Verification:** Both phones boot without crash; "Cactus: ready" + "Ditto: peers=1" when in BLE range.

---

### U1.5. Cactus Flutter-package version-skew spike

**Goal:** Validate that the Cactus Flutter package produces equivalent outputs on iOS and Android to the native Cactus Swift + Kotlin packages. If the Flutter wrapper diverges, escape to native.

**Requirements:** Prerequisite for trust in U2's results being attributable to Cactus, not the Flutter wrapper.

**Dependencies:** U1.

**Files:** `scripts/flutter_native_compare.dart` (or equivalent quick check); `docs/spikes/U1.5-flutter-package.md`.

**Approach:** Run a single fixture through Cactus Flutter on both phones AND through Cactus Swift CLI on the iPhone (or Kotlin CLI on the Android); compare vectors. If Flutter-package output matches native-package output to bitwise, proceed. If not, **escape to native**: rebuild U1 with native Swift on iOS + native Kotlin on Android.

**Test scenarios:**
- *Outcome — pass:* Flutter package matches native; proceed.
- *Outcome — fail:* Native escape path triggered; ~2h of rewiring U1.

**Verification:** `docs/spikes/U1.5-flutter-package.md` records the decision.

---

### U2. SPIKE — Cross-platform embedding determinism

**Goal:** Confirm or refute `cactus_embed(text)` produces cosine ≥ 0.999 across iOS and Android using **Qwen3-Embedding-0.6B + Q4_K_M + CPU backend + batch=1**. Load-bearing for R2.

**Requirements:** R2.

**Dependencies:** U1 (or native-escape U1).

**Files:** `scripts/determinism_spike.dart` (on-device); `scripts/determinism_compare.dart` (host-side); `assets/determinism_fixtures.json`; `docs/spikes/U2-determinism-results.md`.

**Approach:**
- **20 fixtures** mixing recipe ingredients, recipe steps, car-service notes, punctuation, numbers, plain ASCII (corpus-neutral so result isn't fragile).
- Pin Cactus Flutter package + Q4_K_M weights + CPU backend explicitly on both phones (no ANE / Hexagon dispatch in Stage 0).
- Force batch=1 per Thinking Machines batch-invariance recipe.
- Dump per-fixture: dim, first-16 components, L2 norm, full vector. Export to JSON, transfer host-side, compare.
- **Candidate ladder:** Qwen3-Embedding-0.6B first → EmbeddingGemma 300M → Nomic Embed v1.5 → all-MiniLM-L6-v2 ONNX (deterministic floor only).

**Execution note:** Measurement spike; throwaway code.

**Test scenarios:**
- *Outcome — pass:* All 20 fixtures cosine ≥ 0.999 → lock embedding + backend config; proceed to U5.
- *Outcome — borderline (0.99 ≤ cosine < 0.999):* Try next candidate. If still borderline, accept and document; do not soften the deck claim.
- *Outcome — fail (all candidates < 0.999):* **Honest-failure path** — surface to user, pivot Stage 0 to brainstorm option C (no determinism dependency). Do not claim parity in deliverables.

**Verification:** `docs/spikes/U2-determinism-results.md` has cosine score per fixture, chosen embedding model, backend config locked in, PASS / FALLBACK / FAIL decision with rationale.

---

### U3. SPIKE — Recipe-merge LLM eval (corpus-choice gate)

**Goal:** Confirm or refute that an off-the-shelf small LLM can coherently synthesize a normalized recipe from heterogeneous variants. Gates corpus choice per [SEED.md Open Questions (Resolved) §1](../../SEED.md).

**Requirements:** R1 (gates whether recipes is the demo corpus).

**Dependencies:** U1.

**Files:** `scripts/recipe_merge_eval.dart`; `assets/eval_recipes_chicken_tortilla.json` + 4 more dishes; `assets/eval_cars_*.json` (cars fallback fixtures **authored in advance**); `lib/prompts/recipe_merge.dart` (pinned starting template); `docs/spikes/U3-recipe-merge-eval.md`.

**Approach:**
- **5 dishes × 3 variants each.** Each variant set has adversarial-but-benign coverage: missing ingredient quantities, conflicting optional ingredients, substitutions, duplicate steps, and polarizing ingredients (e.g., avocado).
- **Pre-author matching cars fallback fixtures** in identical schema before judging recipes (so corpus swap is a fixture swap, not a re-author session).
- **Pin the prompt template** before judging: `Context: {top_k_texts}\nQuestion: {user_query}\nAnswer: synthesize a single coherent recipe; preserve provenance for divergent ingredients.` Variants tested only after corpus decision.
- **Run eval on the slowest target device**, not just the faster phone. Merge quality can degrade on slower-device quantization paths.
- **Candidate ladder:** Qwen 2.5 1.5B Instruct → SmolLM2 1.7B → Gemma 3 1B IT.
- **Pass threshold: 8 of 10 fixtures coherent** per rubric (coherent ingredient list, preserved provenance, readable steps, no invented critical details), within cold-load + answer-time budget.

**Test scenarios:**
- *Outcome — pass:* ≥ 1 candidate clears 8/10 → lock LLM + recipes corpus.
- *Outcome — fail:* Switch corpus to cars; lock the smallest candidate that produces coherent answer-from-context.

**Verification:** `docs/spikes/U3-recipe-merge-eval.md` has per-model per-fixture scores, latency on slowest device, chosen LLM, corpus decision with rationale.

---

### U4. Ditto integration — `Tuple` schema + deterministic IDs + sync subscription

**Goal:** Working Ditto integration storing, querying, and subscribing to `Tuple` documents locally and across the mesh. Idempotent first-run seeding via deterministic content-derived IDs.

**Requirements:** R3, R4, R5, R6.

**Dependencies:** U1.

**Files:** Create `lib/models/tuple.dart` (`Tuple` data class; corpus-neutral name; matches SEED.md / RESEARCH-BRIEF.md inline schema with added `metadata.corpus`); `lib/services/ditto_service.dart`; `lib/prompts/dql_queries.dart`; `assets/seed_recipes_a.json` + `_b.json` (without embeddings — embeddings populated at U5). Test `test/integration/ditto_local_crud_test.dart`.

**Approach:**
- `Tuple` document: `{ _id, dish, contributor, ingredients, steps, embedding, created_at, metadata: { source_device_id, corpus } }`. Corpus theme lives in `metadata.corpus`, not in the type name.
- **Deterministic IDs:** `_id = sha256(corpus + title + text)`. Re-running seed loader on reinstall is a no-op.
- On first launch (gated by absence of corpus-id key in app prefs): read `seed_*.json` based on `PHONE_ROLE` build-time env var; insert each via `addTuple`. Embedding column left empty for U5's lazy fill.
- Subscription auto-rebuilds the in-memory retrieval array on tuple arrival (sync or local insert).
- Preserve `source_device_id` through sync.

**Patterns to follow:** `inspiration/repos/getditto__demoapp-inventory/` for subscription shape.

**Test scenarios:**
- *Happy path:* Insert 5 `Tuple`s on first launch; `queryAll()` returns 5.
- *Happy path:* Subscribe; insert one more; subscription callback fires with 6.
- *Edge case:* Second launch (tuples already in store) — no duplicate inserts (deterministic IDs make it idempotent).
- *Integration:* `peerCount` stream emits 0 when alone, ≥1 in BLE range.

**Verification:** Both phones show 5 tuples on second launch; both report `peerCount=1` when in BLE range.

---

### U5. Retrieval pipeline — Cactus embed + flat-array cosine top-k

**Goal:** Given a query string, embed it via Cactus, materialize the corpus from Ditto, run flat-array cosine top-k with deterministic tie-breaking, return top-k tuples in score order. Lazy-fill missing embedding columns.

**Requirements:** R1 (retrieve before synthesize), R2 (depends on U2 lock), R5.

**Dependencies:** U2 (locks embedding model + backend), U4 (collection exists).

**Files:** Create `lib/services/retrieval_service.dart` (`embedQuery`, `topK`, `ensureEmbeddings`); modify `lib/models/tuple.dart` (embedding column is write-on-first-read); modify `lib/services/cactus_service.dart` (add `embed`). Test `test/integration/retrieval_test.dart`.

**Approach:**
- `ensureEmbeddings()` runs on app start after Ditto init; iterates rows with empty `embedding`, computes via Cactus, writes back. **L2-normalize at insertion** (vectors stored normalized).
- `topK(query, k=3)` materializes embedding columns into a contiguous `Float32List` (N × dim), then dot-product loop (= cosine on unit vectors).
- **Deterministic tie-breaking:** sort by `(score desc, _id asc)`. Prevents H3 top-k drift on score ties.
- Performance budget: < 10ms on iPhone, < 30ms on mid-range Android at 5k tuples. At Stage 0 corpus size (10 tuples) it's microseconds.

**Patterns to follow:** Brute-force cosine pattern from `inspiration/repos/deepsense-ai__edge-slm/`.

**Test scenarios:**
- *Happy path:* Query lexically close to a seed recipe → that recipe ranks top-1 with cosine > 0.7.
- *Edge case:* `topK` on empty corpus returns empty list (no crash).
- *Edge case:* `topK` with k > corpus size returns all rows in score order.
- *Edge case:* Two embeddings with identical score — tie-break by `_id` produces stable order across runs.
- *Integration:* `ensureEmbeddings()` populates embedding column; Ditto subscription on peer sees the embedded rows.
- *Parity test:* Seed 10 tuples with known clusters; assert iOS and Android return same top-k for same query (catches U2 spike-vs-app drift early).

**Verification:** On a phone with 5 preloaded recipes, "soup with chicken" returns chicken-tortilla recipe at top-1. All 5 seed recipes have non-empty embedding columns within 30s of first launch.

---

### U6. Cactus LLM synthesis — pinned prompt + answer rendering

**Goal:** Given a query + top-k retrieved tuples, call `cactus_complete` with the pinned prompt to synthesize a normalized merged recipe. Render with source-attribution labels.

**Requirements:** R1.

**Dependencies:** U3 (locks LLM choice), U5 (retrieves top-k).

**Files:** Modify `lib/services/cactus_service.dart` (add `complete(prompt, maxTokens) → Stream<String>` for streaming UX; non-streaming fallback `completeAll`); use pinned `lib/prompts/recipe_merge.dart` from U3; modify `lib/services/retrieval_service.dart` (add `answerQuery(query) → Stream<String>` orchestrator). Test `test/integration/end_to_end_test.dart`.

**Approach:**
- Prompt template **locked at U3 output** — same prompt for eval and production. No prompt drift between gate and demo.
- Source attribution: post-process the LLM output to detect ingredient mentions overlapping with retrieved tuples; render those with "(from <contributor>)" suffixes.
- Add a **visible failure state** for missing/incompatible model artifacts — don't crash silently.

**Patterns to follow:** Prompt shape from `inspiration/repos/software-mansion-labs__react-native-rag/`; source-attribution UX from `inspiration/repos/ramanujammv1988__edge-veda/`.

**Test scenarios:**
- *Happy path:* Query "chicken tortilla soup" → coherent merged recipe (matches U3 rubric).
- *Edge case:* Query with no relevant retrieved tuples (top-1 cosine < 0.3) → answer says "I don't know" or generates from prior alone (verify against rubric).
- *Edge case:* LLM streaming partial result is renderable mid-token (no UTF-8 corruption).
- *Integration:* Cold-load to first-token latency on slowest device < 10s (R5 verification surface; full measurement at U9).

**Verification:** Known-good query returns coherent merged recipe on slowest device in < 10s first-token, < 30s full answer.

---

### U7. Mesh sync verification + no-server invariant

**Goal:** Confirm with two devices in BLE range that tuples sync bidirectionally + idempotently + queries reflect union of corpora after sync. Add code-level invariant: no app code path can call a server.

**Requirements:** R3, R4, R6.

**Dependencies:** U4, U5.

**Files:** Create `scripts/sync_verification.dart` (debug-menu screen exposing manual sync triggers); `scripts/no_server_check.dart` (CI/compile-time check that `apps/*` transitively reaches no network); `docs/spikes/U7-sync-verification.md`.

**Approach:**
- Sync verification is procedural — observe behavior across two real devices per a 7-step procedure (airplane mode + BLE handshake + sync + offline persistence + re-meet idempotence).
- No-server invariant: a compile-time guard (e.g., dependency-graph analyzer, or simple grep for `http`/`https`/`Socket`/`URLSession`) that fails the build if any app code can transitively reach the network. The check itself is inspectable.

**Test scenarios:**
- *Outcome — pass:* All 7 sync-verification steps observe expected behavior. R3 + R4 + R6 marked verified.
- *Outcome — sync slow:* Step 3 (10-tuple sync after handshake) takes > 90s → investigate Ditto BLE config; may need LAN transport enabled.
- *Outcome — duplicates:* Step 7 (re-meet idempotence) shows duplicates → deterministic ID derivation bug; fix U4.
- *Outcome — no-server check fails:* Code path reaches network → fix and re-run.

**Verification:** `docs/spikes/U7-sync-verification.md` updated with timing + idempotence result + final pass/fail per holdout. `no_server_check.dart` passes in CI.

---

### U8. Demo UI — query, mesh-state, peer-tuple counter, debug menu

**Goal:** Minimal, on-camera-legible UI: one text input, streaming answer pane, mesh-status pill, "tuples from other device" counter, source-attribution footer, debug menu for demo-day recovery.

**Requirements:** R1.

**Dependencies:** U5, U6, U7.

**Files:** Create `lib/widgets/query_screen.dart`, `lib/widgets/mesh_status_widget.dart`, `lib/widgets/debug_menu.dart`; modify `lib/main.dart` (wire as root); ensure `lib/prompts/recipe_merge.dart` template marks each ingredient with `[from <contributor>]` for attribution post-processing.

**Approach:**
- Big input, big "ask" button, big answer pane. Large readable typography — audience reads from across the hall.
- **Mesh-state pill** at top: "Connected to N peers" + colored dot (green=connected, gray=alone). Visible in recording frame at all times.
- **"Tuples from other device" badge:** counter that increments when a tuple with `metadata.source_device_id != self` arrives. Load-bearing affordance for H4.
- **Debug menu** (long-press the title or a tap-7-times easter-egg): one-tap reset (clears synced state without uninstall), one-tap re-seed (re-runs seed loader). Demo-day recovery.

**Patterns to follow:** Source-attribution UX from `inspiration/repos/ramanujammv1988__edge-veda/`. Mesh-state pill from `inspiration/repos/permissionlesstech__bitchat/`.

**Test scenarios:**
- *Happy path:* Same query before and after sync produces visibly different answers; both legible on camera at arm's length.
- *Happy path:* Mesh-state pill updates within 2s of peer count change.
- *Edge case:* Streaming answer renders mid-token without UI flicker.
- *Edge case:* Query while peer-count=0 still works (uses only local corpus); demo can narrate "this is the alone case."
- *Edge case:* Pressing "ask" twice rapidly doesn't double-fire the LLM.
- *Integration:* End-to-end: open app, type query, see answer; bring second phone close; re-type same query; see different answer.

**Verification:** Hand-test full demo flow on two phones; eyeballed for camera-legibility. Phone A's answer changes between pre-sync and post-sync runs of the identical query.

---

### U9. Demo rehearsal — preload, airplane-mode toggle, in-app H2 re-run, H5 measurement, B-roll, single-take

**Goal:** Three+ end-to-end rehearsals; capture in-app H2 parity result; measure H5 cold-load × 5 trials; produce B-roll backup + single-take final.

**Requirements:** R7 (ship criterion).

**Dependencies:** U8.

**Files:** Finalize `assets/seed_recipes_a.json` + `_b.json`; create `docs/spikes/U9-demo-rehearsal.md`; create `slides/media/` with before/after-sync screenshots, B-roll, single-take final.

**Approach:**
- **In-app H2 re-run** (production app build, not spike CLI): run the 20-fixture determinism check from within the actual app. Catches spike-vs-app divergence in backend selection, batch size, or threading.
- **H5 measurement:** cold-launch → first-answer × 5 trials on slowest device. Record p50 + worst-case in `docs/spikes/U9-demo-rehearsal.md`. **No back-door pass** — if > 10s, execute the remediation playbook below until ≤ 10s. Documentation alone is not a pass.
- **H5 remediation playbook** (run in order if needed):
  1. Verify weights are mmap'd, not fully loaded into RAM
  2. Move LLM init from "after splash" to "during splash"
  3. Reduce max-tokens to ~128
  4. Shrink LLM from 1.5B to 1B (Gemma 3 1B or SmolLM2 1B variant)
- Three rehearsals minimum. Record each; watch back; identify weakest moment; fix in U8 if needed.
- Set the camera: both phones in frame, mesh pills visible, hand visible toggling airplane mode.
- **B-roll backup:** pre-recorded in a quiet RF environment as fallback for live BLE flakes. Commit at `slides/media/H1-broll.mp4`.
- **Second hardware pair on standby:** same models, freshly built apps, factory-toggled airplane mode tested.
- **Single-take H1 final** committed to `slides/media/H1-final.mp4`.

**Execution note:** Less code, more iteration on the demo flow.

**Test scenarios:**
- *Outcome — green:* In-app H2 ≥ 0.999, H5 p50 < 10s, single-take H1 visibly passes R1 + R2 + R3 + R4 + R6.
- *Outcome — flake:* BLE handshake > 10s → B-roll fallback rehearsed.

**Verification:** A single recorded take at `slides/media/H1-final.mp4` ships in the deck. `docs/spikes/U9-demo-rehearsal.md` records H2 in-app cosine + H5 5-trial latency table.

---

### U10. Presenterm slide deck

**Goal:** Presenterm-rendered Markdown deck framing the demo: thesis, architecture, latency-floor argument, before/after-sync result, four-thread future-work arc.

**Requirements:** Out of scope for SEED.md holdouts but explicit in deliverable list.

**Dependencies:** U8 (screenshots), U9 (final recording).

**Files:** Create `slides/deck.md`, `slides/notes.md` (speaker notes), `slides/media/` (screenshots, Mermaid architecture PNG, recording).

**Approach:**
- Lean on writeup arc from [open-questions.md §2](../research/index/open-questions.md) and the four-thread future-work narrative.
- Structure:
  1. Title + one-line thesis ("Your knowledge base wants to be a CRDT")
  2. The problem with cloud RAG: physics-bound latency + offline-impossible
  3. **Latency-floor argument slide** — cloud RTT ≥ 200ms physical floor vs on-device < 100ms
  4. The CRDT insight: vector index as grow-only set
  5. **Architecture diagram (Mermaid)** — Cactus embed + LLM, Ditto CRDT, BLE/LAN mesh
  6. Live demo (or B-roll)
  7. What this is + what it isn't (Stage 0 scope honesty)
  8. **Four-thread future-work arc — landing line: "Family recipes through generations."**
  9. Q&A / contact slide

**Patterns to follow:** Presenterm exemplar deck at `inspiration/repos/mfontanini__presenterm/examples/demo.md`.

**Test scenarios:**
- *Happy path:* `presenterm slides/deck.md` renders all slides without errors.
- *Happy path:* PDF export via `presenterm --export-pdf` produces shareable artifact.

**Verification:** Dry-run of deck takes ≤ 10 min with comfortable pacing. Deck + recording both committed.

---

## System-Wide Impact

- **Interaction graph:** Retrieval and synthesis depend on Cactus model staying loaded across queries; Ditto subscription drives UI refresh; airplane-mode toggle is a hardware affordance the app must merely not crash on.
- **Error propagation:** Cactus model load failure → app shows "Cactus: failed" on init screen and aborts query. Ditto sync failure → mesh-status pill stays gray. LLM generation failure → answer pane shows error text. No silent retries.
- **State lifecycle risks:** `ensureEmbeddings()` is idempotent so partial embedding-fill on interruption recovers cleanly. Deterministic IDs prevent duplicate inserts on reinstall.
- **API surface parity:** Same Flutter codebase on iOS + Android. Per-platform branches only where Cactus or Ditto Flutter packages diverge (locked at U1).
- **Integration coverage:** R2 cross-platform parity, R3 idempotence, R4 bidirectional merge — not provable by unit tests. U7 is the integration holdout. U5's parity unit test catches early drift before U9 final rehearsal.
- **Unchanged invariants:** None (greenfield).

---

## Risks & Dependencies

| # | Risk | Mitigation |
|---|------|------------|
| **R1** | U2 fails: cross-platform embedding cosine < 0.999 across all candidates | Spike-first; honest-failure rule — pivot to brainstorm option C, do not soften the threshold. |
| **R2** | U3 fails: small LLM can't coherently merge recipes | Spike-first; cars corpus pre-authored, hot-swap (8/10 fixture threshold makes the decision objective). |
| **R3** | iOS↔Android **mixed BLE pairing** flakes during live demo | B-roll backup; LAN-only rehearsed fallback; second hardware pair on standby; visible mesh-state pill. |
| **R4** | Cold-load > 10s on Android | Eager-load during splash; mmap'd weights; H5 remediation playbook in U9 (4 ordered steps). Hard 10s bar — no back-door pass. |
| **R5** | iOS background BLE limitation kills sync if app backgrounded mid-demo | Demo runs foregrounded only; rehearsal includes "don't touch home button"; deck does not claim background sync. |
| **R6** | Llama license accidentally enters the repo | Default to Qwen 2.5 1.5B Apache-2.0 in U3 candidate ladder; swap to Llama only if both Qwen and SmolLM2 fail. |
| **R7** | Ditto trial / license terms restrict public-repo redistribution | Resolved at U1 scaffold time; fallback is private repo + public writeup. |
| **R8** | Cactus wants to own persistence (`cactus_rag_query` / `cactus_index_*`) and fights Ditto's CRDT store | Keep Cactus narrow (embed + LLM only); we own cosine top-k from the Ditto-materialized array. Explicit decision in Key Technical Decisions. |
| **R9** | **Cactus Flutter-package version-skew vs native Swift + Kotlin packages** | U1.5 spike at scaffold time validates the Flutter wrapper; native escape path is documented if Flutter wrapper diverges. |
| **R10** | Demo legible to operator, illegible to audience from across the hall | Large typography; mesh-state badge; "tuples from peer" counter; device-name banner; source-device labels on tuples. |
| **R11** | **Quantization-format drift** (Q4_K_M on one phone, Q4_0 on the other) silently breaks parity | Pin Q4_K_M exactly in U1's `pubspec.yaml` and model-fetch script; verify in U2 `RESULTS.md`. |
| **R12** | **In-app H2 fails despite spike Gate A passing** (backend or batch drift between CLI and app) | U9 includes explicit in-app H2 re-run with production build before final demo. |
| **R13** | iOS background-BLE for "always-on" mesh | Acknowledged as environmental constraint; not in scope. |

---

## Documentation / Operational Notes

- **README.md update:** add "what this is + how to run" once U1 lands.
- **Spike docs:** `docs/spikes/U1.5-flutter-package.md`, `docs/spikes/U2-determinism-results.md`, `docs/spikes/U3-recipe-merge-eval.md`, `docs/spikes/U7-sync-verification.md`, `docs/spikes/U9-demo-rehearsal.md`. Each captures the empirical decision + date.
- **License audit before publishing:** check resolved package licenses + model weight licenses. Apache-2.0 is the target. Surface anything requiring attribution.
- **Demo-day operational notes:** Pre-flight checklist — both phones charged > 80%, airplane mode, apps launched + warm, model files cached. U9 rehearsal log doubles as this checklist.

---

## Sources & References

- **Origin documents:** [SEED.md](../../SEED.md), [RESEARCH-BRIEF.md](../../RESEARCH-BRIEF.md), [IDEA-A.md](../../IDEA-A.md)
- **Companion research:** [docs/research/index/README.md](../research/index/README.md), [docs/research/index/top-N.md](../research/index/top-N.md), [docs/research/index/open-questions.md](../research/index/open-questions.md), [docs/research/future-work-research.md](../research/future-work-research.md)
- **Sibling planning passes (this composite is the merge of these two):**
  - Sibling A — [`docs/plans/2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md`](2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md) (ce-plan; Opus single-author)
  - Sibling B — [`docs/sprints/SPRINT-0001.md`](../sprints/SPRINT-0001.md) (sprint-planner; codex/gemini/claude drafts + 3 cross-critiques + Opus merge)
  - Sibling B critique artifacts at [`docs/sprints/drafts/`](../sprints/drafts/) — read the critiques to see which sibling-B claims survived peer review.
- **Mode B research worker outputs:** [docs/research/claude.md](../research/claude.md), [docs/research/codex.md](../research/codex.md), [docs/research/gemini.md](../research/gemini.md)
- **External primary sources cited in plan:**
  - [Thinking Machines Lab — Defeating Nondeterminism in LLM Inference](https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/)
  - [Cactus engine docs](https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md)
  - [Ditto SDK docs](https://docs.ditto.live/)
  - [MobileRAG (arXiv 2507.01079)](https://arxiv.org/abs/2507.01079)
  - [EmbeddingGemma (arXiv 2509.20354)](https://arxiv.org/abs/2509.20354)
  - [Qwen3 Embedding (arXiv 2506.05176)](https://arxiv.org/abs/2506.05176)
  - [Presenterm](https://github.com/mfontanini/presenterm)
