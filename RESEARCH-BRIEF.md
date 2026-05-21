---
internal_only: false
---

# Research Brief: Prior Art for Mesh RAG (Ditto × Cactus)

> Audience: a deep-research agent. You have no prior context on this project. Read the *Project Summary* below, then execute the *Research Tasks* and return the *Required Deliverables*. Cite primary sources (arxiv DOI, repo URL + commit/tag, official docs URL). Skip blog-rehashes unless they point to a primary source we'd otherwise miss.

---

## Project Summary (read first)

We are building a peer-to-peer **retrieval-augmented generation (RAG)** system in which the vector index *is* a CRDT — specifically a grow-only set of `{ id, text, embedding[], metadata }` tuples. Each device runs an identical on-device embedding model and an on-device small LLM (via the **Cactus** framework), and stores tuples in **Ditto**, a peer-to-peer document database with BLE/LAN mesh sync. When two devices come into range, Ditto syncs the tuples bidirectionally; each device's next query draws on the combined corpus, with no server and no internet.

The deliverable is a two-device hackathon demo (iOS + Android) plus a writeup. The writeup's thesis is that *retrieval-augmented* is the AI primitive most naturally aligned with peer-to-peer sync — more so than chat history, more so than weights, more so than caches — and that on-device + mesh wins on **latency** and **offline-first** as durable properties (not on cost).

Concrete technical anchors:

- **Cactus** — an on-device AI framework supporting Flutter, Swift, Kotlin, React Native, C++, Python. Claims ~120ms on-device inference latency, hybrid cloud fallback (we will NOT use the hybrid path), and zero-copy memory mapping for embeddings. Critical-path question: does Cactus give us *identical* embedding outputs across iOS and Android for the same input + model + weights?
- **Ditto** — a peer-to-peer document database with CRDT internals and BLE+LAN mesh sync. The canonical demo data is the `cars` collection. We will store `{ id, text, embedding[], metadata }` tuples and rely on Ditto's grow-only semantics for the merge.
- **Two-device demo:** one iOS phone + one Android phone, airplane mode toggled live on camera. The "moment of magic" is that phone A's answer to a query changes after phone B comes into BLE range and tuples sync.
- **Holdouts** include the airplane-mode moment of magic, embedding determinism (cosine ≥ 0.999) across iOS and Android, sync idempotence, bidirectional merge observable through queries, cold-load latency under ~10s on the slowest target device, and full offline operation (only BLE/LAN, no Wi-Fi or cellular).

Adjacent prior art we already know about (do **not** spend research budget rediscovering — instead find what's *adjacent* or *competing*):

- Local-first software essay (Kleppmann, Beyer, Kleppmann, McGranaghan, van Hardenberg — Ink & Switch, 2019).
- The Shapiro / Preguiça / Burckhardt CRDT line of papers.
- Standard cloud-RAG architecture (embed → vector DB → top-k → LLM) — we are *contrasting* with this, not re-explaining it.
- Ditto's `cars` collection as the canonical demo shape.
- Cactus's published latency claims (~120ms on-device, hybrid fallback, mmap).

Out of scope by thesis:
- Chat-history sync. Weight sync. KV-cache sync. We are arguing *retrieval* is the right primitive — do not collect prior art that would dilute that argument.
- Cost-comparison material vs. cloud RAG. The thesis is latency + offline-first; cost is explicitly NOT the framing.

---

## Research Tasks

For each topic below, return: the strongest 3–8 primary sources, what each contributes, and where it falls short for our use case. Prefer recent (≤ 3 yrs) for on-device AI tooling; canonical sources may be older for CRDT theory and local-first.

### 1. On-device embedding determinism & cross-platform reproducibility

This is the riskiest technical claim. The CRDT merge is meaningless if device A and device B produce different vectors for the same text.

- **Cactus** specifically: official docs, GitHub repo, model packaging story, any release-notes or issue threads that address cross-platform numerical parity. Find the Cactus model catalog and the deterministic-output guarantees (or lack thereof).
- Cross-runtime determinism in adjacent frameworks: **llama.cpp** (CPU + Metal + CUDA + Vulkan determinism), **MLC LLM**, **ExecuTorch (PyTorch mobile)**, **Apple Core ML**, **Apple MLX**, **TensorFlow Lite**, **ONNX Runtime Mobile**. How do they each handle float determinism across CPU/GPU/NPU backends?
- Vendor accelerator quirks: **Apple Neural Engine**, **Qualcomm Hexagon NPU**, **MediaTek APU**. Known divergences from CPU reference output.
- Quantization and reproducibility: int8 / int4 / GGUF quantization schemes — do they preserve bit-equivalent outputs across runtimes? See llama.cpp GGUF docs, MLX-LM, AWQ, GPTQ.
- Academic: any arxiv papers on **numerical reproducibility of transformer inference across hardware backends**.

### 2. CRDT vector indexes / mergeable knowledge stores

Has anyone treated an embedding store as a CRDT? Or merged vector indexes across replicas without a central coordinator?

- Direct prior art: search arxiv, GitHub, and engineering blogs for "CRDT vector index", "mergeable vector store", "decentralized vector search", "local-first RAG", "peer-to-peer RAG", "P2P RAG".
- **HNSW, IVF, PQ** indexes over CRDTs — what breaks when the index is grow-only and never centrally rebuilt? Reports from anyone running HNSW with concurrent inserts across replicas.
- CRDT framework prior art applied to AI workloads: **Automerge**, **Yjs**, **Loro**, **diamond-types**, **Riak**, **Antidote**. Have any of these been used to store embeddings or related ML state?
- Adjacent: **OrbitDB** + IPFS embeddings, **Earthstar** for personal-data sync with AI, **Iroh** + ML state, **Willow Protocol**.

### 3. Peer-to-peer / mesh sync infrastructure on mobile (Ditto + alternatives)

- **Ditto** SDK official docs: small-peer model, BLE transport, LAN transport, mesh topology, conflict resolution, query language (DQL). Find the canonical example apps and any RAG-shaped uses.
- iOS↔Android BLE interop: known pain points, what the working setups look like, public reports from Ditto users.
- Alternative mesh-sync stacks worth comparing the architecture against (so we can defend "why Ditto"): **libp2p** mobile builds, Apple's **MultipeerConnectivity**, Google's **Nearby Connections API**, **Bridgefy**, **Briar's BTP**, **IPFS** mobile, **Iroh**, **Earthstar**, **Willow**.

### 4. On-device LLM inference frameworks (the small-LLM ecosystem)

We need a small LLM that runs at acceptable latency on a mid-range Android and a mid-range iPhone, ships in Cactus, and produces coherent answers given small retrieved context.

- **Cactus** model catalog: which models are pre-packaged, what their on-device latency looks like, what the deployment story is for shipping the same model to iOS and Android.
- Comparable mobile LLM frameworks: **llama.cpp** (and `llama.swift` / `llama.android` wrappers), **MLC LLM**, **ExecuTorch**, **Apple MLX**, **MediaPipe LLM Inference**, **ONNX Runtime GenAI**, **TensorFlow Lite LLM**.
- Small-LLM candidates: **Phi-3-mini**, **Phi-4-mini**, **Llama 3.2 1B / 3B**, **Gemma 2 2B / Gemma 3 small**, **Qwen 2.5 1.5B**, **SmolLM2 1.7B**, **Granite 3 2B**, **TinyLlama**. Cite benchmarks for mobile latency + quality on RAG-style "small corpus, short retrieved context" prompts.
- **Structured-list merge / aggregation quality at small parameter counts.** The candidate demo corpus is recipes (audience-submitted variants of the same dish, e.g., chicken tortilla soup) that the on-device LLM must normalize / synthesize into a coherent merged recipe after Ditto sync. Find benchmarks or anecdotal reports on small LLMs (≤ 3B) doing structured-list reconciliation: ingredient merging, deduplication, quantity normalization. Specifically: at what parameter count does this task stop being terrible? Is there a published eval (e.g., SummEval-style or list-aggregation-specific) we can use to pre-screen models? This question gates the corpus choice in [SEED.md](SEED.md) and the answer should be explicit in the deliverable.
- Licensing landmines on the model side: Llama community license restrictions, Gemma terms of use, anything else with patent grants we'd inherit by redistributing weights in a public demo repo.

### 5. On-device embedding models + vector search

- Embedding models that run on mobile and produce competitive cosine separation: **all-MiniLM-L6-v2**, **BGE-small / BGE-base**, **GTE-small**, **jina-embeddings-v3-small**, **Nomic Embed v1.5**, **EmbeddingGemma** (if it exists), **bge-micro**, **stella_en_400M_v5**. Cite mobile latency benchmarks if available.
- On-device vector search libraries: **sqlite-vss**, **USearch** (Unum), **Faiss-mobile**, **Vald-lite**, **annoy**, raw cosine over a ≤5000-item array. Trade-offs at our scale (≤ ~50–500 tuples per device; combined ≤ ~5000).
- Hybrid retrieval (BM25 + dense) — relevant if dense alone underperforms on tiny corpora, which is a known regime hazard.

### 6. Local-first AI / offline-first AI prior art (and the writeup framing)

- The Kleppmann et al. Ink & Switch local-first software essay — confirmed adjacent; we cite it but need the *latest* local-first AI follow-ons.
- Local-first AI projects: **Subconscious**, **Notesnook** AI, **Logseq** AI plugin, **Anytype** AI, **Obsidian** local-AI plugins. What's their stance on sync between devices?
- Conference talks: **Local-First Conf** (any edition with on-device AI talks), **Strange Loop** sessions on edge AI / local-first AI, **Mobile@Scale** talks on on-device inference.
- Edge-AI / on-device-AI manifestos worth quoting in the writeup: a16z's pieces on edge AI, recent essays on "AI on the edge" with a latency or offline framing.
- Public writing arguing on-device beats cloud on **latency** or **offline-first** specifically (NOT cost). Find the strongest articulations of each.

### 7. Latency floors and "the network round-trip is the moat" argument

This is the writeup's load-bearing claim. We want to defend it rigorously.

- Published p50 / p99 latency numbers for cloud vector-store APIs: **Pinecone**, **Weaviate Cloud**, **Qdrant Cloud**, **Turbopuffer**, **MongoDB Atlas Vector Search**, **Chroma Cloud**. Region-aware vs. cross-region.
- Round-trip latency lower bounds: speed-of-light floors over geographic distance, typical mobile cellular RTT, typical Wi-Fi RTT.
- On-device retrieval + on-device generation end-to-end latency reports: what's the realistic 50–500ms regime on modern phones?
- Any benchmark paper comparing local vs. remote RAG end-to-end latency.

### 8. Hackathon demo aesthetics + presentation tooling

Lower-priority but useful. The primary deliverable is a working repo + a Presenterm slide deck.

- **Presenterm** docs, themes, and exemplar decks for technical demos. Alternatives: **Sli.dev**, **RemarkJS**, **revealjs**, and lower-tech (Keynote + screen capture). Decks for hackathon-shaped on-device-AI demos worth studying.
- Memorable on-device-AI demo writeups (good and bad): **Recall**, **Rewind**, **Granola**, **Apple Intelligence demos**. What makes a small on-device demo legible to a non-technical audience?
- **Ditto's** canonical `cars`-collection demo writeups — find what they do well in framing P2P "moment of magic" moments.
- **Audience-participation demos** worth studying: live-submission-driven demos (e.g., real-time polling, "virtual potluck"-shape conference activities) and any prior hackathon demos that pulled audience input into the on-device corpus. Particularly: how they handled the join-flow latency (people typing on phones) inside a tight demo window.

---

## Required Deliverables

Return a single Markdown document with these sections:

1. **Top 10 must-read sources** — ranked, with one-paragraph annotations. These are the things every engineer joining this hackathon should read first.
2. **Per-topic findings** — one section per Research Task. Include sources (URL + author + date), a 2–3 sentence "what it gives us", and an explicit "gap" line (what it does *not* solve for our case).
3. **Tool shortlist** — concrete decisions we need to make. For each of: on-device embedding model, on-device LLM, on-device vector search lib, mesh-sync layer (Ditto config), slide-deck framework — give: candidate(s), repo URL, last-release date, license, maintenance health (commits in last 90 days, open-issue trend), mobile-platform support matrix, and a one-sentence "use it / don't / maybe + why."
4. **Reference architectures** — 2–5 projects whose layout, demo shape, or on-device pipeline we should mimic or steal from. Link to the specific files/dirs. For each, a 2–3 sentence "what to copy."
5. **Open research questions** — things you searched for and *couldn't* find good prior art on. These are real gaps and tell us where we will have to invent.
6. **Source ledger** — flat deduplicated list of every URL you cite, one per line, no commentary. This is consumed by a downstream automation step.

## Constraints on the search

- **Authoritative > popular.** Prefer arxiv preprints, official docs, primary repos, conference talks (with video), and engineering blogs from the team that built the thing. Skip Medium reposts, listicles, AI-generated summaries, low-signal Twitter/X threads.
- **Show your work on adjacency.** When a source is *almost* relevant but not quite, say what's analogous and what's different. Near-misses teach us as much as direct hits.
- **Recency matters for tooling, less for theory.** On-device LLM frameworks from > 18 months ago are likely superseded; the 2019 local-first essay is not.
- **Don't pad.** If a topic has only two good sources, return two. If it has fifteen, prune to the strongest five plus a "see also."
- **Flag licensing landmines.** Model licenses (Llama, Gemma, etc.), GPL/AGPL libraries, patent-grant clauses — call them out explicitly. This is a public hackathon repo.
- **Cactus + Ditto are the chosen stack.** Find prior art that helps us *succeed with them*, plus enough adjacent comparisons to credibly defend the choices in the writeup. Do not propose swapping them.

## Scope guardrails (don't bother)

- Don't research general transformer architectures or LLM training. We are using off-the-shelf models.
- Don't research embedding-model training or fine-tuning. Off-the-shelf only.
- Don't research production RAG architectures (re-ranking, multi-hop retrieval, query rewriting, fancy chunking strategies). Stage 0 is naive top-k.
- Don't research cloud vector-store SaaS as alternatives. They are the contrast, not the option set. (Latency numbers are still wanted under Task 7 — but not architecture comparisons.)
- Don't research chat-history sync, weight sync, or KV-cache sync as the AI-meets-P2P primitive. The thesis is *retrieval*.
- Don't research cost comparisons. Thesis is latency + offline.
- Don't propose architectures or write code. This is a sourcing exercise.
- Don't research generic Flutter / Swift / Kotlin tutorials.

---

*Brief authored: 2026-05-21. Companion to [SEED.md](SEED.md). Output expected as `docs/research/{claude,codex,gemini}.md` (Mode B, cross-provider) or returned inline.*
