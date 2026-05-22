# SPRINT-0001 — Mesh RAG Stage 0 (Ditto × Cactus)

> *Two devices, airplane mode, BLE handshake, observable state change.*
> Hackathon-weekend sprint. Saturday + Sunday. Deliverable = working iOS + Android repo + Presenterm deck. Stage 0 = generalist small LLM + flat grow-only `RecipeTuple` set; the writeup gestures at the four-thread future-work arc but Stage 0 does not implement it.

Authored: 2026-05-21. Status: planned. Executor: TBD.

---

## 1. Goal

Ship a two-device peer-to-peer RAG demo where the vector index is a Ditto CRDT, embeddings + generation run on-device via Cactus, and the moment of magic is an airplane-mode-toggle on camera. The blog-post-shaped artifact is **working repo + Presenterm deck**; video / writeup are downstream of code-quality and demo legibility.

One-line target: *Phone A returns answer X; phone B walks into BLE range; phone A re-queries and returns X + Y, visibly drawing on phone B's notes — with no network involved.*

## 2. Definition of Done (mapped to SEED holdouts)

The sprint exits when every box below is ✅ on the chosen hardware pair, in a single live take, with the recording in `docs/demo/`:

- [ ] **H1 — Airplane-mode moment of magic.** Live airplane-mode toggle on camera; phone A's query result expands visibly to include phone B's contributions after BLE meet. Single take, no cuts.
- [ ] **H2 — Cross-platform embedding parity.** `cactus_embed("chicken tortilla soup")` on iOS vs Android produces cosine ≥ 0.999 (target: bitwise-identical) on at least 20 representative recipe strings.
- [ ] **H3 — Sync idempotence.** Re-meet with no changes → zero new tuples, top-k unchanged for a fixed query set of 10.
- [ ] **H4 — Bidirectional merge.** A's notes appear in B's index and vice versa, demonstrable via a query whose top-k pre-meet lives only on the *other* device.
- [ ] **H5 — Cold-load latency.** On the slowest target device, app-launch → first-answer rendered < 10s. Measured 5× and recorded.
- [ ] **H6 — Audience-survivable Stage 1.** Audience-picked free-text query → coherent LLM answer that visibly references retrieved tuples; passes for ≥ 3/5 attempts on ~50 notes/device.
- [ ] **H7 — End-to-end offline.** Wi-Fi off, cellular off, only BLE/LAN; full pipeline runs.

Plus the artifact gates:

- [ ] Repo builds cleanly from scratch on a fresh macOS + Android Studio.
- [ ] Presenterm deck exports to PDF and contains the "before sync / after sync" reveal.
- [ ] One pre-recorded backup capture of H1 exists as B-roll in case BLE flakes mid-presentation.

## 3. Scope boundaries

**In scope (Stage 0):**
- Generalist small LLM (1B–3B class) running on-device on both platforms via Cactus.
- One embedding model running on-device on both platforms via Cactus.
- Flat float32 array cosine top-k over the locally-materialized Ditto query result (no HNSW, no sqlite-vec).
- `RecipeTuple { id, text, embedding[], metadata }` as a single Ditto collection.
- BLE + LAN transports both enabled; no big-peer, no internet.
- Recipes corpus, ~50 notes/device. Cars corpus as a hot-swappable fallback.
- Presenterm deck (Markdown source).

**Explicitly out of scope:**
- [ ] *(intentionally blank — these items are NOT being done)*
- Cloud fallback or Cactus hybrid mode.
- Arbitrary document ingestion (PDF/EPUB/archives). Only hand-curated text recipes.
- Multi-user identity, auth, access control.
- Persistent chat history.
- Streaming token output.
- Settings panels, polished error toasts, multi-screen UI.
- Web/desktop clients (optional macOS via Flutter only if Sunday has runway).
- HNSW, sqlite-vec, USearch (flagged as escape hatch, not built).
- Preference-aware merge, adversarial filtering, generational evolution (future-work arc; writeup-only).

## 4. Stack — locked vs gated

**Locked (non-negotiable):**
- Sync + storage: **Ditto SDK** (Swift + Kotlin), BLE + LAN transports.
- Embedding + LLM runtime: **Cactus** (Swift + Kotlin bindings), GGUF/Q4 quantized weights, same backend tier on both phones (lean CPU/Vulkan, pin away from ANE/Hexagon vendor paths for parity).
- Vector search: flat float32 array cosine top-k. No ANN at Stage 0.
- Deck: **Presenterm** (Markdown).

**Gated by the two empirical spikes (decision by mid-Day-1):**
- Embedding model: **EmbeddingGemma 300M** if Cactus exposes it cleanly to both Swift and Kotlin with cosine ≥ 0.999. Fallback: **Nomic Embed Text v1.5** (Apache-2.0, cleanest license, already in Cactus catalog). Floor: **all-MiniLM-L6-v2** only if both fail parity.
- Small LLM: **Qwen 2.5 1.5B Instruct** (Apache-2.0, in Cactus catalog) as default. Backup: **SmolLM2 1.7B Instruct** if Cactus loads it. Quality-reach: **Gemma 3 1B IT** if 1.5B class fails merge eval.
- Corpus: **recipes** if the small-LLM merge eval clears the bar. **Cars** if not. Corpus shape is identical, so swap is cheap.

## 5. Sequencing

```
Day 1 Saturday
├─ 09:00–09:30  Sprint kickoff, hardware setup, repo init        (§6.0)
├─ 09:30–12:30  PARALLEL gates (both must finish by lunch)        (§6.1)
│   ├─ Spike A: Embedding determinism (cosine ≥ 0.999)
│   └─ Spike B: Recipe-merge LLM eval (5–10 fixtures, 3 models)
├─ 12:30–13:00  GATE DECISION: corpus = recipes|cars, models locked
├─ 13:00–18:30  Main pipeline build (parallel iOS/Android)        (§6.2)
├─ 18:30–21:00  Mesh sync wiring + two-device meet UX              (§6.3)
└─ 21:00–22:00  Mid-sprint holdout dry-run (H3, H4, H7)            (§6.5)

Day 2 Sunday
├─ 09:00–12:00  Holdout pass + cold-load tuning (H1, H2, H5)      (§6.5)
├─ 12:00–15:00  Audience-query rehearsal + corpus tuning (H6)     (§6.6)
├─ 15:00–17:30  Presenterm deck + B-roll backup recording         (§6.7)
└─ 17:30–18:30  Final rehearsal, single-take H1 capture           (§6.8)
```

The two empirical gates run BEFORE the main pipeline because corpus-or-fallback decisions need to be in hand by lunch; building the pipeline first and then discovering ingredient-merging is incoherent at 1.5B costs a half-day.

## 6. Tasks

### 6.0 — Kickoff & repo skeleton

- [ ] Choose hardware pair: confirm exact iOS device (model + iOS version) and exact Android device (model + Android version); record both in `docs/demo/hardware.md`.
- [ ] Bootstrap monorepo skeleton: `apps/ios/`, `apps/android/`, `shared/corpus/`, `tools/embedding-determinism/`, `tools/merge-eval/`, `docs/demo/`, `docs/deck/`.
- [ ] Add Cactus dependency to iOS (Swift package) — version-pin in `apps/ios/Package.swift`.
- [ ] Add Cactus dependency to Android (Kotlin / Gradle) — version-pin in `apps/android/build.gradle.kts`.
- [ ] Add Ditto SDK to iOS — version-pin, BLE + LAN transports enabled, no big-peer, no cloud.
- [ ] Add Ditto SDK to Android — version-pin, BLE + LAN transports enabled, no big-peer, no cloud.
- [ ] Resolve Ditto trial/license terms for a public hackathon-repo redistribution — note resolution in `docs/legal/ditto.md`.
- [ ] Add `.gitignore` entries for downloaded model weights; document model-fetch script.
- [ ] Write `README.md` stub: one-line thesis, link to SEED.md, link to research index, run instructions.

### 6.1 — Empirical gates (PARALLEL, must finish by 12:30 Day 1)

#### Spike A — Embedding determinism (cosine ≥ 0.999)

- [ ] Pick 20 representative recipe-domain strings (mix of short titles, ingredient lists, prose steps); commit to `tools/embedding-determinism/fixtures.json`.
- [ ] iOS CLI harness: `cactus_embed(fixture)` → write `{ id, vector[] }` JSON to file, transferable off-device.
- [ ] Android CLI harness: same shape, same fixture order.
- [ ] Cross-device diff tool: load both JSONs, print first 8 vector components per fixture side-by-side, compute cosine + L2 per pair, summary stats.
- [ ] Pin Cactus backend to CPU/Vulkan path on both devices (away from ANE/Hexagon) to maximize parity per Thinking Machines batch-invariance guidance.
- [ ] Force batch-size 1 / single-sample inference path on both platforms.
- [ ] Run with **EmbeddingGemma 300M** first; record mean / min / max cosine across the 20 fixtures.
- [ ] If EmbeddingGemma cosine < 0.999 anywhere: re-run with **Nomic Embed Text v1.5**; record again.
- [ ] If both < 0.999: re-run with **all-MiniLM-L6-v2** (ONNX path) as deterministic floor.
- [ ] Write `tools/embedding-determinism/RESULTS.md`: chosen model, min cosine, parity decision (PASS / FALLBACK / FAIL), evidence.

#### Spike B — Recipe-merge LLM eval

- [ ] Curate fixture set: 5 dishes × 3 variant recipes each (chicken tortilla soup, banana bread, carbonara, chana masala, miso soup) in `tools/merge-eval/fixtures/`.
- [ ] Define eval rubric in `tools/merge-eval/rubric.md`: coherent ingredient list (no contradictions, no hallucinated ingredients), preserved provenance ("Alice's adds avocado"), readable instructions.
- [ ] iOS / desktop harness that loads a Cactus model + prompts: "Synthesize a single coherent recipe from these N variants, preserving provenance for divergent ingredients."
- [ ] Run with **Qwen 2.5 1.5B Instruct**; score 5 fixtures against rubric; record latency.
- [ ] Run with **Gemma 3 1B IT**; score, record.
- [ ] Run with **SmolLM2 1.7B Instruct** if Cactus loads it; score, record.
- [ ] Write `tools/merge-eval/RESULTS.md`: pass/fail per model per fixture, chosen model, **corpus decision: recipes vs cars**.

#### Gate decision (12:30 Day 1)

- [ ] Update `docs/sprints/SPRINT-0001-decisions.md` with: chosen embedding model, chosen LLM, corpus = recipes | cars, backend pin, justification.
- [ ] If corpus = cars: swap `shared/corpus/recipes/` for `shared/corpus/cars/` and update fixture references — schema is identical so no code changes required downstream.

### 6.2 — Main pipeline (Day 1 afternoon)

#### Data model & corpus

- [ ] Define `RecipeTuple` Ditto document shape: `{ _id: string, text: string, embedding: float32[], metadata: { source_device_id, created_at, title?, tags? } }`.
- [ ] Decide embedding storage strategy: inline `float32[]` in the Ditto Map document for Stage-0 simplicity (≤5k tuples × 384 dims = ≤7.7 MB; well under any reasonable per-doc limit at our scale). Document this choice + the escape hatch in `docs/design/storage.md`.
- [ ] Author seed corpus: 50 hand-curated recipe notes on phone A, 50 on phone B, with deliberate overlap on 3 dishes (so H4 has known cross-device top-k targets). Commit to `shared/corpus/seed/A.json` and `shared/corpus/seed/B.json`.
- [ ] Write a corpus loader (each platform) that ingests `shared/corpus/seed/<device>.json` on first run only; subsequent runs are no-ops.

#### Retrieval

- [ ] Implement local retrieval in Swift: load all `RecipeTuple` embeddings into a flat `[Float]` array on subscription update; cosine top-k = brute-force loop. No persistence layer of its own — just an in-memory mirror of the Ditto query result.
- [ ] Implement the same in Kotlin: identical shape, identical cosine formula, identical normalization (L2-normalize at insertion time so retrieval is dot-product only — match Cactus' normalized-embedding contract).
- [ ] Define top-k retrieval API per-platform: `func retrieve(query: String, k: Int = 5) -> [RecipeTuple]`.
- [ ] Unit test: seed 10 tuples with known clusters, assert top-k returns the right cluster on both platforms (parity test, not just correctness).

#### Generation

- [ ] Define prompt template for "answer using retrieved recipes": query + top-k tuples concatenated with provenance, instruction to cite which retrieved note(s) the answer draws from.
- [ ] Wire Cactus LLM init on iOS: model load on app launch (eager, not lazy — for H5 latency), cache to disk, warm prompt once.
- [ ] Wire Cactus LLM init on Android: same eager-load shape, same warm prompt.
- [ ] Implement `generate(query, retrieved) -> String` per platform; non-streaming output; bounded max-tokens (~256) to keep latency tight.
- [ ] Render answer in the UI alongside the retrieved-tuple cards so the audience can see *which* notes the model used.

### 6.3 — Mesh sync & meet UX (Day 1 evening)

- [ ] Configure Ditto sync subscription: subscribe to all `RecipeTuple` documents; verify subscription auto-rebuilds when new tuples arrive.
- [ ] Mesh-state indicator UI: icon + peer count, updates within 1s of peer-found / peer-lost events; visible in the demo without zoom.
- [ ] "Tuples seen from other device" counter: small badge that increments when a tuple with `metadata.source_device_id != self` arrives. This is the load-bearing affordance for H4 and for the on-camera reveal.
- [ ] Verify BLE pairing works between the chosen iOS device and Android device with no internet — record handshake latency in `docs/demo/handshake-timing.md`.
- [ ] Test LAN-only fallback: airplane mode + Wi-Fi to the same router only (BLE off) — confirm sync still works as the demo-day backup transport.
- [ ] Test BLE-only: airplane mode on, Wi-Fi off — confirm sync still works (this is what the live demo will actually use).

### 6.4 — App scaffolding & UI

- [ ] iOS SwiftUI screen: device-name banner, mesh-state indicator, query text field, "ask" button, top-k tuple cards, generated answer panel.
- [ ] Android Compose screen: same shape, same affordances, visually similar enough that side-by-side on camera reads as "two devices same app."
- [ ] Large readable typography — the audience needs to read tuple text from across a hackathon hall.
- [ ] No login, no settings, no onboarding. Cold launch → ready to query.

### 6.5 — Holdout execution (Day 1 night dry-run, Day 2 morning full pass)

- [ ] H3 dry-run: meet, take a snapshot of tuple count + top-k for 10 fixed queries; meet again; assert no change.
- [ ] H4 dry-run: phone A queries for a dish phone B has and A doesn't; expect no relevant top-k. Meet. Re-query; expect B's tuple in top-k. Record before/after on video.
- [ ] H7 dry-run: airplane mode both devices, Wi-Fi off both devices, attempt the full pipeline end-to-end.
- [ ] H1 full attempt: single-take recording of airplane-mode toggle + meet + re-query. Repeat until clean take exists.
- [ ] H2 full re-run with the locked production model + production app build (not the spike CLI) to confirm parity holds in-app.
- [ ] H5 measurement: cold-launch → first-answer × 5 trials on the slowest device. Record p50 and worst-case.
- [ ] If H5 > 10s: tune. Options: (a) shrink LLM to 1B, (b) verify mmap'd weight load, (c) pre-warm during splash, (d) reduce max-tokens further.
- [ ] If H2 < 0.999 in-app despite spike passing: investigate batch-size drift or backend-selection drift between the CLI and app processes.

### 6.6 — Audience-survival rehearsal (H6)

- [ ] Generate 20 candidate audience-style queries; have a non-author teammate rank them by "would a random audience member ask this."
- [ ] Run the top 10 against the live demo on the actual phones; mark pass/fail per the SEED rubric ("coherent answer that visibly references retrieved notes").
- [ ] If pass rate < 3/5: tune corpus (add notes to fill gaps), tune prompt template, or — last resort — swap corpus theme to cars and re-seed.
- [ ] Lock the corpus state at end of rehearsal; no further corpus edits before demo.

### 6.7 — Presenterm deck

- [ ] Deck source at `docs/deck/SPRINT-0001-deck.md` (Markdown, Presenterm-compatible).
- [ ] Slide: title + thesis ("Your knowledge base wants to be a CRDT").
- [ ] Slide: why now — local-first + on-device + retrieval is the AI primitive that wants to be mesh-synced. Cite Kleppmann's seven ideals.
- [ ] Slide: latency-floor argument (cloud RTT ≥ 200ms physical floor vs on-device <100ms). Use the composite from the research index.
- [ ] Slide: architecture diagram (Mermaid) — Cactus embed + LLM, Ditto CRDT, BLE/LAN mesh.
- [ ] Slide: `RecipeTuple` document shape (code block).
- [ ] Slide: the moment of magic — image / annotated still from B-roll showing top-k expanding post-meet.
- [ ] Slide: future-work four-thread arc (specialists, preference-aware merge, adversarial filtering, generational evolution) — landing-line is "family recipes through generations."
- [ ] Slide: thanks + repo URL + Ditto + Cactus credit.
- [ ] Export to PDF via Presenterm; commit `docs/deck/SPRINT-0001-deck.pdf`.

### 6.8 — Demo-day readiness

- [ ] B-roll recording of H1 in a controlled setting (room with no RF noise) — fallback for live BLE flakes.
- [ ] Second hardware pair on standby (same models, freshly built, factory-toggled airplane mode tested).
- [ ] Rehearse the toggle sequence: airplane on, app open on both, walk into proximity, query, screen-record.
- [ ] Dry-run the deck with a stopwatch; trim slides until the talk fits the hackathon slot.
- [ ] Single-take H1 capture committed to `docs/demo/H1-final.mp4`.

## 7. Risks & mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| R1 | Cactus iOS↔Android embeddings cosine < 0.999 across both candidate models | Medium | Sprint-critical | Spike A runs first; backend-pin to CPU/Vulkan + force batch=1; fall back to all-MiniLM ONNX deterministic path. If still failing, accept ≥ 0.99 and document the gap. |
| R2 | 1.5B-class LLM produces incoherent recipe merges | Medium | Demo-critical for recipes corpus | Spike B runs first; cars corpus is a hot swap (identical schema). |
| R3 | BLE pairing flakes during live demo | Medium | Demo show-stopper | Pre-recorded B-roll; LAN-only rehearsed fallback; second hardware pair on standby. |
| R4 | Cold-load > 10s on Android | Medium-high | H5 fail | Eager-load during splash; mmap'd weights; shrink LLM to 1B if needed; pre-bake KV-cache on a no-op prompt. |
| R5 | iOS background-BLE limitation kills sync if app backgrounded mid-demo | Low (foregrounded demo) | Recoverable | Demo runs foregrounded only; no background-sync claim in the deck. |
| R6 | Ditto trial/license terms restrict public repo redistribution | Low | Repo-publish blocker | Resolved on Day 1 morning (task in §6.0); fallback is a private repo + public writeup. |
| R7 | Audience-pick query falls outside corpus coverage (H6 fail) | Medium | Stage 1 fail; ship Stage 0 only | Pre-seed corpus broadly; rehearse §6.6; H6 is `≥ 3/5` not `5/5` for exactly this reason. |
| R8 | Cactus + Ditto integration friction (Cactus wants to own persistence) | Medium | Schedule risk | Mitigate by NOT using `cactus_rag_query`; do retrieval ourselves over the Ditto-materialized array. Cactus is narrow: embed + LLM only. |
| R9 | RN bindings drift between iOS and Android Cactus packages | Low-medium | Parity bugs | Use the Swift package on iOS and Kotlin bindings on Android natively, not React Native, to keep the surface narrow and version-aligned. |
| R10 | We ship a demo that works but isn't legible to the audience | Medium | Stage 1 fail | Large typography, named tuple cards, mesh-state badge, "from other device" counter — all explicit affordances for legibility. |

## 8. Open questions (to resolve before / during sprint)

- [ ] Confirm Cactus exposes EmbeddingGemma 300M via both Swift and Kotlin bindings (model catalog check on Day 1 morning).
- [ ] Confirm Cactus exposes Qwen 2.5 1.5B Instruct via both Swift and Kotlin bindings.
- [ ] Confirm Ditto SDK trial terms permit the public-repo redistribution shape.
- [ ] Decide whether the macOS optional third device adds enough story to the deck to justify the extra build target (default: no; only if Sunday has runway).

## 9. Exit checklist (run before declaring sprint done)

- [ ] All H1–H7 boxes in §2 are ✅.
- [ ] All artifact-gate boxes in §2 are ✅.
- [ ] `tools/embedding-determinism/RESULTS.md` and `tools/merge-eval/RESULTS.md` committed.
- [ ] `docs/sprints/SPRINT-0001-decisions.md` committed.
- [ ] `docs/deck/SPRINT-0001-deck.pdf` committed.
- [ ] `docs/demo/H1-final.mp4` committed (or linked if too large for git).
- [ ] Repo README points at SEED.md, the deck, and the demo video.
- [ ] Retro stub at `docs/sprints/SPRINT-0001-retro.md` ready for post-sprint fill-in.

---

*Stage 0 is a stepping stone, not the destination. The thesis the writeup lands on — specialists not generalists, preference-aware merge, adversarial filtering, generational evolution — is downstream of this sprint, not part of it. Family recipes through generations is the load-bearing analogy, kept for the writeup, not the code.*
