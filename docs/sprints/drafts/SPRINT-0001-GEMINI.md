# SPRINT-0001: Mesh RAG Stage 0 (Ditto × Cactus)

**Intent:** Deliver a hackathon-ready, two-device (iOS + Android) demo of peer-to-peer RAG where the vector index is a CRDT.
**Success Metric:** Holdout scenarios 1–5 + 7 in `SEED.md` pass on real hardware (iOS + Android).

---

## Goals
1. **Prove Cross-Platform Determinism:** Verify that Cactus embeddings are identical/equivalent across iOS and Android.
2. **Validate Corpus Merge:** Confirm the small LLM can coherently synthesize recipes from a merged CRDT corpus.
3. **Execute the "Moment of Magic":** Demonstrate offline BLE/LAN sync and immediate RAG update on camera with airplane mode toggled.
4. **Deliver Presentation:** Create a `presenterm` deck and a working repository.

## Scope Boundaries
- **In-Scope:** On-device Cactus inference (Embed + LLM), Ditto mesh sync (BLE/LAN), flat-array vector retrieval, iOS (SwiftUI) and Android (Compose) apps.
- **Out-of-Scope:** Cloud fallbacks, PDF ingestion, persistent chat history, streaming tokens, production UI polish.

---

## Task List

### Phase 1: Empirical Gates (Day 1 Morning)
- [ ] **Task 1: Embedding Determinism Spike**
    - [ ] Initialize Cactus runtime on iOS (Swift) and Android (Kotlin) with `Qwen3-Embedding-0.6B`.
    - [ ] Embed a set of 10 standard recipe strings (e.g., "Chicken Tortilla Soup") on both devices.
    - [ ] Implement a comparison harness to calculate cosine similarity between the two sets.
    - [ ] **Gate:** Verify cosine similarity ≥ 0.999. If failed, investigate quantization parity or switch model.
- [ ] **Task 2: LLM Merge Quality Eval**
    - [ ] Prompt the Cactus small LLM (Qwen-1.5B/3B) with two slightly different versions of a recipe (e.g., one with avocado, one without).
    - [ ] Evaluate the LLM's ability to normalize and synthesize a single coherent recipe.
    - [ ] **Gate:** If output is incoherent or hallucinations are high, pivot the corpus from `recipes` to `cars` fallback.

### Phase 2: Core Mesh RAG Implementation (Day 1 Afternoon)
- [ ] **Task 3: Ditto Schema & Transport**
    - [ ] Define `RecipeTuple` DQL schema: `{ id: string, text: string, embedding: float[], metadata: object }`.
    - [ ] Configure Ditto small-peer transports (BLE + LAN) for iOS and Android.
    - [ ] Implement `RecipeStore` wrapper for Ditto CRUD operations.
- [ ] **Task 4: Retrieval & Synthesis Engine**
    - [ ] Implement flat-array cosine similarity search for the local Ditto collection.
    - [ ] Implement the RAG prompt template: `Context: {top_k_texts} \n Question: {user_query} \n Answer:`.
    - [ ] Wire Cactus LLM to the retrieval output.

### Phase 3: Mobile App & Sync Integration (Day 2 Morning)
- [ ] **Task 5: Mobile UI Development**
    - [ ] Build iOS (SwiftUI) view: Input query, List top-k neighbors, Display LLM answer, Toggle Airplane Mode.
    - [ ] Build Android (Compose) view: Parity with iOS UI.
    - [ ] Implement "Mesh State" visualization (Discovery indicator, Peer count).
- [ ] **Task 6: E2E Sync Verification**
    - [ ] Verify Holdout 3: Sync idempotence (no duplicates on re-meet).
    - [ ] Verify Holdout 4: Bidirectional merge (A's notes visible to B, and vice versa).

### Phase 4: Finalization & Deliverables (Day 2 Afternoon)
- [ ] **Task 7: Holdout Validation Harness**
    - [ ] Run Holdout 5: Cold-load latency < 10s.
    - [ ] Run Holdout 7: Full offline operation (Airplane mode).
    - [ ] Record the "Moment of Magic" dry run (Holdout 1).
- [ ] **Task 8: Presentation & Documentation**
    - [ ] Create `docs/slides.md` for `presenterm`.
    - [ ] Draft README with "Latency + Offline-first" thesis and Stage 0 results.
    - [ ] Cleanup repo for public-facing hackathon submission.

---

## Sequencing & Dependencies
1. **Cactus Parity (Task 1)** is the hard blocker for the thesis. It must run first.
2. **Corpus Decision (Task 2)** dictates the UI and prompt engineering.
3. **Ditto Integration (Task 3)** can run in parallel with **UI (Task 5)** if mocked.

## Risks
- **BLE Flakiness:** Mixed iOS/Android BLE pairing is notoriously hard. *Mitigation:* Have LAN fallback ready; use Ditto's `SmallPeer` best practices.
- **Model Size vs. Latency:** A 3B model might exceed the 10s cold-load limit on Android. *Mitigation:* Profile early; keep 1B variants on standby.
- **Quantization Drift:** FP16 vs INT8 might break the 0.999 cosine gate. *Mitigation:* Pin exact model versions and quantization methods across both runtimes.

## Acceptance Criteria (Holdouts)
- [ ] **Scenario 1:** Airplane-mode toggle live re-query success.
- [ ] **Scenario 2:** Cross-platform cosine > 0.999.
- [ ] **Scenario 3:** Sync idempotence (no duplicates).
- [ ] **Scenario 4:** Bidirectional merge observable.
- [ ] **Scenario 5:** Cold-load < 10s.
- [ ] **Scenario 7:** 100% offline functionality.
