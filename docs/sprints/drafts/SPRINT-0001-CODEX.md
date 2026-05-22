# SPRINT-0001: Mesh RAG Stage 0

Independent draft for the Ditto x Cactus Stage 0 sprint. Source of truth: `SEED.md`, `docs/research/index/README.md`, and `docs/research/index/top-N.md`. The sibling implementation plan was intentionally not read.

## Sprint Intent

Stage 0 is a hackathon-weekend proof that a peer-to-peer RAG vector index can be a CRDT. Two phones, one iOS and one Android, each run Cactus for embeddings and small-LLM synthesis, and Ditto owns sync and storage for `{ id, text, embedding[], metadata }` tuples. The demo moment is filmed with airplane mode toggled live: device A answers from its local corpus, syncs with device B over local peer transport, then answers with A + B knowledge while the internet remains unavailable.

Recipes are the primary corpus because the "virtual potluck" story is legible on camera and supports the future-work arc around specialist models, preference-aware merge, filtering, and generational drift. Cars are the fallback corpus if the Cactus small LLM cannot produce coherent recipe merges early enough.

## Goals

- [ ] Prove cross-platform Cactus embedding determinism on real iOS + Android devices with cosine similarity >= 0.999 for the same fixture text.
- [ ] Decide recipes-vs-cars by mid-Day-1 using an empirical small-LLM merge-quality eval, before building the full pipeline around a corpus.
- [ ] Ship a working two-device local-first RAG demo where Ditto syncs embedding tuples bidirectionally and queries immediately retrieve from the combined corpus.
- [ ] Keep the entire demo offline: no cloud fallback, no server proxy, no hosted vector database, and no Cactus hybrid mode.
- [ ] Produce a Presenterm deck that explains the thesis, architecture, demo script, verification results, and future-work arc.
- [ ] Leave the repo in a handoff-ready state with runnable setup notes, validation commands, corpus fixtures, and demo instructions.

## Scope Boundaries

In scope is only Stage 0: a flat grow-only tuple set, exact local vector search, two phones, one corpus theme, and a demo-grade UI. Ditto is the storage and sync layer. Cactus is the only embedding and LLM runtime. Retrieval can brute-force a flat float32 array because the target size is roughly 50 notes per device, not a production-scale ANN index.

Out of scope: arbitrary document ingestion, auth, multi-user identity, persistent chat history, streaming tokens, cloud fallback, production UI polish, browser clients, and CRDT semantics beyond Ditto-managed tuple merge.

## Sequencing

The sprint starts with two empirical gates because they determine whether the rest of the weekend is viable and which corpus to build around.

- [ ] Day 0 / first setup: complete only the foundation tasks needed to run Gate A and Gate B.
- [ ] Day 1 morning: run Gate A and Gate B in parallel and stop broad app work until both gates have a decision.
- [ ] Day 1 afternoon: build the main pipeline around the selected corpus after the gate decisions are recorded.
- [ ] Day 2 morning: harden the holdout paths for sync, idempotence, offline mode, cold-load latency, and the airplane-mode recording.
- [ ] Day 2 afternoon: finish the deck, final evidence, setup docs, and end-to-end holdout run.

## Critical Gates

### Gate A: Embedding Determinism

- [ ] Pin the exact Cactus runtime, embedding model artifact, quantization, tokenizer, and model-loading configuration for both iOS and Android.
- [ ] Use Qwen3-Embedding-0.6B as the first candidate if the local Cactus integration exposes it cleanly on both platforms.
- [ ] Try EmbeddingGemma only if it is packaged by Cactus for both target platforms and can be loaded without weekend-scale integration risk.
- [ ] Create a fixture set with at least 20 short texts covering recipe ingredients, recipe steps, car-service notes, punctuation, numbers, and Unicode-free plain ASCII strings.
- [ ] Build the smallest possible iOS harness that embeds the fixture set on device and exports vector length, first 16 components, checksum, and full vectors.
- [ ] Build the smallest possible Android harness that embeds the same fixture set on device and exports the same trace fields.
- [ ] Add a repo-local comparison script or test that computes cosine similarity, max absolute component difference, vector length equality, and top-k stability for every fixture.
- [ ] Run the harness on real iOS and Android hardware with networking disabled.
- [ ] Record the determinism result table in the repo, including model name, runtime version, device names, cosine min/median, and whether any fixture failed.
- [ ] Pass Gate A only if every same-text iOS-vs-Android pair has cosine similarity >= 0.999 and vector dimensions match exactly.
- [ ] If Gate A fails on the first candidate, run one alternate Cactus-packaged embedding model before changing the demo plan.
- [ ] If all Cactus embedding candidates miss cosine >= 0.999, document the failure and switch the sprint to a non-claiming fallback that does not pretend cross-platform embedding parity passed.

### Gate B: Recipe-Merge LLM Eval

- [ ] Build a tiny offline eval set of recipe contribution pairs where device A and device B each hold partial or variant notes for the same dish.
- [ ] Include at least one chicken tortilla soup scenario because it is the seed example for audience-legible merge behavior.
- [ ] Include adversarial-but-benign recipe cases: missing ingredient quantities, conflicting optional ingredients, substitutions, duplicate steps, and preference-sensitive ingredients such as avocado.
- [ ] Build a matching cars fallback eval set using service/manual-style facts with clear retrieval-grounded answers.
- [ ] Pin the first Cactus small-LLM candidate and prompt template before judging corpus quality.
- [ ] Run the recipe eval on the slowest target device, not only on the faster phone.
- [ ] Score each answer for grounding in retrieved notes, preservation of facts from both devices, coherence, and absence of invented critical details.
- [ ] Pass recipes only if at least 8 of 10 scripted merge cases are coherent, visibly use both devices' notes when relevant, and fit within the cold-load budget.
- [ ] Switch to cars if recipe merge quality is below the pass threshold, if the prompt requires brittle hand-holding, or if recipe latency threatens the live demo.
- [ ] Record the recipes-vs-cars decision in the repo by mid-Day-1 with example prompts, retrieved notes, generated answers, and the scoring table.

## Build Tasks

### Repo And App Foundation

- [ ] Inventory the existing repo layout and identify where mobile apps, shared fixtures, validation scripts, docs, and the Presenterm deck should live.
- [ ] Add a short `README` path for Stage 0 setup that names required devices, SDK versions, model files, and offline demo assumptions.
- [ ] Create a shared corpus fixture format that can represent both recipes and cars without changing the retrieval pipeline.
- [ ] Add seed fixtures for roughly 50 notes per device for recipes, plus a same-shape cars fallback corpus.
- [ ] Add deterministic tuple IDs derived from stable content fields so repeated sync cannot create duplicate logical notes.
- [ ] Define the Ditto document shape for `{ id, text, embedding, metadata }`, including corpus name, source device, source fixture ID, created timestamp, and human-readable title.
- [ ] Keep embedding vectors stored in Ditto-owned documents for Stage 0 so the vector index itself is the synced CRDT state.
- [ ] Add a local build/run checklist for iOS and Android that does not require internet during demo execution.

### Cactus Integration

- [ ] Wire Cactus embedding inference into the selected mobile app surface on iOS.
- [ ] Wire Cactus embedding inference into the selected mobile app surface on Android.
- [ ] Wire Cactus small-LLM generation into iOS using the same model and prompt contract as Android.
- [ ] Wire Cactus small-LLM generation into Android using the same model and prompt contract as iOS.
- [ ] Load models eagerly at app startup so the cold-load budget is measured honestly.
- [ ] Log model load time, first embedding time, first retrieval time, and first answer time on each device.
- [ ] Add a visible failure state for missing or incompatible model artifacts.
- [ ] Keep all inference local and verify that no request path can call a server.

### Ditto Sync And Storage

- [ ] Initialize Ditto on both mobile platforms with the same app ID, auth mode, collections, and small-peer configuration required for the demo.
- [ ] Enable local peer transport needed for the live demo, prioritizing BLE and allowing LAN only if it remains local and offline.
- [ ] Add a visible peer/sync state indicator that helps the camera show when the devices have met.
- [ ] Insert local corpus tuples into Ditto on first run without duplicating them on app restart.
- [ ] Observe Ditto collection changes and refresh the in-memory retrieval array whenever synced tuples arrive.
- [ ] Preserve source-device metadata through sync so retrieved results can visibly show whether a note came from A or B.
- [ ] Verify bidirectional sync by adding at least one query whose nearest useful result starts on iOS and one whose nearest useful result starts on Android.
- [ ] Verify sync idempotence by re-meeting devices after no changes and confirming tuple count and top-k results do not change.

### Retrieval And Answering

- [ ] Implement exact cosine search over the local in-memory array built from Ditto documents.
- [ ] Normalize embedding vectors consistently before similarity scoring or document why Cactus outputs are already normalized.
- [ ] Return top-k results with score, title, source device, and snippet for camera-visible debugging.
- [ ] Use a fixed top-k for the demo dry run and document the value in the repo.
- [ ] Build the answer prompt from retrieved notes only, with instructions to cite or name the notes it used.
- [ ] Make the UI show local answer state before sync and combined-corpus answer state after sync.
- [ ] Add a scripted query set where the expected answer changes after sync because remote notes become retrievable.
- [ ] Add an audience-query path that accepts free text and runs the same retrieval-plus-generation flow.

### Demo UI And Offline Moment

- [ ] Build a simple two-pane or stacked UI showing query input, answer, retrieved notes, peer state, corpus count, and offline status.
- [ ] Add a device label control or build-time label so camera viewers can tell iOS and Android apart.
- [ ] Add a one-tap reset for demo data that clears local generated state without requiring uninstall/reinstall.
- [ ] Add a one-tap seed action if first-run seeding cannot be fully automatic.
- [ ] Write the exact airplane-mode procedure for each phone, including whether Bluetooth must be re-enabled after toggling airplane mode.
- [ ] Dry-run the demo with Wi-Fi and cellular unavailable and only the chosen local peer transport active.
- [ ] Record a rehearsal take showing pre-sync answer X, peer meet, post-sync answer X + Y, and no internet connectivity.
- [ ] Keep a backup hardware pair or backup recorded take available if demo-day radio behavior becomes flaky.

### Validation Harness

- [ ] Create a holdout checklist file that maps directly to SEED holdouts 1 through 7.
- [ ] Add a determinism trace artifact for Holdout 2 with cosine >= 0.999 across iOS and Android.
- [ ] Add a sync-idempotence trace artifact for Holdout 3 with stable tuple counts and stable top-k results across repeated meet cycles.
- [ ] Add a bidirectional-merge trace artifact for Holdout 4 with queries proving A-to-B and B-to-A retrieval.
- [ ] Add cold-load measurements for Holdout 5 on the slowest target device.
- [ ] Add an audience-query mini-eval for Holdout 6 with at least 5 free-text queries and at least 3 successful grounded answers.
- [ ] Add an offline-operation trace for Holdout 7 showing the full flow with internet unavailable.
- [ ] Run the full holdout checklist after every major integration change on Day 2.

### Deck And Handoff

- [ ] Create a Presenterm deck in the repo for the Stage 0 demo.
- [ ] Add slides for the one-line thesis: "Your knowledge base wants to be a CRDT."
- [ ] Add slides explaining why retrieval is a better local-first AI primitive than chat history, weights, or caches.
- [ ] Add an architecture slide showing Cactus embeddings and LLM on each phone, Ditto syncing tuple state, and local exact retrieval.
- [ ] Add a demo-script slide with the airplane-mode sequence and expected before/after query behavior.
- [ ] Add a verification slide with the seven holdouts and their pass/fail status.
- [ ] Add a future-work slide for specialist small models, preference-aware merge, adversarial filtering, and generational evolution.
- [ ] Add final repo run instructions and troubleshooting notes for model files, device permissions, and peer discovery.

## Risks And Mitigations

### Embeddings are not deterministic enough across iOS and Android

- [ ] Keep the determinism harness smaller than the full app so it can be rerun quickly across model/runtime variants.
- [ ] Prefer single-sample inference paths and fixed model/runtime configuration when comparing vectors.
- [ ] Capture first-N vector components and max absolute differences so failures are diagnosable instead of just red/green.
- [ ] Make the sprint decision explicit if cosine similarity cannot reach >= 0.999 with Cactus-packaged models.

### Recipe synthesis is too weak for the live demo

- [ ] Run the recipe eval before investing in recipe-specific UI or copy.
- [ ] Keep cars fixtures ready in the same tuple format so fallback is a corpus swap, not an architecture rewrite.
- [ ] Use retrieved-note visibility in the UI so the demo still proves mesh retrieval even if generated prose is modest.

### BLE or local peer discovery is flaky on camera

- [ ] Test the exact airplane-mode and Bluetooth sequence on both phones before the final build.
- [ ] Keep LAN-local sync as a rehearsed fallback if it preserves the no-internet claim.
- [ ] Add a visible peer-state indicator so the operator can wait for sync instead of guessing.
- [ ] Capture one clean rehearsal video as fallback evidence.

### Cold-load latency exceeds ~10 seconds

- [ ] Measure cold-load on the slowest target device during Gate B, not at the end of the sprint.
- [ ] Eager-load models on app start and show a clear loading state before the live query begins.
- [ ] Downgrade model size or switch corpus if the selected LLM cannot answer within the demo budget.

### Sync creates duplicates or unstable retrieval order

- [ ] Use deterministic tuple IDs and idempotent first-run seeding.
- [ ] Sort top-k ties deterministically by score, then tuple ID.
- [ ] Re-run the no-change re-meet test after every schema or seeding change.

## Acceptance Criteria

- [ ] Holdout 1 passes in a single recorded take: airplane mode toggled live, local answer before sync, combined answer after sync, and no central network involved.
- [ ] Holdout 2 passes with iOS-vs-Android embedding cosine similarity >= 0.999 for every fixture text.
- [ ] Holdout 3 passes with no duplicate tuples and no top-k drift after repeated no-change peer meetings.
- [ ] Holdout 4 passes with bidirectional merge observable through queries on both devices.
- [ ] Holdout 5 passes with cold-load to first answer under roughly 10 seconds on the slowest target device, or the miss is documented with an explicit mitigation.
- [ ] Holdout 6 passes for at least 3 of 5 audience-style free-text queries against roughly 50 notes per device.
- [ ] Holdout 7 passes with the full flow running offline and no server, cloud inference, or hosted vector database.
- [ ] The selected corpus decision is documented, including why recipes passed or why cars replaced recipes.
- [ ] The repo contains runnable app instructions, validation artifacts, fixture data, and the Presenterm deck.
- [ ] The final demo can be rehearsed from a clean install on both phones without undocumented manual state.
