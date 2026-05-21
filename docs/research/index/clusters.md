# Thematic Clusters

> Ten clusters covering all 69 indexed sources. Within each cluster, sources are ordered by density (5 = load-bearing → 1 = peripheral). One sentence per source: what makes it cluster-fit. Where a source legitimately belongs to multiple clusters, it appears in each (e.g., bitchat is in both *Ditto & mesh-sync* and *Demo references*).

---

## 1. Ditto & mesh-sync infrastructure (the chosen stack)

These are the docs and demos you implement against directly. Read first.

- (5) [docs-docs-ditto-live](_per_source/docs-docs-ditto-live.md) — official Ditto docs on mesh formation, BLE+LAN transport, CRDT conflict resolution, small-peer model.
- (5) [docs-docs-ditto-live-transports](_per_source/docs-docs-ditto-live-transports.md) — multi-transport architecture (BLE, LAN, AWDL, Wi-Fi Aware, WebSocket) and the Multiplexer.
- (5) [docs-docs-ditto-live-dql](_per_source/docs-docs-ditto-live-dql.md) — Ditto Query Language, SQL-like declarative syntax for distributed queries.
- (5) [docs-ditto-live](_per_source/docs-ditto-live.md) — automatic mesh data sync, subscription model.
- (5) [repo-getditto-demoapp-pos-kds](_per_source/repo-getditto-demoapp-pos-kds.md) — DittoPOS — cross-platform iOS+Android BLE-mesh demo. Closest reference for our demo shape.
- (5) [repo-getditto-demoapp-inventory](_per_source/repo-getditto-demoapp-inventory.md) — Ditto Inventory demo — counter-based CRDT sync, presence-aware.
- (3) [repo-getditto-demoapp-chat](_per_source/repo-getditto-demoapp-chat.md) — Ditto Chat demo. Messaging shape, less aligned to RAG than POS/Inventory.
- (3) [repo-getditto-samples](_per_source/repo-getditto-samples.md) — catalog of Ditto sample apps across Swift / Kotlin / C# / Electron / Rust / MAUI.

## 2. Mesh-sync alternatives (the "why Ditto" defense)

Read only if you need to defend the Ditto choice in the writeup, or to understand what swapping it would cost.

- (5) [repo-n0-computer-iroh](_per_source/repo-n0-computer-iroh.md) — iroh: QUIC-based P2P with hole-punching + relay fallback. Strongest non-BLE alternative but doesn't do BLE.
- (5) [repo-earthstar-project-willow-rs](_per_source/repo-earthstar-project-willow-rs.md) — Willow Protocol Rust impl. Partial sync with capabilities + destructive edits.
- (5) [repo-permissionlesstech-bitchat-android](_per_source/repo-permissionlesstech-bitchat-android.md) — bitchat for Android — production cross-platform BLE mesh, mesh-state UX reference.
- (4) [repo-permissionlesstech-bitchat](_per_source/repo-permissionlesstech-bitchat.md) — bitchat for iOS — dual transport (BLE mesh + Nostr fallback).
- (4) [repo-earthstar-project-earthstar](_per_source/repo-earthstar-project-earthstar.md) — Earthstar TypeScript P2P storage. CRDT-adjacent semantics.
- (3) [docs-bridgefy-sdk](_per_source/docs-bridgefy-sdk.md) — commercial mesh SDK. License-restricted; not for us.
- (2) [repo-libp2p-go-libp2p](_per_source/repo-libp2p-go-libp2p.md) — libp2p (Go). Heavyweight on mobile.
- (2) [repo-orbitdb-orbitdb](_per_source/repo-orbitdb-orbitdb.md) — IPFS-backed CRDT DB. Web-native, not mobile-first.
- (1) [docs-mesh-networking-101](_per_source/docs-mesh-networking-101.md) — generic mesh intro. Background only.

## 3. CRDT theory & frameworks (background — Ditto subsumes most of this)

Read when stuck on conceptual ground for the writeup.

- (5) [paper-1106.4374](_per_source/paper-1106.4374.md) — Shapiro et al. foundational CRDT paper. The mathematical bedrock.
- (5) [paper-2504.06135](_per_source/paper-2504.06135.md) — SHIMI. Closest published cousin to "memory layer as a CRDT."
- (3) [paper-2506.09501](_per_source/paper-2506.09501.md) — CRDT-based vector index consistency. Direct topic-fit.
- (3) [paper-2505.00443](_per_source/paper-2505.00443.md) — Local-first computing principles paper.
- (3) [repo-loro-dev-loro](_per_source/repo-loro-dev-loro.md) — Loro. Modern CRDT lib (Rust + JS + Swift). Not our stack but illustrative.
- (3) [repo-yjs-yjs](_per_source/repo-yjs-yjs.md) — Yjs. Production CRDT library with provider ecosystem.

## 4. Embedding determinism & numerical reproducibility (the riskiest holdout)

The literature converges on three rules: (a) batch=1 sidesteps most non-determinism, (b) INT4/INT8 quantization is dramatically more stable than FP16/BF16 across hardware, (c) same backend tier on both phones — don't let each device pick optimum.

- (5) [paper-2602.17099](_per_source/paper-2602.17099.md) — Numerical Sources of Nondeterminism. Quantifies FP32 vs FP16 vs BF16 cross-GPU divergence.
- (5) [paper-2402.00841](_per_source/paper-2402.00841.md) — Deterministic Transformer Inference Across Hardware.
- (4) [paper-2402.04351](_per_source/paper-2402.04351.md) — Numerical Stability of Transformer Inference. Companion lens.
- (4) [paper-2402.01613](_per_source/paper-2402.01613.md) — Embeddings and Determinism in Small Language Models.
- (4) [paper-2509.20354](_per_source/paper-2509.20354.md) — Deterministic Embeddings and Reproducible Semantic Search.
- (3) [repo-thinking-machines-lab-batch-invariant-ops](_per_source/repo-thinking-machines-lab-batch-invariant-ops.md) — PyTorch kernel substitutions for batch-invariance.
- (2) [docs-docs-pytorch-org](_per_source/docs-docs-pytorch-org.md) — PyTorch reproducibility reference docs.

## 5. On-device LLM frameworks & benchmarks (model selection)

- (5) [repo-ggml-org-ggml](_per_source/repo-ggml-org-ggml.md) — GGUF format + ggml runtime. The substrate Cactus / llama.cpp / many others sit on.
- (4) [paper-2403.12844](_per_source/paper-2403.12844.md) — MELT. Mobile LLM benchmark; iOS + Android + Jetson.
- (4) [paper-2406.10290](_per_source/paper-2406.10290.md) — MobileAIBench. iOS instrumentation harness.
- (3) [paper-2409.00088](_per_source/paper-2409.00088.md) — On-Device Small LLM Inference & Latency Characterization.
- (3) [repo-mlc-ai-mlc-llm](_per_source/repo-mlc-ai-mlc-llm.md) — MLC LLM. Multi-platform compiler; Cactus alternative.
- (3) [repo-google-ai-edge-gallery](_per_source/repo-google-ai-edge-gallery.md) — Google AI Edge Gallery. LiteRT + Gemma UI/UX reference.

## 6. On-device embedding models + vector search (retrieval layer)

- (5) [paper-2505.09388](_per_source/paper-2505.09388.md) — EmbeddingGemma. Primary candidate.
- (5) [paper-2506.05176](_per_source/paper-2506.05176.md) — Qwen3 Embedding. Other primary candidate.
- (5) [paper-1908.10084](_per_source/paper-1908.10084.md) — Sentence-BERT. Foundational sentence-embedding work.
- (5) [paper-2401.02385](_per_source/paper-2401.02385.md) — Faiss library paper.
- (5) [repo-asg017-sqlite-vec](_per_source/repo-asg017-sqlite-vec.md) — sqlite-vec. iOS + Android-ready SQLite vector extension.
- (5) [repo-facebookresearch-faiss](_per_source/repo-facebookresearch-faiss.md) — Faiss canonical repo.
- (4) [repo-unum-cloud-usearch](_per_source/repo-unum-cloud-usearch.md) — USearch. Single-header C++ HNSW, mobile-ready.
- (4) [repo-qwenlm-qwen3-embedding](_per_source/repo-qwenlm-qwen3-embedding.md) — Qwen3 Embedding repo.
- (3) [paper-2404.14219](_per_source/paper-2404.14219.md) — Efficient Vector Search and Quantization for Edge Deployment.
- (3) [paper-2412.04922](_per_source/paper-2412.04922.md) — ANN for distributed vector indices.
- (3) [repo-spotify-annoy](_per_source/repo-spotify-annoy.md) — Annoy. Tree-based ANN; lighter than HNSW.
- (2) [repo-developermindset-com-faiss-mobile](_per_source/repo-developermindset-com-faiss-mobile.md) — Faiss mobile port. iOS only; Android missing.
- (2) [repo-ukplab-sentence-transformers](_per_source/repo-ukplab-sentence-transformers.md) — Sentence Transformers framework.

## 7. End-to-end on-device RAG implementations (reference architectures)

The closest implementations to what we're building (minus the mesh part).

- (5) [paper-2507.01079](_per_source/paper-2507.01079.md) — MobileRAG. EcoVector + SCR; 1.72–8.89× speedup.
- (5) [paper-2412.21023](_per_source/paper-2412.21023.md) — EdgeRAG. 131% retrieval-latency improvement on accelerated edge.
- (5) [paper-2301.07788](_per_source/paper-2301.07788.md) — Original RAG paper (foundational).
- (4) [repo-deepsense-ai-edge-slm](_per_source/repo-deepsense-ai-edge-slm.md) — Edge SLM. Phi-2 + TinyLlama + gte on Samsung S20/S24. Working Android RAG pipeline.
- (4) [repo-ramanujammv1988-edge-veda](_per_source/repo-ramanujammv1988-edge-veda.md) — Edge-Veda. Flutter managed runtime, supervised worker isolate.
- (4) [repo-software-mansion-labs-react-native-rag](_per_source/repo-software-mansion-labs-react-native-rag.md) — React Native RAG framework. Modular LLM / embeddings / vector-store seams to copy.

## 8. HNSW & approximate-nearest-neighbor (Stage 0 brute-forces; this is escape-hatch territory)

- (4) [paper-2407.07871](_per_source/paper-2407.07871.md) — Enhancing HNSW for Real-Time Updates. The "unreachable points phenomenon" under concurrent inserts.
- (3) [paper-2507.17647](_per_source/paper-2507.17647.md) — SHINE — HNSW for disaggregated memory. Server-class.
- (1) [paper-2505.11783](_per_source/paper-2505.11783.md) — d-HNSW. Server-class disaggregated memory. Off-topic for us; negative example.
- (2) [paper-2308.14963](_per_source/paper-2308.14963.md) — "Lucene Is All You Need." Argument against dedicated vector stores.

## 9. Specialist small models / parameter-efficient adaptation (future-work arc)

For the writeup's "next move is specialists, not generalists" thread. Not Stage-0 implementation reading.

- (4) [paper-2405.00732](_per_source/paper-2405.00732.md) — LoRA Land. 310 specialized 7B LoRAs rivaling GPT-4 on narrow tasks.
- (4) [paper-1910.01108](_per_source/paper-1910.01108.md) — DistilBERT. Canonical compression reference.
- (3) [paper-2505.14992](_per_source/paper-2505.14992.md) — Schema-aware Information Extraction Using On-Device LLMs. Most directly relevant to recipe-merge eval.
- (2) [paper-2106.09685](_per_source/paper-2106.09685.md) — LoRA. Original parameter-efficient fine-tuning paper.
- (2) [repo-unickcheng-logseq-ai-assistant](_per_source/repo-unickcheng-logseq-ai-assistant.md) — Logseq AI plugin. Local-knowledge + LLM pattern.

## 10. Local-first / writeup framing + demo tooling

- (3) [docs-developer-apple-com](_per_source/docs-developer-apple-com.md) — Apple Foundation Models docs. Production on-device LLM patterns.
- (2) [repo-slidevjs-slidev](_per_source/repo-slidevjs-slidev.md) — Slidev. Markdown deck framework.
- (2) [repo-hakimel-reveal-js](_per_source/repo-hakimel-reveal-js.md) — reveal.js. HTML deck framework.
- (1) [repo-mfontanini-presenterm](_per_source/repo-mfontanini-presenterm.md) — Presenterm. Terminal-native Markdown deck. (Density-1 from the Map agent; the user's stated primary choice — worth elevating in practice. See *Caveats* note below.)

### Caveats on the cluster ordering

- Several sources legitimately could be density 4 or 5 that the Map agents scored lower (notably **Presenterm**, which the user explicitly chose as the primary deck framework — Map agent scored it 1 as a generic CLI tool without knowing project context). Don't take density scores as authoritative when the context-specific role is known; treat them as "how universally relevant does this look out of context" rather than "how much does this matter for our specific project."
- The off-topic HNSW papers (d-HNSW, SHINE) are kept in the index because they're useful *negative examples* for the writeup — "we are explicitly not in the regime where scale-up HNSW matters."
