# C4 Step 0 — Interview Notes

**Project:** Mesh RAG demo (Ditto × Cactus, iOS + Android)
**Date:** 2026-05-23
**Drafted by:** the c4-design skill, from the planning artifacts listed in §6.

This file is consumed by Step 1 (`docs/c4/model.c4` generation).

---

## 1. External Actors

Humans and other systems outside the design boundary that touch the system.

### Humans

| Actor ID | Display name | Role |
|---|---|---|
| `demonstrator` | Demonstrator | The single human running the demo on camera. Holds both phones, toggles airplane mode, runs the rehearsed query set, narrates the moment of magic. Also the developer during the build loop. |
| `audience_contributor` | Audience contributor | Stage 1 only: submits a study note before the demo starts (audience-submitted study-notes corpus per the resolved Q1 corpus theme). |
| `audience_querent` | Audience querent | R6b (Holdout 6b) stretch only: picks a free-text query during the demo. |

### Other systems (outbound — system calls OUT to these)

| Actor ID | Display name | Why it's external |
|---|---|---|
| `cactus_model_registry` | Cactus model registry | Hosts the GGUF weights for `qwen3-0.6` (embedding head) and `qwen3-1.7` (LLM). Downloaded *once*, pre-demo, with internet on. Never touched during the demo itself (airplane mode); kept in the model to make the "warmup vs demo" distinction explicit. |

### Other systems (inbound — these call IN to the system)

None. There is no public ingress: no webhooks, no scheduled poll-ers, no partner integrations. The thesis breaks if anything calls in over the network.

### Peer instances (special — same software, different device)

| Actor ID | Display name | Why it deserves modeling |
|---|---|---|
| `peer_phone` | Peer Mesh-RAG phone | Another instance of the *same app* on a paired phone (iOS+Android pair). From any one phone's perspective this is "external" — different process, different device, different operator (in principle). It exchanges Ditto delta-state CRDT payloads over BLE/LAN/AWDL. Modeled as an external "system" because doing otherwise hides the mesh-edge — which is the entire thesis of this design. |

---

## 2. System Boundary

### Inside the boundary (designed here)

- **Mesh-RAG Phone App** — the Flutter binary deployed to both iOS and Android. Same source, two build targets. (`R10` (heterogeneous mobile, plan §Requirements) requires iOS+Android both, not iOS+macOS.)
- **Bundled native runtimes** inside the app process — Cactus engine (embed + LLM via FFI) and Ditto SDK (CRDT store + mesh transports via FFI).
- **On-device persistent state** — Cactus model files (GGUF, in app Documents directory — OS does not evict) and the Ditto local store (CRDT documents + sync metadata, in app data dir).
- **Determinism Harness** — a separate Dart CLI tool at `tools/determinism_harness/` that runs the `R2 (Holdout 2)` cosine-parity gate against fixtures on each device. Pre-flight only; not on a phone at demo time, but materially part of the design.
- **Seed loader assets** — `assets/seed_notes_<role>.json` bundled into the app binary; role-switched by the `PHONE_ROLE` env var at build/run time. (Build-time artifact rather than a container; surfaced here so it doesn't get lost.)

### Outside the boundary (acknowledged but not modeled in detail)

- The Cactus model registry (CDN/HTTPS) — appears as an external system on the Context view; the edge is "pre-demo download" only.
- Operator's developer machine (build host, USB-deploy host, harness runner) — implicit; not modeled.
- Cloud anything (Cactus hybrid mode, big-peer, remote vector stores, internet at all during the demo) — explicit *anti-scope* per `R9` (thesis preservation, plan §Requirements); called out in the writeup, not modeled.

### Explicitly deferred beyond this design pass

- **HNSW / USearch under concurrent CRDT insert.** Flat-array brute-force is the chosen path for ≤5k tuples; index-side merge is its own paper, deferred per the plan's Scope Boundaries section.
- **Document ingestion plumbing** for arbitrary file types (PDFs, EPUBs, archives) — Stage 2, follow-on seed.
- **Multi-user identity / authentication / corpus ACL** — explicitly out per the SEED threat-model bound. The mesh is intentional disclosure to chosen peers, not privacy from peers.
- **Persistent chat history.**
- **Web / desktop clients beyond an optional macOS surface for the writeup screenshots.**
- **The four-thread future-work arc** (adversarial filtering, preference-aware merge, specialist routing, generational evolution) — the writeup gestures at them; this build ships the flat grow-only union only.
- **`writeup_reviewer` actor** (R8 narrative-pickup gate) — modeled in the writeup follow-up plan, not here.

---

## 3. Containers

Deployable units of the inside-boundary system.

| ID | Display name | Technology | Responsibility | External dependencies |
|---|---|---|---|---|
| `phone_app` | Mesh-RAG Phone App | Flutter (Dart 3.8) on iOS (Podfile floor 15.0) and Android (compileSdk 35, minSdk 24, NDK 27, JDK 11) | The user-facing demo binary. Hosts the UI, the Dart service layer, and (in-process via FFI) the Cactus and Ditto native runtimes. Same source, two build targets. | `peer_phone` (mesh sync, runtime); `cactus_model_registry` (one-time pre-demo download). |
| `cactus_models` | Cactus Model Files | GGUF model artifacts on disk (`qwen3-0.6` for embeddings; `qwen3-1.7` for completion) | On-device persistent state Cactus mmaps at launch. Distinct lifecycle from the app: downloaded once, retained across app launches, never modified at runtime. | Populated by `cactus_model_registry` on first launch; read by `phone_app`. |
| `ditto_store` | Ditto Local Store | Ditto v5 on-disk store (DQL-addressable; CRDT delta-state internals) | On-device persistent state for the `notes` collection. Survives app restarts; merge-converges with peer stores under sync. | Synced bidirectionally with the `ditto_store` of any `peer_phone` in range, via the in-app Ditto runtime's transport stack (BLE / LAN / AWDL). |
| `determinism_harness` | Determinism Harness CLI | Dart CLI tool (`tools/determinism_harness/run.dart`) | Pre-flight R2 gate. Runs a fixed 20-query × 20-passage fixture against the chosen Cactus slug pair, reports top-k agreement rate iOS-vs-Android, and checks against a checked-in `baseline.json`. If <95%, the SEED cut-order pivots to brainstorm option C. | Reads embeddings produced on each device (off-device collection mechanism is harness-internal); not networked. |

Cross-check against the plan's origin flows. F1–F5 are inherited from `_docs/plans/001-feat-mesh-rag-demo.md` §Requirements; each is labeled inline below:

- **F1 — corpus authorship + preload** → `phone_app` (SeedLoader component) + `assets/seed_notes_*.json` (build asset).
- **F2 — local query → embed → retrieve → answer (Stage 0)** → `phone_app` end-to-end; `ditto_store` is the retrieval substrate; `cactus_models` is the embed source.
- **F3 — same + buffered LLM generation (Stage 1)** → `phone_app` + `cactus_models` (LLM head).
- **F4 — airplane-mode + BLE-pair → mesh sync → combined-corpus re-query (R1 / Holdout 1)** → edge between two `phone_app` instances via their respective `ditto_store`s.
- **F5 — recorded artifact production** → build-time tooling under `slides/`; not modeled as a runtime container (build-time output; no Container modeled).

The five cross-cuts above each map cleanly. The Determinism Harness is the only container that does not participate in F1–F5 — it's a pre-flight gate, modeled separately.

---

## 4. Component-Level Decomposition

### 4.1 `phone_app` (the meat of the design — decomposed)

16 components, grouped by concern. IDs use Dart-style snake_case to match the file layout in `_docs/plans/001-feat-mesh-rag-demo.md` §Output Structure.

| Component ID | Responsibility |
|---|---|
| `boot_screen` | Splash + init flow (model presence check, Cactus warmup, Ditto identity bring-up, role detection from `PHONE_ROLE`). [`lib/main.dart`] |
| `query_screen` | Two-tab Scaffold (Notes, Flashcards) + `mesh_status_widget` in the AppBar. Top-level demo surface. [`lib/widgets/query_screen.dart`] |
| `notes_tab` | Live notes list grouped by contributor; long-press to accept peer notes into the local OR-Set. [`lib/widgets/notes_tab.dart`] |
| `flashcards_tab` | Topic input + streaming flashcard generation + swipeable stack + rate mode + history. The Stage 1 surface. [`lib/widgets/flashcards_tab.dart`] |
| `mesh_status_widget` | Camera-legible pill in the AppBar: "mesh: alone" (gray) → "mesh: N peers" (green). The visible mesh-edge indicator on stage. [`lib/widgets/mesh_status_widget.dart`] |
| `demo_overlay` | Optional debug HUD (peer count, note count, last-query latency). Off by default; on for rehearsal. [`lib/widgets/demo_overlay.dart`] |
| `study_note_model` | `StudyNote` Dart class + UUIDv5 seed factory + Ditto round-trip + OR-Set acceptance helpers. The data shape. [`lib/models/study_note.dart`] |
| `ditto_service` | Singleton wrapping Ditto SDK: init, transport config (BLE+LAN+AWDL, no big-peer, no Wi-Fi Aware), sync subscription, presence stream, CRUD over `StudyNote`. [`lib/services/ditto_service.dart`] |
| `cactus_service` | Singleton wrapping two `CactusLM` instances (embedding + completion): model download/init, `generateEmbedding(text)`, `generateCompletion(messages)`, `generateCompletionStream(messages)`. [`lib/services/cactus_service.dart`] |
| `seed_loader` | Reads the role-switched `assets/seed_notes_<role>.json` and idempotently UPSERTs into Ditto (UUIDv5 makes the seed loader a no-op on re-run). [`lib/services/seed_loader.dart`] |
| `retrieval_service` | `ensureEmbeddings()` (late backfill), `topK(topic, k)` (flat-array cosine + `(score desc, _id asc)` tie-break), `generateFlashcards(topic)` (returns `Stream<FlashcardEvent>`). The pure retrieval pipeline. [`lib/services/retrieval_service.dart`] |
| `notes_queries` | DQL strings: `selectAll`, `upsert`, `setEmbedding`, `syncSubscription`. Single source of truth for collection name and DQL shape. [`lib/prompts/dql_queries.dart`] |
| `flashcard_gen_prompt` | System prompt + user-message builder for the flashcard-generation LLM call; tolerant parser for `Q:` / `A:` / `SOURCE:` lines. [`lib/prompts/flashcard_gen.dart`] |
| `cold_load_timer` | R5 (Holdout 5) instrument — phase-marked timing report from app launch to first answer. [`lib/holdouts/cold_load_timer.dart`] |
| `idempotence_check` | R3+R4 (Holdouts 3 and 4) instrument — convergence + idempotence detection runner. [`lib/holdouts/idempotence_check.dart`] |
| `coherence_dryrun` | R6a (Holdout 6a) instrument — rehearsed-coherence capture runner. [`lib/holdouts/coherence_dryrun.dart`] |

(One over the cap; the three `lib/holdouts/` instruments are tight in responsibility and worth keeping legible separately.)

### 4.2 `determinism_harness` (decomposed lightly — non-trivial because R2 is the build gate)

| Component ID | Responsibility |
|---|---|
| `harness_fixtures` | 20 fixture queries + 20 fixture passages — checked in. [`tools/determinism_harness/fixtures/queries.json`] |
| `harness_runner` | Two modes: `measure` (produce top-k lists per device) and `check` (compare against `baseline.json` and compute agreement rate). [`tools/determinism_harness/run.dart`] |
| `harness_baseline` | Checked-in top-k baseline for the locked Cactus slug pair (`qwen3-0.6` + `qwen3-1.7`). The R2 gate compares against this. [`tools/determinism_harness/baseline.json`] |

### 4.3 Containers not decomposed (intentionally)

- `cactus_models` — opaque on-disk artifacts; no internal structure worth a Component view.
- `ditto_store` — opaque on-disk CRDT store; internal structure (HLC vector clock, dot-tagged deltas) is library-internal, not pre-code-design surface.

---

## 5. Open Questions (Resolved Inline)

1. **Are Cactus runtime and Ditto runtime separate containers?**
   *Resolution:* No. They are FFI native libraries bundled into the same Flutter binary (single deployable). They're modeled as components inside `phone_app` (`cactus_service` and `ditto_service` are the Dart-side wrappers; the native libs themselves are implementation detail of those components). This keeps the Container view honest about deployability.

2. **Is the peer phone an external actor or a self-edge on the container?**
   *Resolution:* External `system` named `peer_phone`. P2P architectures are clearest when "any other instance" is modeled as an external interactor; otherwise the mesh edge — the entire thesis — disappears into a self-loop annotation. Drawback: the type system says it's an external system when it's actually a sibling instance of the same software. Mitigated with the description field calling that out explicitly.

3. **Is the Determinism Harness in scope?**
   *Resolution:* Yes, as a container. R2 (Holdout 2) is the build gate per the plan ("Determinism gate fires BEFORE the build loop"); leaving the harness out of the C4 model misrepresents what the design *is*. It's not on a phone at demo time, but it's not optional either — without it, the whole project pivots to brainstorm option C.

4. **Audience: one actor or two?**
   *Resolution:* Two — `audience_contributor` (Stage 1 corpus-author role; load-bearing on the audience-as-contributor moment) and `audience_querent` (R6b stretch role; not exit-blocking). They're different interaction shapes even if often the same person.

---

## 6. Source Docs Consulted

Loaded into context before drafting:

- `_docs/SEED.md` — the validation harness, holdouts, cut order, and threat-model bound. Single most load-bearing input.
- `_docs/IDEA-A.md` — the original "Your knowledge base wants to be a CRDT" thesis statement.
- `_docs/RESEARCH-BRIEF.md` — the cars-collection reference shape, the technical anchors, the Stage 0/1 split.
- `_docs/plans/001-feat-mesh-rag-demo.md` — the implementation plan: containers (lib/, tools/, slides/), components (services/, widgets/, holdouts/), the data flow ASCII diagram, the demo-flow sequence diagram.
- `README.md` — the parent brainstorm; the A/B/C/D comparison; the pursued-A frame.
- `MEMORY.md` — auto-memory pointers (specialist-small-models thesis, writeup arc, Stage-1 study-notes corpus theme, the demo-already-exists framing).

Not consulted in this pass (no STRATEGY.md at this scope; `_docs/research/index/` referenced by ID in the plan but not re-walked here).

---

## 7. Deferred / Open Questions

### From 2026-05-23 review

Items surfaced by the ce-doc-review pass on this interview but not resolved in-line. Each carries the reviewer(s) and a one-line frame; full evidence and suggested fixes live in the review artifact.

1. **`notes_queries` + `flashcard_gen_prompt` are files, not components.** Collapse them into the descriptions of their consuming services (`retrieval_service`, `cactus_service`) and drop the count from 16 → 14? (scope-guardian, anchor 75)

2. **Determinism Harness: container or build-gate annotation?** §3 admits it participates in zero of F1–F5. Demote to "build-time tooling" precedent set by the slides deck, or keep as container with deployment-view note? (product-lens + adversarial, anchor 100)

3. **`audience_contributor` is build-time, not runtime.** The mechanism is JSON-asset authorship by the demonstrator pre-build, not a runtime ingest. Reclassify as a build-time contributor (no Context edge), or add a missing runtime ingestion component? (feasibility + adversarial, anchor 100)

4. **`peer_phone` as external system hides bit-identical-software invariant.** The peer being the same binary is what makes R2/R3 correct, but the C4 type system treats it as a foreign integration. Replace with a paired-instance convention or annotate the edge "same binary, same model files"? (adversarial + product-lens, anchor 100)

5. **Determinism Harness embedding-collection mechanism unspecified.** §3 says the harness "reads embeddings produced on each device (off-device collection mechanism is harness-internal)" — but Cactus FFI runs on the phone, not the dev host. Does the harness run on-device, or extract via USB/file-export? (feasibility, anchor 75)

6. **No C4 deliverable for the co-marketing goal.** Every cross-check in §3 is engineering-facing; nothing makes the Ditto-owned / Cactus-owned / glue decomposition legible. Add a vendor-ownership annotation to components, or accept this as out-of-scope for the build C4 model? (product-lens, anchor 75)

7. **FFI boundary hidden in component view.** `cactus_service` and `ditto_service` are modeled as pure Dart components, but the runtime-significant boundary (where R2 determinism and R5 cold-load actually live) is the FFI seam to native Cactus + Ditto libraries. Add a sub-component for each native runtime, or accept the simplification? (adversarial, anchor 75)

8. **`cactus_model_registry` edge under model-missing condition.** `boot_screen` does a model-presence check on launch; if missing, does it fetch from the registry (runtime edge) or fail closed (one-shot setup only)? Affects whether the Context view's registry edge is "always available" or "first launch only". (feasibility, anchor 75)

9. **`audience_querent` has no described path to any component.** Draw the edge to `flashcards_tab`'s topic input, or explicitly omit as stretch-only and orphan the actor? (feasibility, anchor 75)

10. **`peer_phone` cardinality (1 vs 1..N).** Ditto's mesh is N-ary by design; modeling exactly one peer encodes the 2-device demo staging into the architecture. Model as `peer_phone (1..N)` or accept the staging choice? (adversarial, anchor 75)

