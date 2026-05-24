---
title: Build the Mesh RAG demo (Ditto × Cactus, iOS + Android)
type: feat
status: active
date: 2026-05-23
origin: _docs/SEED.md
---

# Build the Mesh RAG demo (Ditto × Cactus, iOS + Android)

## Summary

Build a Flutter mesh-RAG demo where two phones (iOS + Android) keep a shared `StudyNote` corpus (`topic, body, contributor, tags, embedding, createdAt, …`) as a grow-only CRDT in Ditto, embed and answer locally with Cactus, and meet over BLE so each device's next query can draw on the other's notes — no internet, no central index. Stage 0 ships CRDT vector sync + retrieval; Stage 1 layers a streaming flashcard generator with per-card source attribution. The plan is research-anchored: every load-bearing technical decision (embedding model, LLM choice, vector-search shape, Ditto transport config, determinism gate, reference architectures) cites the 281-source research index at `_docs/research/index/` (top-N entries, clusters, per-source IDs).

---

## Problem Frame

RAG today assumes a centralized vector store: every corpus is uploaded, indexed server-side, and queried over the network. That breaks local-first — no offline, no composition across devices without a sync server, all corpus content routed through a third-party operator. The demo's existence proof is that the vector-index shape (grow-only set of `(embedding, payload)` tuples whose retrieval is a local function over the set) is a clean CRDT fit for AI: two phones in airplane mode, meeting briefly over BLE, leave with the union of each other's corpora and can answer questions neither could before. Secondary use: a co-marketing story positioning Ditto's mesh-sync primitive and Cactus's cross-platform packaging as a reference architecture for edge AI that composes across devices. See `_docs/SEED.md` for full framing, validation harness, and threat-model bound.

---

## Requirements

Carried verbatim from `_docs/SEED.md` Holdout Scenarios — each is a gate the loop runs against until green:

- **R1 (Holdout 1).** Airplane-mode moment of magic: Phone A answers from local corpus alone; demonstrator toggles airplane mode + re-enables BT; Phone B comes into BLE range; Phone A re-queries and returns A's answer + B's contribution, citing the retrieved note IDs from the other phone. Corpora are disjoint-by-design so at least one rehearsed query has zero hits in A and ≥1 hit in B.
- **R2 (Holdout 2).** Cross-platform embedding determinism: for ≥95% of N rehearsed queries, same query against same combined corpus returns same top-k ordering on iOS and Android. Cosine reported as a diagnostic; ordering is the gate.
- **R3 (Holdout 3).** Sync idempotence: re-meeting after no changes produces no duplicate tuples and no change to top-k.
- **R4 (Holdout 4).** Bidirectional merge: notes pushed from A appear in B's index and vice versa, observable through queries whose nearest neighbors live on the other device.
- **R5 (Holdout 5).** Cold-load latency: on the slowest target device, app launch → first answer (embed + retrieve + generate) ≤ ~10s end-to-end.
- **R6a (Holdout 6a).** Rehearsed coherence: 5 of 5 rehearsed queries against the combined corpus produce a coherent buffered LLM answer that visibly references the retrieved notes.
- **R6b (Holdout 6b, stretch).** Free-text audience survival: ≥3 of 5 audience-chosen queries produce coherent answers. Not exit-blocking; included in the recorded artifact only if clean.
- **R7 (Holdout 7).** End-to-end offline: full demo runs with Wi-Fi off, cellular off; BLE remains on after the airplane-mode toggle described in R1.
- **R8 (Holdout 8 — narrative pickup, deferred).** Three independent readers of the writeup draft can, unprompted, articulate (i) what role Ditto plays, (ii) what role Cactus plays, (iii) why mesh changes the RAG story. Out of scope for this build plan; handled by the writeup follow-up.
- **R9 (thesis preservation).** "Your knowledge base wants to be a CRDT" survives end-to-end: the grow-only set semantic is observable in the demo, the retrieval pure-function-over-set property is provable in code, and nothing in the build cheats the cloud back in (no Cactus hybrid mode, no remote vector store, no internet-required path).
- **R10 (heterogeneous mobile).** iOS + Android both required (iOS + macOS does not satisfy the mobile-edge claim).
- **R11 (Stage 0 ship-survivability).** Under the cut order in SEED.md, Stage 0 (CRDT vector sync + retrieval, no LLM generation) is a valid ship if the loop runs out of time before Stage 1's R6a clears. Holdout 7 (offline) must never be cut.

**Origin actors:** demonstrator (single human running the demo); audience (passive viewer in Stage 0, query author in R6b stretch); reviewer (writeup pre-publish reader, gates R8).
**Origin flows:** F1 = corpus authorship + preload; F2 = local query → embed → retrieve → answer (Stage 0); F3 = same + buffered LLM generation (Stage 1); F4 = airplane-mode + BLE-pair → mesh sync → combined-corpus re-query (R1); F5 = recorded artifact production.
**Origin acceptance examples:** AE1 (covers R1, R4) = "Phone A queries 'Jupiter's moons', returns A's two notes; airplane on, BT on, B in range; A re-queries, returns A's two + B's one, citing all three IDs." AE2 (covers R2) = "identical fixture string embedded on both phones via same GGUF + Q4 + CPU backend yields top-k order match ≥95% on 20 rehearsed queries." AE3 (covers R3) = "re-meet with no edits → tuple count unchanged, top-k for fixture-query unchanged." AE4 (covers R5) = "cold start on slowest target → first answer ≤ 10s wall-clock." AE5 (covers R6a) = "rehearsed query 'what do we know about Jupiter's moons?' produces a buffered paragraph that names the note IDs A2 and B3 inline."

---

## Scope Boundaries

- Cloud fallback / Cactus hybrid mode — never. Thesis breaks if the cloud is back in the trust boundary.
- Document ingestion plumbing for arbitrary file types (PDFs, EPUBs, archives) — Stage 2, follow-on seed.
- Multi-user identity, authentication, access control on the synced corpus — explicitly out per SEED threat-model bound. The demo discloses this in the writeup.
- Persistent chat history — irrelevant to the RAG-as-CRDT thesis.
- Production-grade UI polish, settings panels, error toasts.
- Web/desktop clients beyond the demo machine (one optional macOS via Flutter; no browser client).
- Adversarial filtering, preference-aware merge, specialist routing, generational evolution — the four-thread future-work arc in `_docs/research/index/open-questions.md`. Stage 0 ships the flat grow-only union; the writeup gestures at all four threads.

### Deferred to Follow-Up Work

- The writeup itself (post + reviewer pass + R8 narrative-pickup test) — separate plan once the demo's recorded artifact is in hand.
- HNSW-under-concurrent-CRDT-insert correctness analysis — publishable paper lives there, but flat-array brute-force sidesteps it for ≤5k tuples; revisit only if Stage 0 corpus grows past that.
- Cactus + Ditto integration shape decision: do we use `cactus_index_t` (Cactus owns the index) or our own cosine top-k over the materialized Ditto query result? Default in this plan is the latter (keep Cactus narrow to embed + LLM); revisit if Cactus' `cactus_rag_query` proves significantly faster or cleaner.

---

## Context & Research

### Relevant Code and Patterns

- **`_docs/research/index/top-N.md`** — 22 must-read sources, ranked. Reads list for any implementer joining: #1 Thinking Machines determinism paper; #2 Cactus engine FFI docs; #3 Ditto delta-state CRDTs blog; #4–5 Local-First manifesto + Onward!; rest cluster around mesh, embedding, and small-LLM choice.
- **`_docs/research/index/clusters.md`** — 13 narrative clusters. C1 = case for on-device, C3 = Ditto, C5 = Cactus + LLM runtimes, C6 = determinism, C7 = specialists, C8 = distributed/decentralized RAG, C9 = vector search. Per the README's "How to navigate": building the demo = C3 + C5 + C9 first.
- **`_docs/research/index/_per_source/`** — 281 per-source files. Below references the IDs that matter for the build:
  - **`paper-1106.4374`** — Shapiro et al., G-Set CRDT foundations. R9 thesis citation.
  - **`paper-2403.12844`** — MELTing Point mobile-LLM benchmark. Latency floor argument (used in writeup; informs R5 budget).
  - **`paper-2507.01079`** — MobileRAG (EcoVector + SCR). Closest published on-device RAG measurement; 1.7×–8.9× retrieval-latency win over baselines.
  - **`paper-2505.00443`** — Distributed RAG (DRAG). Closest neighbor to our thesis but overlay-routed (not CRDT-merged); gap is what we fill.
  - **`paper-2504.06135`** — SHIMI. Decentralized hierarchical memory with explicit CRDT-style merging; server-class peers, not phones; we adapt the merge idea to BLE-mesh + phone-class.
  - **`paper-2509.20354`** — EmbeddingGemma 300M model card. Embedding-candidate reference (see Key Technical Decisions for the chosen slug).
  - **`paper-2402.01613`** — Nomic Embed v1.5. Backup embedding (Apache-2.0, cleanest license).
  - **`article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference`** — Horace He et al. The batch-invariance recipe for R2 determinism. Single most load-bearing source for the holdout.
  - **`article-ditto-blog-dittos-delta-state-crdts`** — Ditto's HLC + dot-tagged-tree CRDT model. Read before designing the tuple document.
- **Reference implementations** (top 3, points implementers at runnable patterns):
  1. `_inspiration/repos/software-mansion-labs__react-native-rag/` — modular Embeddings / VectorStore / LLM seam shapes. Copy the interface boundaries even though backed by Cactus instead of an external runtime.
  2. `_inspiration/repos/deepsense-ai__edge-slm/` — real Android-native RAG pipeline (llama.cpp backend, Phi-2/Gemma/TinyLlama at 1B–3B). Closest mature reference for "everything-on-device RAG, no Ditto."
  3. `_inspiration/repos/ramanujammv1988__edge-veda/` — Flutter on-device RAG with dual-model (separate embedder + generator), semantic chunking, streaming-answer-with-source-attribution UX. Source-attribution UX is exactly R6a's note-ID display requirement.
  - Honorable mention: `_inspiration/repos/permissionlesstech__bitchat/` and `_inspiration/repos/permissionlesstech__bitchat-android/` for the "you are in mesh with N peers" affordance and BLE foreground-only ergonomics (informs R1's choreography).
  - The Cactus example code lives at `_inspiration/cactus-compute/cactus/`, `cactus-flutter/`, and `cactus-react-native/`.
- **Flutter project layout.** Platform scaffolding under `android/` and `ios/` is produced by `flutter create` and then preserved — `flutter create .` is not re-run after the project exists (it may overwrite `AppDelegate.swift` / `MainActivity.kt`). `flutter pub get` is the canonical (re-)registration step: it regenerates `ios/Runner/GeneratedPluginRegistrant.swift` and its Android equivalent whenever the plugin set changes. Dart SDK `^3.8.0`, Android `compileSdk = 35`, `ndkVersion = "27.0.12077973"`, `minSdk = 24`, JDK 11. The Flutter SDK version is taken from the local toolchain — no `flutter:` constraint is written into `pubspec.yaml`. The pubspec declares 9 plugins (`cactus`, `ditto_live`, `device_info_plus`, `objectbox_flutter_libs`, `package_info_plus`, `path_provider_foundation`, `permission_handler_apple`, `record_ios`, `shared_preferences_foundation`); iOS plugin registration is Swift-based via `ios/Runner/AppDelegate.swift` calling `GeneratedPluginRegistrant.register(with: self)`.

### Institutional Learnings

- None at `_docs/solutions/` (directory does not exist on this change).

### External References

External research already lives in `_docs/research/{claude,codex,gemini,claude-deep-research,chatgpt-deep-research,gemini-deep-research}.md` (six independent passes). The plan does not duplicate them — citations above point directly at the per-source files those passes produced.

---

## Key Technical Decisions

- **Embedding model = Cactus-packaged `qwen3-0.6` (Qwen3 0.6B, chat-tuned — exposes the embedding head).** EmbeddingGemma 300M was attempted; the Cactus Flutter 1.3.0 catalog cannot fetch `qwen3-embedding-0.6` (download fails with "Failed to get model qwen3-embedding-0.6") and the dedicated embedding slugs the engine docs list are not yet resolvable by the Flutter SDK. `qwen3-0.6` is the chat-tuned fallback that exposes the embedding head and clears the cosine-parity gate on the rehearsed fixtures. Quantization / backend / batch are whatever the slug ships with — Cactus does not currently expose runtime knobs for those in the Flutter SDK. (Citations: `paper-2509.20354`, `paper-2402.01613`, `article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference`.)
- **LLM = Cactus-packaged `qwen3-1.7` (Qwen3 1.7B Instruct).** `qwen3-0.6` produced incoherent flashcards at ~600M, so the completion path uses the 1.7B slug. Apache-2.0 license. Quantization is whatever the Cactus slug ships (not currently selectable from the Flutter SDK). Backup considered: SmolLM2 1.7B Instruct (also Apache-2.0). Avoid Llama 3.2 as primary for a public repo (Llama Community License requires "Built with Llama" + name-prefix attribution). (Citations: `paper-2403.12844`, top-N entries on Qwen / SmolLM2 / Phi-3.)
- **Vector search = flat float32 array + brute-force cosine top-k over materialized Ditto query result.** At ≤5k tuples × 384 dims = 7.7 MB, brute force is exact-recall, sub-millisecond, trivially CRDT-friendly (no index state to merge), and sidesteps the HNSW-concurrent-insert correctness problem documented in `paper-2407.07871`. Escape hatch (deferred): swap to USearch with native Swift+Kotlin bindings if corpus crosses 10k tuples. Not sqlite-vec — Ditto already provides the persistence layer; sqlite-vec on top would duplicate state.
- **Deterministic top-k tie-breaking: sort by `(score desc, _id asc)`.** Tied cosine scores otherwise produce nondeterministic top-k ordering across devices (and across reruns on the same device), which directly fails R2's ordering-agreement gate even when the embeddings themselves are bitwise-identical. The tie-break rule is load-bearing for R2 and R3 (idempotence), not just an implementation nicety — pinned in `lib/services/retrieval_service.dart` (`topK`) as an invariant, not a heuristic. UUIDv5 strings are lexicographically comparable, so `_id asc` is well-defined for any tuple pair.
- **Tuple shape = `{ _id: UUIDv5, topic: string, contributor: string, body: string, tags: List<string>, embedding: List<double>, createdAt: ISO-8601 string, acceptedBy: List<string>, originalNoteId: string, originalContributor: string }`, stored as a Ditto v5 DQL Document in collection `notes`.** `_id` is UUIDv5 over `(contributor, topic, createdAt)` so re-running the seed loader is a no-op (same input → same id; Ditto's `ON ID CONFLICT DO UPDATE` finishes the job). `contributor` doubles as the author-device identifier (e.g. `phone-a`). `acceptedBy` is an application-layer OR-Set the UI uses for cross-device "save peer's note" acceptance (Stage 0.5). `embedding` is stored as `List<double>` and converted to `Float32List` on the hot path in `RetrievalService.topK`. `originalNoteId` / `originalContributor` are carried for compatibility with documents authored by the fork-clone predecessor of the acceptance OR-Set. `D` (embedding length) is whatever `qwen3-0.6`'s embedding head returns at runtime; the code does not assert D at compile time — `topK` drops any document whose embedding length differs from the query's, so a model swap is contained at the query boundary instead of crashing the corpus. Ditto v5 uses DQL-addressable documents (no v4-style Map/Register typed-CRDT distinction); the embedding still merges by delta-state propagation but the application code does not choose a CRDT type per field. Insert is the only mutation; delete is out of scope for Stage 0. (Citation: `article-ditto-blog-dittos-delta-state-crdts`.)
- **Ditto transport config: BLE + LAN on both platforms + AWDL on iOS/macOS only; no Wi-Fi Aware (Android); no big-peer; no internet.** `sync.start()` aggressively explores all enabled transports per Ditto's mesh-networking-101 docs. AWDL activates alongside BLE on iOS for higher throughput when peers are close enough; BLE remains the "moment of magic" transport for the airplane-mode demo. Wi-Fi Aware is deliberately *not* enabled in Stage 0 — the BLE/LAN/AWDL trio meets every holdout on the chosen device pair, and turning on Wi-Fi Aware expands the Android permission surface without earning a demo-day capability. (Citation: clusters.md C3.)
- **Determinism gate fires BEFORE the build loop.** U1 (the Cactus iOS↔Android cosine-parity CLI harness) runs against a fixed 20-query fixture. If top-k order agreement < 95% on the chosen model + quantization + backend triple, the SEED's cut order pivots us to brainstorm option C ("Narrate the mesh"). The plan does not assume the gate passes; U1 is the load-bearing pre-flight.
- **No Cactus `cactus_index_t` / `cactus_rag_query` in Stage 0.** Keep Cactus narrow: just `cactus_embed` and the LLM inference call. Retrieval lives in Dart, over the materialized Ditto query result. Avoids fighting Cactus' index-owns-persistence shape against Ditto's CRDT-owns-persistence shape. (Citation: `paper-2509.20354` cross-ref; clusters.md C5/C9 contrast.)
- **Streaming LLM generation in Stage 1.** `CactusService.complete(messages, maxTokens: …)` returns `Stream<String>`; `RetrievalService.generateFlashcards` wraps it as a discriminated `FlashcardEvent` stream (`retrieved`, `partial(chunk)`, `cards(parsed)`, `done()`). The chunk-render UX gives the audience visible-progress feedback during the ~10–30s generation window; parsed cards still land in one shot on `cards`, which satisfies R6a's coherence-with-citations spirit. A non-streaming `completeAll` exists for evals/tests but is not on the UI hot path.
- **Plan respects SEED.md's cut order under time pressure.** Implementation units are ordered so that under any forcing function, dropping in SEED's cut order (macOS → polish → corpus pre-screening → R6b → R6a → R7) corresponds to dropping units from the tail. R7 is never cut. R1 + R2 + R3 + R4 + R5 + R7 = Stage 0 ship; add R6a for Stage 1.

---

## Open Questions

### Resolved During Planning

- **Embedding model.** Cactus `qwen3-0.6` (chat-tuned slug that exposes the embedding head). Rationale above.
- **LLM choice.** Cactus `qwen3-1.7` (Qwen3 1.7B Instruct). Apache-2.0. Rationale above.
- **Corpus theme (SEED Q1).** **Audience-submitted study notes** ("the solar system" topic, ~5 notes per device, 10 post-sync). The recipe theme from SEED.md was tested and dropped — the merge-by-co-occurrence story did not survive skeptic stress; study notes land harder for R6a (the audience-as-contributor moment). See U3.
- **Vector search shape.** Flat float32 array + brute-force cosine top-k over the materialized Ditto query result; normalize both sides per query. Resolution above.
- **Should Cactus own retrieval?** No; keep it narrow to `generateEmbedding` + `generateCompletion[Stream]`. Resolution above.
- **Ditto transport flags.** BLE + LAN on both platforms + AWDL on iOS/macOS only; no Wi-Fi Aware (Android); no big-peer; no internet. Resolution above.

### Deferred to Implementation

- **Q4 thesis-framing durability.** Per SEED, this must be resolved BEFORE the loop starts. U2 holds it. Four candidates: data sovereignty / consent-scoped sharing; offline-by-default; "Bluetooth pairing for ideas"; opportunistic composition in bandwidth-denied environments. Stress-tested at 250 words each against the strongest skeptic before locking.
- **Q6 demo artifact form.** Recorded video, working repo, or both? Affects code-polish scope (U17). Default assumption in this plan: both — the recorded artifact is the exit gate, the public repo follows once R1–R7 are green.
- **Specific iOS + Android hardware pair (SEED Q2).** Picked at U1 time based on what's physically available + which pair gives the cleanest determinism signal.
- **Exact disjoint-pair construction algorithm for R1.** Depends on the picked corpus theme. U12 owns it.

---

## Output Structure

    _docs/
    ├── plans/
    │   └── 001-feat-mesh-rag-demo.md       # this file
    ├── thesis-framings.md                  # U2
    ├── demo-script.md                      # U12
    ├── rehearsed-queries.md                # U16
    └── recording-checklist.md              # U17

    lib/
    ├── main.dart                       # MeshRagApp + BootScreen splash/init flow
    ├── models/
    │   └── study_note.dart             # StudyNote class + UUIDv5 seed factory + Ditto round-trip + OR-Set acceptance helpers
    ├── services/
    │   ├── ditto_service.dart          # singleton; init, transport config, sync, presence stream, CRUD over StudyNote
    │   ├── cactus_service.dart         # singleton; two CactusLM instances (completion + embedding); download + init + embed + complete[All]
    │   ├── seed_loader.dart            # reads assets/seed_notes_<role>.json, idempotently inserts (PHONE_ROLE env var)
    │   └── retrieval_service.dart      # ensureEmbeddings(), topK(topic, k), generateFlashcards(topic) → Stream<FlashcardEvent>
    ├── prompts/
    │   ├── dql_queries.dart            # NotesQueries: selectAll, upsert, setEmbedding, syncSubscription
    │   └── flashcard_gen.dart          # FlashcardGenPrompt: system + user-message builder; tolerant parser for Q:/A:/SOURCE:
    ├── widgets/
    │   ├── query_screen.dart           # two-tab Scaffold (Notes, Flashcards) + MeshStatusWidget in AppBar
    │   ├── mesh_status_widget.dart     # camera-legible pill: 'mesh: alone' (gray) / 'mesh: N peers' (green)
    │   ├── notes_tab.dart              # live notes list grouped by contributor; long-press to accept peer notes
    │   ├── flashcards_tab.dart         # topic input + streaming generation + swipeable stack + rate mode + history
    │   └── demo_overlay.dart           # U12 — optional debug HUD (peer count, note count, last-query latency)
    └── holdouts/
        ├── cold_load_timer.dart        # U14 — phase-marked timing report
        ├── idempotence_check.dart      # U15a — convergence + idempotence detection
        └── coherence_dryrun.dart       # U16 — R6a capture runner

    assets/
    ├── seed_notes_a.json                  # device A's preload (PHONE_ROLE=a)
    └── seed_notes_b.json                  # device B's preload (PHONE_ROLE=b)

    ios/
    ├── Podfile                            # U18 — `platform :ios, '15.0'` floor for Ditto v5 + objectbox
    └── Runner/Info.plist                  # NSBluetoothAlwaysUsageDescription, NSBluetoothPeripheralUsageDescription,
                                           # NSLocalNetworkUsageDescription, NSBonjourServices = [_http-alt._tcp.]

    android/app/
    ├── build.gradle.kts                   # U18 — proguardFiles wiring for release builds
    ├── proguard-rules.pro                 # U18 — live.ditto.** + com.ditto.** + rustls + KMP closure keeps
    └── src/main/AndroidManifest.xml       # BLE_CONNECT/ADVERTISE/SCAN, NEARBY_WIFI_DEVICES, location-floor permissions

    tools/
    ├── determinism_harness/               # U1, U13 — cross-device cosine-parity CLI
    │   ├── fixtures/queries.json          # 20 fixture queries + 20 fixture passages
    │   ├── run.dart                       # measure + check modes; agreement-rate math
    │   ├── baseline.json                  # U13 — checked-in top-k baseline for the locked slug pair
    │   └── README.md
    ├── holdout_7/
    │   └── offline_witness.md             # U15b — pre-demo network-state checklist
    ├── holdout_34/
    │   └── runner.sh                      # U15a — two-device R3+R4 orchestration
    └── holdout_357/
        └── runner.sh                      # U16 — chains R3/R4/R7 then R6a capture

    slides/
    ├── deck.md                            # U19 — Presenterm Markdown source (8 slides)
    ├── notes.md                           # U19 — speaker notes per slide
    └── media/                             # U17, U19 — recorded artifact, screenshots, Mermaid PNGs

    test/
    ├── study_note_test.dart               # UUIDv5 determinism + Ditto round-trip + OR-Set semantics
    ├── retrieval_service_test.dart        # normalize + dot pure-math
    ├── flashcard_gen_test.dart            # FlashcardGenPrompt tolerant parser
    ├── determinism_harness_test.dart      # U1 — agreement-rate math + fixture parsing
    └── holdouts/
        ├── cold_load_timer_test.dart      # U14 — synthetic phase sequence + report format
        └── idempotence_check_test.dart    # U15a — convergence-detection logic

The implementer may adjust layout if implementation reveals a better seam (especially if the Cactus SDK's idioms suggest a different module split).

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

The data flow is a four-layer pure pipeline with one CRDT-merge edge:

```
                              ┌─────────────────────────────┐
                              │     Cactus runtime (local)   │
                              │  embed(text) -> Float32List  │
                              │  generate(prompt) -> String  │
                              └────────────┬─────────────────┘
                                           │ pinned model + Q4 + CPU + batch=1
       ┌───────────────────────────────────┼───────────────────────────────────┐
       │                                   │                                   │
   query "moons"              ingest (text)│                            tuple insert
       │                                   ▼                                   │
       │                       ┌──────────────────────┐                        │
       │                       │  embedder            │                        │
       │                       └──────────┬───────────┘                        │
       │                                  │ Float32List[384]                   │
       │                                  ▼                                    │
       │                       ┌──────────────────────┐                        │
       │                       │  Ditto store (Doc)   │◄──── grow-only ────────┘
       │                       │  collection:notes    │
       │                       └──────────┬───────────┘
       │                                  │ materialized snapshot
       │              query embedding     │
       └────────────────┐                 │
                        ▼                 ▼
                  ┌────────────────────────────────┐
                  │  retrieval (Dart)              │
                  │  cosine top-k over float[]     │
                  └──────────────┬─────────────────┘
                                 │ top-k tuples
                                 ▼
                       ┌──────────────────┐
                       │  prompt assembly │
                       │  + generate()    │ (Stage 1 only)
                       └─────────┬────────┘
                                 ▼
                            answer + cited IDs


  Mesh edge (between two devices A and B):

            ┌────────────────┐                      ┌────────────────┐
            │   Device A     │   Ditto BLE/LAN      │   Device B     │
            │    notes_A     │ ◄───── merge ──────► │    notes_B     │
            └────────────────┘  (grow-only G-Set;   └────────────────┘
                                 dot-tagged delta   notes_A ∪ notes_B
                                 propagation)       is the next snapshot
                                                    each device queries against
```

Why this shape: retrieval is a *pure function over a CRDT-merged set*. Sync correctness reduces to G-Set convergence (Shapiro et al.). The only thing the demo actually has to engineer beyond "embed + brute force + merge" is the cross-platform reproducibility of `embed()` — every other property falls out of the algebra.

### Demo-flow sequence

The user-facing "moment of magic" expressed as a sequence diagram. The corpus split is disjoint-by-design (α on phone A, β on phone B) so the post-sync answer is provably different from the pre-sync answer for the rehearsed query set.

```mermaid
sequenceDiagram
    participant A as Phone A (iOS)
    participant B as Phone B (Android)
    participant U as User on camera

    Note over A,B: Both phones in airplane mode (Wi-Fi off, cellular off, BLE on)
    Note over A: Local corpus: ~N notes (variant set α)
    Note over B: Local corpus: ~N notes (variant set β)

    U->>A: Rehearsed topic Q1
    A->>A: cactus.generateEmbedding(Q1) → List of double
    A->>A: cosine top-k over α → α top-k (tie-break by _id asc)
    A->>A: cactus.generateCompletionStream(prompt + α top-k) → flashcards Cα (sourceNoteIds drawn from α)
    A-->>U: Renders Cα with per-card source attribution + 'drew on N notes (0 from peers)' footer

    Note over A,B: Phone B enters BLE range; mesh indicator on A flips gray to green
    A->>B: Ditto BLE/LAN handshake (AWDL activates alongside on iOS)
    A->>B: Ditto delta-state sync of notes_B → A holds α ∪ β
    Note over A: Local corpus now: ~2N notes (some with contributor = phone-b)

    U->>A: Same topic Q1 repeated (post-sync)
    A->>A: cactus.generateEmbedding(Q1) (same vector — R2 invariant)
    A->>A: cosine top-k over α ∪ β → mixed α+β top-k (tie-break by _id asc)
    A->>A: cactus.generateCompletionStream(prompt + mixed top-k) → flashcards Cα+β (sourceNoteIds include peer ids)
    A-->>U: Renders Cα+β; the source set visibly expanded, attribution footer shows 'M from peers'
```

The R1 moment of magic is the *visible source-set expansion* between the two generations — not the cards themselves, which are a derived consequence. The audience sees the mesh-indicator turn green, then the attribution footer's peer count moves from 0 to M, then the new card stack lands; the streaming generation is the last thing they parse.

---

## Implementation Units

### U1. Cactus iOS↔Android embedding determinism spike (the gate)

**Goal:** Before the rest of the build is locked, prove (or disprove) that the chosen Cactus slug pair produces stable embeddings across iOS and Android on a fixed fixture set. If the gate fails, halt the loop and pivot to brainstorm option C ("Narrate the mesh") instead of continuing.

**Requirements:** R2 (Holdout 2 — primary), R10.

**Dependencies:** None — this is the gate.

**Files:**
- Create: `tools/determinism_harness/` (separate directory; standalone Dart CLI or shell-runnable per-platform binary, NOT Flutter UI).
- Create: `tools/determinism_harness/fixtures/queries.json` (20 fixture query strings + 20 fixture passages; the same JSON loaded on both platforms).
- Create: `tools/determinism_harness/run.dart` (load model on both phones via Cactus FFI, embed each fixture, dump top-k IDs to stdout, side-by-side diff).
- Create: `tools/determinism_harness/README.md` (how to run, how to read the agreement-rate output).
- Test: `test/determinism_harness_test.dart` (parse fixture JSON, compute top-k from a known float matrix, agreement rate math).

**Approach:**
- Fixture: 20 short queries + 20 short passages, chosen to span clear-cut semantic similarity (e.g., adjacent vs. unrelated topics) so top-k ordering is meaningful, not random.
- On each device: load the embedding slug via `CactusLM.downloadModel` + `initializeModel`, embed each fixture (batch=1, fixed seed if Cactus exposes one), compute cosine for every (query, passage) pair, write `<query_id>\t<sorted_top_k_passage_ids>\n` lines to stdout.
- Side-by-side diff: read both devices' outputs (offline transfer over USB or shared Wi-Fi LAN, not BLE — this is bench instrumentation, not demo). Agreement rate = fraction of queries whose top-k ordering matches exactly.
- Diagnostic: also dump cosine for the top-1 (query, passage) pair from each phone to detect float-level drift even when top-k order agrees.

**Execution note:** Test-first on the agreement-rate math. The phone-side measurement code is the part that has to work; the agreement-rate calculation should not be where bugs hide.

**Technical design:** Pseudo-code for the agreement-rate computation:

```
function agreement_rate(per_query_topk_A: Map[QueryId, List[PassageId]],
                        per_query_topk_B: Map[QueryId, List[PassageId]],
                        k: int = 5) -> float:
    matches = 0
    for query_id in per_query_topk_A.keys:
        if per_query_topk_A[query_id][0..k] == per_query_topk_B[query_id][0..k]:
            matches += 1
    return matches / len(per_query_topk_A)
```

**Patterns to follow:**
- `_docs/research/index/_per_source/article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference.md` — the batch-invariance recipe; this is the playbook for engineering the determinism, not just measuring it.
- `_docs/research/index/_per_source/paper-2509.20354.md` — EmbeddingGemma deployment notes; informs the gate-design even though the chosen slug is `qwen3-0.6`.

**Test scenarios:**
- Happy path: 20 identical fixture inputs → identical top-5 ordering → agreement = 1.0. Covers AE2.
- Edge case: query with cosine ties at the top-k boundary — agreement rate must NOT count tie reorderings as failures unless they cross the top-k threshold (clearly document the policy in the test).
- Error path: fixture JSON missing / malformed → harness exits non-zero with a clear message; CI / pre-flight script catches it.
- Diagnostic: when agreement_rate is between 0.85 and 0.95, the harness must dump the offending queries (so a human can decide whether to expand the fixture or re-engineer the kernel pin).
- Integration: same fixture run through two real builds (one iOS device, one Android device) returns ≥ 0.95 agreement OR fails loudly with the diff. This is the actual gate.

**Verification:**
- The harness runs on both physical devices.
- For the chosen model + quant + backend triple, agreement_rate ≥ 0.95.
- If the gate fails, the loop is suspended and the implementer pivots to option C. The harness's failure output is the artifact that justifies the pivot.

---

### U2. Thesis-framing stress test (Q4 resolution)

**Goal:** Resolve SEED.md's Q4 "Resolve Before Loop Starts" by writing 250-word versions of all four candidate thesis framings, stress-testing each against the strongest skeptic, and picking the one the demo + writeup will land on. Affects U3's corpus choice.

**Requirements:** R8 (forward-affecting — the writeup depends on it; the demo's choreography also depends on which moment is "the moment").

**Dependencies:** None.

**Files:**
- Create: `_docs/thesis-framings.md` — four 250-word sections, one per candidate, each followed by a "strongest skeptic objection" and a "response" paragraph.
- Modify (after the pick): `_docs/SEED.md` open-questions section — fold Q4's resolution back in-line.

**Approach:**
- Candidates per SEED Q4: (i) data sovereignty / consent-scoped sharing; (ii) offline-by-default; (iii) "Bluetooth pairing for ideas — knowledge composes when devices meet"; (iv) opportunistic composition in bandwidth-denied environments (disaster zones, ships, transit, classified facilities).
- Each gets a strongest-skeptic stress test: who is the loudest "but cloud RAG will be cheaper and faster in a year, so this doesn't matter" critic, and what's the irreducible counter? If no counter survives, the framing dies.
- The surviving framing binds the corpus theme (U3) and the demo's narration script (U13).

**Test scenarios:**
- Test expectation: none — this is a writing exercise, not a code unit. The artifact is the four-framing doc + the picked framing folded into SEED.md.

**Verification:**
- `_docs/thesis-framings.md` exists with four 250-word framings, each carrying a "skeptic objection" + "response" pair.
- SEED.md Q4 is marked resolved with a one-paragraph rationale citing which framing won and why.

---

### U3. Corpus theme + disjoint-pair seed (Q1 resolution)

**Goal:** Resolve SEED.md's Q1 — pick a corpus theme that supports disjoint-by-design pairs for R1, binds to the U2-picked thesis framing, and is pre-screenable for audience-safe display.

**Requirements:** R1, R6a, R6b, R9 (theme must support the thesis — e.g., the "Bluetooth pairing for ideas" frame needs complementary-knowledge pairs, not redundancy).

**Dependencies:** U2.

**Files:**
- Create: `assets/seed_notes_a.json` — 5 study notes the `phone-a` build preloads. Each entry: `{ topic, contributor: "phone-a", createdAt, tags, body }`. Schema is flat — no `text`, no `metadata.source`.
- Create: `assets/seed_notes_b.json` — likewise for `phone-b`.

**Approach:**
- Theme = audience-submitted study notes (topic "the solar system", ~5 notes per device, 10 post-sync). The earlier recipe theme from SEED.md was tested and dropped — the merge-by-co-occurrence story did not survive skeptic stress; study notes land harder for R6a (the audience-as-contributor moment). The corpus and per-note metadata live directly in `assets/seed_notes_<role>.json` — no standalone `_docs/corpus-theme.md` is needed.
- Per-note shape is `{ topic, contributor, createdAt, tags, body }`; the `_id` is derived deterministically by `StudyNote.seed` (UUIDv5 over `'<contributor>|<topic>|<createdAt-iso8601>'`) so re-running the seed loader is a no-op.
- Choose entries so that at least 5 R1-style queries have zero hits in A and ≥1 hit in B (and vice versa). Document each query → expected-source mapping in `_docs/rehearsed-queries.md` (U16) so the disjoint property is provable, not asserted.
- Pre-screen every plausible audience query against the combined corpus per SEED's "Real Environment" rule — no unintended content lands on the big screen.

**Test scenarios:**
- Happy path: load `seed_notes_a.json` and `seed_notes_b.json` → counts match the stated numbers; no two entries collide on `(contributor, topic, createdAt)` across both files; the planned R1 fixture query returns zero from A alone and ≥1 from the union.
- Edge case: every entry has a non-empty `body` and `topic`; embeddings are NOT pre-computed (`RetrievalService.ensureEmbeddings` backfills them after Cactus loads).
- Verification: 5 of 5 rehearsed R6a topics produce a card stack where ≥1 retrieved note comes from each device when run against the combined corpus.

**Verification:**
- `assets/seed_notes_a.json` + `assets/seed_notes_b.json` exist, are well-formed JSON arrays, and the seeded UUIDv5 `_id`s are disjoint across the two files (by virtue of differing `contributor` inputs).
- The R6a rehearsed topics are captured in `_docs/rehearsed-queries.md` (U16).

---

### U4. Flutter project shell — pubspec + lib/main.dart + app scaffolding

**Goal:** Establish the Flutter source under existing `android/` / `ios/` platform scaffolding so the app is runnable. Do NOT re-run `flutter create .` once the project exists — the platform scaffolding is preserved as-is.

**Requirements:** R5 (cold-load latency starts from app launch; the app needs to exist), R10.

**Dependencies:** None (can run in parallel with U1–U3).

**Files:**
- Create: `pubspec.yaml` — Dart SDK constraint `^3.8.0` (no `flutter:` constraint — the Flutter SDK version is taken from the local toolchain). Direct dependencies are minimal: `cactus: ^1.3.0`, `ditto_live: ^5.0.0`, `permission_handler: ^12.0.1` (runtime BLE / nearby-Wi-Fi prompts), `uuid: ^4.5.1` (deterministic UUIDv5 for `StudyNote.seed`), `cupertino_icons: ^1.0.8`. Do **not** redeclare `device_info_plus`, `package_info_plus`, `objectbox_flutter_libs`, `record`, `path_provider`, or `shared_preferences` — they come in transitively via `cactus` + `ditto_live`. Declare `assets/seed_notes_a.json` + `assets/seed_notes_b.json` under `flutter.assets`.
- Create: `lib/main.dart` — entry that runs `MeshRagApp` and renders a `BootScreen` splash that sequences `DittoService.initialize` → `startSync` → `SeedLoader.loadAndInsert` → `CactusService.initialize` → `RetrievalService.ensureEmbeddings`, then swaps in `QueryScreen`. `MeshRagApp` lives in the same file (no separate `lib/app.dart`).
- Create: `analysis_options.yaml` — Dart's `package:flutter_lints/flutter.yaml` baseline.

**Approach:**
- No Flutter SDK pin is written into `pubspec.yaml`; whatever the local toolchain ships is used.
- Direct dependencies are kept minimal (the five above). Transitive plugins still register correctly via `flutter pub get` because they're declared inside `cactus` and `ditto_live`'s own pubspecs.
- Permission prompts are requested at `main()` boundary (before `runApp`) for `bluetoothConnect`, `bluetoothAdvertise`, `bluetoothScan`, `nearbyWifiDevices` — see U5 Approach.

**Patterns to follow:**
- `_inspiration/repos/ramanujammv1988__edge-veda/lib/main.dart` — single-file entry pointing at an app shell.

**Test scenarios:**
- Happy path: `flutter analyze` is clean; `flutter test` passes; `flutter run --dart-define=DITTO_APP_ID=... --dart-define=DITTO_LICENSE=... --dart-define=PHONE_ROLE=a` on a debug iOS simulator shows the `BootScreen` then `QueryScreen`.
- Error path: missing `DITTO_APP_ID` or `DITTO_LICENSE` → `BootScreen` surfaces a clear `StateError` rather than crashing.

**Verification:**
- `flutter analyze` exits clean.
- `flutter test` runs the three core suites (`study_note_test.dart`, `retrieval_service_test.dart`, `flashcard_gen_test.dart`) and passes.
- A debug build runs on both iOS simulator and Android emulator and reaches `QueryScreen` once Cactus models are downloaded + corpus is embedded.

---

### U5. Ditto client init + transport config

**Goal:** Wire Ditto with BLE + LAN + AWDL enabled, no big-peer, no internet sync URL. Expose `sync.start()` and `sync.stop()` via a `DittoService` Dart wrapper. Surface peer-count state as a `Stream<int>` for U10's mesh indicator.

**Requirements:** R1, R3, R4, R7, R10.

**Dependencies:** U4.

**Files:**
- Create: `lib/services/ditto_service.dart` — singleton `DittoService.instance` with `initialize()`, `startSync({subscriptionQuery})`, `stopSync()`, `Stream<int> peerCount`, `upsertNote(StudyNote)`, `queryAll() / queryWithEmbedding() / queryMissingEmbedding()`, `setEmbedding(id, List<double>)`, and `subscribeToNotes(callback) -> StoreObserver`.
- Create: `lib/prompts/dql_queries.dart` — `NotesQueries` constants class holding the DQL strings (`selectAll`, `selectById`, `upsert`, `setEmbedding`, `syncSubscription`).
- Modify: `lib/main.dart` — `BootScreen._boot` calls `DittoService.instance.initialize()` then `startSync(subscriptionQuery: 'SELECT * FROM notes')`.
- Modify: `ios/Runner/Info.plist` — Bluetooth + Local Network + Bonjour usage descriptions (`NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`, `NSLocalNetworkUsageDescription`, `NSBonjourServices = [_http-alt._tcp.]`).
- Modify: `android/app/src/main/AndroidManifest.xml` — `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_SCAN` (with `usesPermissionFlags="neverForLocation"`), `ACCESS_FINE_LOCATION` (maxSdk 32), `NEARBY_WIFI_DEVICES`, plus the legacy `BLUETOOTH` / `BLUETOOTH_ADMIN` / `ACCESS_COARSE_LOCATION` floors gated by `maxSdkVersion`, plus the Wi-Fi / network-state permissions Ditto needs at runtime.

**Approach:**
- Credentials inject via `--dart-define`: `DITTO_APP_ID` (app/database UUID) and `DITTO_LICENSE` (offline license token). Both are read with `String.fromEnvironment(..., defaultValue: '')` and validated in `initialize()`; missing values throw a clear `StateError` that `BootScreen` surfaces.
- Identity / connect mode: `DittoConfig(databaseID: <envAppId>, connect: const DittoConfigConnectSmallPeersOnly())` (no `privateKey` arg). After `Ditto.open(config)`, call `d.setOfflineOnlyLicenseToken(<envLicense>)` before any sync — small-peers-only mode refuses to start without it.
- Transports: enable `c.peerToPeer.bluetoothLE`, `c.peerToPeer.lan`, and (only on iOS/macOS) `c.peerToPeer.awdl`. Do **not** enable Wi-Fi Aware (Android) in Stage 0. No WebSocket / big-peer URL is wired.
- Subscription / observation: `ditto.sync.registerSubscription(subscriptionQuery)` (where `subscriptionQuery = 'SELECT * FROM notes'`) followed by `ditto.sync.start()`. For UI live updates, `ditto.store.registerObserver(NotesQueries.selectAll, onChange: …)` — callback-based; wraps as `subscribeToNotes(callback) -> StoreObserver`. Mutations go through `ditto.store.execute(<DQL>, arguments: …)` (`INSERT INTO notes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE` for upsert; `UPDATE notes SET embedding = :embedding WHERE _id = :id` for late embedding backfill).
- Peer-count stream: `d.presence.observe((graph) { peerCount.add(graph.remotePeers.length); })` returns a `PresenceObserver` whose `stop()` is the disposal hook. The local peer identifier is `d.presence.graph.localPeer.peerKey`.
- `iOS Info.plist` Bonjour list is a single entry — `_http-alt._tcp.` — sufficient for Ditto v5's LAN discovery on the chosen hardware pair.

**Patterns to follow:**
- Bitchat's iOS BLE permission strings — `_inspiration/repos/permissionlesstech__bitchat/<plist>` for the NSBluetoothAlwaysUsageDescription wording that doesn't get rejected.
- Ditto v5 quick-start under `_inspiration/getditto/` (preferred over the marketing pages).

**Test scenarios:**
- Happy path: `DittoService.initialize` with valid env vars succeeds; `startSync` returns; `peerCount` stream emits `0` initially.
- Edge case: `initialize` called twice → idempotent (`if (_ditto != null) return;`).
- Error path: missing `DITTO_APP_ID` or `DITTO_LICENSE` → throws a clear `StateError`; `BootScreen` surfaces it rather than crashing.
- Integration (deferred to U15): two real devices in BLE range → `peerCount` emits `1` on both within ~10s.

**Verification:**
- `flutter analyze` clean.
- App launches on a single device without crash; `MeshStatusWidget` shows `mesh: alone` (gray); no non-Ditto traffic observed.

---

### U6. Cactus runtime + model loading

**Goal:** Wire Cactus with two `CactusLM` instances — one for completion (`qwen3-1.7`) and one for embedding (`qwen3-0.6`) — and expose them via a singleton `CactusService` (`lib/services/cactus_service.dart`). The completion + embedding slugs are independent because the chat-tuned slugs Cactus ships do not expose an embedding head on the Flutter SDK 1.3.0 catalog.

**Requirements:** R2 (the slug pair this unit pins is what U1's spike measures), R5 (download + load timing), R6a, R9 (no hybrid cloud).

**Dependencies:** U4, U1 (the determinism spike informs the slug pick).

**Files:**
- Create: `lib/services/cactus_service.dart` — singleton `CactusService.instance` holding `_completionLm = CactusLM()` and `_embeddingLm = CactusLM()`. Exposes `initialize({completionSlugOverride, embeddingSlugOverride, contextSize = 2048, onProgress})`, `embed(text) -> Future<List<double>>`, `embedF32(text) -> Future<Float32List>`, `complete(messages, {maxTokens = 256}) -> Stream<String>`, and `completeAll(messages, {maxTokens = 256}) -> Future<String>`. No explicit `dispose()` — the singleton lives the app's lifetime.
- Slug pins as `static const`: `preferredCompletionSlug = 'qwen3-1.7'`; `preferredEmbeddingSlug = 'qwen3-0.6'`. An in-source comment records the rationale (next bullet).

**Approach:**
- **Slug rationale (preserve in source comment):** EmbeddingGemma 300M was attempted as the embedding primary; the Cactus Flutter 1.3.0 catalog cannot fetch the dedicated `qwen3-embedding-0.6` slug ("Failed to get model qwen3-embedding-0.6") and the engine docs' embedding-only slugs aren't yet resolvable by the Flutter SDK. `qwen3-0.6` is the chat-tuned fallback that exposes the embedding head and clears the cosine-parity gate on the rehearsed fixtures. For the completion slug, `qwen3-0.6` produced incoherent flashcards at ~600M parameters; `qwen3-1.7` is the size class that produces coherent cards while still loading under the R5 budget on the chosen hardware pair.
- `initialize()` runs sequentially: `_completionLm.downloadModel(model: cSlug, downloadProcessCallback: …)` → `_embeddingLm.downloadModel(model: eSlug, …)` → `_completionLm.initializeModel(params: CactusInitParams(model: cSlug, contextSize: 2048))` → `_embeddingLm.initializeModel(params: CactusInitParams(model: eSlug, contextSize: 2048))`. The `onProgress(double? p, String status, bool isError)` callback labels which phase is reporting so `BootScreen` can render `'completion (qwen3-1.7): downloading 42%'`-style strings.
- **Telemetry pin.** Inside `initialize()`, set `CactusConfig.isTelemetryEnabled = false` before either `downloadModel` call. The Cactus Flutter SDK default is `true`; R7 (offline) is satisfied behaviorally by airplane-mode discipline but the explicit pin closes the loop and lets U15b's witness verify zero outbound telemetry.
- **Local-only invariant.** Construct `CactusCompletionParams(maxTokens: …, completionMode: CompletionMode.local)` explicitly in `complete` / `completeAll`. The SDK default is local, but the explicit pin prevents a default-change from silently switching modes.
- `embed(text)` calls `_embeddingLm.generateEmbedding(text: text)`, checks `r.success`, and returns `r.embeddings` (`List<double>`). On failure it throws a `StateError`. `embedF32` wraps for the cosine hot path.
- `complete(messages, maxTokens)` returns `Stream<String>` from `_completionLm.generateCompletionStream(messages: messages, params: CactusCompletionParams(maxTokens: maxTokens, completionMode: CompletionMode.local))`. `completeAll` exists for tests/evals.

**Patterns to follow:**
- `_inspiration/cactus-compute/cactus-flutter/lib/services/lm.dart` — the actual `CactusLM` surface.
- `_inspiration/cactus-compute/cactus/docs/cactus_engine.md` — the FFI surface reference; useful for confirming embed/complete return shapes.
- `_inspiration/repos/deepsense-ai__edge-slm/` — the analog for llama.cpp-style model load on Android; informs the cold-load mental model.

**Test scenarios:**
- Happy path: `initialize()` returns; `embed("solar system")` returns a non-empty `List<double>` and `complete(...)` yields a non-empty stream.
- Edge case: empty string input to `embed()` → `CactusEmbeddingResult.success == false` → throws `StateError`. Document this behavior so the caller doesn't pass empty queries through.
- Edge case: `complete()` with a prompt that exceeds 2048 tokens → Cactus truncates or errors; surface in UI as `_error` rather than crashing.
- Error path: model download fails (no network on first launch) → `downloadProcessCallback(p, status, true)` fires; `BootScreen` renders a "connect to wifi to fetch the model" message.

**Verification:**
- Both slugs download + initialize on iOS and Android within R5's budget (≤10s steady-state on subsequent launches once cached).
- `flutter analyze` clean.

---

### U7. StudyNote model + Ditto v5 DQL document layout

**Goal:** Define the canonical `StudyNote` shape as a Dart class + a Ditto v5 DQL document, with idempotent upsert semantics and a stable serialization. Stage 0 mutations are insert-only (plus a late-embedding `UPDATE`); delete is out of scope.

**Requirements:** R3 (idempotence), R4 (bidirectional merge), R9 (CRDT shape preserved end-to-end).

**Dependencies:** U5, U6.

**Files:**
- Create: `lib/models/study_note.dart` — `StudyNote` class with `fromDittoValue` / `toDittoDoc` for Ditto interchange. Plus `StudyNote.seed(...)` factory (UUIDv5 over `'<contributor>|<topic>|<createdAt-iso8601>'`), `withAcceptedBy` / `withoutAcceptedBy` OR-Set helpers, and a `StudyNote.cloneFrom(...)` factory carried for compatibility with documents authored by the fork-clone predecessor of the acceptance OR-Set.
- (Insertion pipeline lives directly on `DittoService.upsertNote(note)` + `SeedLoader.loadAndInsert()` — no separate `lib/corpus/ingest.dart`.)
- Test: `test/study_note_test.dart` — UUIDv5 stability across reruns, UUIDv5 differs for different contributors, round-trip through Ditto doc shape, OR-Set add/remove semantics, hasEmbedding invariant.

**Approach:**
- `_id` = UUIDv5 over `'<contributor>|<topic>|<createdAt-iso8601>'`. UUIDv5 is content-addressed → same `(contributor, topic, createdAt)` produces a bitwise-identical id on every device and run, so the seed loader is idempotent. UUIDv5 strings are lexicographically comparable, which is enough for the cosine tie-break (`_id asc`).
- Field set: `{ _id, topic, contributor, body, tags: List<string>, embedding: List<double>, createdAt: ISO-8601 string, acceptedBy: List<string>, originalNoteId: string, originalContributor: string }`. The `contributor` field doubles as the author-device identifier (`phone-a` / `phone-b`); `acceptedBy` is an application-layer OR-Set the UI uses for cross-device "save peer's note" acceptance; the two `original…` fields carry the fork-clone predecessor's identity so documents authored before the acceptance OR-Set still round-trip cleanly.
- `embedding` is stored as `List<double>` and converted to `Float32List` on the hot path in `RetrievalService.topK`; `topK` skips any document whose embedding length differs from the query's. This is the silent guard against a model swap mid-corpus — old embeddings are dropped from results until explicitly cleared and re-backfilled (see U8 edge case: `ensureEmbeddings()` only fills *empty* embeddings, so a stale-length embedding survives until the column is cleared).
- Idempotence: `DittoService.upsertNote` runs `INSERT INTO notes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE` — re-running the seed on a peer that already has the same `_id` is a no-op by Ditto v5 DQL semantics.

**Patterns to follow:**
- `_docs/research/index/_per_source/article-ditto-blog-dittos-delta-state-crdts.md` — Ditto delta-state semantics + HLC dot-tags. Read before defining the document shape.
- `_docs/research/index/_per_source/paper-1106.4374.md` — G-Set foundations. The `notes` collection IS a G-Set.

**Test scenarios:**
- Happy path: `StudyNote.fromDittoValue(note.toDittoDoc())` round-trips with `_id`, `topic`, `contributor`, `body`, `tags`, `embedding`, `createdAt`, `acceptedBy`, `originalNoteId`, `originalContributor` all preserved.
- UUIDv5 stability: two `StudyNote.seed(...)` calls with the same `(contributor, topic, createdAt)` produce equal `_id`s; differing contributors produce distinct `_id`s.
- Idempotence (covers AE3): insert T1, sync to peer, peer re-inserts T1 with same id → final note count on both peers is 1, not 2.
- OR-Set: `withAcceptedBy(c)` is idempotent (re-adding a contributor returns `this`); `withoutAcceptedBy(c)` is idempotent (removing an absent contributor returns `this`); `fromDittoValue` dedups `acceptedBy` defensively in case multiple replicas raced.
- Integration (deferred to U15): two devices insert T1 and T2 respectively → after sync, both have `{T1, T2}`.

**Verification:**
- All round-trip + UUIDv5 stability + OR-Set tests pass (`test/study_note_test.dart`).
- A single-device insert + restart produces the same note count + same `_id`s (Ditto persistence works).

---

### U8. Seed insert + late embedding backfill (two-phase corpus preload)

**Goal:** Read `assets/seed_notes_<role>.json` and idempotently upsert each entry into Ditto **without** an embedding (the embedding column is backfilled in a separate phase after Cactus is ready). Both phases are idempotent on subsequent launches.

**Requirements:** R1, R4, R5 (preload + embedding time both count toward R5's budget).

**Dependencies:** U3, U6, U7.

**Files:**
- Create: `lib/services/seed_loader.dart` — singleton `SeedLoader.instance` with `loadAndInsert() -> Future<int>`, `String get role` (reads `--dart-define=PHONE_ROLE`, default `'a'`), `String get assetPath`, `String get selfContributor` (returns `'phone-<role>'`).
- (Embedding backfill lives in `lib/services/retrieval_service.dart` — `ensureEmbeddings()` — covered in U9.)

**Approach:**
- `BootScreen._boot` runs `SeedLoader.instance.loadAndInsert()` **before** Cactus has been initialized. Each entry is mapped through `StudyNote.seed(topic, contributor, body, tags, createdAt)` (deterministic UUIDv5) and inserted via `DittoService.upsertNote(note)` → DQL `INSERT INTO notes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE`. Re-runs are no-ops.
- After Cactus models are initialized, `RetrievalService.instance.ensureEmbeddings()` pulls all notes with `embedding.isEmpty`, runs `CactusService.embed('<topic>. <first 200 chars of body>')` on each, and persists via `UPDATE notes SET embedding = :embedding WHERE _id = :id`. This phase is also idempotent — already-embedded notes are skipped.
- Device selects its seed JSON via `--dart-define=PHONE_ROLE=a` (default) or `=b`. The `contributor` in the JSON matches the device's `selfContributor` (`phone-a` / `phone-b`).
- Time both phases via U14's `ColdLoadTimer.mark()`. The `BootScreen` phase strings (`'seeding local corpus'`, `'embedding local corpus'`) are the natural mark boundaries.

**Patterns to follow:**
- Edge-Veda's preload pattern — `_inspiration/repos/ramanujammv1988__edge-veda/` document ingestion phase. Don't import the code; mirror the two-phase split.

**Test scenarios:**
- Happy path: fixture JSON with 5 entries → 5 notes in Ditto post-`loadAndInsert`, all with `contributor == "phone-a"` (or `"phone-b"`) and `embedding == []`. After `ensureEmbeddings()`, the same 5 notes have non-empty embeddings.
- Idempotence: run `loadAndInsert` twice → note count unchanged. Run `ensureEmbeddings` twice → second call returns 0.
- Edge case: a peer's note arrives via sync with a different embedding length than the local model → `topK` skips it; the next `ensureEmbeddings()` does not re-embed it (the peer's embedding is non-empty). The mismatch survives until the user explicitly clears the embedding column. Document the behavior.
- Integration (deferred): preload on both devices in parallel → after their first BLE meet, combined tuple count = device_a.json count + device_b.json count.

**Verification:**
- Fresh install + preload completes within the R5 budget on the slowest target.
- Tuple counts match fixture counts post-preload; `contributor` labels are correct.

---

### U9. Retrieval — flat-array cosine top-k

**Goal:** Given a query embedding, return the top-k tuples from the materialized Ditto snapshot, ranked by cosine similarity. k = 5 default. Brute force over a `Float32List` view of all embeddings.

**Requirements:** R1, R6a (retrieval feeds the LLM prompt assembly), R9 (retrieval is a *pure function over the CRDT-merged set* — this property is the demo's load-bearing claim).

**Dependencies:** U7, U6 (need an embedder), U8 (need a corpus to retrieve from).

**Files:**
- Create: `lib/services/retrieval_service.dart` — singleton `RetrievalService.instance` with `ensureEmbeddings() -> Future<int>` (backfill), `embedQuery(query) -> Future<Float32List>`, `topK(topic, {k = defaultK}) -> Future<List<RetrievedNote>>`, `generateFlashcards(topic, {k, n, savedExamples}) -> Stream<FlashcardEvent>`. Pure-math helpers `normalize(v)` and `dot(a, b)` are static + tested directly.
- Test: `test/retrieval_service_test.dart` — `normalize` produces unit vectors, `normalize` is identity on zero vectors, `dot` of normalized parallel vectors = 1.0, `dot` survives a 384-dim sanity case.

**Approach:**
- `topK` is per-query (not amortized via observer): pulls `DittoService.queryWithEmbedding()` on each call (re-runs the DQL select). Acceptable while the Stage 0 corpus is ≤ 10 rows. A future revision can hang a `subscribeToNotes` observer + cached `Float32List` in front of this when the corpus grows.
- Normalize both sides per query: `qVec = normalize(embedQuery(topic))`; for each note, `docVec = normalize(Float32List.fromList(note.embedding))`. The Cactus output is typically L2-normalized but we normalize anyway so the score stays in `[-1, 1]` regardless of model quirks. Cosine = `dot(qVec, docVec)`.
- Length mismatch: if `docVec.length != qVec.length`, skip the note. Old embeddings are dropped from `topK` until they are re-backfilled.
- DQL predicates on the embedding column are deliberately avoided: Ditto v5's MISSING-vs-NULL semantics make `WHERE embedding IS NOT NULL` brittle for fresh-seeded notes, so the embedded-vs-missing split lives in Dart (`DittoService.queryWithEmbedding` / `queryMissingEmbedding`).
- Tie-break: `scored.sort((a, b) { final s = b.score.compareTo(a.score); return s != 0 ? s : a.note.id.compareTo(b.note.id); })`. UUIDv5 strings sort lex-asc; this is the R2 stability invariant.
- Default `k = 5`. Default flashcard count `n = 3` (see U11 for rationale).

**Patterns to follow:**
- `_docs/research/index/_per_source/paper-2507.01079.md` (MobileRAG / EcoVector) — measured on-device retrieval latency; informs the perf target (sub-millisecond at our scale).
- `_inspiration/repos/unum-cloud__usearch/` — reference for batched cosine via SIMD; we don't link USearch in Stage 0 but the algorithm is the same.

**Test scenarios:**
- Happy path: hand-crafted Float32 fixtures → known top-1 / top-k ordering matches expectation.
- Edge case: empty corpus → `topK` returns `const []` without crashing.
- Edge case: `k > N` → returns all N scored results in correct order.
- Edge case: tied cosines → tie-break by `_id` lexicographic (informs R2's "is this a tie failure?" call in U1).
- Performance: top-5 over 5,000 random-normal-vector notes completes in < 5ms on a mid-range Android device (Stage 0 is well below this scale).

**Verification:**
- All tests pass.
- Manual: topic "the solar system" against preloaded corpus returns notes whose `body` field is recognizably solar-system-related.

---

### U10. UI — two-tab Scaffold + mesh status pill + per-card source attribution

**Goal:** Two-tab Flutter UI (`QueryScreen`) backed by `IndexedStack` so tab state survives swap. Tabs: `NotesTab` (live list of `StudyNote`s grouped by contributor, with long-press to accept peer notes) + `FlashcardsTab` (topic input + streaming generation + swipeable card stack + rate mode + history). `MeshStatusWidget` lives in the AppBar trailing action.

**Requirements:** R1 (per-card source attribution must be visible — that's how the audience sees B's contribution appear), R6a (cited note IDs shown per card in the flashcard stack).

**Dependencies:** U5 (peer count stream), U9 (retrieval + flashcard stream).

**Files:**
- Create: `lib/widgets/query_screen.dart` — `QueryScreen` widget: two-tab Scaffold + AppBar + `IndexedStack(NotesTab, FlashcardsTab)` + `NavigationBar` for tab switching.
- Create: `lib/widgets/mesh_status_widget.dart` — `MeshStatusWidget` pill rendering 'mesh: alone' (gray) or 'mesh: N peer(s)' (green). Camera-legible (font size 16, monospace, big dot, large pill).
- Create: `lib/widgets/notes_tab.dart` — live notes list: subscribes to `DittoService.subscribeToNotes`, groups by `contributor` (self first, peers after), long-press surfaces the "accept this peer note" action (writes to `acceptedBy` OR-Set via `DittoService.upsertNote(note.withAcceptedBy(self))`).
- Create: `lib/widgets/flashcards_tab.dart` — topic input + `generate`/`regenerate` button → consumes `RetrievalService.generateFlashcards(topic).listen(...)` → renders a swipeable stack with flip-on-tap. Rate mode (up/down) feeds back as few-shot exemplars to the next generation; generation history persists across regenerates so the audience can see how the cards change when a peer joins.

**Approach:**
- `QueryScreen` lands on `NotesTab` (index 0) so the audience compares per-phone notes first, then taps over to `FlashcardsTab` for the generative moment.
- `MeshStatusWidget` is a single pill — no pulse animation. The color change from gray → green is the legible signal; the surrounding deck/script handles dramatic timing.
- Per-card source attribution lives **inside** `FlashcardsTab`: each card's `sourceNoteIds` is rendered as a chip row at the card foot, and the aggregate `'drew on N notes (M from peers)'` footer above the swipeable stack carries the R1 visible-improvement signal. There is no separate `cited_note_chip` widget — the chips are inline.
- `BootScreen` (in `main.dart`) handles the splash/init flow before `QueryScreen` is reachable.

**Patterns to follow:**
- `_inspiration/repos/permissionlesstech__bitchat/` peer-count UI — visual idiom for "you are in mesh with N peers."
- `_inspiration/repos/ramanujammv1988__edge-veda/` source-attribution display — the chip-row pattern at the card foot.

**Test scenarios:**
- Happy path: peer count stream emits `0` then `1` → pill transitions gray → green; label updates from `'mesh: alone'` to `'mesh: 1 peer'`.
- Happy path: topic submitted with a fake corpus → flashcards stack renders 3 cards with source chips.
- Edge case: empty topic → `generate` button is a no-op (early return).
- Edge case: retrieval returns 0 notes → prompt still well-formed, LLM emits "(no notes available — output nothing.)"; UI shows the empty stack gracefully.
- Integration (deferred to U13): real generation on device A pre-sync → all source chips show `phone-a`. After BLE meet with B, regenerate → mixed `phone-a` + `phone-b` chips.

**Verification:**
- Widget tests for `MeshStatusWidget` (peer-count → label/color transitions) and `FlashcardsTab` rate-mode + history persistence pass.
- Manual: launch on iOS + Android, type a topic, generate, see the streaming partials land, then the final card stack with source attribution.

---

### U11. Stage 1 — streaming flashcards generator

**Goal:** Given a topic + top-k retrieved notes, assemble a flashcards prompt, call Cactus's LLM in **streaming** mode, parse the streamed plain-text `Q:` / `A:` / `SOURCE:` blocks into `Flashcard{question, answer, sourceNoteIds}` records, and render them in the swipeable stack from U10. Stage 1 is layered ON TOP of U10's `FlashcardsTab` — Stage 0 (notes list + mesh-status pill) ships even if Stage 1 falls over.

**Stage 1 pivot rationale:** An earlier draft of Stage 1 was a single buffered answer with inline citations. The cards-and-streaming shape replaced it because (a) a card stack reads better on camera than a paragraph, (b) per-card `sourceNoteIds` chips are more legible than inline `note [A-Z]\d+` regex citations, and (c) the Q/A line format survives 1.5B-class model truncation in a way JSON does not. This rationale is load-bearing for why the spec specifies a streaming `FlashcardEvent` API instead of a buffered `String` return — preserve it when revisiting Stage 1's surface.

**Requirements:** R6a, R6b stretch, R9.

**Dependencies:** U6, U9, U10.

**Files:**
- Create: `lib/prompts/flashcard_gen.dart` — `FlashcardGenPrompt`: system + user-message builder, plus the tolerant parser. Exports `Flashcard{question, answer, sourceNoteIds}`.
- Modify: `lib/services/retrieval_service.dart` — `generateFlashcards(topic, {k = 5, n = 3, savedExamples = const []}) -> Stream<FlashcardEvent>`. `FlashcardEvent` is a discriminated union: `retrieved(List<RetrievedNote>)`, `partial(String chunk)`, `cards(List<Flashcard>)`, `done()`.
- Modify: `lib/widgets/flashcards_tab.dart` — consume the stream, render partials as a 'generating…' indicator, commit the parsed cards on `cards`.
- Test: `test/flashcard_gen_test.dart` — tolerance tests for the parser: bare Q:/A:/SOURCE: blocks, markdown-emphasis-wrapped variants (`**Q:**`, `*A:*`), numbered/bulleted prefixes (`1.`, `- `), long-form labels (`Question:`, `Answer:`, `Notes:`), `<think>` reasoning leaks, multi-line continuation lines.

**Approach:**
- Prompt shape — **system message** (hard-coded "study buddy" persona; no `{{corpus_persona}}` slot): "You are a careful study buddy. You make study flashcards from short notes." + output rules enforcing plain `Q:` / `A:` / `SOURCE:` line format with negative instructions against markdown emphasis (no `**Q:**`), JSON, bullets/numbering, reasoning leaks (`<think>` blocks), made-up facts, and near-duplicate questions; instructs the model to emit exactly N cards. Includes an example block in the exact target shape. **User message:** `Topic: <topic>`, `Number of flashcards (N): <n>`, optional "below are flashcards you produced before that the user kept — mirror their style" + up to 3 few-shot exemplars from up-rated cards, `Notes:` header + numbered `Note i (id: <_id>): <body>` blocks, closing `Now output N flashcards in the Q: / A: / SOURCE: format. Start with "Q:" on its own line. No reasoning, no preamble.`
- Streaming generation: `CactusService.complete(messages, maxTokens: …)` yields token chunks; `generateFlashcards` accumulates them in a `StringBuffer`, emits `partial(chunk)` to the UI on each chunk, and on stream end runs `FlashcardGenPrompt.parse(raw)` to produce the final `Flashcard[]`. The UI shows a "generating…" indicator during partials and lands the stack on `cards`.
- Token budget: `maxTokens = thinkBudget (512) + maxTokensPerCard (160) × n`. The `thinkBudget` slush exists because Qwen 2.5 leaks `<think>` chain-of-thought even when told not to (`/no_think` is Qwen3-only) — reserving 512 tokens prevents the visible cards from being starved. There is **no** prompt-side context-window overflow guard; the Stage 0 corpus is small enough (≤ 5 notes × ~200 chars each) to fit comfortably inside the 2048 `contextSize`. A future revision should add tail-drop by lowest cosine once the corpus grows.
- Defaults: `n = 3` (1.5B Qwen on a Pixel 6a in debug decodes at ~6 chars/s; 3 cards halves the wall-clock vs. 5). `k = 5` for retrieval.
- Parser tolerance (`FlashcardGenPrompt.parse`): strips `<think>...</think>` (and unclosed `<think>` prefixes by anchoring at the first `Q:`); strips markdown emphasis (`*`, `_`) up front so the prefix regexes stay simple; permissive `Q.` / `Q)` / `Question:` variants and the same for `A` / `Notes` / `Source` / `From`; tolerates bullet/numeric prefixes (`1.`, `- `); supports multi-line continuation. Returns only complete (`question` + `answer` non-empty) cards.

**Patterns to follow:**
- `_inspiration/repos/software-mansion-labs__react-native-rag/` — prompt assembly + source-attribution pattern. Mirror the seam, not the exact strings.
- `_inspiration/repos/deepsense-ai__edge-slm/` — prompt template shape for small-LLM-on-mobile.

**Test scenarios:**
- Happy path: topic + 3 retrieved notes → assembled prompt contains all 3 note ids in numbered `Note i (id: …)` form and the user message ends with the closing imperative; system preamble is the documented one.
- Edge case: 0 retrieved notes → prompt still well-formed (closing line is "(no notes available — output nothing.)").
- Edge case: model emits markdown-wrapped prefixes (`**Q:**`), bullet prefixes (`1.`), or a `<think>` block before the first `Q:` → parser strips them and recovers cards cleanly.
- Edge case: stream truncates mid-card → parser keeps complete prior cards and drops the incomplete tail.
- Error path: completion stream errors (model OOM, etc.) → UI shows `_error` and the rate-mode + history from prior generations remains intact.
- Integration: rehearsed R6a topic → streamed answer parses into ≥ 1 card whose `sourceNoteIds` includes ≥ 1 retrieved note id.

**Verification:**
- Parser tolerance tests pass (`test/flashcard_gen_test.dart`).
- 5 of 5 R6a rehearsed topics produce a coherent card stack with visible source attribution (manual review against `_docs/rehearsed-queries.md`).

---

### U12. Holdout 1 demo choreography — airplane-mode + BLE-meet flow

**Goal:** Build the demo-day script: device A starts on the Flashcards tab, generates a card stack with B's notes absent, airplane mode toggled, BT re-enabled per iOS Control Center quirk, B comes into range, A regenerates, the card stack expands with B's content (visibly attributed). This is the *single most important user-facing moment*; the rest of the build is plumbing.

**Requirements:** R1, R7, R10.

**Dependencies:** U3 (the disjoint corpus pair is what makes this moment work), U10 (the mesh-status pill + per-card attribution are how the audience sees it). U11 is *additive*, not required — under SEED's cut order item 5 (Stage-0-only ship), U12 must still produce a working demo from the Notes tab + per-contributor grouping alone, without LLM generation.

**Files:**
- Create: `_docs/demo-script.md` — narrated sequence: each step's verbal beat + what the audience should see on screen + the fallback if something goes wrong.
- Create: `lib/widgets/demo_overlay.dart` — optional debug HUD showing peer count, note count, last-query latency. Toggleable via a build-time flag.
- Modify: `lib/widgets/query_screen.dart` — accept an `initialTopic` prop for repeatable demo state.

**Approach:**
- Three demo-script beats: (1) "Phone A alone, generate on a topic, **card stack draws on only A's notes (attribution footer: '0 from peers')**" — Stage 0.5 substrate; (2) "Airplane mode on, BT re-enabled from Control Center, B comes into range, **Notes tab fills in with B's notes as they sync; mesh pill flips green**" — the moment of magic, visible in the Notes list before any regeneration runs; (3) "Regenerate, **new card stack now draws on B's notes too (attribution footer: 'M from peers'; per-card SOURCE chips include phone-b ids)**" — the Stage-1 layer.
- Wait-for-sync beat: after the peer indicator turns green in beat 2, demonstrator waits ~2 seconds for the notes list to absorb B's notes (and for `ensureEmbeddings` to backfill their embeddings, if applicable) before regenerating.
- Fallback per SEED: if BLE pairing fails on stage, the recorded artifact uses B-roll for the pairing moment with on-camera disclosure ("this clip is from rehearsal"); the LAN fallback (joining the same Wi-Fi without internet) is the second-tier escape.
- Demo overlay: small, top-corner, gray. Not the main UI — but lets the demonstrator + recording confirm peer count and note count update live.

**Patterns to follow:**
- `_inspiration/repos/permissionlesstech__bitchat/` — the closest 2025 reference for "two phones, BLE mesh, observable state change."
- Apple WWDC 2025 "Explore prompt design & safety for on-device foundation models" — pacing for narrating an on-device-AI demo.

**Test scenarios:**
- Test expectation: scenario-level. The unit's "test" is the recorded dry-run video, scored against R1's exact wording. Lower-level unit tests in U5/U10/U11 cover the mechanics.
- Manual: 3 of 3 dry-run takes on physical devices reproduce the R1 sequence without on-stage debugging.

**Verification:**
- `_docs/demo-script.md` exists and is rehearsable end-to-end.
- A dry-run video on the chosen device pair reproduces R1 cleanly (single take preferred; with disclosed B-roll if needed).

---

### U13. Holdout 2 — automated cross-device determinism check (CI-style)

**Goal:** Promote U1's spike to a repeatable, automatable test that runs after every model swap or quantization tweak. Keeps R2 from regressing silently if anyone changes the embedding pin.

**Requirements:** R2.

**Dependencies:** U1, U6.

**Files:**
- Modify: `tools/determinism_harness/run.dart` — accept a `--ci` flag; outputs a JSON summary; exits non-zero if `agreement_rate < 0.95`.
- Create: `tools/determinism_harness/baseline.json` — recorded top-k IDs for each fixture query under the locked-in slug pair. Regenerated only on intentional pin change.

**Approach:**
- Two modes: `--measure` (no baseline; produces a new one) and `--check` (compares against baseline; exits 0/1).
- Baseline file is checked into git so any future change to the pin shows up as a diff.

**Test scenarios:**
- Happy path: re-run on same device + same pin → matches baseline exactly (agreement = 1.0).
- Edge case: baseline missing → `--check` exits with a clear "no baseline; run --measure first" message.
- Integration: introduce a deliberate change to the slug pair → CI mode exits non-zero with a diff of the offending queries.

**Verification:**
- CI mode runs to completion on both devices.
- Baseline file is checked in.

---

### U14. Holdout 5 — cold-load latency timer

**Goal:** End-to-end measurement from app launch to first-answer display. Asserts ≤ 10s on the slowest target device. If not, surfaces the slowest component (model load? preload? embed? retrieval? generate?) to drive a targeted fix.

**Requirements:** R5.

**Dependencies:** U4, U6, U8, U9, U11.

**Files:**
- Create: `lib/holdouts/cold_load_timer.dart` — `ColdLoadTimer.start()` at app init; `ColdLoadTimer.mark("phase")` at each phase boundary; `ColdLoadTimer.report()` writes a per-launch JSON to platform-specific log.
- Modify: `lib/main.dart` — wire `ColdLoadTimer.start()` at `runApp` boundary; call `mark()` at each `setState(() => _stage = …)` boundary inside `BootScreen._boot`. The existing phase strings (`'connecting to mesh'`, `'seeding local corpus (role=…)'`, `'downloading cactus model'`, `'embedding local corpus'`) are the natural mark boundaries.
- Modify: `lib/services/cactus_service.dart`, `lib/services/seed_loader.dart`, `lib/services/retrieval_service.dart` — `mark()` at completion of each sub-phase.
- Test: `test/holdouts/cold_load_timer_test.dart` — synthetic phase sequence + assertion on report format.

**Approach:**
- Phase markers: `app_init_done`, `ditto_initialized`, `sync_started`, `corpus_seeded`, `cactus_completion_downloaded`, `cactus_embedding_downloaded`, `cactus_initialized`, `embeddings_backfilled`, `first_query_submitted`, `first_top_k_returned`, `first_card_buffered`, `first_card_displayed`.
- Report shape: `{ device, total_ms, phases: { ... } }`. Logged to console + a per-launch file for offline analysis.

**H5 remediation playbook (run in order if `total_ms > 10000`):** SEED.md's cut-order names model-size downgrade as the explicit lever; this playbook orders the cheaper levers first so the LLM-shrink option is a last resort, not a first reach. Each step is a single targeted change; re-measure after each before continuing to the next.

1. **Verify model weights are mmap'd, not fully loaded into RAM.** Cactus should default to mmap; confirm via memory profile that the resident set after `load()` is < weights file size. If not, pass the mmap flag (per Cactus SDK) and re-measure.
2. **Move LLM init from "after splash" to "during splash".** Currently `cactus_service.dart` loads eagerly at app init; if the splash screen is non-trivial (animation, asset preload), parallelize the model load against the splash duration so the user-perceived cold-load shrinks.
3. **Reduce `max_tokens` for the first answer to ~128.** R6a's coherence rubric does not require long answers; capping the generation budget cuts the dominant tail-latency component without compromising the rehearsed-query rubric.
4. **Shrink the LLM from 1.7B to 1B class** (SmolLM2 1B variant or equivalent). Per SEED.md cut-order, this is the explicit lever for R5 failures; it compromises R6a's coherence ceiling but preserves the R5 hard bar.

The playbook is ordered cheapest-to-most-disruptive — do not jump steps. Whichever step makes the bar, record it in `_docs/spikes/U14-h5-remediation.md` so the writeup can name the lever used.

**Test scenarios:**
- Happy path: synthetic timer with deterministic phase durations → report matches expected JSON.
- Verification (manual, on physical device): cold launch on slowest target → `total_ms ≤ 10000`. If not, execute the remediation playbook above; **no back-door pass** — documentation alone is not a pass.

**Verification:**
- R5 holdout passes on the slowest target device.
- Report JSON is parseable and contains all expected phase markers.

---

### U15a. Holdouts 3 + 4 — sync idempotence + bidirectional merge

**Goal:** A live-device test that two devices, after BLE meet, converge to the union of their corpora, and a re-meet with no changes produces no duplicates and no top-k drift.

**Requirements:** R3, R4.

**Dependencies:** U5, U7, U8, U9.

**Cut-order tier:** Cuttable at SEED cut-order item 5 (same tier as R6a). If forced, the demo can show R3+R4 manually during the recorded artifact in lieu of the orchestrated runner.

**Files:**
- Create: `lib/holdouts/idempotence_check.dart` — convergence + idempotence detection logic.
- Create: `tools/holdout_34/runner.sh` — orchestrates two devices; commits to a specific mechanism (ADB + Maestro on Android, idb + XCTest on iOS) OR is downgraded to a manual checklist if the orchestration mechanism is out of scope.
- Create: `test/holdouts/idempotence_check_test.dart` — unit tests around convergence-detection logic (no live devices required).

**Approach:**
- Two phases: (1) meet — `DittoService.startSync`, wait for `peerCount == 1`, wait for note count to stabilize (no change for 5s); (2) re-meet — disconnect, reconnect with no edits, assert note counts unchanged + cosine top-k for the fixture topic unchanged.

**Test scenarios:**
- Happy path (R4): A has {T1, T2}, B has {T3}; after meet, both have {T1, T2, T3}.
- Idempotence (R3, covers AE3): re-meet → both still have {T1, T2, T3}; top-k for fixture query identical to pre-re-meet.
- Edge case: meet while sync.start has just been called → no panic; eventual consistency in ≤ 30s.

**Verification:**
- R3 + R4 green on the chosen hardware pair; evidence captured as runner JSON OR recorded-artifact manual checklist sign-off.

---

### U15b. Holdout 7 — end-to-end offline verification (NEVER CUT)

**Goal:** Prove the demo runs with Wi-Fi off, cellular off, BLE on. R7 is the non-droppable Stage-0 floor.

**Requirements:** R7.

**Dependencies:** U5, U8, U9.

**Cut-order tier:** Non-droppable. Held separately from U15a so that R7's evidence survives even if U15a's orchestrated runner is dropped under time pressure.

**Files:**
- Create: `tools/holdout_7/offline_witness.md` — pre-demo checklist (toggle airplane mode, verify Wi-Fi disabled, verify cellular off, manually re-enable BT, screenshot the network indicator); doubles as the demo-day go/no-go gate.
- Modify (optionally): `lib/holdouts/idempotence_check.dart` — surface "network traffic observed" boolean for any platform-level network-monitor capture, if a host-side capture is feasible. If not, the witness checklist is sufficient.

**Approach:**
- The witness step runs immediately before U17's recorded artifact. It's a checked-off pre-demo gate.
- If a host-side network monitor (Charles/Proxyman on a macOS host watching the device pair through a controlled hotspot) is feasible, capture the "no non-Ditto traffic" assertion as a recording-side artifact (this is what verifies U6's `CactusConfig.isTelemetryEnabled = false` pin is actually holding under load). Otherwise, the device-side network indicator + the absence of internet (airplane mode toggle visible on camera per R1) is the canonical evidence.

**Test scenarios:**
- Offline witness: pre-demo checklist signed; airplane-mode indicator visible on both phones in the recording.
- Diagnostic: if a host-side capture is set up, the capture log contains zero non-Ditto request URLs during the recording window.

**Verification:**
- R7 evidence is part of the recorded artifact in U17. The witness checklist is checked in to `tools/holdout_7/`.

---

### U16. Holdouts 6a + 6b — rehearsed coherence dry-run capture + audience-stretch capture

**Goal:** Capture the recorded artifact for R6a (5 of 5 rehearsed topics → coherent card stack with visible source attribution) and, if budget permits, R6b (3 of 5 audience-free topics clean). Includes the corpus pre-screen step from SEED's "Real Environment."

**Requirements:** R6a, R6b stretch.

**Dependencies:** U3 (the rehearsed topic set is authored alongside the corpus), U11 (generation works), U12 (demo flow is rehearsable).

**Files:**
- Create: `_docs/rehearsed-queries.md` — the 5 R6a topics + 5 R6b candidate audience topics + each one's pre-screened-acceptable expected card stack.
- Create: `lib/holdouts/coherence_dryrun.dart` — runs all 5 R6a topics against the combined corpus, captures the generated cards + source IDs to a per-launch JSON for manual review.
- Create: `tools/holdout_357/runner.sh` — chain the R6a capture step after R3/R4/R7.

**Approach:**
- The R6a topics are the writeup's screenshot fodder. They must be picked to feel naturally diverse (not 5 variations of the same template).
- R6b is a 5-minute capture at the end of a real audience session; if 3+ produce coherent card stacks, the recorded artifact includes the segment with audience-quote captions. If not, the segment is cut and the writeup says so.
- Pre-screen step: every plausible audience-direction topic is pre-run against the combined corpus, the top-k inspected, and any note that produces unintended on-screen content is removed from the corpus. The pre-screen is a manual review pass; the holdout captures it as a checklist artifact.

**Test scenarios:**
- Happy path: 5 of 5 R6a queries return non-empty answers with regex-detectable citation IDs.
- Manual review: 5 of 5 are *coherent* (not just well-formed). The reviewer is the demonstrator; the bar is "would I be embarrassed to show this on stage?"
- R6b: 3 of 5 audience queries clean → segment included; else cut.

**Verification:**
- `_docs/rehearsed-queries.md` exists; the 5 R6a queries are captured + reviewed.
- The recorded artifact contains the R6a segment.
- The pre-screen checklist exists and is signed off by the demonstrator before demo day.

---

### U17. Demo day prep — recorded artifact production + final corpus pre-screen

**Goal:** Produce the final recorded artifact (single-take preferred; B-roll for BLE-pairing permitted with on-camera disclosure). Final corpus pre-screen sign-off. Final hardware-pair sign-off.

**Requirements:** R1 + R6a + R7 captured in a coherent ≤ 5-minute video; R8 narrative-pickup setup (the writeup's screenshots come from here).

**Dependencies:** U12, U13, U14, U15, U16, U18 (release builds must succeed before a recording session).

**Files:**
- Create: `_docs/recording-checklist.md` — the demo-day go/no-go checklist (charged phones, BT enabled, airplane-mode toggle path tested, fallback B-roll captured, network monitor armed).
- Create: `slides/media/` — final captured artifact (recorded video, screenshots, mesh-indicator-transition export).
- Modify: `README.md` — add a section pointing at the recorded artifact + the demo-script.

**Approach:**
- Two rehearsal takes minimum before the final take. Each rehearsal logs the cold-load timer report (U14) + the determinism baseline (U13) + the idempotence runner output (U15) as evidence the holdouts cleared on the recorded hardware pair.
- Single-take preferred; if BLE pairing fails on the final take, the disclosed-B-roll fallback path is exercised cleanly per SEED's exit-condition wording.

**Test scenarios:**
- Test expectation: production. The artifact IS the test.

**Verification:**
- The final recorded artifact exists at `slides/media/`.
- The README links to it.
- R1, R6a, and R7 are all visible in the recording.

---

### U18. Platform configuration fixes — iOS Podfile floor + Android ProGuard keep rules

**Goal:** Capture the two platform-level build-config artifacts the Ditto Flutter SDK requires that aren't obvious from `pubspec.yaml` alone. These are real-build pain points: without them, `pod install` fails on iOS and the Ditto native classes are stripped on Android release builds (the app launches, then silently crashes when `sync.start()` calls into a stripped symbol). Documented as a unit because they're load-bearing artifacts the implementer must produce, not just transient debugging.

**Requirements:** R5 (the app has to actually launch), R10 (both platforms must build).

**Dependencies:** U4. Touched again whenever U5/U6 add new Ditto or Cactus surfaces that ProGuard might strip.

**Files:**
- Modify: `ios/Podfile` — raise the iOS deployment target to **15.0** (Ditto v5 SDK floor + objectbox-flutter-libs 15+ floor pulled in transitively via Cactus). Without this, `pod install` errors on the deployment-target mismatch.
- Modify: `android/app/build.gradle.kts` — wire `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")` inside `buildTypes.release`.
- Create: `android/app/proguard-rules.pro` — keep rules for the Ditto v5 KMP native interface (both `live.ditto.**` and `com.ditto.**` namespaces), the rustls platform verifier (Ditto's TLS transport reflects on it at runtime), and KMP closures:
  ```proguard
  # Ditto v5 KMP namespaces (both required)
  -keep class live.ditto.** { *; }
  -keep class com.ditto.** { *; }

  # rustls TLS verifier — Ditto's transport reflects on this at runtime
  -keep, includedescriptorclasses class org.rustls.platformverifier.** { *; }

  # KMP closures used by ditto_live's Kotlin↔Java interop
  -keep class kotlin.jvm.functions.Function* { *; }

  # Suppress the transient-annotation warning kotlinx-serialization emits
  -dontwarn kotlinx.serialization.Transient
  ```

**Approach:**
- The Podfile floor is non-negotiable: Ditto v5 dropped iOS 14, and `objectbox_flutter_libs` (transitive via Cactus) requires iOS 15+. Set `platform :ios, '15.0'` at the top of `ios/Podfile`; the iOS Runner project's `IPHONEOS_DEPLOYMENT_TARGET` should match or `pod install` warns on every run.
- The ProGuard rules narrate the SDKS-3594 / SDKS-2626 backstory in the header comment: ditto_live v4 bundled consumer-rules.pro inside the SDK; v5's KMP rewrite dropped that, so apps must supply equivalents themselves. Without these rules, R8 strips the classes `libdittoffi.so` reflects on, and release builds break in two stages — SIGABRT pre-main "Cannot initialize rustls without SDK class loader", then (once that's fixed) silent TLS failure because `org.rustls.platformverifier.CertificateVerifier` is missing.
- Cactus does not currently require its own keep rule — the package's JNI surface isn't being R8-shrunk or the SDK ships its own consumer-rules. If a future Cactus SDK version adds reflective JNI, this file will need a `-keep class com.cactus.** { *; }` clause; track via the writeup follow-up.
- Verify both: `flutter build ios --release --no-codesign` should complete without Podfile warnings; `flutter build apk --release` followed by `flutter run --release` on a real Android device should reach `DittoService.startSync()` without a `NoSuchMethodError` / `UnsatisfiedLinkError`.

**Patterns to follow:**
- `_inspiration/repos/permissionlesstech__bitchat-android/` — confirm the keep-rules shape against another BLE-mesh Android release build.
- Ditto's public release notes for any SDK-version-specific keep-rule changes.

**Test scenarios:**
- Happy path: `flutter build ios --release --no-codesign` exits 0 with no Podfile-target warnings.
- Happy path: `flutter build apk --release` produces an APK; `flutter run --release` on an Android device reaches the home screen without crashing inside `DittoClient.start()`.
- Edge case: a new Cactus SDK release adds a new JNI-exposed package — release build silently crashes on first inference. Detection: integration test that runs one `embed()` call on a release build, not just debug.

**Verification:**
- Both release builds succeed on the chosen hardware pair.
- A release-mode integration test calling `Ditto.start()` + `Cactus.embed()` runs without `NoSuchMethodError` / `UnsatisfiedLinkError`.
- The `proguard-rules.pro` file is checked in; release builds use it (verify via `build.gradle` `proguardFiles` line).

---

### U19. Presenterm slide deck — thesis, architecture, demo, future-work arc

**Goal:** A Presenterm-rendered Markdown deck framing the demo for the writeup audience: thesis, architecture, latency-floor argument, before/after-sync result, four-thread future-work arc. The recorded artifact from U17 is shown as a live demo (or B-roll) inside the deck; the deck is what makes the demo legible *as a writeup* to readers who weren't in the room.

**Requirements:** R8 (narrative pickup — the deck is the surface that lets a reader unprompted articulate Ditto's role, Cactus's role, and why mesh changes the RAG story).

**Dependencies:** U10 (screenshots), U12 (demo-script narration arc), U17 (final recorded artifact).

**Files:**
- Create: `slides/deck.md` — Presenterm Markdown source for the deck.
- Create: `slides/notes.md` — speaker notes paralleling each slide.
- Create: `slides/media/` — Mermaid architecture export (PNG), before/after-sync screenshots from U10, and the U17 recording as embedded video.

**Approach:**

Eight-slide structure, sized for a ~10-minute walkthrough at comfortable pacing:

1. **Title + one-line thesis** — "Your knowledge base wants to be a CRDT" + presenter name + one-sentence "what you'll see in the next 10 minutes."
2. **The problem with cloud RAG** — physics-bound latency floor + offline-impossible + corpus content routed through a third party. Names the three failure modes the demo avoids.
3. **The latency-floor argument** — cloud RTT ≥ ~200ms physical floor vs on-device < 100ms; citation to `paper-2403.12844` (MELTing Point). The slide that makes the on-device pitch numerical, not aspirational. Latency band uses measurements from `qwen3-1.7` on the chosen hardware pair.
4. **The CRDT insight** — vector index as grow-only set (G-Set), retrieval as pure function over the set. Citation to `paper-1106.4374` (Shapiro et al.). The slide that names the math. Schema example block uses the `StudyNote` shape (`_id, topic, contributor, body, tags, embedding, createdAt, …`).
5. **Architecture diagram (Mermaid)** — Cactus embed + LLM at the leaves, Ditto CRDT in the middle, BLE/LAN/AWDL mesh at the bottom. Export from the High-Level Technical Design section's sequence diagram for visual continuity with the plan.
6. **Live demo** — the U17 recorded artifact embedded, OR a live run if the venue + hardware cooperate. The "moment of magic" is the source-set expansion (attribution footer's peer count moves from 0 to M) when phone B enters BLE range. Stack-summary references `qwen3-1.7` for completion and `qwen3-0.6` for embedding.
7. **What this is + what it isn't** — Stage 0 scope honesty: ships CRDT vector sync + retrieval; Stage 1 ships a streaming flashcard generator; threat-model bound (no peer auth, no provenance signatures, no corpus ACL — see SEED.md). Audience leaves with a sized picture, not an oversold one.
8. **Future-work arc + Q&A** — the four-thread writeup arc from `_docs/research/index/open-questions.md` (specialists → preference-aware merge → adversarial filtering → generational evolution). Landing line: "Family recipes through generations." Contact slide as the visual tail.

Render with Presenterm and export PDF as the shareable artifact: `presenterm slides/deck.md --export-pdf`.

**Patterns to follow:**
- Presenterm exemplar deck at `_inspiration/repos/mfontanini__presenterm/examples/demo.md` — the canonical syntax + slide-transition idioms.
- The four-thread arc in `_docs/research/index/open-questions.md` — load-bearing for slide 8; do not summarize lossy, lift the four-thread structure verbatim.

**Test scenarios:**
- Happy path: `presenterm slides/deck.md` renders all 8 slides without errors; navigation keys work; embedded media (Mermaid PNG, recording) loads.
- Happy path: `presenterm slides/deck.md --export-pdf` produces a shareable PDF.
- Verification (manual): a dry-run of the deck takes ≤ 10 min with comfortable pacing; a reviewer who hasn't seen the demo can articulate slide 7's "what this is + what it isn't" boundary unprompted (R8 dry-run).

**Verification:**
- `slides/deck.md` + `slides/notes.md` exist and render cleanly.
- PDF export exists at `slides/deck.pdf`.
- Dry-run with one external reviewer confirms R8's three-question test passes (Ditto's role, Cactus's role, why mesh changes RAG).

---

## System-Wide Impact

- **Interaction graph.** The Cactus runtime and the Ditto client are both singletons in the app lifecycle. The Cactus runtime owns model files; the Ditto client owns persistence. The retrieval layer materializes a snapshot from Ditto and runs cosine against an in-memory float array — so a Ditto snapshot change invalidates the materialized array. Document this invalidation contract in `lib/services/retrieval_service.dart`.
- **Error propagation.** Cactus model load failure must not crash the app — the UI surfaces a "model not provisioned" state and the user can retry. Ditto sync failure must not block local-only retrieval — Stage 0 retrieval against the local corpus works without a peer. These two properties together preserve the "single phone gives a useful answer even when alone" contract.
- **State lifecycle risks.** The materialized embedding array can lag behind Ditto's snapshot if a sync event lands mid-query — accept the staleness (next query sees the new tuple). Do NOT introduce locking; the CRDT property says re-querying eventually converges.
- **API surface parity.** iOS and Android paths must be functionally identical (same model + quant + backend + embedding length + tuple shape). Platform-specific code is permitted only for OS permission UI and BLE foreground-state handling.
- **Integration coverage.** Unit tests prove serialization + retrieval math. Two-device integration (U15) is what proves merge correctness. The recorded artifact (U17) is what proves the demo works on real hardware.
- **Unchanged invariants.** The `_inspiration/` directory and its yaml manifest are *read-only research materials* — the build does not depend on them at runtime. The `_docs/research/index/` is a documentation artifact; the build doesn't read it either. Both stay clean.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Cactus iOS↔Android embedding parity fails U1's gate | Pivot to brainstorm option C ("Narrate the mesh") per SEED's fallback path. U1's spike output is the artifact that justifies the pivot. |
| iOS background-BLE for "always-on" mesh is unsolved at the OS level (Briar has no iOS app for this reason; bitchat works only foregrounded) | Demo runs foregrounded only. The writeup names this as an OS-level constraint, not a project failure. R7 is unaffected (offline + BLE-foregrounded is still offline). |
| Cactus 1.3.0 SDK surface for embedding + LLM differs from the FFI docs (top-N #2) | U6 reads the actual SDK + writes the Dart wrapper to absorb any name/lifecycle differences. Downstream units depend only on `CactusService`'s surface (`embed`, `embedF32`, `complete`, `completeAll`). |
| Cold-load latency exceeds R5's 10s budget on the slowest target | U14's per-phase report identifies the slowest phase; SEED's cut order has model-size downgrade as the explicit lever and U14's remediation playbook orders the cheaper levers (mmap verification, splash-parallel load, max_tokens cap) before reaching for it. |
| Audience-query miss in R6b damages the writeup story | R6b is explicitly stretch; the recorded artifact omits the segment if it fails. Writeup's narrative survives without it. |
| BLE pairing flaky on demo day | Pre-recorded "airplane mode + meet" capture as fallback B-roll (used with on-camera disclosure per SEED's exit-condition wording); rehearsed LAN-only fallback path; second hardware pair on standby. |
| Memory-pressure crash from loading both models simultaneously on a mid-range Android | Both models load eagerly in `CactusService.initialize()` (sequentially: completion then embedding). Under R5 budget pressure a future revision can add an opt-in `lazyEmbeddings` flag that defers `_embeddingLm.downloadModel` until the first `embed()` call. |
| Cactus 1.3.0 and Ditto 5.0.0 SDK reality | Pinned in U5 and U6: `DittoConfig(databaseID, connect: const DittoConfigConnectSmallPeersOnly())` + `setOfflineOnlyLicenseToken` + `presence.observe` for Ditto; two `CactusLM` instances + `downloadModel` + `initializeModel(CactusInitParams(model, contextSize: 2048))` + `generateEmbedding` + `generateCompletionStream` for Cactus. Embedding dim is not asserted at compile time; `RetrievalService.topK` drops length-mismatched embeddings silently so a model swap is contained at the query boundary. |
| Cactus telemetry default leaks outbound traffic on a "no internet" demo | U6's `initialize()` sets `CactusConfig.isTelemetryEnabled = false` before either `downloadModel` call. U15b's witness verifies zero outbound non-Ditto traffic in the recorded run. |
| Cactus completion mode defaults silently change in a future SDK release | U6 constructs `CactusCompletionParams(maxTokens: …, completionMode: CompletionMode.local)` explicitly so the local-only invariant survives a default change. |

---

## Documentation / Operational Notes

- `README.md` at repo root frames the brainstorm and points at SEED.md. U17 adds a "Demo & recorded artifact" section linking to the recording + the demo script.
- Plan exit condition: every holdout has a checked-in evidence artifact — `tools/determinism_harness/baseline.json` for R2, `_docs/rehearsed-queries.md` for R6a, `slides/media/` recording for R1+R7, `tools/holdout_7/offline_witness.md` for R7. Drop an artifact only with SEED cut-order justification logged inline.
- The writeup post (R8) is a separate plan, NOT covered here. Open it after the recorded artifact lands.

---

## Sources & References

- **Origin document:** `_docs/SEED.md`
- Related context: `_docs/RESEARCH-BRIEF.md`, `_docs/IDEA-A.md`, the project's root `README.md` brainstorm.
- Research index (the load-bearing input for every Key Technical Decision): `_docs/research/index/README.md` → `top-N.md`, `clusters.md` C3 (Ditto), C5 (Cactus + LLM runtimes), C6 (Determinism), C7 (Specialists), C8 (Distributed RAG), C9 (Vector search); `_per_source/` per-citation files referenced inline above.
- Reference implementations under `_inspiration/`: `_inspiration/repos/software-mansion-labs__react-native-rag/`; `_inspiration/repos/deepsense-ai__edge-slm/`; `_inspiration/repos/ramanujammv1988__edge-veda/`; `_inspiration/repos/permissionlesstech__bitchat/` + `_inspiration/repos/permissionlesstech__bitchat-android/`; `_inspiration/cactus-compute/{cactus,cactus-flutter,cactus-react-native}/` (the engine + Flutter + RN packages).
- Future-work writeup arc: `_docs/research/index/open-questions.md` — the four threads (specialists → preference-aware merge → adversarial filtering → generational evolution; family-recipes analogy).