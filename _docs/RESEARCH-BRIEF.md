---
internal_only: false
---

# Research Brief: Prior Art for Mesh RAG (Ditto × Cactus)

> Audience: a deep-research agent. You have no prior context on this project. Read the *Project Summary* below, then execute the *Research Tasks* and return the *Required Deliverables*. Cite primary sources with the most stable URL available: arxiv DOI, repo URL + commit/tag when applicable, official docs URL with version or date-accessed when no commit exists. Skip blog-rehashes unless they point to a primary source we'd otherwise miss.

---

## Project Summary (read first)

We are building a peer-to-peer **retrieval-augmented generation (RAG)** system in which the vector index *is* a CRDT — specifically a grow-only set of `{ id, text, embedding[], metadata }` tuples. Each device runs an identical on-device embedding model and an on-device small LLM (via the **Cactus** framework), and stores tuples in **Ditto**, a peer-to-peer document database with BLE/LAN mesh sync. When two devices come into range, Ditto syncs the tuples bidirectionally; each device's next query draws on the combined corpus, with no server and no internet.

The deliverable is a two-device hackathon demo (iOS + Android) plus a writeup. The writeup's thesis is that *retrieval-augmented* is a particularly natural fit for peer-to-peer sync among AI primitives — and that on-device + mesh wins on **latency** and **offline-first** as durable properties (not on cost; see Task 6 for why cost is the wrong axis to argue from).

### Demo staging

The demo has two staged shapes; the brief asks the recipient to gather prior art for both, with Stage 1's audience-participation aspects load-bearing on the writeup if Stage 1 ships:

- **Stage 0 — Static two-device sync.** One iOS phone + one Android phone with pre-loaded corpora. Airplane mode toggled live on camera. The "moment of magic" is that phone A's answer to a query changes after phone B comes into BLE range and tuples sync. Stage 0 is the minimum recorded artifact.
- **Stage 1 — Audience-submitted study-notes merge.** Audience members submit notes on the same study topic (e.g., several attendees' notes on the same lecture or concept). Each phone receives a subset; on sync, the on-device LLM normalizes the merged tuples into coherent consolidated study notes. Stage 1 demonstrates the *RAG* in mesh RAG end-to-end and requires Task 4's structured-list-synthesis research to clear a model-choice bar.

### Glossary

- **Holdouts** — acceptance criteria. The demo is not done until each one is observably true on stage.
- **Moment of magic** — the on-camera beat where the audience can see the corpus compound after the BLE meet (phone A's answer visibly changing).

### Technical anchors

- **Cactus** — an on-device AI framework supporting Flutter, Swift, Kotlin, React Native, C++, Python. *Claims* (to be verified empirically in Task 1 + Holdout 2): ~120ms on-device inference latency, hybrid cloud fallback (we will NOT use the hybrid path), zero-copy memory mapping for embeddings. **Critical-path question:** does Cactus produce top-k-stable embeddings across iOS and Android for the same input + model + weights? See Task 1's contingency block.
- **Ditto** — a peer-to-peer document database with CRDT internals and BLE+LAN mesh sync. The reference shape we can mirror is the `cars` collection; the full spec is inlined below under *Reference: carsapp shape* so the recipient has a self-contained reference. Our Mesh-RAG document is `{ _id: { id, locationId }, text, embedding[], metadata }` — same composite-`_id` and grow-only-collection pattern as carsapp; the merge inherits Ditto's CRDT semantics.

### Reference: carsapp shape

The `cars` collection is Ditto's canonical small-peer demo data. The shape is internal and it's copied here so the recipient research agent has a self-contained reference (Ditto's public docs cover the SDK / DQL / transport layers, not this specific schema).

**Schema** — composite `_id` map plus four top-level fields:

| Field            | Type   | Notes                                                                  |
| ---------------- | ------ | ---------------------------------------------------------------------- |
| `_id.id`         | string | Per-doc identifier. UUIDv4 preferred; monotonic strings also accepted  |
| `_id.locationId` | string | Identifies the writer. Commonly the local peer key or a fixed string   |
| `color`          | string | Lowercase color name (see enum below)                                  |
| `numUpdates`     | number | Bump on each update; write as int or float (`f64` in Rust)             |
| `timestamp`      | number | Unix seconds with fractional part (e.g. `1234567890.123`)              |

**Color enum** (canonical palette, lowercase): `blue, red, yellow, green, cyan, black, magenta, gray`. Apps may render additional colors locally, but documents sent over the wire should stick to this list for cross-app compatibility.

**DQL operations** — every carsapp implements these three:

```sql
-- Insert / upsert
INSERT INTO cars DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE

-- Select (subscribe via `sync.registerSubscription` using the same statement)
SELECT * FROM cars

-- Delete
DELETE FROM cars WHERE _id.id = :id
```

**Cross-SDK compatibility note:** strict-parsing SDKs (C, C++, Swift) silently drop documents if any field is missing or if `_id` is flattened to a string. Composite `_id` is load-bearing.

**Mesh-RAG inherits this shape** with the document body changed and `color`/`numUpdates` dropped:

| Cars field        | Mesh-RAG field   | Notes                                              |
| ----------------- | ---------------- | -------------------------------------------------- |
| `_id.id`          | `_id.id`         | Same pattern (UUIDv4 preferred)                    |
| `_id.locationId`  | `_id.locationId` | Same pattern (device peer key)                     |
| `color`           | —                | Cars-specific; replaced by `text`                  |
| `numUpdates`      | —                | Tuples are immutable post-write in Stage 0         |
| `timestamp`       | `timestamp`      | Same Unix-seconds-with-fraction format             |
| —                 | `text`           | New: the source note/document text                 |
| —                 | `embedding[]`    | New: f32 vector from the on-device embedding model |
| —                 | `metadata`       | New: optional map (source, tags, etc.)             |

Collection name for Mesh-RAG: pick a singular-shaped name following the carsapp convention (e.g., `tuples`, `notes`, or domain-specific) and stick to it across SDKs.
- **Two-device demo:** iOS + Android, airplane mode toggled live on camera.
- **Holdouts** (acceptance criteria, demo is not done until each is observably true):
  - The airplane-mode moment of magic
  - **Top-k retrieval stability across iOS and Android: top-k retrieved set agrees on ≥95% of a fixed eval-query set** (cosine drift reported as diagnostic)
  - Sync idempotence
  - Bidirectional merge observable through queries whose nearest neighbors live on the other device
  - Cold-load latency under ~10s on the slowest target device
  - Full offline operation (only BLE/LAN, no Wi-Fi or cellular)
- **Reusable agent-skills artifact (lower-priority parallel deliverable; ship-or-skip).** Package the demo's reusable parts — the Ditto offline-only sync, maybe Ditto+Cactus pairing for on-device RAG, the embedding-as-CRDT pattern, as agent skills following the Firebase AI assistance skills format (https://firebase.google.com/docs/ai-assistance/agent-skills) and/or the Flutter skills format (https://github.com/flutter/skills) we're already using as the build harness. Build alongside the demo if runway allows; skip if Stage 0/1 holdouts are at risk. The case for this is that the demo's value compounds if future agents can reach for ditto-initializations and maybe mesh-RAG-shaped builds as a skill instead of starting from scratch — this is the answer to "what reusable byproducts outlast the hackathon."

### Adjacent prior art we already know about

Do **not** rediscover these — instead find: (1) follow-up work (≤3 yrs) that extends, critiques, or operationalizes them in an on-device-AI context, and (2) competing frames that propose a different primitive than retrieval for P2P/local-first AI. Both are useful; pure adjacency without novelty pads sources without strengthening the writeup.

- Local-first software essay (Kleppmann, Beyer, Kleppmann, McGranaghan, van Hardenberg — Ink & Switch, 2019). Confirmed adjacent — but examples are documents/text, not embeddings or RAG. Task 6 should specifically articulate where local-first-for-documents and local-first-for-RAG diverge: failure modes, merge semantics, what a CRDT actually buys when merged objects are vectors rather than text.
- The Shapiro / Preguiça / Burckhardt CRDT line of papers.
- Standard cloud-RAG architecture (embed → vector DB → top-k → LLM) — we are *contrasting* with this, not re-explaining it.
- Ditto's `cars` collection as the canonical demo shape.
- Cactus's published latency claims (~120ms on-device, hybrid fallback, mmap) — published, not independently verified.

### Out of scope by thesis (collect bounded, for rebuttal in the writeup)

- Chat-history sync, weight sync, KV-cache sync as the AI-meets-P2P primitive. *We are arguing retrieval is the right primitive. Do not collect prior art exhaustively, but DO surface the 3 strongest counter-articulations under Task 9 so the writeup has a sourced rebuttal.*
- Cost-comparison material vs. cloud RAG. *Same posture as above: thesis is latency + offline; Task 6 surfaces the strongest "cost is the wrong axis" arguments rather than ignoring the question.*

### Motivating context — why now

Google I/O 2026 (May 2026) put cloud-anchored AI-on-sync directly on the roadmap for the canonical competing stack: Firebase is shipping AI features as part of its sync-and-storage offering ([I/O keynote](https://io.google/2026/explore/pa-keynote-13); [Firebase blog summary](https://firebase.blog/posts/2026/05/google-io-2026-announcements/)). The cloud-anchored answer to "AI composes with sync" is now an explicit product direction, not a hypothetical. Mesh RAG argues the local-first answer to the same composition question — the relevant question for the writeup is not "is anyone doing AI + sync?" (yes, the biggest vendor) but "is the local-first shape qualitatively different on latency / offline / trust-boundary?" Task 6 should map Firebase's stated edge-AI direction against the mesh-RAG framing.

### Internal team commitments (orchestrator addendum)

These are project commitments, not instructions to the recipient:
- We will NOT use Cactus's hybrid cloud-fallback path. The thesis breaks if we cheat with cloud.
- This is a public hackathon repo (license-aware sourcing matters).
- Source-of-truth for the carsapp reference shape is the private `~/Work/ditto/examples` checkout (cross-SDK: `carsapp` (C), `carsapp-cpp`, `carsapp-flutter`, `carsapp-rust`, `DittoCarsApp` (Swift)). For our Flutter target, mimic the layout of `carsapp-flutter` — file structure, sync subscription wiring, document-store observer registration. Recipient research agents do NOT have access to this repo; the recipient-facing shape spec above (Technical anchors → Ditto bullet) is the self-contained reference.

---

## Research Tasks

For each topic below, return: the strongest 3–8 primary sources, what each contributes, and where it falls short for our use case. Canonical sources may be older for CRDT theory and local-first software; for tooling, see the consolidated recency rule under *Constraints*.

### 1. On-device embedding determinism & cross-platform reproducibility

This is the riskiest technical claim. The CRDT merge is meaningless if device A and device B produce different top-k retrieved sets for the same query against an identical corpus.

- **Cactus** specifically: official docs, GitHub repo, model packaging story, any release-notes or issue threads that address cross-platform numerical parity. Find the Cactus model catalog and the deterministic-output guarantees (or lack thereof). *Maintainer-authored GitHub issues / discussions are in-scope sources here — primary-source rule waived for this and Task 4 because the hard-won determinism knowledge lives at that layer.*
- Cross-runtime determinism in adjacent frameworks: **llama.cpp** (CPU + Metal + CUDA + Vulkan determinism), **MLC LLM**, **ExecuTorch (PyTorch mobile)**, **Apple Core ML**, **Apple MLX**, **TensorFlow Lite**, **ONNX Runtime Mobile**. How do they each handle float determinism across CPU/GPU/NPU backends?
- Vendor accelerator quirks: **Apple Neural Engine**, **Qualcomm Hexagon NPU**, **MediaTek APU**. Known divergences from CPU reference output.
- Quantization and reproducibility: int8 / int4 / GGUF quantization schemes — do they preserve bit-equivalent outputs across runtimes? See llama.cpp GGUF docs, MLX-LM, AWQ, GPTQ.
- Academic: any arxiv papers on **numerical reproducibility of transformer inference across hardware backends**.
- **Threshold question (load-bearing on Holdout 2):** What threshold of embedding agreement is sufficient for retrieval-result stability on small corpora? Is top-k-set agreement ≥95% a defensible bar, or do we need bit-equivalence? Cite any empirical work on embedding-perturbation tolerance for top-k retrieval.

**Contingency block — if Cactus determinism is undocumented or falsified.** If the search returns no primary source on Cactus's cross-platform determinism:
1. Report explicitly as a Deliverable-5 gap.
2. Identify which underlying runtime Cactus wraps on each platform (e.g., llama.cpp + Metal on iOS, llama.cpp + Vulkan on Android) and report *that* runtime's determinism story.
3. Propose a holdout-test protocol (model + 50 inputs + agreement threshold) we can run ourselves in a half-day to settle the question empirically.
4. Identify the smallest bridging work that would restore determinism without swapping the stack (build flag, model format, shared runtime path). The stack lock is on the writeup's framing, not on a willingness to learn.

### 2. CRDT vector indexes / mergeable knowledge stores

Has anyone treated an embedding store as a CRDT? Or merged vector indexes across replicas without a central coordinator?

**If primary sources on CRDT-native vector indexes don't exist as established research terms — likely, as of 2026-05 — say so plainly and route the gap to Open Research Questions. Do not pad with tangential CRDT-or-vector-but-not-both sources.**

- Direct prior art: search arxiv, GitHub, and engineering blogs for "CRDT vector index", "mergeable vector store", "decentralized vector search", "local-first RAG", "peer-to-peer RAG", "P2P RAG".
- **HNSW, IVF, PQ** indexes over CRDTs — what breaks when the index is grow-only and never centrally rebuilt? Reports from anyone running HNSW with concurrent inserts across replicas.
- CRDT framework prior art applied to AI workloads: **Automerge**, **Yjs**, **Loro**, **diamond-types**, **Riak**, **Antidote**. Have any of these been used to store embeddings or related ML state?
- Adjacent: **OrbitDB** + IPFS embeddings, **Earthstar** for personal-data sync with AI, **Iroh** + ML state, **Willow Protocol**.

### 3. Peer-to-peer / mesh sync infrastructure on mobile (Ditto + alternatives)

- **Ditto** SDK official docs: small-peer model, BLE transport, LAN transport, mesh topology, conflict resolution, query language (DQL). Look for any RAG-shaped uses of Ditto in public material (blog posts, demo writeups, conference talks). The canonical `cars` shape — composite `_id` schema and the upsert/observe/delete DQL trio — is the reference; the Mesh-RAG demo's only deviation is the document body (text + embedding instead of color + counter).
- iOS↔Android BLE interop: known pain points, what the working setups look like, public reports from Ditto users.
- Alternative mesh-sync stacks worth comparing the architecture against (so we can defend "why Ditto"): **libp2p** mobile builds, Apple's **MultipeerConnectivity**, Google's **Nearby Connections API**, **Bridgefy**, **Briar's BTP**, **IPFS** mobile, **Iroh**, **Earthstar**, **Willow**. **Research only far enough to produce a 1–2 sentence architectural contrast with Ditto for the writeup's defense section — do not evaluate as deployment candidates.**
- **Firebase's edge-AI direction** (per Google I/O 2026): characterize what Firebase ships for AI-on-sync, what its trust / latency / offline shape looks like, and where it explicitly *doesn't* go (true mesh between devices in BLE range). This is the cloud-anchored counterpart to our local-first claim; the writeup needs a sourced comparison.

### 4. On-device LLM inference frameworks (the small-LLM ecosystem)

We need a small LLM that runs at acceptable latency on a mid-range Android and a mid-range iPhone, ships in Cactus, and produces coherent answers given small retrieved context. *Maintainer-authored GitHub issues, conference-talk videos, and engineering blogs from the framework team are in-scope here — primary-source rule waived for this task.*

- **Cactus** model catalog: which models are pre-packaged, what their on-device latency looks like, what the deployment story is for shipping the same model to iOS and Android.
- Comparable mobile LLM frameworks: **llama.cpp** (and `llama.swift` / `llama.android` wrappers), **MLC LLM**, **ExecuTorch**, **Apple MLX**, **MediaPipe LLM Inference**, **ONNX Runtime GenAI**, **TensorFlow Lite LLM**.
- Small-LLM candidates: **Phi-3-mini**, **Phi-4-mini**, **Llama 3.2 1B / 3B**, **Gemma 2 2B / Gemma 3 small**, **Qwen 2.5 1.5B**, **SmolLM2 1.7B**, **Granite 3 2B**, **TinyLlama**. Cite benchmarks for mobile latency + quality on RAG-style "small corpus, short retrieved context" prompts.
- **Structured-list merge / aggregation quality at small parameter counts (gates the Stage 1 demo).** Stage 1's audience-submitted study-notes merge needs the on-device LLM to normalize / synthesize notes from multiple attendees on the same topic (e.g., several students' notes on a single lecture or concept) into coherent consolidated study notes. Find benchmarks or anecdotal reports on small LLMs (≤3B) doing structured-list reconciliation: fact merging, deduplication, claim consolidation. At what parameter count does this task stop being terrible? **If no targeted eval exists (likely), return (a) the closest analogous evals — SummEval, BFCL, IFEval, and any note-aggregation- or multi-document-summarization-shaped evals — with what they do and don't cover, and (b) a recommended micro-eval protocol we could run ourselves in a half-day to pre-screen models on 5–10 hand-crafted study-notes merge cases.** Corpus options under consideration (audience-submitted study-notes variants on a common topic, generic notes, Ditto-canonical `cars` notes) — recommend findings on structured-list synthesis in general, with worked examples in the study-notes domain.
- **Audience join-flow latency** (relevant for Stage 1; informs the Stage 0 vs Stage 1 ship decision). How prior hackathon and conference demos handled the join-flow latency (people typing on phones inside a tight demo window): real-time polling (Slido, Mentimeter, Kahoot), "virtual potluck"-shape conference activities, and any audience-input-driven on-device-AI demos. Anecdotal blog posts and conference postmortems are acceptable here.
- Licensing landmines on the model side: Llama community license restrictions, Gemma terms of use, anything else with patent grants we'd inherit by redistributing weights in a public demo repo.

### 5. On-device embedding models + vector search

- Embedding models that run on mobile and produce competitive cosine separation: **all-MiniLM-L6-v2**, **BGE-small / BGE-base**, **GTE-small**, **jina-embeddings-v3-small**, **Nomic Embed v1.5**, **EmbeddingGemma** (verify existence before citing), **bge-micro**, **stella_en_400M_v5**. Cite mobile latency benchmarks if available.
- On-device vector search libraries: **sqlite-vss**, **USearch** (Unum), **Faiss-mobile**, **Vald-lite**, **annoy**, raw cosine over an array. Trade-offs at our scale: target ~50 tuples/device for Stage 0, upper bound ~500/device with ~5000 combined for Stage 1+ as audience submissions accumulate.
- Hybrid retrieval (BM25 + dense) — relevant if dense alone underperforms on tiny corpora, which is a known regime hazard.

### 6. Local-first AI / offline-first AI prior art (and writeup framing)

- The Kleppmann et al. Ink & Switch local-first software essay — confirmed adjacent; we cite it but need the *latest* local-first AI follow-ons. Specifically articulate where local-first-for-documents (Kleppmann's worked examples) and local-first-for-RAG (our claim) diverge.
- Local-first AI projects: **Subconscious**, **Notesnook** AI, **Logseq** AI plugin, **Anytype** AI, **Obsidian** local-AI plugins. What's their stance on sync between devices?
- Conference talks. *Note: Strange Loop retired after 2023 — its archive is canonical-only (recency rule waived for those talks); do not search for new editions.* In-scope: **Local-First Conf** 2024/2025 editions, **!!Con**, **P99 CONF**, **NeurIPS workshops** on on-device / efficient AI, **MLSys**, and individual on-device-AI talks from generalist venues.
- Edge-AI / on-device-AI manifestos worth quoting in the writeup: a16z's pieces on edge AI, recent essays on "AI on the edge" with a latency or offline framing.
- Public writing arguing on-device beats cloud on **latency** or **offline-first** specifically (NOT cost). Find the *strongest articulations* of each — both supporting AND adjudicating. We need to name the counterargument by its sharpest form, not the strawman.
- **Google I/O 2026 / Firebase + AI framing** ([keynote](https://io.google/2026/explore/pa-keynote-13), [Firebase summary](https://firebase.blog/posts/2026/05/google-io-2026-announcements/)). Firebase is the canonical cloud-anchored sync product and now ships AI as part of the bundle. For the writeup, characterize: (a) what Firebase's AI features actually do (on-device inference? cloud inference with edge cache? hybrid?), (b) how Firebase frames the trust boundary and offline story, (c) the strongest published or community comparison of Firebase-style sync-with-AI vs mesh-with-AI. This is the dominant alternative direction at the moment the writeup lands.
- **Cost-as-wrong-axis sourcing.** Find the strongest published arguments that cost is a transient/unreliable basis for durable architectural decisions in AI (cloud-price-war history, model-cost-decline curves). We're choosing not to argue cost and need a one-paragraph sourced defense of that choice.

### 7. Latency floors and "the network round-trip is the moat" argument

This is the writeup's load-bearing claim. We want to defend it rigorously. **Scope this task to latency numbers and round-trip floors only — do not compare cloud vector-store architectures, pricing, or feature sets.**

- Published p50 / p99 latency numbers for cloud vector-store APIs: **Pinecone**, **Weaviate Cloud**, **Qdrant Cloud**, **Turbopuffer**, **MongoDB Atlas Vector Search**, **Chroma Cloud**. Region-aware vs. cross-region.
- Round-trip latency lower bounds: speed-of-light floors over geographic distance, typical mobile cellular RTT, typical Wi-Fi RTT.
- On-device retrieval + on-device generation end-to-end latency reports: what's the realistic 50–500ms regime on modern phones?
- Any benchmark paper comparing local vs. remote RAG end-to-end latency.
- **Counter-case sourcing.** Find the strongest published counter-cases — where cloud beats on-device on latency once you account for cold-load, connection reuse, model-quality differences, or warm-vector-cache effects. We need to name the strongest counterargument explicitly.

### 8. Hackathon demo presentation tooling

Slide-deck and recording infrastructure for the demo artifact. The audience-participation prior art moved to Task 4 because it informs the Stage 0/Stage 1 ship decision; what remains here is presentation craft only.

- **Presenterm** docs, themes, and exemplar decks for technical demos. Alternatives: **Sli.dev**, **RemarkJS**, **revealjs**, and lower-tech (Keynote + screen capture). Decks for hackathon-shaped on-device-AI demos worth studying.
- Memorable on-device-AI demo writeups (good and bad): **Recall**, **Rewind**, **Granola**, **Apple Intelligence demos**. What makes a small on-device demo legible to a non-technical audience?
- **Ditto's** canonical `cars`-collection demo writeups — find what they do well in framing P2P "moment of magic" moments.

### 9. Adversarial sourcing — counter-thesis findings

The writeup's thesis is a *comparative* claim (RAG is the most P2P-natural AI primitive). This task collects the rebuttals we need to anticipate.

- The 3 strongest published or community arguments that **chat history** is equally or more naturally P2P (Matrix, Automerge text CRDTs, Yjs collaborative-doc work, per-user-log CRDTs).
- The 3 strongest published or community arguments that **model weights** are equally or more naturally P2P (FedAvg, federated SGD, gboard federated learning, federated-fine-tuning, LoRA-delta sync).
- The 3 strongest published or community arguments that **KV-cache or other AI substrates** are P2P-natural (any community-level sketches; this is the thinnest category and may genuinely be empty).
- For each: cite the strongest articulation, summarize the argument in 2–3 sentences, and note in one sentence what we'd need to say in rebuttal.

This task explicitly inverts the otherwise-shared "Authoritative > popular" rule: opinionated essays and maintainer-team blog posts that articulate a counter-position are the right sources here, not arxiv preprints.

---

## Required Deliverables

Return a single Markdown document with these sections (any section may be short or empty if the search returns nothing material — an empty section with a one-sentence explanation is better than padded filler):

1. **Top 10 must-read sources** — ranked, with one-paragraph annotations. These are the things every engineer joining this hackathon should read first.
2. **Per-topic findings** — one section per Research Task. Include sources (URL + author + date), a 2–3 sentence "what it gives us", and an explicit "gap" line (what it does *not* solve for our case).
3. **Tool shortlist** — concrete decisions. For each of: on-device embedding model, on-device LLM, on-device vector search lib, slide-deck framework — give: candidates, repo URL, last-release date, license, approximate activity level (active / maintenance-mode / dormant — eyeballed from the repo landing page), mobile-platform support matrix, and a one-sentence "use it / don't / maybe + why." For **Cactus** and **Ditto**, the verdict is locked to "use it"; research these for *configuration only* (recommended Ditto small-peer settings, Cactus model packaging for our target devices). Flag licensing landmines for shortlisted candidates — fetch and skim the LICENSE file for each.
4. **Reference architectures** — 2–5 existing projects whose layout, demo shape, or on-device pipeline we should mimic. Link to specific files/dirs. For each, a 2–3 sentence "what is structurally analogous to our use case." (This is sourcing existing patterns to copy from, not proposing novel architecture.)
5. **Open research questions** — gaps where we'll have to invent. Task 1 determinism verdict (pass/fail/unknown) belongs here as a *named verdict line*, not buried in per-topic findings.
6. **Adversarial findings** — output from Task 9. The strongest counter-thesis arguments and what they'd take to rebut.
7. **Source ledger** — flat deduplicated list of every URL cited, one per line. Format: `URL` only, no commentary, in order of first appearance. Duplicates removed. (Consumed by a downstream automation step that does URL extraction.)

## Constraints on the search

- **Authoritative > popular by default, but maintainer-level secondary sources are in-scope for Tasks 1, 4, and 9.** Prefer arxiv preprints, official docs, primary repos, conference talks (with video), and engineering blogs from the team that built the thing. For determinism (Task 1), structured-list-merge quality (Task 4), and adversarial counter-thesis (Task 9), maintainer-authored GitHub issues/discussions, HN threads from maintainers, and engineering tweets that link to specific code or PRs are often the only signal — include them and label them as such.
- **Show your work on adjacency.** When a source is *almost* relevant but not quite, say what's analogous and what's different. Near-misses teach us as much as direct hits.
- **Recency rule (single rule, no conjunction).** For tooling, prefer the current stable release docs and any major change-notes from the last ~18 months. Foundational announcements and format specs (GGUF spec, MLC launch posts, ExecuTorch announcement, original framework whitepapers) are canonical regardless of age — cite the original even if older.
- **Don't pad.** If a topic has only two good sources, return two. Section-presence ≠ content-mandatory.
- **Flag licensing landmines on the Tool shortlist specifically.** Model licenses (Llama, Gemma, etc.), GPL/AGPL libraries, patent-grant clauses. This is a public hackathon repo. License-check at the Tool-shortlist level, not on every cited source.
- **Cactus + Ditto are the chosen stack.** Find prior art that helps us *succeed with them* (Cactus configuration, Ditto config), and adjacent comparisons (Task 3 alternatives) only deep enough to defend the choice in the writeup's defense section. *If Task 1 surfaces a strong falsifier for Cactus determinism, flag the smallest restoration (build flag, model format, runtime swap) without proposing a wholesale stack swap. See Task 1's Contingency block.*

## Scope guardrails (don't bother)

- Don't research general transformer architectures or LLM training. We are using off-the-shelf models.
- Don't research embedding-model training or fine-tuning. Off-the-shelf only.
- Don't research production RAG architectures (re-ranking, multi-hop retrieval, query rewriting, fancy chunking strategies). Stage 0 is naive top-k.
- Don't research cloud vector-store SaaS architectures, pricing, or feature sets. (Latency numbers are still wanted under Task 7 per its own scope note.)
- Don't propose *novel* architectures or write new code. Pointing to existing architectures to mimic (Deliverable #4) is the sourcing exercise, not a violation of this rule.
- Don't research generic Flutter / Swift / Kotlin tutorials.

---

*Brief authored: 2026-05-21. Updated 2026-05-23 with ce-doc-review auto-resolved fixes. Companion to [SEED.md](SEED.md). Output expected at `{OUTPUT_PATH}` (set by the orchestrator) or returned inline. In Mode B, cross-provider runs (claude / codex / gemini) execute this brief independently against the same inputs; a separate orchestrator-owned synthesis step deduplicates Source ledgers and reconciles divergent findings. Each provider's output should be self-contained — do not assume the others' output.*
