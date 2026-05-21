# Top 12 Must-Read Sources for Mesh RAG

> Ranked. Read top-down. Stop when your question is answered. Each entry: a one-paragraph annotation explaining what it gives us and what it doesn't. Sources are pulled from `_per_source/` and validated against the Mode B worker findings in `docs/research/claude.md`.

---

## 1. Thinking Machines Lab — "Defeating Nondeterminism in LLM Inference" (Sep 2025)

The single most load-bearing source for Mesh RAG's riskiest claim: cross-device embedding parity. Reframes LLM non-determinism as a *batch-invariance* problem in matmul / RMSNorm / attention kernels (not floating-point or concurrency), and demonstrates bitwise-identical outputs across 1,000 runs after rewriting three reduction kernels. Tells us *what to engineer for* (single-sample inference paths, fixed reduction order) and *what not to chase* (FP non-associativity in isolation). Companion code: [repo-thinking-machines-lab-batch-invariant-ops](_per_source/repo-thinking-machines-lab-batch-invariant-ops.md). Read this before designing the embedding-determinism holdout. — https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/

## 2. Ditto official docs — Mesh, Transports, DQL, and Delta-State CRDTs

[docs-docs-ditto-live](_per_source/docs-docs-ditto-live.md), [docs-docs-ditto-live-transports](_per_source/docs-docs-ditto-live-transports.md), [docs-docs-ditto-live-dql](_per_source/docs-docs-ditto-live-dql.md). The mesh architecture (BLE + LAN + AWDL + Wi-Fi Aware + WebSockets, all aggregated by the Ditto Multiplexer), the small-peer model, the Ditto Query Language, and the delta-state CRDT semantics with HLC-keyed version vectors. This is the implementation surface Mesh RAG sits on top of; read these *before* designing the `RecipeTuple` document shape. Companion engineering post: ["An inside look at Ditto's Delta State CRDTs"](https://www.ditto.com/blog/dittos-delta-state-crdts).

## 3. SHIMI — Semantic Hierarchical Memory Index for Scalable Agent Reasoning (Vora et al., arXiv 2504.06135, Apr 2025)

The closest published prior art to "treat the memory layer as a CRDT." SHIMI is a decentralized hierarchical concept-tree memory architecture for agents, synchronized via CRDT-style merging + Merkle-DAG summaries + Bloom filters. We are doing the same shape (CRDT-merged memory store, no central index) but at flatter granularity (tuples, not concept trees) and on phone-class peers over BLE. Read for the *architecture rhyme*; gap is they target server-class peers and agent reasoning. — [_per_source/paper-2504.06135.md](_per_source/paper-2504.06135.md) — https://arxiv.org/abs/2504.06135

## 4. MobileRAG — A Fast, Memory-Efficient, and Energy-Efficient Method for On-Device RAG (Wang et al., arXiv 2507.01079, Jul 2025)

Direct prior art for the local hot path. Measures end-to-end on-device RAG on real phones with EcoVector ANN + SCR selective content reduction, showing 1.72–8.89× retrieval-latency speedup and 10.7–54.5% memory reduction vs baselines. The implementation patterns are reusable verbatim; the gap is single-device — no syncing across peers. Pair with EdgeRAG ([paper-2412.21023](_per_source/paper-2412.21023.md)) for the second mobile-RAG benchmark. — [_per_source/paper-2507.01079.md](_per_source/paper-2507.01079.md) — https://arxiv.org/abs/2507.01079

## 5. Kleppmann et al. — Local-First Software (Onward! 2019, Ink & Switch)

The foundational manifesto for the writeup. Frame against the seven ideals (no spinners, work offline, sync seamlessly, longevity, privacy, user agency, "you own your data"); cite directly when arguing retrieval is the AI primitive that aligns with these. Cited extensively by Mode B Claude worker and informs the writeup's "latency + offline-first, not cost" framing. — https://www.inkandswitch.com/essay/local-first/

## 6. MELTing Point — Mobile Evaluation of Language Transformers (Laskaridis et al., arXiv 2403.12844, 2024)

The best on-device LLM benchmark. MELT harness, real iOS + Android devices, llama.cpp and MLC-LLM backends, measured energy + latency + accuracy, plus the empirical finding that on-device inference is memory-bound and quantization is an accuracy-vs-fit trade. Use its numbers for the latency-floor argument. Pair with MobileAIBench ([paper-2406.10290](_per_source/paper-2406.10290.md)) for iOS-side instrumentation. — [_per_source/paper-2403.12844.md](_per_source/paper-2403.12844.md) — https://arxiv.org/abs/2403.12844

## 7. EmbeddingGemma — Powerful and Lightweight Text Representations (Google, arXiv 2509.20354)

308M-parameter multilingual embedding model, sub-22ms on EdgeTPU, <200MB quantized, Matryoshka dims (128–768), top open <500M on MTEB. Strongest candidate for Mesh RAG's embedding stage if Cactus packages it; cleanest license under Gemma terms. — [_per_source/paper-2505.09388.md](_per_source/paper-2505.09388.md) — https://arxiv.org/abs/2509.20354

## 8. DittoPOS + Ditto Inventory Demo Apps — official cross-platform reference

Production-quality Ditto reference apps showing real-time cross-platform BLE+LAN sync on iOS + Android. **The closest existing reference for the kind of demo we're building** — peer discovery UX, mesh-state visualization, multi-platform CRDT merge in user view. The recipe corpus replaces the inventory/POS corpus; everything else (mesh discovery, conflict resolution, sync indicator) is the same problem shape. — [_per_source/repo-getditto-demoapp-pos-kds.md](_per_source/repo-getditto-demoapp-pos-kds.md), [_per_source/repo-getditto-demoapp-inventory.md](_per_source/repo-getditto-demoapp-inventory.md)

## 9. bitchat (iOS + Android) — open-source BLE-mesh chat

[repo-permissionlesstech-bitchat-android](_per_source/repo-permissionlesstech-bitchat-android.md), [repo-permissionlesstech-bitchat](_per_source/repo-permissionlesstech-bitchat.md). The clearest 2025 reference for what a working iOS↔Android BLE mesh looks like outside the Ditto stack: peer discovery UX, foregrounding requirements, mesh-state affordances, E2E encryption. We're not copying the chat protocol (we have Ditto for that), but the *mesh-state UX* is the same problem the demo needs to solve.

## 10. sqlite-vec + USearch — on-device vector search escape hatches

[repo-asg017-sqlite-vec](_per_source/repo-asg017-sqlite-vec.md), [repo-unum-cloud-usearch](_per_source/repo-unum-cloud-usearch.md). For Stage 0 we use a flat float32 array (~5k tuples × 384 dims = 7.7 MB; exact recall, sub-ms, CRDT-trivial). If we ever cross 10k tuples, USearch is the right ANN escape (Apache-2.0, single-header C++, iOS + Android bindings). sqlite-vec is the right persistence-fused option if we move embeddings outside Ditto. Read these together when designing the retrieval module's swap surface.

## 11. Qwen3 Embedding paper + repo (arXiv 2506.05176)

[paper-2506.05176](_per_source/paper-2506.05176.md), [repo-qwenlm-qwen3-embedding](_per_source/repo-qwenlm-qwen3-embedding.md). The other strong embedding candidate. Top MTEB multilingual leaderboard score, Cactus already packages Qwen3-Embedding-0.6B, Apache-2.0 license (cleanest of the candidates). Read alongside EmbeddingGemma — the practical question is which of the two Cactus exposes most cleanly to both Swift and Kotlin with bitwise-identical outputs.

## 12. Numerical Sources of Nondeterminism (arXiv 2602.17099) + Conflict-Free Vector Indices (arXiv 2506.09501)

[paper-2602.17099](_per_source/paper-2602.17099.md), [paper-2506.09501](_per_source/paper-2506.09501.md). Two complementary lenses on the embedding-parity problem: 2602.17099 quantifies FP32 vs FP16 vs BF16 cross-GPU divergence (BF16 is worst, INT4/INT8 quantized paths most stable); 2506.09501 frames the same problem from the CRDT-side ("how do we keep vector indices consistent across peers without coordination"). Together they bracket the engineering envelope for the cosine-determinism holdout.

---

## What's NOT in this list (and why)

- **Faiss (paper-2401.02385, repo-facebookresearch-faiss)** — load-bearing in centralized vector search but our Stage 0 brute-forces over a flat array; Faiss is escape-hatch territory at our scale. Read only if you outgrow the array.
- **CRDT foundational theory (paper-1106.4374, Shapiro/Preguiça)** — load-bearing as background but we don't design new CRDT semantics, we use Ditto's. Read if you're stuck on conceptual ground; skip if you're shipping.
- **HNSW papers (paper-2407.07871, paper-2505.11783, paper-2507.17647, paper-2401.02385)** — relevant if we use HNSW; we don't, Stage 0 is flat array. Negative examples for the writeup.
- **LoRA / DistilBERT / LoRA Land (paper-2106.09685, paper-1910.01108, paper-2405.00732)** — load-bearing for the *future-work* arc (specialist small models). Read when drafting the writeup, not when implementing Stage 0.
- **iroh / libp2p / Earthstar / Willow / Yjs / Loro / OrbitDB** — all *alternatives* to Ditto. Don't read for implementation; read only to defend the Ditto choice in the writeup or to identify what a non-Ditto rewrite would cost.
- **Presenterm / Slidev / reveal.js** — slide-deck tooling. Read when starting the deck, not before.
