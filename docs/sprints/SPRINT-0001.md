# SPRINT-0001 — Mesh RAG Stage 0 (Ditto × Cactus)

> *Two devices, airplane mode, BLE handshake, observable state change.*
> Hackathon-weekend sprint. Sat + Sun. Merged final plan; drafts at `docs/sprints/drafts/`. Stage 0 = generalist small LLM + flat grow-only tuple set; the writeup gestures at the four-thread future-work arc but Stage 0 does not implement it.

**Authored:** 2026-05-21. **Status:** planned. **Executor:** TBD.

---

## 1. Intent

Ship a two-device peer-to-peer RAG demo where the vector index is a Ditto CRDT, embeddings + generation run on-device via Cactus, and the moment of magic is an airplane-mode toggle on camera. Phone A returns answer X; phone B walks into BLE range; phone A re-queries and returns X + Y, visibly drawing on phone B's notes — with no network involved. Deliverable = working iOS + Android repo + Presenterm slide deck.

Two empirical gates (Gate A: embedding determinism; Gate B: small-LLM merge quality) run **before** the main pipeline so corpus-or-fallback decisions are in hand by lunch on Day 1.

---

## 2. Definition of Done

The sprint exits when every box below is ✅ on the chosen hardware pair, in a single live take, with the recording in `docs/demo/`:

- [ ] **H1 — Airplane-mode moment of magic.** Live airplane-mode toggle on camera; phone A's query result expands visibly to include phone B's contributions after BLE meet. Single take, no cuts.
- [ ] **H2 — Cross-platform embedding parity.** `cactus_embed(text)` on iOS vs Android produces cosine ≥ 0.999 on ≥ 20 representative fixture strings, with matching vector dimensions and a recorded result table.
- [ ] **H3 — Sync idempotence.** Re-meet with no changes → zero new tuples, top-k unchanged for a fixed query set of 10. Deterministic content-derived IDs + score-then-id tie-breaking guarantee stability.
- [ ] **H4 — Bidirectional merge.** A's notes appear in B's index and vice versa, demonstrable via a query whose top-k pre-meet lives only on the other device. Source-device metadata is preserved through sync and shown in the UI.
- [ ] **H5 — Cold-load latency.** App-launch → first-answer rendered < 10s on the slowest target device. Measured ×5; p50 and worst-case recorded. No soft-pass — if 10s is missed, the remediation playbook executes; documentation is not a pass.
- [ ] **H6 — Audience-survivable Stage 1.** Audience-picked free-text query → coherent LLM answer that visibly references retrieved tuples; passes ≥ 3 of 5 attempts on ~50 notes/device.
- [ ] **H7 — End-to-end offline.** Wi-Fi off, cellular off, only BLE/LAN. Inspectable invariant: no code path can call a server. Full pipeline runs.

**Artifact gates:**
- [ ] Repo builds cleanly from scratch on a fresh macOS + Android Studio.
- [ ] Presenterm deck exports to PDF; committed at `docs/deck/SPRINT-0001-deck.pdf`.
- [ ] Single-take H1 recording committed (or linked) at `docs/demo/H1-final.mp4`.
- [ ] One pre-recorded B-roll capture of H1 exists as fallback if BLE flakes mid-presentation.
- [ ] Decision artifacts committed: `tools/embedding-determinism/RESULTS.md`, `tools/merge-eval/RESULTS.md`, `docs/sprints/SPRINT-0001-decisions.md`.

---

## 3. Scope

**In scope (Stage 0):**
- Generalist small LLM (1B–3B class) and one embedding model — both running on-device on both platforms via Cactus.
- Flat float32 array cosine top-k over the locally-materialized Ditto query result (no HNSW, no sqlite-vec).
- A single Ditto collection of `Tuple { id, text, embedding[], metadata }` documents — **corpus-neutral schema**; "recipes" is a fixture choice, not a type.
- BLE + LAN transports both enabled; no big-peer, no internet, no Cactus hybrid mode.
- Recipes corpus, ~50 notes/device. Cars corpus pre-authored in identical schema as hot-swappable fallback.
- Presenterm deck (Markdown source) + PDF export.

**Explicitly out of scope:** cloud fallback, document ingestion (PDF/EPUB), auth, multi-user identity, persistent chat history, streaming tokens, polished settings UI, web/desktop clients, HNSW/sqlite-vec/USearch (flagged as escape hatches only), preference-aware merge / adversarial filtering / generational evolution (future-work arc; writeup-only).

---

## 4. Stack — locked vs gated

**Locked (non-negotiable):**
- Sync + storage: **Ditto SDK** (Swift + Kotlin native bindings, not React Native — version-skew between RN bindings is a real parity risk). BLE + LAN transports.
- Embedding + LLM runtime: **Cactus** (Swift + Kotlin native bindings). GGUF quantized weights, **Q4_K_M on both phones with identical quantization format** (Q4_0 vs Q4_K_M silently breaks parity). Same backend tier on both phones — lean CPU; pin away from vendor accelerator paths (ANE/Hexagon) until Gate A confirms parity holds there. Actual backend choice recorded in Gate A.
- Vector search: flat float32 array cosine top-k with **L2-normalize at insertion** (dot product at query time). No ANN at Stage 0.
- Deck: **Presenterm** (Markdown → PDF).

**Gated by the two empirical spikes (decision by 12:30 Day 1):**

| Layer | Primary | Backup | Floor |
|---|---|---|---|
| Embedding | **Qwen3-Embedding-0.6B** (Cactus-packaged, Apache-2.0) | EmbeddingGemma 300M (if Cactus exposes it) | Nomic Embed v1.5 → all-MiniLM-L6-v2 (ONNX fallback only if no Cactus model clears 0.999) |
| LLM | **Qwen 2.5 1.5B Instruct** (Apache-2.0, in Cactus catalog) | SmolLM2 1.7B Instruct | Gemma 3 1B IT (Gemma terms — accept friction only if 1.5B class fails Gate B) |
| Corpus | **Recipes** if Gate B clears | **Cars** (identical schema; pre-authored) | — |

**Avoid Llama 3.2** as default — Community License's "Built with Llama" attribution + naming requirements add public-repo friction we don't need.

---

## 5. Sequencing

```
Day 1 Saturday
├─ 09:00–09:30  Sprint kickoff: hardware pair locked, repo skeleton    (§6.0)
├─ 09:30–12:30  PARALLEL gates (both must finish by lunch)              (§6.1)
│   ├─ Spike A: Embedding determinism (cosine ≥ 0.999, 20 fixtures)
│   └─ Spike B: Recipe-merge LLM eval (8/10 fixtures, slowest device)
├─ 12:30–13:00  GATE DECISION: corpus + models locked, Spike B prompt frozen
├─ 13:00–18:30  Main pipeline build                                     (§6.2)
├─ 18:30–21:00  Mesh sync wiring + two-device meet UX                   (§6.3)
└─ 21:00–22:00  Saturday-night dry-run (H3, H4, H7 only)                (§6.5)

Day 2 Sunday
├─ 09:00–12:00  Holdout pass: H1, H2 in-app re-run, H5 ×5              (§6.5)
├─ 12:00–15:00  Audience-query rehearsal (H6) + corpus tuning           (§6.6)
├─ 15:00–17:30  Presenterm deck + B-roll backup recording               (§6.7)
└─ 17:30–18:30  Final rehearsal + single-take H1 capture                (§6.8)
```

The gates run before the main pipeline because corpus-or-fallback decisions need to be in hand by lunch; building the pipeline first and then discovering ingredient-merging is incoherent at 1.5B costs a half-day.

---

## 6. Tasks

### 6.0 — Kickoff & repo skeleton (09:00–09:30, Sat)

- [ ] Lock hardware pair: record exact iOS device (model + iOS version) and exact Android device (model + Android version) in `docs/demo/hardware.md`.
- [ ] Bootstrap monorepo skeleton: `apps/ios/`, `apps/android/`, `shared/corpus/`, `tools/embedding-determinism/`, `tools/merge-eval/`, `docs/demo/`, `docs/deck/`, `docs/legal/`.
- [ ] Pin Cactus + Ditto SDK versions in `apps/ios/Package.swift` and `apps/android/build.gradle.kts`. Use **native** bindings (Swift / Kotlin) — not React Native — for both.
- [ ] **Ditto trial/license resolution** for a public hackathon repo: confirm redistribution shape acceptable, document in `docs/legal/ditto.md`. (If blocked: fallback is private repo + public writeup.)
- [ ] Add model-weight `.gitignore` entries + a model-fetch script that runs offline-cached on demo day.
- [ ] Stub `README.md`: one-line thesis, link to [SEED.md](../../SEED.md), link to [research index](../research/index/), run instructions.

### 6.1 — Empirical gates (09:30–12:30, Sat; PARALLEL)

#### Spike A — Embedding determinism

- [ ] Curate **20 representative fixtures** in `tools/embedding-determinism/fixtures.json`: short titles, ingredient lists, prose steps, car-service notes (for corpus-neutrality), punctuation, numbers, plain ASCII strings. Mix on purpose so the determinism result is not corpus-fragile.
- [ ] iOS CLI harness: `cactus_embed(fixture)` → write `{ id, dim, first_16_components, l2_norm, full_vector }` JSON, transferable off-device.
- [ ] Android CLI harness: identical shape, identical fixture order.
- [ ] Cross-device diff tool: cosine + L2 + max-absolute-component-diff + dim-equality + top-k stability per fixture.
- [ ] **Pin Cactus backend** explicitly on both devices to match each other; pin **Q4_K_M quantization**; **force batch size 1** per Thinking Machines batch-invariance guidance. Record actual backend choice (likely CPU initially) in `tools/embedding-determinism/RESULTS.md`.
- [ ] Run **Qwen3-Embedding-0.6B first**; record min / median / max cosine, dim match, top-k stability.
- [ ] If Qwen3 misses parity: re-run with **EmbeddingGemma 300M** (if Cactus exposes it).
- [ ] If both Cactus options miss parity: re-run with **Nomic Embed v1.5** as Cactus's third option.
- [ ] If no Cactus-packaged model clears 0.999: re-run with **all-MiniLM-L6-v2** on a deterministic ONNX path. This breaks the "Cactus is the only runtime" boundary; if forced here, the deck must say so explicitly.
- [ ] **Honest-failure rule:** if no candidate clears 0.999 across iOS and Android, document the failure and switch the demo to a non-claiming fallback. Do NOT publish a deck claiming cross-platform parity passed when it did not.
- [ ] Write `tools/embedding-determinism/RESULTS.md` with the chosen model, backend pin, quantization pin, full cosine table, and PASS / FALLBACK / FAIL verdict.

#### Spike B — Recipe-merge LLM eval

- [ ] Curate **5 dishes × 3 variants each** in `tools/merge-eval/fixtures/`: chicken tortilla soup, banana bread, carbonara, chana masala, miso soup. Each variant set has adversarial-but-benign coverage: **missing ingredient quantities, conflicting optional ingredients, substitutions, duplicate steps, preference-sensitive ingredients (e.g., avocado).**
- [ ] Author a **matching cars fallback fixture set** in identical schema before judging recipes (so corpus swap is a fixture swap, not a re-author).
- [ ] **Pin the prompt template before judging.** Define starting prompt in `tools/merge-eval/prompt.md`: `Context: {top_k_texts}\nQuestion: {user_query}\nAnswer: synthesize a single coherent recipe; preserve provenance for divergent ingredients.` Variants tested only after corpus decision.
- [ ] Define rubric in `tools/merge-eval/rubric.md`: coherent ingredient list (no contradictions, no hallucinations), provenance preserved on divergent ingredients, readable instructions, no invented critical details.
- [ ] **Run eval on the slowest target device**, not just the faster phone. Merge-quality can degrade on slower-device quantization paths.
- [ ] Score Qwen 2.5 1.5B Instruct → SmolLM2 1.7B → (if needed) Gemma 3 1B IT.
- [ ] **Pass threshold: 8 of 10 fixtures coherent** per rubric, within cold-load + answer-time budget. Below threshold → corpus = cars.
- [ ] Write `tools/merge-eval/RESULTS.md` with per-model per-fixture scores, latency on slowest device, chosen LLM, **corpus decision (recipes | cars) with explicit reasoning**.

#### Gate decision (12:30, Sat)

- [ ] Update `docs/sprints/SPRINT-0001-decisions.md`: chosen embedding model + backend + quantization, chosen LLM, corpus, prompt template hash. If corpus = cars: swap `shared/corpus/recipes/` for `shared/corpus/cars/` (schema-identical; no downstream code changes).

### 6.2 — Main pipeline (13:00–18:30, Sat)

#### Data model & corpus

- [ ] Define `Tuple` Ditto document shape (corpus-neutral name): `{ _id: string, text: string, embedding: float32[], metadata: { source_device_id, created_at, title?, tags?, corpus? } }`.
- [ ] **Deterministic IDs:** derive `_id` from stable content fields (e.g., `sha256(corpus + title + text)`) so repeated first-run seeding across reinstall does NOT create duplicate logical tuples. Load-bearing for H3.
- [ ] Decide embedding-storage strategy: inline `float32[]` in the Ditto document. At ≤5k tuples × ≤500 dims (actual dim recorded in Gate A) the inline approach is well under Ditto's per-doc limits and trivially CRDT-merged. Document this + the sidecar-blob escape hatch in `docs/design/storage.md`.
- [ ] Author 50 hand-curated tuples per device in the locked corpus, with **deliberate overlap on 3 dishes** so H4 has known cross-device top-k targets. Commit to `shared/corpus/seed/A.json` and `shared/corpus/seed/B.json`.
- [ ] Implement per-platform corpus loader: ingests `shared/corpus/seed/<device>.json` on first run only; subsequent runs are idempotent no-ops (via deterministic IDs).

#### Retrieval (parallel iOS + Android)

- [ ] Implement local retrieval in Swift: load all `Tuple` embeddings into a flat `[Float]` array on Ditto subscription update; cosine top-k = brute-force loop. **L2-normalize at insertion**; query path is dot product only.
- [ ] Implement the same in Kotlin: identical shape, identical normalization, identical formula.
- [ ] **Deterministic tie-breaking on top-k:** sort by score desc, then `_id` asc. Prevents H3 top-k drift on score ties.
- [ ] Define top-k retrieval API per-platform: `retrieve(query: String, k: Int = 5) → [Tuple]`.
- [ ] Parity unit test: 10 seed tuples with known clusters; assert iOS and Android return the same top-k for the same query.

#### Generation (parallel iOS + Android)

- [ ] Wire Cactus LLM init **eagerly at app launch** (not lazy — required for H5 cold-load budget). Warm with a no-op prompt before UI is interactive.
- [ ] Implement `generate(query, retrieved) → String` per platform; non-streaming; max-tokens bounded (~256).
- [ ] Apply the prompt template locked in Gate B.
- [ ] Add a **visible failure state** for missing or incompatible model artifacts (don't crash silently).
- [ ] Render answer in UI alongside retrieved-tuple cards so the audience sees which notes the model used.

#### Inspectable offline invariant (H7)

- [ ] Add a code-level check (compile-time guard or unit test): no transitive code path in `apps/ios/` or `apps/android/` can reach the network. This is an inspectable invariant, not just a property of airplane mode.

### 6.3 — Mesh sync & meet UX (18:30–21:00, Sat)

- [ ] Configure Ditto sync subscription on both platforms; verify auto-rebuild of local array on tuple arrival.
- [ ] **Mesh-state visualization** (single named UI component): icon + peer count, updates within 1s of peer-found / peer-lost. Visible from across the room.
- [ ] **"Tuples from other device" counter:** badge that increments when a tuple with `metadata.source_device_id != self` arrives. Load-bearing affordance for H4 and the on-camera reveal.
- [ ] Preserve `source_device_id` through sync; render it on each tuple card so the audience can see provenance.
- [ ] Verify BLE-only sync (airplane mode + BLE on, Wi-Fi off) on the chosen hardware pair. Record handshake-to-first-tuple-sync latency in `docs/demo/handshake-timing.md`.
- [ ] Verify LAN-only fallback (airplane mode + Wi-Fi to local router only, BLE off) as the demo-day backup transport.

### 6.4 — App scaffolding & UI (folded into 6.2/6.3 timing)

- [ ] iOS SwiftUI screen: device-name banner, mesh-state indicator, query field, "ask" button, top-k tuple cards (large readable typography — audience reads from across the hall), generated-answer panel.
- [ ] Android Compose screen: parity with iOS; side-by-side on camera reads as "two devices, same app."
- [ ] No login, no settings, no onboarding. Cold launch → ready to query.
- [ ] **One-tap reset** button (debug menu): clears synced state without uninstall/reinstall. Demo-day recovery.
- [ ] **One-tap re-seed** button (debug menu): re-runs the seed loader if reset was triggered. Demo-day recovery.

### 6.5 — Holdout execution

**Saturday night (21:00–22:00) — dry-run:**

- [ ] H3 dry-run: meet, snapshot tuple count + top-k for 10 fixed queries; meet again; assert zero change.
- [ ] H4 dry-run: phone A queries for a dish phone B has and A doesn't; expect no relevant top-k. Meet. Re-query; expect B's tuple in top-k.
- [ ] H7 dry-run: airplane mode both devices, Wi-Fi off both devices, attempt the full pipeline end-to-end. Also run the H7 code-path invariant check from §6.2.

**Sunday morning (09:00–12:00) — full pass:**

- [ ] H1 full attempt: single-take recording of airplane-mode toggle + meet + re-query. Repeat until clean take exists.
- [ ] H2 **in-app re-run** with locked production app build (not the spike CLI harness). Confirm parity holds in-app — drift between spike CLI and app process is its own bug.
- [ ] H5 measurement: cold-launch → first-answer × 5 trials on the slowest device. Record p50 + worst-case. **No back-door pass:** if > 10s, execute the remediation playbook below until ≤ 10s. Documentation alone is not a pass.

**H5 remediation playbook (run in order if needed):**
1. Verify weights are mmap'd, not fully loaded into RAM
2. Move LLM init from "after splash" to "during splash"
3. Reduce max-tokens to ~128
4. Shrink LLM from 1.5B to 1B (Gemma 3 1B or SmolLM2 1B variant)

### 6.6 — Audience-survival rehearsal (12:00–15:00, Sun) — H6

- [ ] Generate 20 candidate audience-style queries; have a non-author rank them by "would a random audience member ask this."
- [ ] Run the top 10 against the live demo on the actual phones; mark pass/fail per rubric.
- [ ] If pass rate < 3/5: tune corpus (fill gaps), tune prompt template, or — last resort — swap corpus theme (recipes ↔ cars) and re-seed.
- [ ] Lock corpus state at end of rehearsal; no further corpus edits before demo.

### 6.7 — Presenterm deck (15:00–17:30, Sun)

- [ ] Deck source at `docs/deck/SPRINT-0001-deck.md` (Markdown, Presenterm-compatible).
- [ ] Slide: title + thesis ("Your knowledge base wants to be a CRDT").
- [ ] Slide: why now — local-first + on-device + retrieval is the AI primitive aligned with mesh sync. Cite Kleppmann's seven ideals.
- [ ] Slide: **latency-floor argument** — cloud RTT ≥ 200ms physical floor vs on-device < 100ms.
- [ ] Slide: **Mermaid architecture diagram** — Cactus embed + LLM, Ditto CRDT, BLE/LAN mesh.
- [ ] Slide: `Tuple` document shape (code block).
- [ ] Slide: the moment of magic — annotated still from B-roll showing top-k expanding post-meet.
- [ ] Slide: **future-work four-thread arc** — specialists, preference-aware merge, adversarial filtering, generational evolution. Landing line: *"Family recipes through generations."*
- [ ] Slide: thanks + repo URL + Ditto + Cactus credit.
- [ ] Export to PDF: `presenterm --export-pdf`. Commit `docs/deck/SPRINT-0001-deck.pdf`.

### 6.8 — Demo-day readiness (17:30–18:30, Sun)

- [ ] **B-roll recording** of H1 in a quiet RF environment — fallback for live BLE flakes. Commit at `docs/demo/H1-broll.mp4`.
- [ ] **Second hardware pair** on standby (same models, freshly built apps, factory-toggled airplane mode tested).
- [ ] Rehearse the toggle sequence: airplane on, app open on both, walk into proximity, query, screen-record.
- [ ] Stopwatch the deck dry-run; trim until it fits the hackathon slot.
- [ ] **Single-take H1 capture** committed to `docs/demo/H1-final.mp4`.

---

## 7. Risks & mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| R1 | Cactus iOS↔Android embeddings cosine < 0.999 across all candidate models | Medium | Sprint-critical | Spike A runs first; backend-pin + Q4_K_M quantization-format pin + batch=1 per Thinking Machines guidance. Candidate ladder: Qwen3-Embedding-0.6B → EmbeddingGemma → Nomic → ONNX MiniLM. **Honest-failure rule:** if all miss, switch to non-claiming fallback (do not claim parity in the deck). |
| R2 | 1.5B-class LLM produces incoherent recipe merges | Medium | Demo-critical for recipes corpus | Spike B runs first on slowest device with adversarial fixtures + pinned prompt; 8/10 pass threshold. Cars corpus is hot-swap-ready (schema-identical, pre-authored). |
| R3 | **iOS↔Android mixed BLE pairing** flakes during live demo (same-platform BLE is fine; cross-platform is the actual risk) | Medium | Demo show-stopper | Pre-recorded B-roll; LAN-only rehearsed fallback; second hardware pair on standby; visible mesh-state indicator so operator waits for connect instead of guessing. |
| R4 | Cold-load > 10s on Android | Medium-high | H5 fail | Eager-load during splash; mmap'd weights; shrink LLM to 1B if needed; reduce max-tokens. Hard 10s bar — no back-door pass. |
| R5 | **iOS background-BLE limitation** kills sync if app backgrounded mid-demo | Low (foregrounded demo) | Recoverable | Demo runs foregrounded only; rehearsal includes "don't touch home button"; deck does not claim background sync. |
| R6 | Ditto trial/license terms restrict public-repo redistribution | Low | Repo-publish blocker | Resolved at §6.0 task on Sat morning; fallback is private repo + public writeup. |
| R7 | Audience-pick query falls outside corpus coverage (H6 fail) | Medium | Stage 1 incomplete | Pre-seed corpus broadly; §6.6 rehearsal; H6 bar is ≥ 3/5 (not 5/5) for exactly this reason. |
| R8 | **Cactus wants to own persistence** (`cactus_rag_query` / `cactus_index_*`) and fights Ditto's CRDT store | Medium | Schedule risk | Do NOT use `cactus_rag_query`. Keep Cactus narrow (embed + LLM only); retrieval is our own cosine top-k over the Ditto-materialized array. |
| R9 | RN bindings drift between iOS and Android Cactus packages | Low-medium | Parity bugs | Use Swift package on iOS + Kotlin bindings on Android natively (not React Native) to keep the surface narrow and version-aligned. |
| R10 | Demo is technically correct but not legible to the audience from across the hall | Medium | Stage 1 fail | Large typography on tuple cards, mesh-state badge, "tuples from other device" counter, device-name banner, source-device labels on each tuple. |
| R11 | **Quantization-format drift** (e.g., Q4_K_M on one phone, Q4_0 on the other) silently breaks parity | Low | H2 fail | Pin Q4_K_M exactly in §4 Locked Stack; verify in Gate A `RESULTS.md`. |
| R12 | Spike CLI passes Gate A but full-app re-run fails parity (backend or batch drift between CLI and app) | Medium | Sunday-morning surprise | §6.5 Sunday-morning includes H2 **in-app re-run** with production build, not just trust in spike result. |

---

## 8. Open questions (resolve during sprint)

- [ ] Does Cactus expose Qwen3-Embedding-0.6B through both Swift and Kotlin bindings cleanly? (Verify Sat morning; the candidate ladder accounts for "no" but Qwen3 is the cheapest path.)
- [ ] Does Cactus expose Qwen 2.5 1.5B Instruct through both bindings?
- [ ] What's the exact Q4_K_M file path and download URL we ship with? (Document in `docs/models/manifest.md` after Sat-morning catalog check.)
- [ ] Optional third device — macOS via Flutter? Default: **no**; revisit only if Sunday has runway.

---

## 9. Exit checklist

- [ ] All H1–H7 boxes in §2 are ✅
- [ ] All artifact-gate boxes in §2 are ✅
- [ ] `tools/embedding-determinism/RESULTS.md` committed
- [ ] `tools/merge-eval/RESULTS.md` committed
- [ ] `docs/sprints/SPRINT-0001-decisions.md` committed (chosen models + backend + quantization + corpus + prompt template hash)
- [ ] `docs/deck/SPRINT-0001-deck.pdf` committed
- [ ] `docs/demo/H1-final.mp4` committed (or linked if too large)
- [ ] `docs/demo/H1-broll.mp4` committed as B-roll fallback
- [ ] `docs/demo/hardware.md`, `docs/demo/handshake-timing.md` committed
- [ ] `docs/legal/ditto.md` records the license redistribution resolution
- [ ] Repo README points at SEED.md, the deck, and the demo video
- [ ] Retro stub at `docs/sprints/SPRINT-0001-retro.md` ready for post-sprint fill-in

---

*Stage 0 is a stepping stone, not the destination. The thesis the writeup lands on — specialists not generalists, preference-aware merge, adversarial filtering, generational evolution — is downstream of this sprint, not part of it. Family recipes through generations is the load-bearing analogy, kept for the writeup, not the code.*
