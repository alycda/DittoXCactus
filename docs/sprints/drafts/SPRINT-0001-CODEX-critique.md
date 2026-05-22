# Critique of the Gemini and Claude SPRINT-0001 Drafts

Baseline: my CODEX draft is more exhaustive than Gemini's and less operationally timeboxed than Claude's. It is strongest on gate rigor, validation artifacts, fallback semantics, deterministic IDs, idempotent seeding, and making the recipes-vs-cars decision empirical. It is weaker than Claude on concrete repo paths, demo artifact planning, and camera-legibility affordances.

## Gemini draft

### What is stronger than mine

- Gemini's task list is much easier to scan. `Task 1: Embedding Determinism Spike`, `Task 2: LLM Merge Quality Eval`, `Task 3: Ditto Schema & Transport`, and `Task 4: Retrieval & Synthesis Engine` give a compact project-manager view that my draft makes the reader reconstruct from many checklist items.
- The `Sequencing & Dependencies` section makes one useful parallelization point explicit: `Ditto Integration (Task 3)` can run in parallel with `UI (Task 5)` if mocked. My draft says the gates run in parallel, but it is less explicit about safe parallelism after the gates.
- Gemini names the expected native app surfaces directly in `Task 5: Mobile UI Development`: iOS `SwiftUI` and Android `Compose`. My draft describes platform work but does not lock the UI frameworks as cleanly.
- The phase structure is practical for status reporting. `Phase 1: Empirical Gates`, `Phase 2: Core Mesh RAG Implementation`, `Phase 3: Mobile App & Sync Integration`, and `Phase 4: Finalization & Deliverables` would make a better sprint board skeleton than my longer thematic sections.

### What is weaker than mine

- `Task 1: Embedding Determinism Spike` is too shallow for the core thesis. It embeds only "10 standard recipe strings" and does not require vector dimensions, first components, checksums, max absolute component difference, top-k stability, full-vector artifacts, or a recorded result table. My `Gate A: Embedding Determinism` is stricter and more diagnosable.
- `Task 2: LLM Merge Quality Eval` does not define a rubric, sample size, latency condition, slowest-device requirement, or pass threshold. My `Gate B: Recipe-Merge LLM Eval` requires adversarial-but-benign cases, scoring dimensions, and an explicit 8-of-10 decision threshold.
- Gemini's acceptance criteria skip Holdout 6 entirely. It lists `Scenario 1`, `Scenario 2`, `Scenario 3`, `Scenario 4`, `Scenario 5`, and `Scenario 7`, but not the audience-query holdout. My `Validation Harness` includes an `audience-query mini-eval for Holdout 6`.
- `Task 5: Mobile UI Development` includes "Toggle Airplane Mode" as an app feature. That is not a realistic iOS/Android app control. The task should instead be a written operator procedure plus visible offline status, as in my `Demo UI And Offline Moment` tasks.
- The `RecipeTuple` name in `Task 3: Ditto Schema & Transport` bakes in recipes before the corpus gate has passed. My draft keeps the corpus fixture format generic enough that cars can replace recipes without rewriting the retrieval pipeline.

### Missing tasks

- No equivalent to my `Create a shared corpus fixture format that can represent both recipes and cars without changing the retrieval pipeline`.
- No equivalent to my `Add seed fixtures for roughly 50 notes per device for recipes, plus a same-shape cars fallback corpus`.
- No deterministic tuple ID task. My `Add deterministic tuple IDs derived from stable content fields` is important for `Task 6: E2E Sync Verification` and Holdout 3.
- No explicit source-device metadata preservation. My `Preserve source-device metadata through sync` makes the before/after reveal camera-visible.
- No `Observe Ditto collection changes and refresh the in-memory retrieval array whenever synced tuples arrive` task. Gemini says "Implement flat-array cosine similarity search" but not how the local array stays synced with Ditto.
- No platform-specific Cactus generation tasks equivalent to my `Wire Cactus small-LLM generation into iOS` and `Wire Cactus small-LLM generation into Android`.
- No visible failure state for missing or incompatible model artifacts.
- No one-tap reset or seed action for demo recovery.
- No explicit "no server path" verification. My `Keep all inference local and verify that no request path can call a server` is needed for the offline claim.
- No artifacts for determinism, sync idempotence, bidirectional merge, cold-load, or offline operation beyond the broad `Task 7: Holdout Validation Harness`.

### Risks underweighted

- Corpus quality is underweighted. `Task 2: LLM Merge Quality Eval` has no holdout corpus, no cars fallback fixtures, and no documented decision artifact, so the sprint could discover recipe synthesis problems after too much recipe-specific work.
- Cold-load latency is underweighted. Gemini defers `Run Holdout 5: Cold-load latency < 10s` to `Task 7`, but my draft measures load and first-answer time during Cactus integration and Gate B.
- Offline operation is underweighted. `Run Holdout 7` appears only in finalization, and the risks section does not call out OS-specific airplane-mode/Bluetooth behavior.
- Idempotence is underweighted. `Task 6: E2E Sync Verification` checks no duplicates after the implementation, but the plan lacks the upstream deterministic ID and idempotent first-run seeding tasks that make that test likely to pass.
- Demo legibility is underweighted. `Mesh State` is included, but there is no "remote tuple count", source labels, corpus count, or retrieved-note debugging requirement like my UI and Ditto sections require.

### Sequencing problems

- `Task 7: Holdout Validation Harness` is too late for H1, H5, and H7. Cold-load, offline behavior, and airplane-mode procedure should be exercised before finalization, not discovered in the last phase.
- `Task 5: Mobile UI Development` can run with mocks, but only the shell should run before the corpus and model decisions. Building recipe-specific UI before `Task 2` passes risks wasted work.
- `Task 3: Ditto Schema & Transport` defines `RecipeTuple` before the corpus gate. The schema should be corpus-neutral until `Task 2` records recipes vs cars.
- `Task 8: Presentation & Documentation` is last, but the deck needs early architecture and demo-script scaffolding so validation artifacts can land in the right places as they are produced.

## Claude draft

### What is stronger than mine

- Claude's `Definition of Done (mapped to SEED holdouts)` is stronger as an exit contract. It includes H1 through H7, demands a single live take for H1, requires `docs/demo/`, and adds artifact gates for a clean repo, deck export, and backup capture.
- `Section 5. Sequencing` is more operational than my day-level plan. It gives explicit timeboxes, a 12:30 gate decision, a mid-sprint dry run, and a final rehearsal window.
- `6.0 - Kickoff & repo skeleton` fills gaps in my draft: concrete directories (`apps/ios/`, `apps/android/`, `shared/corpus/`, `tools/embedding-determinism/`, `tools/merge-eval/`, `docs/demo/`, `docs/deck/`), hardware documentation, dependency version pins, model-weight `.gitignore`, and Ditto license resolution.
- `6.1 - Empirical gates` has good artifact naming. `tools/embedding-determinism/RESULTS.md`, `tools/merge-eval/RESULTS.md`, and `docs/sprints/SPRINT-0001-decisions.md` are clearer than my more general "record in the repo" language.
- `6.2 - Main pipeline` is stronger on storage and seed planning. The `Decide embedding storage strategy` task, `shared/corpus/seed/A.json`, `shared/corpus/seed/B.json`, and deliberate overlap on 3 dishes are concrete and useful.
- `6.3 - Mesh sync & meet UX` has the best camera-legibility task across all drafts: `Tuples seen from other device` counter. My draft asks for source-device metadata and peer state, but this counter is a sharper demo affordance.
- `6.5 - Holdout execution` is stronger than mine on repeated measurement. `H5 measurement: cold-launch -> first-answer x 5 trials` and `H2 full re-run with the locked production model + production app build` should be kept.
- The risk table catches items my draft only implies: `R6 Ditto trial/license terms restrict public repo redistribution`, `R8 Cactus + Ditto integration friction`, `R9 RN bindings drift`, and `R10 We ship a demo that works but isn't legible to the audience`.

### What is weaker than mine

- Claude overcommits the weekend. `6.0` repo bootstrap, dependency pinning, legal review, three embedding candidates, three LLM candidates, full native apps, H1 video, deck PDF export, second hardware pair, and fresh-machine buildability are too much to treat as equal sprint commitments.
- `R1` weakens the central claim by saying "If still failing, accept >= 0.99 and document the gap." My draft is stricter: if all Cactus embedding candidates miss cosine >= 0.999, switch to a non-claiming fallback rather than pretending cross-platform parity passed.
- `Spike A` proposes `all-MiniLM-L6-v2 (ONNX path)` as a deterministic floor. That breaks the "Cactus is the only embedding and LLM runtime" boundary in my draft unless Cactus itself is serving that ONNX path.
- `Stack - locked vs gated` says "GGUF/Q4 quantized weights" and "same backend tier on both phones (lean CPU/Vulkan, pin away from ANE/Hexagon)". This is too specific and partly suspect: iOS does not have Vulkan, and the exact Cactus backend choices should be discovered and pinned during Gate A.
- The storage calculation in `Decide embedding storage strategy` assumes "384 dims", but the named embedding candidates may not share that dimension. My draft avoids a hardcoded dimensional estimate and requires dimension equality as part of Gate A.
- `RecipeTuple` is still too recipe-specific despite the cars fallback. My draft's corpus fixture and Ditto shape are more neutral about recipes vs cars.
- Claude's model choices are more concrete but less defensible without verification. `EmbeddingGemma 300M`, `Nomic Embed Text v1.5`, `Qwen 2.5 1.5B Instruct`, `SmolLM2 1.7B`, and `Gemma 3 1B IT` are treated as likely Cactus options before the model catalog questions are resolved.

### Missing tasks

- No task to actually author a same-shape cars fallback corpus before the gate. `Gate decision` says swap to `shared/corpus/cars/`, but `6.2` only authors recipe seeds.
- No visible failure state for missing or incompatible model artifacts. My `Cactus Integration` section includes this explicitly.
- No one-tap reset or one-tap seed action for demo recovery.
- No explicit verification that no code path can call a server. Claude says no cloud and no big-peer, but does not include a test or trace for that claim.
- `Spike A` fixtures are recipe-only. My fixture set also covers car-service notes, punctuation, numbers, and plain ASCII strings, which makes the determinism result less corpus-fragile.
- No explicit top-k tie-break rule. My `Sync creates duplicates or unstable retrieval order` mitigation sorts ties by score and tuple ID.
- No dedicated holdout checklist file that maps directly to SEED holdouts 1 through 7. Claude maps holdouts well in prose, but my `Validation Harness` creates a checklist artifact.
- No explicit audience free-text input path in the UI tasks. `6.6 - Audience-survival rehearsal` tests audience-style queries, but `6.4 - App scaffolding & UI` only names a query text field and ask button without tying it to the same retrieval-plus-generation flow as the scripted demo.

### Risks underweighted

- Schedule risk is underweighted. The risk table is broad, but it does not admit that the number of artifacts in `6.0` through `6.8` may exceed a hackathon weekend.
- Model availability risk is underweighted. Claude lists open questions about Cactus exposing EmbeddingGemma and Qwen, but many downstream tasks assume those models will load through both Swift and Kotlin.
- Ditto document-size and query-performance risk is underweighted. `6.2` assumes inline float arrays are acceptable, but that should be validated against Ditto's actual document constraints and mobile memory behavior.
- Public-repo redistribution risk is underweighted. `R6` labels it low, but a blocked Ditto or model redistribution story could affect the final artifact even if the demo works.
- LAN fallback messaging is underweighted. `6.3` includes "airplane mode + Wi-Fi to the same router only", which may be technically local but can confuse the "no internet" claim unless the deck and demo procedure are precise.
- The "fresh macOS + Android Studio" artifact gate is underweighted. Reproducible native mobile builds plus large model weights are a substantial deliverable, not a small cleanup item.

### Sequencing problems

- `6.0 - Kickoff & repo skeleton` contains work that is not needed for the empirical gates, including legal documentation and full repo scaffolding. My draft correctly limits first setup to the foundation needed for Gate A and Gate B.
- `6.1 - Empirical gates` tries to run up to three embedding models and up to three LLMs by 12:30 Day 1. That is useful as a stretch plan, but unrealistic as a hard gate on real iOS and Android hardware.
- `H2 full re-run with the locked production model + production app build` happens in `6.5` on Day 2 morning. If the app path differs from the spike harness, discovering parity drift that late can sink the sprint. A production-path smoke test should happen as soon as the Cactus app integration exists.
- `6.6 - Audience-survival rehearsal` is scheduled after the Day 2 morning holdout pass. If H6 fails and requires corpus tuning or cars fallback, there is little time to regenerate embeddings, re-sync, and re-record.
- `6.7 - Presenterm deck` starts late. The skeleton deck can be created early, then populated with final evidence. Waiting until Sunday afternoon risks losing the architecture and decision rationale that the sprint has already generated.

## If I were merging

- From Gemini, I would keep the concise phase and task skeleton, especially the named `Task 1` through `Task 8` board shape and the note that `Task 3: Ditto Schema & Transport` can run in parallel with `Task 5: Mobile UI Development` when mocked.
- From Claude, I would keep the H1-H7 `Definition of Done`, concrete repo artifact paths, `6.0 - Kickoff & repo skeleton`, `6.3 - Mesh sync & meet UX` with the `Tuples seen from other device` counter, `6.5 - Holdout execution`, and `6.6 - Audience-survival rehearsal`.
- From my CODEX draft, I would keep the stricter Gate A semantics, the 8-of-10 recipe merge gate, the same-shape recipes/cars corpus fallback, deterministic IDs, idempotent seeding, no-server verification, and the rule that a failed cosine >= 0.999 gate becomes a non-claiming fallback rather than a softened success.
